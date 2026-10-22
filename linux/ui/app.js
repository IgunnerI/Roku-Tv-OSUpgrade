// Amber launcher controller. All keys are handled here; focus is drawn with a
// CSS class, never by moving DOM focus, so it can't get lost.
import { navMove, navClamp } from "./lib/focusnav.js";
import { recentPush, recentFilter, recentLoad, recentSave, recentClear } from "./lib/recent.js";
import { SECTIONS, settingsContent, connectionName } from "./lib/settings.js";

const COLS = 4;
const MAX_RECENT = 4;
const TILE_W = 380;
const GAP = 36;
const DRAWER_ITEMS = [
  { id: "home", label: "Home" },
  { id: "network", label: "Settings" },
  { id: "diagnostics", label: "Network check" },
  { id: "privacy", label: "Privacy" },
  { id: "power", label: "Power" },
  { id: "about", label: "About" },
];
// Remote and keyboard keys. Home is taken by the window manager (it closes
// the streaming window), so the page never sees it.
const KEYS = {
  ArrowUp: "up", ArrowDown: "down", ArrowLeft: "left", ArrowRight: "right",
  Enter: "OK", Escape: "back", Backspace: "back", BrowserBack: "back",
  ContextMenu: "options", m: "options", M: "options",
};

const $ = (id) => document.getElementById(id);
const storage = window.localStorage;

const app = {
  mode: "home", // "home" | "drawer" | "settings"
  focus: { area: "grid", index: 0 },
  catalog: [],
  byId: new Map(),
  recent: [],
  gridTiles: [],
  recentTiles: [],
  net: null,
  about: null,
  diag: { state: "idle" },
  diagHistory: [],
  drawerIndex: 0,
  section: 0,
  settingsArea: "menu", // "menu" | "buttons"
  buttonIndex: 0,
  content: { buttons: [] },
  pendingConfirm: null,
};

// ---- API ---------------------------------------------------------------------

async function getJson(path) {
  const response = await fetch(path);
  return response.json();
}

async function post(path, body) {
  const response = await fetch(path, {
    method: "POST",
    headers: { "Content-Type": "application/json", "X-Amber": "1" },
    body: JSON.stringify(body),
  });
  return response.ok;
}

// ---- Layout --------------------------------------------------------------------

function fitStage() {
  const scale = Math.min(window.innerWidth / 1920, window.innerHeight / 1080);
  $("stage").style.transform = `scale(${scale})`;
}

function makeTile(parent, index, kind) {
  const tile = document.createElement("div");
  tile.className = `tile ${kind}`;
  const height = kind === "tall" ? 200 : 110;
  tile.style.left = `${(index % COLS) * (TILE_W + GAP)}px`;
  tile.style.top = `${Math.floor(index / COLS) * (height + GAP)}px`;
  tile.innerHTML = '<div class="name"></div><div class="note"></div>';
  parent.appendChild(tile);
  return tile;
}

function setTile(tile, entry) {
  tile.querySelector(".name").textContent = entry.label;
  tile.querySelector(".note").textContent = entry.kind === "web" ? entry.note || "Website" : "Launcher";
}

function makeList(parent, labels, step) {
  return labels.map((label, i) => {
    const item = document.createElement("div");
    item.className = "item";
    item.style.top = `${170 + i * step}px`;
    item.textContent = label;
    parent.appendChild(item);
    return item;
  });
}

function layout() {
  return { cols: COLS, recentCount: app.recent.length, gridCount: app.gridTiles.length };
}

// ---- Home ----------------------------------------------------------------------

function refreshRecent() {
  app.recentTiles.forEach((tile, i) => {
    tile.hidden = i >= app.recent.length;
    if (!tile.hidden) setTile(tile, app.byId.get(app.recent[i]));
  });
  $("recentEmpty").hidden = app.recent.length > 0;
  app.focus = navClamp(app.focus, layout());
  applyFocus();
}

function applyFocus() {
  document.querySelectorAll(".tile.focused").forEach((tile) => tile.classList.remove("focused"));
  if (app.mode !== "home") return;
  const tiles = app.focus.area === "recent" ? app.recentTiles : app.gridTiles;
  tiles[app.focus.index]?.classList.add("focused");
}

function refreshNet() {
  const net = app.net;
  const box = document.querySelector(".net");
  box.classList.toggle("offline", !!net && !net.linkUp);
  box.classList.toggle("online", !!net && net.linkUp);
  $("netLabel").textContent = !net ? "" : net.linkUp ? connectionName(net.connectionType) : "Offline";
}

