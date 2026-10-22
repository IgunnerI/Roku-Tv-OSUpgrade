#!/bin/sh
# Runs the off-device unit tests for the pure logic in components/lib.
# "-c tests" works around brs 0.45 globbing from / when no extra dir is given.
set -e
cd "$(dirname "$0")/.."
out=$(npx brs --root . -c tests \
    components/lib/FocusNav.brs components/lib/RecentUsage.brs components/lib/Catalog.brs \
    components/lib/Diagnostics.brs components/lib/SettingsContent.brs \
    tests/assert.brs tests/test_focusnav.brs tests/test_recent.brs tests/test_catalog.brs \
    tests/test_diagnostics.brs tests/test_settings.brs tests/main.brs 2>&1 | grep -v "extends unknown component 'Task'")
echo "$out"
echo "$out" | grep -q "Failed: 0$"
