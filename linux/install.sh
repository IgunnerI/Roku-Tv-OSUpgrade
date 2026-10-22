#!/bin/sh
# Turns a minimal Debian 13 install into an Amber TV box:
#   - installs sway (kiosk compositor), Chromium, Python 3, NetworkManager
#   - creates the "amber" user, which logs in automatically on tty1 and starts
#     sway with the launcher; nothing else runs on screen
#   - applies a Chromium policy that turns off Google telemetry features
#
# Run as root from the console (not over SSH: networking moves to
# NetworkManager and the address may change):
#   sudo sh linux/install.sh
#
# Safe to run again. It does not touch disks, users other than "amber", or
# anything outside the paths listed below. See linux/README.md to undo it.
set -eu

SRC=$(cd "$(dirname "$0")" && pwd)
DEST=/opt/amber
USER_NAME=amber

say() { printf '\n== %s\n' "$*"; }

[ "$(id -u)" -eq 0 ] || { echo "Run as root: sudo sh $0"; exit 1; }
. /etc/os-release
if [ "${ID:-}" != debian ]; then
    echo "This installer supports Debian only (found: ${PRETTY_NAME:-unknown})."
    exit 1
fi
[ "${VERSION_ID:-}" = 13 ] || echo "Warning: written for Debian 13; found ${PRETTY_NAME}. Continuing."

say "Installing packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    sway swaybg chromium python3 network-manager iproute2 iputils-ping procps \
    fonts-dejavu-core ca-certificates sudo
# Debian's only opt-in usage reporter; make sure it is absent.
apt-get purge -y popularity-contest 2>/dev/null || true

say "Copying Amber to $DEST"
rm -rf "$DEST"
install -d -m 755 "$DEST"
cp -r "$SRC/server" "$SRC/ui" "$SRC/bin" "$SRC/sway" "$DEST/"
chmod 755 "$DEST"/bin/*
chown -R root:root "$DEST"

say "Applying the Chromium privacy policy"
install -d -m 755 /etc/chromium/policies/managed
install -m 644 "$SRC/chromium/policies.json" /etc/chromium/policies/managed/amber.json

say "Creating the $USER_NAME user (no password; it only autologins on tty1)"
if ! id "$USER_NAME" >/dev/null 2>&1; then
    useradd --create-home --shell /bin/bash "$USER_NAME"
fi
passwd --lock "$USER_NAME" >/dev/null
cat > "/home/$USER_NAME/.bash_profile" <<'PROFILE'
# Start the Amber kiosk on tty1. If it exits, getty logs in again and restarts it.
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ "$(tty)" = /dev/tty1 ]; then
    exec sway --config /opt/amber/sway/config
fi
PROFILE
chown "$USER_NAME:$USER_NAME" "/home/$USER_NAME/.bash_profile"

say "Enabling autologin on tty1"
install -d /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/amber-autologin.conf <<UNIT
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER_NAME --noclear %I \$TERM
UNIT

if systemctl is-enabled display-manager.service >/dev/null 2>&1; then
    say "Disabling the desktop login screen (Amber replaces it)"
    systemctl disable display-manager.service || true
fi
systemctl set-default multi-user.target

say "Handing networking to NetworkManager"
if grep -Eq '^[[:space:]]*(auto|allow-hotplug|iface)[[:space:]]+[^l]' /etc/network/interfaces 2>/dev/null; then
    cp -n /etc/network/interfaces /etc/network/interfaces.amber-backup
    printf 'auto lo\niface lo inet loopback\n' > /etc/network/interfaces
    echo "Moved the old config to /etc/network/interfaces.amber-backup"
fi
systemctl enable NetworkManager

say "Done"
cat <<NEXT
Next:
  1. On Wi-Fi? Join your network now:   nmtui
     (Wired connections work automatically.)
  2. Reboot:                            systemctl reboot
     The box starts straight into Amber.
  3. Admin access later: Ctrl+Alt+F2 on a keyboard, or SSH, as your own user.
NEXT