function say(text) {
  $("message").textContent = text;
}

async function activateFocused() {
  const id = app.focus.area === "recent" ? app.recent[app.focus.index] : app.catalog[app.focus.index]?.id;
  const entry = app.byId.get(id);
  if (!entry) return;
  if (entry.kind === "in_app") {
    openSettings(entry.target);
    return;
  }
  say(`Opening ${entry.label}…  Press Home to come back.`);
  const recent = recentPush(app.recent, entry.id, MAX_RECENT);
  if (app.focus.area === "recent") app.focus = { area: "recent", index: 0 };
  app.recent = recent;
  recentSave(storage, recent);
  refreshRecent();
  if (!(await post("/api/launch", { id: entry.id }))) say(`${entry.label} could not be opened.`);
}

function homeKey(key) {
  say("");
  if (key === "options") return openDrawer();
  if (key === "OK") return activateFocused();
  if (["up", "down", "left", "right"].includes(key)) {
    const moved = navMove(app.focus, key, layout());
    if (moved.openDrawer) return openDrawer();
    app.focus = { area: moved.area, index: moved.index };
    applyFocus();
  }
}

// ---- Drawer --------------------------------------------------------------------

function openDrawer() {
  app.mode = "drawer";
  app.drawerIndex = 0;
  $("drawer").hidden = false;
  document.querySelector("#home .hint").hidden = true;
  renderDrawer();
  applyFocus();
}

function closeDrawer() {
  $("drawer").hidden = true;
  document.querySelector("#home .hint").hidden = false;
  app.mode = "home";
  applyFocus();
}

function renderDrawer() {
  app.drawerItems.forEach((item, i) => item.classList.toggle("current", i === app.drawerIndex));
  $("drawerBar").style.left = "40px";
  $("drawerBar").style.top = `${170 + app.drawerIndex * 76}px`;
}

function drawerKey(key) {
  if (key === "up" && app.drawerIndex > 0) app.drawerIndex--;
  else if (key === "down" && app.drawerIndex < DRAWER_ITEMS.length - 1) app.drawerIndex++;
  else if (key === "back" || key === "right" || key === "options") return closeDrawer();
  else if (key === "OK") {
    const id = DRAWER_ITEMS[app.drawerIndex].id;
    return id === "home" ? closeDrawer() : openSettings(id);
  }
  renderDrawer();
}

// ---- Settings ------------------------------------------------------------------

function openSettings(sectionId) {
  $("drawer").hidden = true;
  document.querySelector("#home .hint").hidden = false;
  app.section = Math.max(0, SECTIONS.findIndex((s) => s.id === sectionId));
  app.settingsArea = "menu";
  app.buttonIndex = 0;
  app.pendingConfirm = null;
  $("home").hidden = true;
  $("settings").hidden = false;
  app.mode = "settings";
  applyFocus();
  if (SECTIONS[app.section].id === "about" && !app.about) loadAbout();
  renderSettings();
}

function closeSettings() {
  $("settings").hidden = true;
  $("home").hidden = false;
  app.mode = "home";
  applyFocus();
}

function renderSettings() {
  if (app.mode !== "settings") return;
  app.content = settingsContent(SECTIONS[app.section].id, {
    net: app.net,
    diag: app.diag,
    diagHistory: app.diagHistory,
    recentCount: app.recent.length,
    about: app.about,
  });
  $("panelHeading").textContent = app.content.heading;
  $("panelBody").textContent = app.content.body;
  const count = app.content.buttons.length;
  if (app.settingsArea === "buttons") {
    if (count === 0) app.settingsArea = "menu";
    else app.buttonIndex = Math.min(app.buttonIndex, count - 1);
  }
  app.buttonNodes.forEach((node, i) => {
    node.hidden = i >= count;
    if (i < count) {
      const button = app.content.buttons[i];
      node.textContent = app.pendingConfirm === button.action ? button.confirm : button.label;
      node.classList.toggle("focused", app.settingsArea === "buttons" && i === app.buttonIndex);
    }
  });
  app.menuItems.forEach((item, i) => item.classList.toggle("current", i === app.section));
  const bar = $("menuBar");
  bar.style.left = "146px";
  bar.style.top = `${170 + app.section * 72}px`;
  bar.classList.toggle("inactive", app.settingsArea !== "menu");
}

