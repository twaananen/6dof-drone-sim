#!/usr/bin/env bash
set -euo pipefail

QUEST_USB_PATTERN='(2833:5012|Quest 3)'
export ANDROID_ADB_SERVER_PORT="${ANDROID_ADB_SERVER_PORT:-5037}"
export ADB_VENDOR_KEYS="${ADB_VENDOR_KEYS:-$HOME/.android}"
ADB_SOCKET="tcp:127.0.0.1:${ANDROID_ADB_SERVER_PORT}"

usage() {
    cat <<'EOF'
Usage:
  bash tools/quest-adb.sh doctor
  bash tools/quest-adb.sh repair-usb
  bash tools/quest-adb.sh restart-server
  bash tools/quest-adb.sh tcpip [port]
  bash tools/quest-adb.sh wireless <ip[:port]>
EOF
}

require_adb() {
    if ! command -v adb >/dev/null 2>&1; then
        echo "adb is not installed in this environment." >&2
        exit 1
    fi
}

quest_usb_lines() {
    if ! command -v lsusb >/dev/null 2>&1; then
        return 0
    fi

    lsusb | grep -E "${QUEST_USB_PATTERN}" || true
}

classify_doctor() {
    local adb_output=$1
    local quest_usb=$2

    if printf '%s\n' "${adb_output}" | grep -Eq 'Address already in use|cannot bind|listener'; then
        printf 'server_conflict'
        return
    fi

    if printf '%s\n' "${adb_output}" | grep -Eq 'unauthorized'; then
        printf 'unauthorized'
        return
    fi

    if printf '%s\n' "${adb_output}" | grep -Eq 'no permissions'; then
        printf 'no_permissions'
        return
    fi

    if printf '%s\n' "${adb_output}" | grep -Eq '(^|\n)[^[:space:]]+[[:space:]]+device\b'; then
        if printf '%s\n' "${adb_output}" | grep -Eq ':[0-9]+[[:space:]]+device\b'; then
            printf 'wireless_only'
        else
            printf 'ready'
        fi
        return
    fi

    if [ -n "${quest_usb}" ]; then
        printf 'no_usb_device'
        return
    fi

    printf 'no_usb_device'
}

doctor() {
    local usb_visible="no"
    local quest_usb=""
    local adb_output=""
    local status=""

    require_adb

    if [ -d /dev/bus/usb ]; then
        usb_visible="yes"
    fi

    quest_usb="$(quest_usb_lines)"
    adb_output="$(adb devices -l 2>&1 || true)"
    status="$(classify_doctor "${adb_output}" "${quest_usb}")"

    echo "ADB server socket: ${ADB_SOCKET}"
    echo "USB bus mounted: ${usb_visible}"

    if [ -n "${quest_usb}" ]; then
        echo "Quest USB visible:"
        printf '%s\n' "${quest_usb}"
    else
        echo "Quest USB visible: no"
    fi

    if command -v ss >/dev/null 2>&1; then
        echo "ADB listeners:"
        ss -ltn 2>/dev/null | grep -E ':(5037|5038)\b' || echo "  none"
    fi

    echo "adb devices -l:"
    printf '%s\n' "${adb_output}"
    echo "STATUS: ${status}"

    case "${status}" in
        ready)
            echo "Quest is reachable over USB from this container."
            ;;
        unauthorized)
            echo "Unlock the Quest and accept the USB debugging RSA prompt, then rerun doctor."
            ;;
        no_permissions)
            echo "The Quest USB node is mounted but not writable by $(id -un). Run 'bash tools/quest-adb.sh repair-usb' and rerun doctor."
            ;;
        wireless_only)
            echo "Wireless ADB is active. Use 'bash tools/quest-adb.sh tcpip' from a USB session if you want to refresh it."
            ;;
        server_conflict)
            echo "The container ADB server socket is colliding with another listener. Confirm ${ADB_SOCKET} is reserved for the container."
            ;;
        no_usb_device)
            if [ "${usb_visible}" = "no" ]; then
                echo "The container cannot see /dev/bus/usb. Rebuild the devcontainer so USB passthrough is applied."
            elif [ -n "${quest_usb}" ]; then
                echo "The Quest is on USB but adb does not see it. Confirm developer mode, unlock the headset, and accept USB debugging."
            else
                echo "No Quest USB device is visible. Check the cable and host-side USB access first."
            fi
            ;;
    esac
}

repair_usb() {
    if [ ! -d /dev/bus/usb ]; then
        echo "/dev/bus/usb is not mounted in this container." >&2
        exit 1
    fi

    sudo bash .devcontainer/repair-usb-permissions.sh
}

restart_server() {
    require_adb
    adb kill-server
    adb start-server
}

tcpip_mode() {
    local port="${1:-5555}"
    require_adb
    adb tcpip "${port}"
}

wireless_connect() {
    local target="${1:-}"
    require_adb

    if [ -z "${target}" ]; then
        echo "wireless requires <ip[:port]>." >&2
        exit 1
    fi

    adb connect "${target}"
}

main() {
    local command="${1:-doctor}"

    case "${command}" in
        doctor)
            shift || true
            doctor
            ;;
        repair-usb)
            shift || true
            repair_usb
            ;;
        restart-server)
            shift || true
            restart_server
            ;;
        tcpip)
            shift || true
            tcpip_mode "${1:-5555}"
            ;;
        wireless)
            shift || true
            wireless_connect "${1:-}"
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
