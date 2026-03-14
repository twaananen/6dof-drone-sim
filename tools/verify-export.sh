#!/usr/bin/env bash
# Smoke test: verify the devcontainer can produce a debug APK.
set -euo pipefail

APK_OUT="/tmp/6dof-drone-debug.apk"
FAIL=0

check() {
    local label="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        echo "  [OK]   ${label}"
    else
        echo "  [FAIL] ${label}"
        FAIL=1
    fi
}

echo "=== Verify Android export prerequisites ==="
echo ""

check "godot binary"          command -v godot
check "ANDROID_HOME set"      test -n "${ANDROID_HOME:-}"
check "JAVA_HOME set"         test -n "${JAVA_HOME:-}"
check "debug keystore"        test -f /opt/debug.keystore

GODOT_VERSION="$(cat .godot-version | tr -d '[:space:]')"
GODOT_VER_NUM="${GODOT_VERSION%-stable}"
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VER_NUM}.stable"
check "export templates"      test -f "${TEMPLATES_DIR}/android_debug.apk"

if [ "${FAIL}" -ne 0 ]; then
    echo ""
    echo "Prerequisites missing — cannot export. Run inside the devcontainer."
    exit 1
fi

echo ""
echo "=== Running import pass ==="
timeout 120 godot --headless --import > /dev/null 2>&1 || true

echo ""
echo "=== Exporting debug APK ==="
rm -f "${APK_OUT}"
godot --headless --export-debug "Android" "${APK_OUT}"

if [ -f "${APK_OUT}" ]; then
    SIZE=$(du -h "${APK_OUT}" | cut -f1)
    echo ""
    echo "Export succeeded: ${APK_OUT} (${SIZE})"
    exit 0
else
    echo ""
    echo "Export failed — no APK produced."
    exit 1
fi
