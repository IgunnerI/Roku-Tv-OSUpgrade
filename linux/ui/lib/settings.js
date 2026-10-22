// Builds each Settings section from plain data. Pure; tested in
// tests/ui-lib.test.mjs. Mirrors components/lib/SettingsContent.brs, plus the
// Linux-only Power section and network restart.
//
// data: { net, diag: { state, progress, title, advice, steps }, diagHistory,
//         recentCount, about }
// Returns { heading, body, buttons: [{ label, action, confirm? }] }.
// A button with confirm needs a second OK; an empty action does nothing.

export const SECTIONS = [
  { id: "network", label: "Network" },
  { id: "diagnostics", label: "Diagnostics" },
  { id: "recent", label: "Recent apps" },
  { id: "privacy", label: "Privacy" },
  { id: "recovery", label: "Recovery help" },
  { id: "power", label: "Power" },
  { id: "about", label: "About" },
];

const dash = (value) => (typeof value === "string" && value !== "" ? value : "—");

export function connectionName(type) {
  return { wifi: "Wi-Fi", wired: "Wired" }[type] ?? "None";
}

export function settingsContent(section, data) {
  switch (section) {
    case "network": return network(data.net);
    case "diagnostics": return diagnostics(data.diag, data.diagHistory);
    case "recent": return recent(data.recentCount);
    case "privacy": return privacy();
    case "recovery": return recovery();
    case "power": return power();
    default: return about(data.about);
  }
}

function network(net) {
  if (!net) return { heading: "Network", body: "Reading network status…", buttons: [] };
  const body = [
    `Connection: ${connectionName(net.connectionType)}`,
    `Link: ${net.linkUp ? "Up" : "Down"}`,
    `Local address: ${dash(net.address)}`,
    `Router: ${dash(net.gateway)}`,
    `Network name: ${dash(net.networkName)}`,
  ].join("\n");
  return {
    heading: "Network",
    body,
    buttons: [
      { label: "Run diagnostics", action: "showDiagnostics" },
      { label: "Restart network", action: "restartNetwork" },
    ],
  };
}

function diagnostics(diag, history) {
  let body;
  let buttons;
  if (diag.state === "running") {
    body = diag.progress;
    buttons = [{ label: "Checking…", action: "" }];
  } else if (diag.state === "done") {
    body = [diag.title, diag.advice, "", ...diag.steps].join("\n");
    buttons = [{ label: "Run again", action: "runDiagnostics" }, { label: "Clear results", action: "clearDiagnostics" }];
  } else {
    body = "Checks the network link, the local address, the router, name lookup, and whether up to two test destinations answer (connectivitycheck.gstatic.com, then www.msftconnecttest.com).\n\nRuns only when you select it, gives up after a short time limit, and keeps results on this box.";
    buttons = [{ label: "Run check", action: "runDiagnostics" }];
  }
  if (history.length > 0) body += "\n\nEarlier results:\n" + history.join("\n");
  return { heading: "Diagnostics", body, buttons };
}

function recent(count) {
  const listed = count === 1 ? "1 tile is listed." : `${count} tiles are listed.`;
  return {
    heading: "Recent apps",
    body: `Recent shows tiles you selected in this launcher, newest first.\n\n${listed}`,
    buttons: [{ label: "Clear recent apps", action: "clearRecent" }],
  };
}

function privacy() {
  return {
    heading: "Privacy",
    body: [
      "Amber collects no analytics and sends no usage data.",
      "",
      "Stored on this box only: the Recent list. Diagnostics results are kept in memory until the launcher restarts.",
      "",
      "The launcher itself contacts the network only for the diagnostics check, when you run it. Streaming sites, Debian updates, time sync and Chromium's DRM component have their own traffic; see docs/PRIVACY.md.",
    ].join("\n"),
    buttons: [{ label: "Clear all local data", action: "clearAll" }],
  };
}

function recovery() {
  return {
    heading: "Recovery help",
    body: [
      "1. Select Restart network below.",
      "2. Restart your router: unplug it for 30 seconds.",
      "3. Check the network cable, or move closer to the router on Wi-Fi.",
      "4. To join a different Wi-Fi network, connect a keyboard, press Ctrl+Alt+F2, log in as the admin user and run: sudo nmtui",
      "5. Restart the box from Power.",
    ].join("\n"),
    buttons: [{ label: "Restart network", action: "restartNetwork" }],
  };
}

function power() {
  return {
    heading: "Power",
    body: "Restart or shut down this box. The TV itself is controlled by its own remote.",
    buttons: [
      { label: "Restart", action: "reboot", confirm: "Press OK again to restart" },
      { label: "Shut down", action: "poweroff", confirm: "Press OK again to shut down" },
    ],
  };
}

function about(info) {
  info = info || {};
  return {
    heading: "About",
    body: [
      `Amber ${dash(info.appVersion)} for Linux`,
      "A static, privacy-first TV launcher.",
      "",
      `System: ${dash(info.os)}`,
      `Kernel: ${dash(info.kernel)}`,
      `Processor: ${dash(info.cpu)}`,
      `Memory: ${dash(info.memory)}`,
    ].join("\n"),
    buttons: [],
  };
}
