#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SCREENSHOT_DIR="${ROOT_DIR}/.screenshots"
SCRCPY_PID_FILE="${SCREENSHOT_DIR}/.scrcpy.pid"

readonly MAX_SCREENSHOTS=20
readonly CAPTURE_TIMEOUT=10
readonly PNG_MAGIC=$'\x89PNG'

usage() {
    cat <<'EOF'
Usage:
  bash tools/quest-screenshot.sh              Capture a single screenshot
  bash tools/quest-screenshot.sh scrcpy       Start scrcpy live mirror
  bash tools/quest-screenshot.sh scrcpy-stop  Stop scrcpy mirror
  bash tools/quest-screenshot.sh clean        Keep only the last 20 captures
  bash tools/quest-screenshot.sh help         Show this help

The capture uses adb screencap over wireless ADB. The Quest must be
connected via wireless ADB before running this script.

Note: adb screencap may not capture VR content on all Quest firmware
versions (OpenXR can bypass Android's SurfaceFlinger). If captures
are black, use scrcpy which reliably captures VR content via MediaCodec.

Screenshots are saved to .screenshots/ with latest.png always being
the most recent capture.
EOF
}

log() {
    printf '==> %s\n' "$*"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_adb() {
    if ! command -v adb >/dev/null 2>&1; then
        die "adb is not installed. Run from inside the distrobox or devcontainer."
    fi
}

resolve_target() {
    local resolve_output=""
    local status=""
    local serial=""
    local message=""

    resolve_output="$(bash "${SCRIPT_DIR}/quest-adb.sh" resolve-target --auto-wireless)"
    while IFS='=' read -r key value; do
        case "${key}" in
            STATUS) status="${value}" ;;
            TARGET_SERIAL) serial="${value}" ;;
            MESSAGE) message="${value}" ;;
        esac
    done <<<"${resolve_output}"

    if [ "${status}" != "ready" ] || [ -z "${serial}" ]; then
        die "No Quest target found. ${message}"
    fi

    printf '%s' "${serial}"
}

ensure_screenshot_dir() {
    mkdir -p "${SCREENSHOT_DIR}"
}

validate_png() {
    local filepath="$1"
    local header=""

    if [ ! -s "${filepath}" ]; then
        return 1
    fi

    header="$(head -c 4 "${filepath}")"
    if [ "${header}" != "${PNG_MAGIC}" ]; then
        return 1
    fi

    return 0
}

auto_clean() {
    local -a all_screenshots=()
    while IFS= read -r -d '' f; do
        all_screenshots+=("${f}")
    done < <(find "${SCREENSHOT_DIR}" -maxdepth 1 -name '*.png' ! -name 'latest.png' -printf '%T@\t%p\0' 2>/dev/null | sort -z -t$'\t' -k1,1n | cut -z -f2-)

    local total="${#all_screenshots[@]}"
    if [ "${total}" -le "${MAX_SCREENSHOTS}" ]; then
        return 0
    fi

    local to_remove=$(( total - MAX_SCREENSHOTS ))
    local i=0
    for f in "${all_screenshots[@]}"; do
        if [ "${i}" -ge "${to_remove}" ]; then
            break
        fi
        rm -f "${f}"
        (( i++ )) || true
    done
}

capture() {
    local serial=""
    local timestamp=""
    local filename=""
    local filepath=""

    require_adb
    ensure_screenshot_dir

    log "Resolving Quest ADB target"
    serial="$(resolve_target)"
    log "Using target: ${serial}"

    timestamp="$(date +%Y%m%d-%H%M%S)"
    filename="${timestamp}.png"
    filepath="${SCREENSHOT_DIR}/${filename}"

    log "Capturing screenshot (${CAPTURE_TIMEOUT}s timeout)"
    if ! timeout "${CAPTURE_TIMEOUT}" adb -s "${serial}" exec-out screencap -p > "${filepath}" 2>/dev/null; then
        rm -f "${filepath}"
        die "screencap failed or timed out. Is the Quest awake? Try: bash tools/quest-adb.sh doctor"
    fi

    if ! validate_png "${filepath}"; then
        rm -f "${filepath}"
        die "Capture is not a valid PNG. adb screencap may not work for VR content on this Quest firmware. Try 'bash tools/quest-screenshot.sh scrcpy' instead."
    fi

    cp -f "${filepath}" "${SCREENSHOT_DIR}/latest.png"
    auto_clean
    log "Saved: ${filepath}"
    printf '%s\n' "${filepath}"
}

scrcpy_start() {
    local serial=""

    if ! command -v scrcpy >/dev/null 2>&1; then
        die "scrcpy is not installed. Run: bash tools/setup-distrobox-ubuntu24.sh"
    fi

    require_adb
    ensure_screenshot_dir

    if [ -f "${SCRCPY_PID_FILE}" ]; then
        local old_pid=""
        old_pid="$(cat "${SCRCPY_PID_FILE}")"
        if kill -0 "${old_pid}" 2>/dev/null; then
            log "scrcpy is already running (PID ${old_pid})"
            return 0
        fi
        rm -f "${SCRCPY_PID_FILE}"
    fi

    log "Resolving Quest ADB target"
    serial="$(resolve_target)"
    log "Using target: ${serial}"

    log "Starting scrcpy mirror"
    scrcpy \
        --serial="${serial}" \
        --max-size=1024 \
        --max-fps=30 \
        --video-bit-rate=4M \
        --window-title="Quest 3 Mirror" \
        --stay-awake \
        --no-audio \
        &
    local pid=$!
    echo "${pid}" > "${SCRCPY_PID_FILE}"
    log "scrcpy running (PID ${pid})"
}

scrcpy_stop() {
    if [ ! -f "${SCRCPY_PID_FILE}" ]; then
        log "No scrcpy PID file found"
        return 0
    fi

    local pid=""
    pid="$(cat "${SCRCPY_PID_FILE}")"
    if kill -0 "${pid}" 2>/dev/null; then
        kill "${pid}"
        log "Stopped scrcpy (PID ${pid})"
    else
        log "scrcpy was not running"
    fi
    rm -f "${SCRCPY_PID_FILE}"
}

clean() {
    ensure_screenshot_dir

    local -a all_screenshots=()
    while IFS= read -r -d '' f; do
        all_screenshots+=("${f}")
    done < <(find "${SCREENSHOT_DIR}" -maxdepth 1 -name '*.png' ! -name 'latest.png' -printf '%T@\t%p\0' | sort -z -t$'\t' -k1,1n | cut -z -f2-)

    local total="${#all_screenshots[@]}"
    if [ "${total}" -le "${MAX_SCREENSHOTS}" ]; then
        log "Only ${total} screenshots, nothing to clean"
        return 0
    fi

    local to_remove=$(( total - MAX_SCREENSHOTS ))
    local i=0
    for f in "${all_screenshots[@]}"; do
        if [ "${i}" -ge "${to_remove}" ]; then
            break
        fi
        rm -f "${f}"
        (( i++ )) || true
    done

    log "Removed ${to_remove} old screenshots, kept ${MAX_SCREENSHOTS}"
}

main() {
    local command="${1:-capture}"

    case "${command}" in
        capture)
            capture
            ;;
        scrcpy)
            scrcpy_start
            ;;
        scrcpy-stop)
            scrcpy_stop
            ;;
        clean)
            clean
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            echo "Unknown command: ${command}" >&2
            usage >&2
            exit 1
            ;;
    esac
}

main "$@"
