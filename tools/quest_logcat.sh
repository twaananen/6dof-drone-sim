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
  -h, --help            Show this help message
EOF
}

require_adb() {
    if ! command -v adb >/dev/null 2>&1; then
        echo "adb is not installed in this environment." >&2
        exit 1
    fi
}

ensure_device() {
    local state
    state="$(adb get-state 2>/dev/null || true)"
    if [ "${state}" != "device" ]; then
        echo "No ready adb device found. Run 'bash tools/quest-adb.sh doctor' first." >&2
        exit 1
    fi
}

connect_wireless() {
    local target="$1"
    if [ -z "${target}" ]; then
        echo "--wireless requires <host:port>." >&2
        exit 1
    fi
    adb connect "${target}"
}

clear_logcat() {
    adb logcat -c
}

launch_app() {
    adb shell monkey -p "${PACKAGE_NAME}" -c android.intent.category.LAUNCHER 1 >/dev/null
}

resolve_pid() {
    local pid=""
    local _attempt=0
    for _attempt in 1 2 3 4 5; do
        pid="$(adb shell pidof -s "${PACKAGE_NAME}" 2>/dev/null | tr -d '\r' || true)"
        if [ -n "${pid}" ]; then
            printf '%s\n' "${pid}"
            return 0
        fi
        sleep 1
    done
    return 1
}

stream_full() {
    adb logcat -v time
}

stream_filtered() {
    adb logcat -v time | grep -Ei --line-buffered "${FILTER_REGEX}"
}

stream_app_only() {
    local pid="$1"
    adb logcat --pid="${pid}" -v time
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
            echo "Streaming pid-filtered logs for ${PACKAGE_NAME} (pid ${pid})." >&2
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
                    echo "--wireless requires <host:port>." >&2
                    exit 1
                fi
                WIRELESS_TARGET="$1"
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
    if [ -n "${WIRELESS_TARGET}" ]; then
        connect_wireless "${WIRELESS_TARGET}"
    fi
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
