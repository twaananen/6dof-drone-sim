#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(pwd)"

readonly GODOT_OPENXR_VENDORS_VERSION="4.3.0-stable"
readonly ANDROID_HOME_DIR="/opt/android-sdk"
readonly ANDROID_PLATFORM="android-35"
readonly ANDROID_BUILD_TOOLS="35.0.1"
readonly ANDROID_CMAKE="3.10.2.4988404"
readonly ANDROID_NDK="28.1.13356709"
readonly JAVA_HOME_DIR="/usr/lib/jvm/java-17-openjdk-amd64"
readonly DEBUG_KEYSTORE="/opt/debug.keystore"
readonly CMDLINE_TOOLS_BOOTSTRAP_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
readonly SCRCPY_REPO="https://github.com/Genymobile/scrcpy.git"

readonly -a REQUIRED_REPO_FILES=(
    ".godot-version"
    "project.godot"
    "export_presets.cfg"
    "tools/install-android-build-template.sh"
    "tools/verify-export.sh"
)

readonly -a APT_PACKAGES=(
    ca-certificates
    curl
    wget
    unzip
    zip
    xz-utils
    file
    git
    python3
    openjdk-17-jdk
    build-essential
    pkg-config
    iproute2
    usbutils
    sudo
    fontconfig
    libfontconfig1
    libfreetype6
    libasound2t64
    libpulse0
    libx11-6
    libxcursor1
    libxext6
    libxi6
    libxinerama1
    libxkbcommon0
    libxrandr2
    libxrender1
    libwayland-client0
    libwayland-cursor0
    libwayland-egl1
    libgl1
    libegl1
    libvulkan1
    libdbus-1-3
    libudev1
    ffmpeg
    libsdl2-2.0-0
    libsdl2-dev
    libavcodec-dev
    libavdevice-dev
    libavformat-dev
    libavutil-dev
    libswresample-dev
    libusb-1.0-0
    libusb-1.0-0-dev
    meson
    ninja-build
)

readonly -a SDK_PACKAGES=(
    "cmdline-tools;latest"
    "platform-tools"
    "build-tools;35.0.1"
    "platforms;android-35"
    "cmake;3.10.2.4988404"
    "ndk;28.1.13356709"
)

readonly -a REQUIRED_VENDOR_FILES=(
    "addons/godotopenxrvendors/plugin.gdextension"
    "addons/godotopenxrvendors/.bin/android/debug/godotopenxr-meta-debug.aar"
    "addons/godotopenxrvendors/.bin/android/release/godotopenxr-meta-release.aar"
    "addons/godotopenxrvendors/.bin/android/template_debug/arm64/libgodotopenxrvendors.so"
    "addons/godotopenxrvendors/.bin/android/template_release/arm64/libgodotopenxrvendors.so"
)

GODOT_VERSION=""
GODOT_VER_NUM=""
GODOT_MAJOR_MINOR=""
GODOT_MAJOR=""
TEMPLATES_DIR=""
EDITOR_SETTINGS=""
EDITOR_SETTINGS_COMPAT=""
SDKMANAGER_BIN=""

log() {
    printf '==> %s\n' "$*"
}