function settingsKey(key) {
  const confirming = app.pendingConfirm;
  app.pendingConfirm = null;
  if (app.settingsArea === "menu") {
    if (key === "up" && app.section > 0) app.section--;
    else if (key === "down" && app.section < SECTIONS.length - 1) app.section++;
    else if ((key === "right" || key === "OK") && app.content.buttons.length > 0) {
      app.settingsArea = "buttons";
      app.buttonIndex = 0;
    } else if (key === "back") return closeSettings();
    if (SECTIONS[app.section].id === "about" && !app.about) loadAbout();
  } else {
    if (key === "left") {
      if (app.buttonIndex === 0) app.settingsArea = "menu";
      else app.buttonIndex--;
    } else if (key === "right" && app.buttonIndex < app.content.buttons.length - 1) app.buttonIndex++;
    else if (key === "back") app.settingsArea = "menu";
    else if (key === "OK") {
      const button = app.content.buttons[app.buttonIndex];
      if (button.confirm && confirming !== button.action) app.pendingConfirm = button.action;
      else runAction(button.action);
    }
  }
  renderSettings();
}

async function runAction(action) {
  if (action === "showDiagnostics") return openSettings("diagnostics");
  if (action === "runDiagnostics") return startDiagnostics();
  if (action === "clearDiagnostics") return clearDiagnostics();
  if (action === "clearRecent") return clearHistory();
  if (action === "clearAll") {
    clearHistory();
    return clearDiagnostics();
  }
  if (action === "restartNetwork") {
    $("panelBody").textContent = "Restarting the network…";
    const ok = await post("/api/action", { action: "restart-network" });
    $("panelBody").textContent = ok ? "Network restarted. Status updates when the connection returns." : "The network could not be restarted.";
    return;
  }
  if (action === "reboot" || action === "poweroff") await post("/api/action", { action });
}

function clearHistory() {
  recentClear(storage);
  app.recent = [];
  refreshRecent();
}

function clearDiagnostics() {
  app.diagHistory = [];
  if (app.diag.state !== "running") app.diag = { state: "idle" };
}

// Polls only while a user-started check runs (at most ~20 s).
async function startDiagnostics() {
  if (app.diag.state === "running") return;
  app.diag = { state: "running", progress: "Starting check…" };
  renderSettings();
  if (!(await post("/api/diagnostics", {}))) {
    app.diag = { state: "idle" };
    return renderSettings();
  }
  while (app.diag.state === "running") {
    await new Promise((resolve) => setTimeout(resolve, 500));
    const diag = await getJson("/api/diagnostics");
    if (diag.state === "done") {
      app.diagHistory = [`Check ${diag.runId}: ${diag.title}`, ...app.diagHistory].slice(0, 4);
    }
    app.diag = diag.state === "idle" ? { state: "idle" } : diag;
    renderSettings();
  }
}

async function loadAbout() {
  app.about = await getJson("/api/about");
  renderSettings();
}

// Long-poll: the server answers when the network changes (netlink events).
async function watchNetwork() {
  let since = 0;
  for (;;) {
    try {
      const status = await getJson(`/api/status?since=${since}`);
      since = status.version;
      app.net = status;
      refreshNet();
      renderSettings();
    } catch {
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }
  }
}

// ---- Startup -------------------------------------------------------------------

function onKey(event) {
  const key = KEYS[event.key];
  if (!key) return;
  event.preventDefault();
  if (app.mode === "settings") settingsKey(key);
  else if (app.mode === "drawer") drawerKey(key);
  else homeKey(key);
}

async function start() {
  fitStage();
  window.addEventListener("resize", fitStage);
  window.addEventListener("keydown", onKey);

  app.drawerItems = makeList($("drawerList"), DRAWER_ITEMS.map((d) => d.label), 76);
  app.menuItems = makeList($("menu"), SECTIONS.map((s) => s.label), 72);
  app.buttonNodes = [0, 1].map((i) => {
    const node = document.createElement("div");
    node.className = "button";
    node.style.left = `${i * 400}px`;
    $("buttons").appendChild(node);
    return node;
  });

  try {
    app.catalog = await getJson("/api/catalog");
  } catch {
    app.catalog = [];
  }
  if (app.catalog.length === 0) say("The app catalog could not be loaded.");
  app.catalog.forEach((entry) => app.byId.set(entry.id, entry));
  app.gridTiles = app.catalog.map((entry, i) => {
    const tile = makeTile($("grid"), i, "tall");
    setTile(tile, entry);
    return tile;
  });
  app.recentTiles = [0, 1, 2, 3].map((i) => makeTile($("recentRow"), i, "short"));
  const known = new Set(app.catalog.filter((e) => e.kind === "web").map((e) => e.id));
  app.recent = recentFilter(recentLoad(storage), known, MAX_RECENT);
  refreshRecent();
  watchNetwork();
}

start();
