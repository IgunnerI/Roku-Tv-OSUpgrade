// Unit tests for the launcher's pure logic. Run: node --test linux/tests/
import test from "node:test";
import assert from "node:assert/strict";
import { navMove, navClamp } from "../ui/lib/focusnav.js";
import { recentPush, recentFilter, recentLoad } from "../ui/lib/recent.js";
import { SECTIONS, settingsContent } from "../ui/lib/settings.js";

const L = { cols: 4, recentCount: 2, gridCount: 7 };

test("focus moves like the Roku app", () => {
  assert.deepEqual(navMove({ area: "grid", index: 4 }, "left", L), { area: "grid", index: 4, openDrawer: true });
  assert.deepEqual(navMove({ area: "grid", index: 3 }, "down", L), { area: "grid", index: 6, openDrawer: false });
  assert.deepEqual(navMove({ area: "grid", index: 3 }, "up", L), { area: "recent", index: 1, openDrawer: false });
  assert.deepEqual(navMove({ area: "recent", index: 1 }, "down", L), { area: "grid", index: 1, openDrawer: false });
  assert.deepEqual(navMove({ area: "grid", index: 6 }, "right", L), { area: "grid", index: 6, openDrawer: false });
});

test("no key from any position leaves focus out of range", () => {
  for (const key of ["up", "down", "left", "right"]) {
    for (const [area, count] of [["grid", L.gridCount], ["recent", L.recentCount]]) {
      for (let i = 0; i < count; i++) {
        const r = navMove({ area, index: i }, key, L);
        const max = r.area === "grid" ? L.gridCount : L.recentCount;
        assert.ok(r.index >= 0 && r.index < max, `${area} ${i} ${key}`);
      }
    }
  }
  assert.deepEqual(navClamp({ area: "recent", index: 3 }, { ...L, recentCount: 0 }), { area: "grid", index: 0 });
});

test("recent is bounded, deduplicated and validated", () => {
  assert.deepEqual(recentPush(["a", "b", "c", "d"], "c", 4), ["c", "a", "b", "d"]);
  assert.deepEqual(recentPush(["a", "b", "c", "d"], "e", 4), ["e", "a", "b", "c"]);
  assert.deepEqual(recentFilter(["a", 3, "x", "b"], new Set(["a", "b"]), 4), ["a", "b"]);
  assert.deepEqual(recentFilter("junk", new Set(), 4), []);
  assert.deepEqual(recentLoad({ getItem: () => "{bad json" }), []);
  assert.deepEqual(recentLoad({ getItem: () => { throw new Error("blocked"); } }), []);
});

test("every settings section renders with at most two buttons", () => {
  const data = { net: null, diag: { state: "idle" }, diagHistory: [], recentCount: 1, about: null };
  for (const section of SECTIONS) {
    const content = settingsContent(section.id, data);
    assert.ok(content.heading && content.body, section.id);
    assert.ok(content.buttons.length <= 2, section.id);
  }
  const power = settingsContent("power", data);
  assert.ok(power.buttons.every((b) => b.confirm), "power actions need confirmation");
  const running = settingsContent("diagnostics", { ...data, diag: { state: "running", progress: "…" } });
  assert.deepEqual(running.buttons, [{ label: "Checking…", action: "" }]);
});
