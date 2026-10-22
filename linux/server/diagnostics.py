"""Network diagnostics: bounded, user-triggered checks and pure classification.

Same rules as the Roku app (components/lib/Diagnostics.brs): runs only on
request, bounded timeouts and retries, nothing uploaded, never claims the
internet is definitely down. On Linux it can also test the router and DNS
directly, so verdicts are more specific.
"""
import http.client
import socket
import subprocess
import threading
import time

# Keep in sync with docs/PRIVACY.md (Linux section) and tests/test_privacy.py.
DESTINATIONS = [
    {"name": "Destination 1", "host": "connectivitycheck.gstatic.com", "path": "/generate_204", "expect": 204},
    {"name": "Destination 2", "host": "www.msftconnecttest.com", "path": "/connecttest.txt", "expect": 200},
]
TIMEOUT_S = 4
MAX_ATTEMPTS = 2
BACKOFF_S = 1

VERDICTS = {
    "online": ("Internet reachable", "At least one test destination answered normally."),
    "disconnected": ("Not connected to a network", "No network link. Check the cable, or that Wi-Fi is configured and in range (see Recovery help)."),
    "no_address": ("Connected, but no address assigned", "The link is up but the router gave no address. Restart the router, then use Restart network."),
    "gateway_unreachable": ("Router not responding", "The box has an address but the router did not answer. Restart the router, then use Restart network."),
    "dns_failed": ("Name lookup failed", "The router answers, but names could not be looked up. Restart the router, or check its DNS settings."),
    "timeout": ("Test destinations timed out", "No answer within the time limit. The connection may be slow or congested. Try again in a moment."),
    "intercepted": ("Unexpected response", "Your network answered, but not as expected. A sign-in page (hotel or guest Wi-Fi) or a network filter may be in the way."),
    "unreachable": ("Local network OK, test destinations unreachable", "This does not prove the internet is down. Your router or provider may be having trouble. Restart the router and try again."),
    "unknown": ("Result unclear", "The check could not determine the problem. Try again."),
}
KIND_TEXT = {"ok": "OK", "dns": "Name lookup failed", "timeout": "Timed out",
             "connect": "Could not connect", "intercepted": "Unexpected response", "other": "Failed"}


def classify(facts):
    """facts: {link, address, gateway: True|False|None (None = not tested), probes: [kind]}"""
    if not facts["link"]:
        return "disconnected"
    if not facts["address"]:
        return "no_address"
    if facts["gateway"] is False:
        return "gateway_unreachable"
    probes = facts["probes"]
    if not probes:
        return "unknown"
    if "ok" in probes:
        return "online"
    if all(p == "dns" for p in probes):
        return "dns_failed"
    if all(p == "timeout" for p in probes):
        return "timeout"
    if "intercepted" in probes:
        return "intercepted"
    if "connect" in probes:
        return "unreachable"
    return "unknown"


def should_retry(kind):
    return kind in ("dns", "timeout", "connect", "other")


def resolve(host, timeout=TIMEOUT_S):
    """True if the name resolves within timeout. getaddrinfo has no timeout of
    its own, so it runs on a daemon thread that is abandoned on timeout."""
    result = {}

    def work():
        try:
            socket.getaddrinfo(host, 80, proto=socket.IPPROTO_TCP)
            result["ok"] = True
        except OSError:
            result["ok"] = False

    thread = threading.Thread(target=work, daemon=True)
    thread.start()
    thread.join(timeout)
    return result.get("ok", False)


def head(dest, timeout=TIMEOUT_S):
    """One HEAD request. Sends only a generic User-Agent; no identifiers."""
    conn = http.client.HTTPConnection(dest["host"], 80, timeout=timeout)
    try:
        conn.request("HEAD", dest["path"], headers={"User-Agent": "amber-diagnostics"})
        code = conn.getresponse().status
        return "ok" if code == dest["expect"] else "intercepted"
    except socket.timeout:
        return "timeout"
    except (ConnectionError, OSError):
        return "connect"
    finally:
        conn.close()


def ping(address, timeout=2):
    """True/False if the router answers one ping; None if ping is unavailable."""
    try:
        done = subprocess.run(["ping", "-c", "1", "-W", str(timeout), address],
                              capture_output=True, timeout=timeout + 1)
    except FileNotFoundError:
        return None
    except subprocess.TimeoutExpired:
        return False
    return done.returncode == 0


def probe(dest, resolve_fn=resolve, head_fn=head):
    if not resolve_fn(dest["host"]):
        return "dns"
    return head_fn(dest)


def run(net, progress, resolve_fn=resolve, head_fn=head, ping_fn=ping, sleep=time.sleep):
    """Runs one bounded check. net is a netinfo.status() dict; progress(text)
    reports steps. Returns {verdict, title, advice, steps}."""
    facts = {"link": net["linkUp"], "address": net["address"], "gateway": None, "probes": []}
    steps = ["Network link: " + ("OK" if facts["link"] else "down"),
             "Local address: " + ("assigned" if facts["address"] else "none")]

    if facts["link"] and facts["address"]:
        if net["gateway"]:
            progress("Checking the router…")
            facts["gateway"] = ping_fn(net["gateway"])
            if facts["gateway"] is not None:
                steps.append("Router: " + ("answering" if facts["gateway"] else "not answering"))
        if facts["gateway"] is not False:
            for dest in DESTINATIONS:
                kind = "other"
                for attempt in range(1, MAX_ATTEMPTS + 1):
                    progress(f"Checking {dest['name']} of {len(DESTINATIONS)}, attempt {attempt} of {MAX_ATTEMPTS}…")
                    kind = probe(dest, resolve_fn, head_fn)
                    if not should_retry(kind) or attempt == MAX_ATTEMPTS:
                        break
                    sleep(BACKOFF_S * attempt)
                facts["probes"].append(kind)
                steps.append(f"{dest['name']}: {KIND_TEXT[kind]}")
                if kind == "ok":
                    break

    verdict = classify(facts)
    title, advice = VERDICTS[verdict]
    return {"verdict": verdict, "title": title, "advice": advice, "steps": steps}
