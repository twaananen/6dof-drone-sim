#!/usr/bin/env bash
# Smoke test: verify the devcontainer can produce a debug APK.
set -euo pipefail

APK_OUT="/tmp/6dof-drone-debug.apk"
FAIL=0

find_apksigner() {
    if command -v apksigner > /dev/null 2>&1; then
        command -v apksigner
        return 0
    fi

    if [ -n "${ANDROID_HOME:-}" ] && [ -d "${ANDROID_HOME}/build-tools" ]; then
        find "${ANDROID_HOME}/build-tools" -path '*/apksigner' -type f | sort -V | tail -n 1
        return 0
    fi

    return 1
}

ensure_debug_signature() {
    local apksigner
    apksigner="$(find_apksigner)" || {
        echo "Unable to locate apksigner for APK verification/signing."
        exit 1
    }

    if "${apksigner}" verify --verbose "${APK_OUT}" > /dev/null 2>&1; then
        return 0
    fi

    echo ""
    echo "=== Signing debug APK ==="
    "${apksigner}" sign \
        --ks /opt/debug.keystore \
        --ks-pass pass:android \
        --ks-key-alias androiddebugkey \
        "${APK_OUT}"

    "${apksigner}" verify --verbose "${APK_OUT}" > /dev/null
}

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

check_file_contains() {
    local file="$1"
    local pattern="$2"
    local label="$3"
    if grep -Fqx "${pattern}" "$file" > /dev/null 2>&1; then
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
check "quest export preset"   test -f export_presets.cfg
check "vendors addon"         test -f addons/godotopenxrvendors/plugin.gdextension

GODOT_VERSION="$(cat .godot-version | tr -d '[:space:]')"
GODOT_VER_NUM="${GODOT_VERSION%-stable}"
TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VER_NUM}.stable"
bash tools/install-android-build-template.sh > /dev/null 2>&1
check "export templates"      test -f "${TEMPLATES_DIR}/android_debug.apk"
check "android build template" test -f android/build/build.gradle
check_file_contains export_presets.cfg 'gradle_build/use_gradle_build=true' "gradle export enabled"
check_file_contains export_presets.cfg 'xr_features/xr_mode=1' "OpenXR export mode"
check_file_contains export_presets.cfg 'screen/immersive_mode=true' "immersive mode enabled"
check_file_contains export_presets.cfg 'permissions/internet=true' "INTERNET permission enabled"
check_file_contains export_presets.cfg 'permissions/change_wifi_multicast_state=true' "multicast/broadcast permission enabled"
check_file_contains export_presets.cfg 'xr_features/enable_meta_plugin=true' "Meta vendor plugin enabled"
check_file_contains export_presets.cfg 'meta_xr_features/passthrough=2' "Meta passthrough export enabled"
check_file_contains export_presets.cfg 'meta_xr_features/render_model=2' "Meta render models enabled"
check_file_contains project.godot 'openxr/enabled.android=true' "OpenXR Android project setting enabled"
check_file_contains project.godot 'openxr/default_action_map="res://openxr_action_map.tres"' "OpenXR action map configured"
check_file_contains project.godot 'openxr/extensions/meta/passthrough=true' "Meta passthrough project setting enabled"
check_file_contains project.godot 'openxr/extensions/meta/render_model=true' "Meta render model project setting enabled"
check_file_contains project.godot 'config/icon="res://icon.svg"' "Project icon configured"

if [ "${FAIL}" -ne 0 ]; then
    echo ""
    echo "Quest Android export prerequisites missing — fix the preset or project settings before exporting."
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
    ensure_debug_signature
    SIZE=$(du -h "${APK_OUT}" | cut -f1)
    echo ""
    echo "Export succeeded: ${APK_OUT} (${SIZE})"
    exit 0
else
    echo ""
    echo "Export failed — no APK produced."
    exit 1
fi
