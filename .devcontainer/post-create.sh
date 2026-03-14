#!/usr/bin/env bash
# Idempotent post-create setup for the Godot Android devcontainer.
# Downloads export templates (if missing) and configures editor settings.
set -euo pipefail

GODOT_VERSION="$(cat .godot-version | tr -d '[:space:]')"
GODOT_VER_NUM="${GODOT_VERSION%-stable}"          # e.g. "4.6.1"
GODOT_MAJOR_MINOR="${GODOT_VER_NUM%.*}"           # e.g. "4.6"

TEMPLATES_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VER_NUM}.stable"
EDITOR_SETTINGS="$HOME/.config/godot/editor_settings-${GODOT_MAJOR_MINOR}.tres"

# ── 0. Fix volume ownership ─────────────────────────────────────────
# VS Code's updateUID remaps the container user's UID to match the host.
# Named volumes retain files owned by the old UID, making them unreadable.
# Always claim the volume mount points and their parent dirs.
sudo chown -R "$(id -u):$(id -g)" \
    "$HOME/.local" \
    "$HOME/.cache/godot" \
    "$HOME/.config/godot" \
    "$HOME/.gradle" \
    2>/dev/null || true

# ── 1. Export templates ──────────────────────────────────────────────
if [ ! -f "${TEMPLATES_DIR}/android_debug.apk" ]; then
    echo "▸ Downloading Godot ${GODOT_VERSION} export templates…"
    TEMPLATES_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
    TMP_TPZ="/tmp/export_templates.tpz"

    wget -q --show-progress -O "${TMP_TPZ}" "${TEMPLATES_URL}"

    mkdir -p "${TEMPLATES_DIR}"
    # The .tpz is a zip with files under templates/
    unzip -q -o "${TMP_TPZ}" -d /tmp/tpz_extract
    mv /tmp/tpz_extract/templates/* "${TEMPLATES_DIR}/"
    rm -rf "${TMP_TPZ}" /tmp/tpz_extract

    echo "  Templates installed to ${TEMPLATES_DIR}"
else
    echo "▸ Export templates already present — skipping download."
fi

# ── 2. Editor settings (Android SDK / JDK / keystore paths) ─────────
if [ ! -f "${EDITOR_SETTINGS}" ]; then
    echo "▸ Writing editor settings…"
    mkdir -p "$(dirname "${EDITOR_SETTINGS}")"
    cat > "${EDITOR_SETTINGS}" << 'TRES'
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "/opt/android-sdk"
export/android/java_sdk_path = "/usr/lib/jvm/java-17-openjdk-amd64"
export/android/debug_keystore = "/opt/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
TRES
    echo "  Written to ${EDITOR_SETTINGS}"
else
    echo "▸ Editor settings already present — skipping."
fi

# ── 3. Import pass ──────────────────────────────────────────────────
echo "▸ Running Godot import pass (this may take a moment)…"
timeout 120 godot --headless --import > /dev/null 2>&1 || true
echo "  Import pass complete."

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "=== Devcontainer ready ==="
echo ""
echo "Export a debug APK:"
echo "  godot --headless --export-debug \"Android\" /tmp/6dof-drone-debug.apk"
echo ""
echo "Deploy to Quest (wireless ADB):"
echo "  adb connect <quest-ip>:5555"
echo "  adb install /tmp/6dof-drone-debug.apk"
echo ""
echo "Smoke test:"
echo "  bash tools/verify-export.sh"
echo ""
