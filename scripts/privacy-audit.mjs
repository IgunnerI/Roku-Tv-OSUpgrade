// Static privacy audit of everything that ships in the channel package.
// Fails (exit 1) on any network destination not on the allowlist, any
// analytics/ads library, device-identifier API, socket, or POST request,
// and on network use outside components/NetworkTask.brs.
// This is a source check only; runtime traffic must still be observed on a
// device (docs/TEST_PLAN.md, "Privacy tests").
import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const root = new URL("..", import.meta.url).pathname;
const shipped = ["manifest", "source", "components", "data"];

// Keep in sync with DiagDestinations() and docs/PRIVACY.md.
const allowedHosts = new Set(["connectivitycheck.gstatic.com", "www.msftconnecttest.com"]);
const networkFiles = new Set(["components/NetworkTask.brs", "components/lib/Diagnostics.brs"]);

const forbidden = [
  [/\bLibrary\s+"/i, "component library import (e.g. Roku_Ads)"],
  [/roku_ads|\bRAF\b/i, "Roku Advertising Framework"],
  [/google-?analytics|googletagmanager|firebase|mixpanel|segment\.(io|com)|amplitude|sentry|bugsnag|new ?relic|conviva|nielsen|comscore|appsflyer|kochava|adjust\.com/i, "analytics/crash-reporting service"],
  [/GetRIDA|IsRIDADisabled|GetAdvertisingId|GetDeviceUniqueId|GetChannelClientId|GetClientTrackingId|GetPublisherId|GetDeviceESN/i, "device/advertising identifier API"],
  [/ro(Stream|DataGram)Socket|roSocketAddress|roHttpAgent/i, "raw socket or HTTP agent"],
  [/AsyncPost|PostFrom(String|File)/i, "outbound POST"],
];

function walk(path) {
  const full = join(root, path);
  if (statSync(full).isFile()) return [path];
  return readdirSync(full).flatMap((name) => walk(join(path, name)));
}

const problems = [];
const urls = [];
for (const file of shipped.flatMap(walk)) {
  if (!/\.(brs|xml|json)$|^manifest$/.test(file)) continue;
  const rel = relative(".", file);
  const text = readFileSync(join(root, file), "utf8");
  text.split("\n").forEach((line, i) => {
    const where = `${rel}:${i + 1}`;
    for (const match of line.matchAll(/\b(?:https?|wss?):\/\/([^\/\s"'<>):]+)/gi)) {
      urls.push(`${where} ${match[0]}`);
      if (!allowedHosts.has(match[1].toLowerCase())) problems.push(`${where} unapproved destination ${match[1]}`);
    }
    for (const [pattern, label] of forbidden) {
      if (pattern.test(line)) problems.push(`${where} ${label}: ${line.trim()}`);
    }
    if (/roUrlTransfer/i.test(line) && !networkFiles.has(rel)) problems.push(`${where} network use outside NetworkTask`);
  });
}

console.log("Network destinations in shipped code:");
for (const url of urls) console.log(`  ${url}`);
if (problems.length) {
  console.log(`\nPrivacy audit FAILED (${problems.length}):`);
  for (const problem of problems) console.log(`  ${problem}`);
  process.exit(1);
}
console.log("\nPrivacy audit passed: no unapproved destinations, trackers, identifiers, sockets or POSTs.");
