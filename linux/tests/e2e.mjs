// End-to-end test: real server (dry run, so nothing is launched or rebooted)
// and the real launcher page in headless Chromium, driven by key presses.
// Run: node linux/tests/e2e.mjs [screenshot-dir]
import { spawn } from "node:child_process";
import { createRequire } from "node:module";
import assert from "node:assert/strict";
import path from "node:path";

const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PLAYWRIGHT_PATH || "playwright");
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const shots = process.argv[2];
const PORT = 8499;
const base = `http://127.0.0.1:${PORT}`;

const server = spawn("python3", [path.join(root, "server/amber_server.py")], {
  env: { ...process.env, AMBER_PORT: String(PORT), AMBER_DRY_RUN: "1" },
  stdio: "inherit",
});
const browser = await chromium.launch();
let failed = false;
try {
  for (let i = 0; i < 50; i++) {
    try { await fetch(`${base}/api/catalog`); break; } catch { await new Promise((r) => setTimeout(r, 100)); }
  }
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
  const outside = [];
  page.on("request", (req) => { if (!req.url().startsWith(base)) outside.push(req.url()); });
  const errors = [];
  page.on("pageerror", (err) => errors.push(err.message));
  await page.goto(base);
  await page.waitForSelector("#grid .tile");

  const focused = () => page.evaluate(() => {
    const tile = document.querySelector(".tile.focused");
    return tile ? tile.parentElement.id + ":" + tile.querySelector(".name").textContent : null;
  });
  const press = async (...keys) => { for (const k of keys) await page.keyboard.press(k); };
  const commands = async () => (await fetch(`${base}/api/commands`)).json();

  assert.equal(await page.locator("#grid .tile").count(), 8, "8 tiles");
  assert.equal(await focused(), "grid:Netflix", "first tile focused at start");
  assert.equal(await page.locator(".tile.focused").count(), 1, "exactly one focus ring");
  if (shots) await page.screenshot({ path: `${shots}/linux-home-empty.png` });

  await press("ArrowRight");
  assert.equal(await focused(), "grid:YouTube");
  await press("Enter");
  assert.match(await page.textContent("#message"), /Opening YouTube/);
  await page.waitForFunction(() => !document.querySelector("#recentRow .tile").hidden);
  assert.deepEqual((await commands()).at(-1), ["/opt/amber/bin/amber-play", "https://www.youtube.com/"]);

  await press("ArrowUp");
  assert.equal(await focused(), "recentRow:YouTube", "up into recent");
  await press("ArrowDown", "ArrowDown", "ArrowRight");
  assert.equal(await focused(), "grid:Network check", "down to second row");
  if (shots) await page.screenshot({ path: `${shots}/linux-home.png` });

  // Drawer: Left at column 0 opens it; focus ring hidden while open.
  await press("ArrowLeft", "ArrowLeft");
  assert.equal(await page.isVisible("#drawer"), true, "drawer open");
  assert.equal(await page.locator(".tile.focused").count(), 0, "no tile ring under drawer");
  assert.equal(await page.isVisible("#home .hint"), false, "hint hidden under drawer");
  await press("ArrowDown");
  if (shots) await page.screenshot({ path: `${shots}/linux-drawer.png` });
  await press("Escape");
  assert.equal(await focused(), "grid:Hulu", "focus restored after drawer");

  // Settings via the "Network check" tile; Back returns with focus intact.
  await press("ArrowRight", "Enter");
  assert.equal(await page.isVisible("#settings"), true);
  assert.equal(await page.textContent("#panelHeading"), "Diagnostics");
  await press("Escape");
  assert.equal(await focused(), "grid:Network check", "focus restored after settings");

  // Power: first OK only arms the confirmation; second OK runs it.
  await press("m");
  for (let i = 0; i < 4; i++) await press("ArrowDown");
  await press("Enter");
  assert.equal(await page.textContent("#panelHeading"), "Power");
  await press("ArrowRight", "ArrowRight", "Enter");
  assert.equal(await page.textContent(".button.focused"), "Press OK again to shut down");
  const before = (await commands()).length;
  assert.equal((await commands()).length, before, "nothing run on first OK");
  await press("Enter");
  await page.waitForFunction(async () => true);
  await new Promise((r) => setTimeout(r, 200));
  assert.deepEqual((await commands()).at(-1), ["systemctl", "poweroff"]);

  // Any other key cancels a pending confirmation.
  await press("ArrowLeft", "Enter", "ArrowRight");
  assert.equal(await page.textContent("#buttons .button:nth-child(1)"), "Restart");

  // Clear recent from Settings: Recent empties and the setting reports zero.
  await press("Escape", "ArrowUp", "ArrowUp", "ArrowUp", "Enter");
  assert.equal(await page.textContent("#panelHeading"), "Recent apps");
  await press("Enter");
  assert.match(await page.textContent("#panelBody"), /0 tiles are listed/);
  if (shots) await page.screenshot({ path: `${shots}/linux-settings.png` });
  await press("Escape", "Escape");
  assert.equal(await page.isVisible("#recentEmpty"), true);

  // Scales to a 720p screen without overflow.
  await page.setViewportSize({ width: 1280, height: 720 });
  const box = await page.locator("#grid .tile").last().boundingBox();
  assert.ok(box.x + box.width <= 1280 && box.y + box.height <= 720, "fits 720p");

  assert.deepEqual(outside, [], "no requests outside the local server");
  assert.deepEqual(errors, [], "no page errors");
  console.log("e2e: all checks passed");
} catch (err) {
  failed = true;
  console.error("e2e FAILED:", err.message);
} finally {
  await browser.close();
  server.kill();
}
process.exit(failed ? 1 : 0);
