#!/bin/sh
# Sideloads out/amber-launcher.zip using the Roku developer web installer.
# Requires Developer Mode on the TV (Home x3, Up x2, Right, Left, Right, Left,
# Right on the remote) and these variables:
#   ROKU_IP        the TV's local address
#   ROKU_DEV_PASS  the password chosen when enabling Developer Mode
# Traffic goes only to the TV on your local network.
set -e
cd "$(dirname "$0")/.."
: "${ROKU_IP:?set ROKU_IP}"
: "${ROKU_DEV_PASS:?set ROKU_DEV_PASS}"
[ -f out/amber-launcher.zip ] || sh scripts/package.sh
curl --fail --silent --show-error --digest --user "rokudev:${ROKU_DEV_PASS}" \
    --form "mysubmit=Install" --form "archive=@out/amber-launcher.zip" \
    "http://${ROKU_IP}/plugin_install" | grep -o '<font color="red">[^<]*' | sed 's/<font color="red">//' || true
echo "Submitted to ${ROKU_IP}. The installer's status message (if any) is shown above."
