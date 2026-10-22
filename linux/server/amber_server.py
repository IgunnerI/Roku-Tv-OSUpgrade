"""Amber local server: serves the launcher UI and a small JSON API.

Listens on 127.0.0.1 only. Protections against other pages (e.g. a streaming
site in the player window) calling the API:
  * Host header must be this server (blocks DNS rebinding).
  * POST requires the "X-Amber: 1" header and a JSON body. Browsers cannot send
    a custom header cross-origin without a CORS preflight, which is never
    granted.
Launch targets come only from the server-side catalog, never from the client.

Environment:
  AMBER_PORT     default 8484
  AMBER_PLAY     command that opens a URL fullscreen (default /opt/amber/bin/amber-play)
  AMBER_DRY_RUN  if set, commands are recorded instead of run (tests, previews)
"""
import json
import os
import platform
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import diagnostics  # noqa: E402
import netinfo  # noqa: E402

VERSION = "0.1.0"
ROOT = Path(__file__).resolve().parent.parent
UI_DIR = ROOT / "ui"
PORT = int(os.environ.get("AMBER_PORT", "8484"))
PLAY = os.environ.get("AMBER_PLAY", "/opt/amber/bin/amber-play")
DRY_RUN = bool(os.environ.get("AMBER_DRY_RUN"))

ACTIONS = {
    "restart-network": [["nmcli", "networking", "off"], ["nmcli", "networking", "on"]],
    "reboot": [["systemctl", "reboot"]],
    "poweroff": [["systemctl", "poweroff"]],
}
CONTENT_TYPES = {".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8",
                 ".js": "text/javascript; charset=utf-8", ".json": "application/json"}
LONG_POLL_S = 25


def load_catalog():
    """Valid entries only. kind "web" needs an https url; "in_app" needs a target."""
    try:
        data = json.loads((UI_DIR / "catalog.json").read_text())
    except (OSError, ValueError):
        return []
    valid = []
    for entry in data if isinstance(data, list) else []:
        if not isinstance(entry, dict) or not all(isinstance(entry.get(k), str) and entry[k] for k in ("id", "label", "kind")):
            continue
        if entry["kind"] == "web" and str(entry.get("url", "")).startswith("https://"):
            valid.append(entry)
        elif entry["kind"] == "in_app" and entry.get("target"):
            valid.append(entry)
    return valid


def about():
    os_name = ""
    for line in Path("/etc/os-release").read_text().splitlines() if Path("/etc/os-release").exists() else []:
        if line.startswith("PRETTY_NAME="):
            os_name = line.split("=", 1)[1].strip('"')
    cpu = next((l.split(":", 1)[1].strip() for l in _lines("/proc/cpuinfo") if l.startswith("model name")), "")
    mem_kb = next((int(l.split()[1]) for l in _lines("/proc/meminfo") if l.startswith("MemTotal:")), 0)
    return {"appVersion": VERSION, "os": os_name, "kernel": platform.release(),
            "cpu": cpu, "memory": f"{round(mem_kb / 1048576, 1)} GB" if mem_kb else ""}


def _lines(path):
    try:
        return Path(path).read_text().splitlines()
    except OSError:
        return []


class State:
    def __init__(self):
        self.monitor = netinfo.StatusMonitor()
        self.catalog = load_catalog()
        self.lock = threading.Lock()
        self.diag = {"state": "idle", "runId": 0, "progress": ""}
        self.commands = []  # dry-run record, bounded

    def run_command(self, argv, wait=True):
        if DRY_RUN:
            self.commands = (self.commands + [argv])[-20:]
            return True
        try:
            if wait:
                return subprocess.run(argv, capture_output=True, timeout=15).returncode == 0
            subprocess.Popen(argv, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except (OSError, subprocess.SubprocessError):
            return False

    def start_diagnostics(self):
        with self.lock:
            if self.diag["state"] == "running":
                return self.diag["runId"]
            run_id = self.diag["runId"] + 1
            self.diag = {"state": "running", "runId": run_id, "progress": "Starting check…"}

        def progress(text):
            with self.lock:
                self.diag["progress"] = text

        def work():
            self.monitor.refresh()
            result = diagnostics.run(self.monitor.current, progress)
            with self.lock:
                self.diag = {"state": "done", "runId": run_id, "progress": "", **result}

        threading.Thread(target=work, daemon=True).start()
        return run_id


class Handler(BaseHTTPRequestHandler):
    state: State = None
    server_version = "amber"
    sys_version = ""

    def log_message(self, *args):
        pass  # no request logging

    def _host_ok(self):
        port = self.server.server_address[1]
        return self.headers.get("Host") in (f"127.0.0.1:{port}", f"localhost:{port}")

    def _send(self, code, body, content_type="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'self'; connect-src 'self'; img-src 'self'; frame-ancestors 'none'")
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if not self._host_ok():
            return self._send(403, {"error": "forbidden"})
        path, _, query = self.path.partition("?")
        if path == "/api/catalog":
            return self._send(200, [{k: e[k] for k in ("id", "label", "kind", "note", "target") if k in e} for e in self.state.catalog])
        if path == "/api/status":
            params = dict(p.split("=", 1) for p in query.split("&") if "=" in p)
            since = int(params.get("since", "0")) if params.get("since", "0").isdigit() else 0
            version, status = self.state.monitor.wait(since, LONG_POLL_S)
            return self._send(200, {"version": version, **status})
        if path == "/api/diagnostics":
            with self.state.lock:
                return self._send(200, dict(self.state.diag))
        if path == "/api/about":
            return self._send(200, about())
        if path == "/api/commands" and DRY_RUN:
            return self._send(200, self.state.commands)
        return self._static(path)

    def _static(self, path):
        rel = "index.html" if path in ("", "/") else path.lstrip("/")
        target = (UI_DIR / rel).resolve()
        if UI_DIR.resolve() not in target.parents or not target.is_file():
            return self._send(404, {"error": "not found"})
        self._send(200, target.read_bytes(), CONTENT_TYPES.get(target.suffix, "application/octet-stream"))

    def do_POST(self):
        if not self._host_ok() or self.headers.get("X-Amber") != "1":
            return self._send(403, {"error": "forbidden"})
        try:
            length = min(int(self.headers.get("Content-Length", "0")), 4096)
            body = json.loads(self.rfile.read(length) or b"{}")
        except ValueError:
            return self._send(400, {"error": "bad request"})
        if not isinstance(body, dict):
            return self._send(400, {"error": "bad request"})

        if self.path == "/api/diagnostics":
            return self._send(200, {"runId": self.state.start_diagnostics()})
        if self.path == "/api/launch":
            entry = next((e for e in self.state.catalog if e["id"] == body.get("id") and e["kind"] == "web"), None)
            if entry is None:
                return self._send(404, {"error": "unknown destination"})
            ok = self.state.run_command([PLAY, entry["url"]], wait=False)
            return self._send(200 if ok else 500, {"ok": ok})
        if self.path == "/api/action":
            commands = ACTIONS.get(body.get("action"))
            if commands is None:
                return self._send(404, {"error": "unknown action"})
            ok = all(self.state.run_command(argv) for argv in commands)
            if ok and body["action"] == "restart-network":
                self.state.monitor.refresh()
            return self._send(200 if ok else 500, {"ok": ok})
        return self._send(404, {"error": "not found"})

    def do_OPTIONS(self):
        # Never grant CORS preflights.
        self._send(403, {"error": "forbidden"})


def make_server(port=PORT):
    Handler.state = State()
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    server.daemon_threads = True
    return server


if __name__ == "__main__":
    make_server().serve_forever()
