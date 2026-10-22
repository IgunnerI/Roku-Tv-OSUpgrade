#!/bin/sh
# Builds the sideloadable package from source as-is (no transpile, no injected
# helper libraries). Output: out/amber-launcher.zip
set -e
cd "$(dirname "$0")/.."
mkdir -p out
rm -f out/amber-launcher.zip
zip -q -r -X out/amber-launcher.zip manifest source components data images
echo "Built out/amber-launcher.zip ($(wc -c < out/amber-launcher.zip) bytes)"
