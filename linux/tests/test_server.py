"""Tests for the Linux server: diagnostics logic, route parsing, API security,
and a source privacy audit. Run: python3 -m unittest discover -s linux/tests"""
import http.client
import json
import os
import re
import sys
import threading
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "server"))
os.environ["AMBER_DRY_RUN"] = "1"

import amber_server  # noqa: E402
import diagnostics  # noqa: E402
import netinfo  # noqa: E402

UP = {"linkUp": True, "connectionType": "wifi", "address": "10.0.0.5", "gateway": "10.0.0.1", "networkName": ""}


def run_with(resolve=True, heads=(), ping=True, net=UP):
    heads = list(heads)
    sleeps = []
    result = diagnostics.run(net, lambda text: None, resolve_fn=lambda host: resolve,
                             head_fn=lambda dest: heads.pop(0), ping_fn=lambda gw: ping,
                             sleep=sleeps.append)
    return result, sleeps


class DiagnosticsTest(unittest.TestCase):
    def test_classify(self):
        base = {"link": True, "address": "10.0.0.5", "gateway": True}
        cases = [
            ({"link": False, "address": "", "gateway": None, "probes": []}, "disconnected"),
            ({**base, "address": "", "probes": []}, "no_address"),
            ({**base, "gateway": False, "probes": []}, "gateway_unreachable"),
            ({**base, "probes": ["dns", "ok"]}, "online"),
            ({**base, "probes": ["dns", "dns"]}, "dns_failed"),
            ({**base, "probes": ["timeout", "timeout"]}, "timeout"),
            ({**base, "probes": ["intercepted", "timeout"]}, "intercepted"),
            ({**base, "probes": ["connect", "timeout"]}, "unreachable"),
            ({**base, "probes": []}, "unknown"),
        ]
        for facts, expected in cases:
            self.assertEqual(diagnostics.classify(facts), expected, facts)

    def test_no_verdict_claims_internet_is_down(self):
        for title, advice in diagnostics.VERDICTS.values():
            text = (title + advice).lower()
            self.assertTrue("internet is down" not in text or "does not prove" in text)

    def test_online_stops_after_first_success(self):
        result, sleeps = run_with(heads=["ok"])
        self.assertEqual(result["verdict"], "online")
        self.assertEqual(sleeps, [])

    def test_retries_are_bounded_with_backoff(self):
        result, sleeps = run_with(heads=["timeout"] * 4)
        self.assertEqual(result["verdict"], "timeout")
        self.assertEqual(sleeps, [diagnostics.BACKOFF_S, diagnostics.BACKOFF_S])

    def test_no_retry_when_server_answered(self):
        result, sleeps = run_with(heads=["intercepted", "intercepted"])
        self.assertEqual(result["verdict"], "intercepted")
        self.assertEqual(sleeps, [])

    def test_router_down_skips_internet_probes(self):
        result, _ = run_with(ping=False, heads=[])
        self.assertEqual(result["verdict"], "gateway_unreachable")

    def test_ping_unavailable_still_probes(self):
        result, _ = run_with(ping=None, heads=["ok"])
        self.assertEqual(result["verdict"], "online")
        self.assertNotIn("Router", " ".join(result["steps"]))

    def test_dns_failure(self):
        result, _ = run_with(resolve=False)
        self.assertEqual(result["verdict"], "dns_failed")

    def test_disconnected_sends_nothing(self):
        result, _ = run_with(net={**UP, "linkUp": False, "address": ""}, heads=[])
        self.assertEqual(result["verdict"], "disconnected")

    def test_worst_case_duration_bounded(self):
        per_attempt = diagnostics.TIMEOUT_S * 2  # name lookup + HEAD
        worst = 3 + len(diagnostics.DESTINATIONS) * (
            diagnostics.MAX_ATTEMPTS * per_attempt + sum(diagnostics.BACKOFF_S * a for a in range(1, diagnostics.MAX_ATTEMPTS)))
        self.assertLessEqual(worst, 40)


class NetinfoTest(unittest.TestCase):
    def test_parse_default_route(self):
        text = ("Iface\tDestination\tGateway\tFlags\n"
                "wlp2s0\t0000000A\t00000000\t0001\n"
                "wlp2s0\t00000000\t0100000A\t0003\n")
        self.assertEqual(netinfo.parse_default_route(text), ("wlp2s0", "10.0.0.1"))
        self.assertEqual(netinfo.parse_default_route("Iface\n"), ("", ""))

    def test_status_shape(self):
        status = netinfo.status()
        self.assertEqual(set(status), {"linkUp", "connectionType", "address", "gateway", "networkName"})


class ServerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = amber_server.make_server(port=0)
        cls.port = cls.server.server_address[1]
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def request(self, method, path, body=None, headers=None, host=None):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        hdrs = {"Host": host or f"127.0.0.1:{self.port}"}
        hdrs.update(headers or {})
        data = json.dumps(body).encode() if body is not None else None
        if data is not None:
            hdrs["Content-Type"] = "application/json"
        conn.request(method, path, body=data, headers=hdrs)
        response = conn.getresponse()
        payload = response.read()
        conn.close()
        return response.status, payload

    def test_serves_ui_and_catalog(self):
        status, body = self.request("GET", "/")
        self.assertEqual(status, 200)
        self.assertIn(b"Amber", body)
        status, body = self.request("GET", "/api/catalog")
        catalog = json.loads(body)
        self.assertEqual(len(catalog), 8)
        self.assertNotIn("url", catalog[0])

    def test_rejects_foreign_host(self):
        status, _ = self.request("GET", "/api/catalog", host="evil.example:8484")
        self.assertEqual(status, 403)

    def test_post_requires_custom_header(self):
        status, _ = self.request("POST", "/api/action", {"action": "reboot"})
        self.assertEqual(status, 403)
        status, _ = self.request("OPTIONS", "/api/action")
        self.assertEqual(status, 403)

    def test_launch_only_catalog_destinations(self):
        status, _ = self.request("POST", "/api/launch", {"id": "https://evil.example"}, {"X-Amber": "1"})
        self.assertEqual(status, 404)
        status, _ = self.request("POST", "/api/launch", {"id": "settings"}, {"X-Amber": "1"})
        self.assertEqual(status, 404)
        status, _ = self.request("POST", "/api/launch", {"id": "netflix"}, {"X-Amber": "1"})
        self.assertEqual(status, 200)
        _, body = self.request("GET", "/api/commands")
        self.assertEqual(json.loads(body)[-1][1], "https://www.netflix.com/browse")

    def test_actions_are_allowlisted(self):
        status, _ = self.request("POST", "/api/action", {"action": "rm -rf /"}, {"X-Amber": "1"})
        self.assertEqual(status, 404)
        status, _ = self.request("POST", "/api/action", {"action": "reboot"}, {"X-Amber": "1"})
        self.assertEqual(status, 200)
        _, body = self.request("GET", "/api/commands")
        self.assertEqual(json.loads(body)[-1], ["systemctl", "reboot"])

    def test_static_path_traversal_blocked(self):
        for path in ("/../server/amber_server.py", "/%2e%2e/server/amber_server.py", "/lib/../../install.sh"):
            status, _ = self.request("GET", path)
            self.assertEqual(status, 404, path)

    def test_status_long_poll_returns_current_first(self):
        status, body = self.request("GET", "/api/status?since=0")
        self.assertEqual(status, 200)
        self.assertIn("linkUp", json.loads(body))


class PrivacyAuditTest(unittest.TestCase):
    """Every network destination in the Linux launcher is a catalog site the
    user opens, or a diagnostics host. No analytics or tracking code."""

    ALLOWED = {"connectivitycheck.gstatic.com", "www.msftconnecttest.com", "127.0.0.1",
               "www.netflix.com", "www.youtube.com", "www.primevideo.com", "www.disneyplus.com", "www.hulu.com"}
    FORBIDDEN = re.compile(r"google-?analytics|googletagmanager|firebase|mixpanel|segment\.(io|com)|amplitude"
                           r"|sentry|bugsnag|new ?relic|sendBeacon|navigator\.sendBeacon|XMLHttpRequest", re.I)

    def test_sources(self):
        files = [p for d in ("server", "ui", "bin", "sway") for p in (ROOT / d).rglob("*") if p.is_file() and "__pycache__" not in p.parts]
        self.assertTrue(files)
        for path in files:
            text = path.read_text()
            for host in re.findall(r"https?://([^/\s\"'<>):]+)", text):
                self.assertIn(host, self.ALLOWED, f"{path}: {host}")
            self.assertIsNone(self.FORBIDDEN.search(text), path)
            for host in re.findall(r'"host":\s*"([^"]+)"', text):
                self.assertIn(host, self.ALLOWED, f"{path}: {host}")

    def test_chromium_policy_disables_reporting(self):
        policy = json.loads((ROOT / "chromium" / "policies.json").read_text())
        self.assertIs(policy["MetricsReportingEnabled"], False)
        self.assertIs(policy["UrlKeyedAnonymizedDataCollectionEnabled"], False)
        self.assertIs(policy["SyncDisabled"], True)


if __name__ == "__main__":
    unittest.main()
