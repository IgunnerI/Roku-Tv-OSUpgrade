"""Read-only network status from the kernel (/sys, /proc, netlink).

Uses only the standard library so it works on a minimal Debian install even
without iproute2. Nothing here changes network settings or sends traffic.
"""
import fcntl
import os
import socket
import struct
import subprocess
import threading
import time

SYS_NET = "/sys/class/net"
SIOCGIFADDR = 0x8915


def _read(path, default=""):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return default


def parse_default_route(route_text):
    """Returns (interface, gateway) for the IPv4 default route, or ("", "")."""
    for line in route_text.splitlines()[1:]:
        fields = line.split()
        if len(fields) < 3 or fields[1] != "00000000":
            continue
        gateway = socket.inet_ntoa(struct.pack("<L", int(fields[2], 16)))
        return fields[0], gateway
    return "", ""


def interfaces():
    """Physical-looking interfaces: everything except loopback and virtual devices."""
    result = []
    try:
        names = sorted(os.listdir(SYS_NET))
    except OSError:
        return result
    for name in names:
        base = os.path.join(SYS_NET, name)
        if name == "lo" or not os.path.exists(os.path.join(base, "device")):
            continue
        result.append({
            "name": name,
            "up": _read(os.path.join(base, "operstate")) == "up",
            "carrier": _read(os.path.join(base, "carrier"), "0") == "1",
            "wireless": os.path.exists(os.path.join(base, "wireless"))
            or os.path.exists(os.path.join(base, "phy80211")),
        })
    return result


def ipv4_address(ifname):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        packed = fcntl.ioctl(sock.fileno(), SIOCGIFADDR, struct.pack("256s", ifname[:15].encode()))
        return socket.inet_ntoa(packed[20:24])
    except OSError:
        return ""
    finally:
        sock.close()


def wifi_network_name():
    """SSID via NetworkManager, if present. Shown on screen only; never logged."""
    try:
        out = subprocess.run(["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"],
                             capture_output=True, text=True, timeout=2).stdout
    except (OSError, subprocess.SubprocessError):
        return ""
    for line in out.splitlines():
        if line.startswith("yes:"):
            return line[4:]
    return ""


def status():
    """{linkUp, connectionType: "wifi"|"wired"|"", address, gateway, networkName}"""
    route_if, gateway = parse_default_route(_read("/proc/net/route"))
    ifaces = interfaces()
    primary = next((i for i in ifaces if i["name"] == route_if), None)
    if primary is None:
        primary = next((i for i in ifaces if i["up"] and i["carrier"]), None)
    if primary is None or not (primary["up"] and primary["carrier"]):
        return {"linkUp": False, "connectionType": "", "address": "", "gateway": "", "networkName": ""}
    wireless = primary["wireless"]
    return {
        "linkUp": True,
        "connectionType": "wifi" if wireless else "wired",
        "address": ipv4_address(primary["name"]),
        "gateway": gateway if primary["name"] == route_if else "",
        "networkName": wifi_network_name() if wireless else "",
    }


class StatusMonitor:
    """Recomputes status when the kernel reports a link, address or route change.

    Event-driven via a netlink socket: no polling. If netlink is unavailable,
    status is recomputed on each request instead.
    """

    GROUPS = 0x1 | 0x10 | 0x40  # RTMGRP_LINK | RTMGRP_IPV4_IFADDR | RTMGRP_IPV4_ROUTE

    def __init__(self, read_status=status):
        self._read_status = read_status
        self._cond = threading.Condition()
        self.version = 1
        self.current = read_status()
        self.event_driven = False
        try:
            self._sock = socket.socket(socket.AF_NETLINK, socket.SOCK_RAW, socket.NETLINK_ROUTE)
            self._sock.bind((0, self.GROUPS))
        except (OSError, AttributeError):
            return
        self.event_driven = True
        threading.Thread(target=self._watch, daemon=True).start()

    def _watch(self):
        while True:
            try:
                self._sock.recv(65536)
                # Changes arrive in bursts; collapse them into one update.
                self._sock.settimeout(0.3)
                while True:
                    self._sock.recv(65536)
            except socket.timeout:
                self._sock.settimeout(None)
            except OSError:
                return
            self.refresh()

    def refresh(self):
        new = self._read_status()
        with self._cond:
            if new != self.current:
                self.current = new
                self.version += 1
                self._cond.notify_all()

    def wait(self, since, timeout):
        """Returns (version, status) once version > since, or after timeout."""
        if self.version > since:
            return self.version, self.current
        if not self.event_driven:
            # Fallback without netlink: re-read at most every 10 s while asked.
            time.sleep(min(timeout, 10))
            self.refresh()
            return self.version, self.current
        with self._cond:
            self._cond.wait_for(lambda: self.version > since, timeout=timeout)
            return self.version, self.current
