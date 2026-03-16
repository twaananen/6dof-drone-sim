#!/usr/bin/env bash
set -euo pipefail

PACKAGE_NAME="${PACKAGE_NAME:-com.fullpotatostudios.dofdronecontroller}"
FILTER_REGEX="${FILTER_REGEX:-QUEST_LOG|godot|openxr|androidruntime|com.fullpotatostudios}"
SAVE_PATH=""
LAUNCH_APP=0
CLEAR_LOGCAT=0
APP_ONLY=0
FULL_LOGCAT=0
WIRELESS_TARGET=""
AUTO_WIRELESS=0
TARGET_SERIAL=""

usage() {
    cat <<'EOF'
Usage:
  bash tools/quest_logcat.sh [options]

Options:
  --launch              Launch the Quest app before streaming logs
  --clear               Clear logcat before streaming
  --save <path>         Save the streamed logs to a file
  --app-only            Prefer PID-filtered logs for the Quest app
  --full                Stream full logcat without filtering
  --wireless <host:port>
                        Connect adb over Wi-Fi before streaming
  --wireless auto       Auto-discover a wireless adb endpoint before streaming
  --auto-wireless       Same as --wireless auto
  -h, --help            Show this help message
EOF
}

require_adb() {
    if ! command -v adb >/dev/null 2>&1; then
        echo "adb is not installed in this environment." >&2
        exit 1
    fi
}

adb_target() {
    adb -s "${TARGET_SERIAL}" "$@"
}

resolve_default_target() {
    local resolve_output=""
    local status=""
    local serial=""
    local message=""

    resolve_output="$(bash tools/quest-adb.sh resolve-target "$@")"
    while IFS='=' read -r key value; do
        case "${key}" in
            STATUS)
                status="${value}"
                ;;
            TARGET_SERIAL)
                serial="${value}"
                ;;
            MESSAGE)
                message="${value}"
                ;;
        esac
    done <<<"${resolve_output}"

    if [ "${status}" != "ready" ] || [ -z "${serial}" ]; then
        echo "${message}" >&2
        exit 1
    fi

    TARGET_SERIAL="${serial}"
}

ensure_device() {
    local state=""

    if [ -n "${WIRELESS_TARGET}" ]; then
        adb connect "${WIRELESS_TARGET}" >/dev/null
        TARGET_SERIAL="${WIRELESS_TARGET}"
    elif [ "${AUTO_WIRELESS}" -eq 1 ]; then
        resolve_default_target --auto-wireless
    else
        resolve_default_target
    fi

    state="$(adb_target get-state 2>/dev/null || true)"
    if [ "${state}" != "device" ]; then
        echo "No ready adb device found. Run 'bash tools/quest-adb.sh doctor' first." >&2
        exit 1
    fi

    echo "Using adb target ${TARGET_SERIAL}." >&2
}

clear_logcat() {
    adb_target logcat -c
}

launch_app() {
    adb_target shell monkey -p "${PACKAGE_NAME}" -c android.intent.category.LAUNCHER 1 >/dev/null
}

resolve_pid() {
    local pid=""
    local _attempt=0

    for _attempt in 1 2 3 4 5; do
        pid="$(adb_target shell pidof -s "${PACKAGE_NAME}" 2>/dev/null | tr -d '\r' || true)"
        if [ -n "${pid}" ]; then
            printf '%s\n' "${pid}"
            return 0
        fi
        sleep 1
    done

    return 1
}

stream_full() {
    adb_target logcat -v time
}

stream_filtered() {
    adb_target logcat -v time | grep -Ei --line-buffered "${FILTER_REGEX}"
}

stream_app_only() {
    local pid="$1"
    adb_target logcat --pid="${pid}" -v time
}

stream_logs() {
    local pid=""

    if [ "${FULL_LOGCAT}" -eq 1 ]; then
        if [ -n "${SAVE_PATH}" ]; then
            stream_full | tee "${SAVE_PATH}"
            return
        fi
        stream_full
        return
    fi

    if [ "${APP_ONLY}" -eq 1 ]; then
        if pid="$(resolve_pid)"; then
            echo "Streaming pid-filtered logs for ${PACKAGE_NAME} (pid ${pid}) from ${TARGET_SERIAL}." >&2
            if [ -n "${SAVE_PATH}" ]; then
                stream_app_only "${pid}" | tee "${SAVE_PATH}"
                return
            fi
            stream_app_only "${pid}"
            return
        fi
        echo "App PID not found; falling back to filtered logcat." >&2
    fi

    if [ -n "${SAVE_PATH}" ]; then
        stream_filtered | tee "${SAVE_PATH}"
        return
    fi
    stream_filtered
}

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --launch)
                LAUNCH_APP=1
                ;;
            --clear)
                CLEAR_LOGCAT=1
                ;;
            --save)
                shift
                if [ $# -eq 0 ]; then
                    echo "--save requires a path." >&2
                    exit 1
                fi
                SAVE_PATH="$1"
                ;;
            --app-only)
                APP_ONLY=1
                ;;
            --full)
                FULL_LOGCAT=1
                ;;
            --wireless)
                shift
                if [ $# -eq 0 ]; then
                    echo "--wireless requires <host:port> or auto." >&2
                    exit 1
                fi
                if [ "$1" = "auto" ]; then
                    AUTO_WIRELESS=1
                else
                    WIRELESS_TARGET="$1"
                fi
                ;;
            --auto-wireless)
                AUTO_WIRELESS=1
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                usage >&2
                exit 1
                ;;
        esac
        shift
    done

    require_adb
    ensure_device

    if [ "${CLEAR_LOGCAT}" -eq 1 ]; then
        clear_logcat
    fi
    if [ "${LAUNCH_APP}" -eq 1 ]; then
        launch_app
    fi

    stream_logs
}

main "$@"