warn() {
    printf 'WARNING: %s\n' "$*" >&2
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_command() {
    local command_name="$1"
    if ! command -v "${command_name}" >/dev/null 2>&1; then
        die "Required command not found: ${command_name}"
    fi
}

check_repo_root() {
    local path=""
    for path in "${REQUIRED_REPO_FILES[@]}"; do
        if [ ! -e "${ROOT_DIR}/${path}" ]; then
            die "Run this script from the repository root. Missing ${path}."
        fi
    done
}

check_os() {
    if [ ! -f /etc/os-release ]; then
        die "/etc/os-release is missing."
    fi

    # shellcheck disable=SC1091
    . /etc/os-release

    if [ "${ID:-}" != "ubuntu" ]; then
        die "This script only supports Ubuntu 24.04."
    fi

    if [ "${VERSION_ID:-}" != "24.04" ]; then
        die "This script only supports Ubuntu 24.04. Found ${VERSION_ID:-unknown}."
    fi
}

check_distrobox_context() {
    if [ -n "${DISTROBOX_ENTER_PATH:-}" ] || [ -n "${container:-}" ] || [ -f /run/.containerenv ]; then
        return 0
    fi

    warn "Distrobox indicators were not found. Continuing anyway."
}

probe_url() {
    local url="$1"
    local host="${url#https://}"
    host="${host%%/*}"

    if command -v curl >/dev/null 2>&1; then
        curl -A 'Mozilla/5.0' -LfsI --connect-timeout 5 --max-time 15 "${url}" >/dev/null 2>&1
        return $?
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -q --spider --timeout=15 "${url}" >/dev/null 2>&1
        return $?
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - "${url}" <<'PY' >/dev/null 2>&1
import sys
import urllib.request

req = urllib.request.Request(sys.argv[1], method="HEAD", headers={"User-Agent": "Mozilla/5.0"})
with urllib.request.urlopen(req, timeout=15):
    pass
PY
        return $?
    fi

    timeout 5 bash -lc "exec 3<>/dev/tcp/${host}/443" >/dev/null 2>&1
}

check_network() {
    log "Checking outbound network access"

    if ! probe_url "https://github.com/"; then
        die "Network check failed for https://github.com/."
    fi

    if ! probe_url "https://dl.google.com/"; then
        die "Network check failed for https://dl.google.com/."
    fi
}

load_versions() {
    GODOT_VERSION="$(tr -d '[:space:]' < "${ROOT_DIR}/.godot-version")"
    if [ -z "${GODOT_VERSION}" ]; then
        die ".godot-version is empty."
    fi

    GODOT_VER_NUM="${GODOT_VERSION%-stable}"
    GODOT_MAJOR_MINOR="${GODOT_VER_NUM%.*}"
    GODOT_MAJOR="${GODOT_VER_NUM%%.*}"
    TEMPLATES_DIR="${HOME}/.local/share/godot/export_templates/${GODOT_VER_NUM}.stable"
    EDITOR_SETTINGS="${HOME}/.config/godot/editor_settings-${GODOT_MAJOR_MINOR}.tres"
    EDITOR_SETTINGS_COMPAT="${HOME}/.config/godot/editor_settings-${GODOT_MAJOR}.tres"
}

install_apt_packages() {
    log "Installing Ubuntu packages"
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends "${APT_PACKAGES[@]}"
}

write_profile_env() {
    log "Writing Android environment profile"
    sudo tee /etc/profile.d/6dof-drone-sim-android.sh >/dev/null <<EOF
export ANDROID_HOME="${ANDROID_HOME_DIR}"
export ANDROID_NDK_ROOT="${ANDROID_HOME_DIR}/ndk/${ANDROID_NDK}"
export JAVA_HOME="${JAVA_HOME_DIR}"
export PATH="${ANDROID_HOME_DIR}/cmdline-tools/latest/bin:${ANDROID_HOME_DIR}/platform-tools:\$PATH"
export ADB_VENDOR_KEYS="\$HOME/.android"
EOF

    export ANDROID_HOME="${ANDROID_HOME_DIR}"
    export ANDROID_NDK_ROOT="${ANDROID_HOME_DIR}/ndk/${ANDROID_NDK}"
    export JAVA_HOME="${JAVA_HOME_DIR}"
    export PATH="${ANDROID_HOME_DIR}/cmdline-tools/latest/bin:${ANDROID_HOME_DIR}/platform-tools:${PATH}"
    export ADB_VENDOR_KEYS="${HOME}/.android"
}

prepare_android_sdk_dirs() {
    sudo mkdir -p "${ANDROID_HOME_DIR}"
    sudo chown -R "$(id -u):$(id -g)" "${ANDROID_HOME_DIR}"
    mkdir -p "${ANDROID_HOME_DIR}/cmdline-tools" "${HOME}/.android"
}

install_android_cmdline_tools() {
    local bootstrap_dir="${ANDROID_HOME_DIR}/cmdline-tools/bootstrap"
    local download_zip

    if [ -x "${ANDROID_HOME_DIR}/cmdline-tools/latest/bin/sdkmanager" ]; then
        SDKMANAGER_BIN="${ANDROID_HOME_DIR}/cmdline-tools/latest/bin/sdkmanager"
        return 0
    fi

    log "Installing Android command-line tools bootstrap"
    download_zip="$(mktemp /tmp/android-cmdline-tools.XXXXXX.zip)"
    wget -q --show-progress -O "${download_zip}" "${CMDLINE_TOOLS_BOOTSTRAP_URL}"

    rm -rf "${bootstrap_dir}"
    mkdir -p "${bootstrap_dir}"
    unzip -q -o "${download_zip}" -d "${bootstrap_dir}"
    rm -f "${download_zip}"

    # Keep bootstrap in place — sdkmanager will install cmdline-tools;latest
    # into the canonical latest/ directory without a self-update conflict.
    if [ -d "${bootstrap_dir}/cmdline-tools" ]; then
        mv "${bootstrap_dir}/cmdline-tools"/* "${bootstrap_dir}/"
        rmdir "${bootstrap_dir}/cmdline-tools"
    fi

    SDKMANAGER_BIN="${bootstrap_dir}/bin/sdkmanager"
}

install_android_sdk_packages() {
    log "Installing Android SDK packages"
    set +o pipefail
    yes | "${SDKMANAGER_BIN}" --sdk_root="${ANDROID_HOME_DIR}" --licenses >/dev/null
    set -o pipefail
    "${SDKMANAGER_BIN}" --sdk_root="${ANDROID_HOME_DIR}" "${SDK_PACKAGES[@]}"
    normalize_android_cmdline_tools_latest

    # Remove bootstrap now that cmdline-tools;latest installed the canonical tools.
    if [ -d "${ANDROID_HOME_DIR}/cmdline-tools/bootstrap" ]; then
        rm -rf "${ANDROID_HOME_DIR}/cmdline-tools/bootstrap"
    fi
    SDKMANAGER_BIN="${ANDROID_HOME_DIR}/cmdline-tools/latest/bin/sdkmanager"
}

normalize_android_cmdline_tools_latest() {
    local cmdline_tools_root="${ANDROID_HOME_DIR}/cmdline-tools"
    local promoted_dir=""
    local candidate=""

    if [ ! -d "${cmdline_tools_root}" ]; then
        return 0
    fi

    while IFS= read -r candidate; do
        promoted_dir="${candidate}"
    done < <(find "${cmdline_tools_root}" -mindepth 1 -maxdepth 1 -type d -name 'latest-*' | sort -V)

    if [ -z "${promoted_dir}" ]; then
        return 0
    fi

    log "Normalizing Android command-line tools path"
    rm -rf "${cmdline_tools_root}/latest"
    mv "${promoted_dir}" "${cmdline_tools_root}/latest"
}

ensure_debug_keystore() {
    if [ -f "${DEBUG_KEYSTORE}" ]; then
        return 0
    fi

    log "Creating Android debug keystore"
    sudo keytool -genkeypair \
        -alias androiddebugkey \
        -keypass android \
        -keystore "${DEBUG_KEYSTORE}" \
        -storepass android \
        -dname "CN=Android Debug,O=Android,C=US" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000
    sudo chmod 0644 "${DEBUG_KEYSTORE}"
}

install_godot_binary() {
    local target_bin="/usr/local/bin/godot"
    local current_version=""
    local tmp_dir=""
    local zip_path=""

    if [ -x "${target_bin}" ]; then
        current_version="$("${target_bin}" --version 2>/dev/null || true)"
        if [[ "${current_version}" == "${GODOT_VER_NUM}.stable."* ]]; then
            log "Godot ${GODOT_VERSION} already installed"
            if [ ! -e /usr/local/bin/godot4 ]; then
                sudo ln -s /usr/local/bin/godot /usr/local/bin/godot4
            fi
            return 0
        fi
    fi

    log "Installing Godot ${GODOT_VERSION}"
    tmp_dir="$(mktemp -d)"
    zip_path="${tmp_dir}/godot.zip"

    wget -q --show-progress -O "${zip_path}" \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    unzip -q -o "${zip_path}" -d "${tmp_dir}"
    sudo install -m 0755 "${tmp_dir}/Godot_v${GODOT_VERSION}_linux.x86_64" "${target_bin}"

    if [ ! -e /usr/local/bin/godot4 ]; then
        sudo ln -s /usr/local/bin/godot /usr/local/bin/godot4
    fi

    rm -rf "${tmp_dir}"
}

install_export_templates() {
    local temp_tpz=""
    local extract_dir=""

    mkdir -p "${TEMPLATES_DIR}"

    if [ -f "${TEMPLATES_DIR}/android_debug.apk" ]; then
        log "Godot export templates already present"
        return 0
    fi

    log "Installing Godot export templates"
    temp_tpz="$(mktemp /tmp/godot-export-templates.XXXXXX.tpz)"
    extract_dir="$(mktemp -d)"

    wget -q --show-progress -O "${temp_tpz}" \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
    unzip -q -o "${temp_tpz}" -d "${extract_dir}"
    mv "${extract_dir}/templates/"* "${TEMPLATES_DIR}/"

    rm -f "${temp_tpz}"
    rm -rf "${extract_dir}"
}

write_one_editor_settings_file() {
    local settings_path="$1"

    python3 - "${settings_path}" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
managed_keys = {
    'export/android/android_sdk_path': '"/opt/android-sdk"',
    'export/android/java_sdk_path': '"/usr/lib/jvm/java-17-openjdk-amd64"',
    'export/android/debug_keystore': '"/opt/debug.keystore"',
    'export/android/debug_keystore_user': '"androiddebugkey"',
    'export/android/debug_keystore_pass': '"android"',
}

if path.exists():
    lines = path.read_text(encoding='utf-8').splitlines()
else:
    lines = ['[gd_resource type="EditorSettings" format=3]', '', '[resource]']

if not lines:
    lines = ['[gd_resource type="EditorSettings" format=3]', '', '[resource]']

if not any(line.strip() == '[gd_resource type="EditorSettings" format=3]' for line in lines):
    lines.insert(0, '[gd_resource type="EditorSettings" format=3]')

if not any(line.strip() == '[resource]' for line in lines):
    lines.extend(['', '[resource]'])

filtered = []
for line in lines:
    key = line.split('=', 1)[0].strip()
    if key in managed_keys:
        continue
    filtered.append(line)

resource_index = next(i for i, line in enumerate(filtered) if line.strip() == '[resource]')
insert_at = resource_index + 1
while insert_at < len(filtered) and filtered[insert_at].strip() != '':
    insert_at += 1

managed_lines = [f'{key} = {value}' for key, value in managed_keys.items()]
filtered[insert_at:insert_at] = managed_lines

text = '\n'.join(filtered).rstrip() + '\n'
path.write_text(text, encoding='utf-8')
PY
}

write_editor_settings() {
    log "Ensuring Godot editor settings"
    mkdir -p "$(dirname "${EDITOR_SETTINGS}")"

    write_one_editor_settings_file "${EDITOR_SETTINGS}"
    if [ "${EDITOR_SETTINGS_COMPAT}" != "${EDITOR_SETTINGS}" ]; then
        write_one_editor_settings_file "${EDITOR_SETTINGS_COMPAT}"
    fi
}

ensure_openxr_vendors_addon() {
    local path=""
    local missing=0
    local temp_dir=""
    local zip_path=""

    for path in "${REQUIRED_VENDOR_FILES[@]}"; do
        if [ ! -f "${ROOT_DIR}/${path}" ]; then
            missing=1
            break
        fi
    done

    if [ "${missing}" -eq 0 ]; then
        log "Godot OpenXR Vendors addon already complete"
        return 0
    fi

    log "Repairing Godot OpenXR Vendors addon from release ${GODOT_OPENXR_VENDORS_VERSION}"
    temp_dir="$(mktemp -d)"
    zip_path="${temp_dir}/godotopenxrvendorsaddon.zip"

    wget -q --show-progress -O "${zip_path}" \
        "https://github.com/GodotVR/godot_openxr_vendors/releases/download/${GODOT_OPENXR_VENDORS_VERSION}/godotopenxrvendorsaddon.zip"
    unzip -q -o "${zip_path}" -d "${temp_dir}"

    mkdir -p "${ROOT_DIR}/addons/godotopenxrvendors"
    cp -an "${temp_dir}/asset/addons/godotopenxrvendors/." "${ROOT_DIR}/addons/godotopenxrvendors/"

    rm -rf "${temp_dir}"
}

install_scrcpy() {
    if command -v scrcpy >/dev/null 2>&1; then
        log "scrcpy already installed: $(scrcpy --version 2>&1 | head -1)"
        return 0
    fi

    log "Installing scrcpy from source"
    local build_dir=""
    build_dir="$(mktemp -d)"

    # Pre-create icon directories that meson install expects.
    # On immutable hosts (Bazzite) these paths may be read-only; the
    # distrobox overlay usually makes /usr/local writable, but the
    # deep icon hierarchy may not exist yet.
    sudo mkdir -p /usr/local/share/icons/hicolor/256x256/apps 2>/dev/null || true

    git clone --depth 1 "${SCRCPY_REPO}" "${build_dir}/scrcpy"
    cd "${build_dir}/scrcpy"
    bash install_release.sh
    cd "${ROOT_DIR}"

    rm -rf "${build_dir}"

    if command -v scrcpy >/dev/null 2>&1; then
        log "scrcpy installed: $(scrcpy --version 2>&1 | head -1)"
    else
        warn "scrcpy installation may have failed. Check the output above."
    fi
}

prepare_project() {
    log "Preparing Android build template"
    bash "${ROOT_DIR}/tools/install-android-build-template.sh"

    log "Running headless Godot import pass"
    local import_exit=0
    timeout 120 godot --headless --import 2>&1 || import_exit=$?
    if [ "${import_exit}" -ne 0 ]; then
        warn "Import pass exited ${import_exit} (may be normal for headless)"
    fi
    sync
}

verify_environment() {
    log "Version summary"
    godot --version
    java -version
    adb version

    log "Running export verification"
    bash "${ROOT_DIR}/tools/verify-export.sh"
}

print_next_steps() {
    printf '\n'
    printf 'Setup complete.\n'
    printf '\n'
    printf 'Next steps:\n'
    printf '  godot\n'
    printf '  bash tools/run_tests.sh\n'
    printf '  bash tools/quest-adb.sh doctor\n'
    printf '  bash tools/quest-deploy.sh export\n'
    printf '  bash tools/quest-deploy.sh\n'
    printf '  bash tools/quest-screenshot.sh\n'
}

main() {
    require_command bash
    require_command sudo
    require_command timeout

    check_repo_root
    check_os
    check_distrobox_context
    check_network
    load_versions
    install_apt_packages
    write_profile_env
    prepare_android_sdk_dirs
    install_android_cmdline_tools
    install_android_sdk_packages
    ensure_debug_keystore
    install_godot_binary
    install_export_templates
    write_editor_settings
    ensure_openxr_vendors_addon
    install_scrcpy
    prepare_project
    verify_environment
    print_next_steps
}

main "$@"
