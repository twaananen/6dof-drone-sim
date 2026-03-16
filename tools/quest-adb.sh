#!/usr/bin/env bash
set -euo pipefail

QUEST_USB_PATTERN='(2833:5012|Quest 3)'
export ANDROID_ADB_SERVER_PORT="${ANDROID_ADB_SERVER_PORT:-5037}"
export ADB_VENDOR_KEYS="${ADB_VENDOR_KEYS:-$HOME/.android}"
ADB_SOCKET="tcp:127.0.0.1:${ANDROID_ADB_SERVER_PORT}"

declare -a CONNECTED_USB_SERIALS=()
declare -a CONNECTED_WIRELESS_SERIALS=()
declare -a DISCOVERED_TLS_ENDPOINTS=()
declare -a DISCOVERED_LEGACY_ENDPOINTS=()
declare -a DISCOVERED_WIRELESS_ENDPOINTS=()

usage() {
    cat <<'EOF'
Usage:
  bash tools/quest-adb.sh doctor
  bash tools/quest-adb.sh resolve-target [--auto-wireless]
  bash tools/quest-adb.sh repair-usb
  bash tools/quest-adb.sh restart-server
  bash tools/quest-adb.sh tcpip [port]
  bash tools/quest-adb.sh wireless <ip[:port]>
  bash tools/quest-adb.sh wireless --auto
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

join_by() {
    local delimiter="$1"
    shift || true
    local first=1
    local item=""

    for item in "$@"; do
        if [ "${first}" -eq 1 ]; then
            printf '%s' "${item}"
            first=0
        else
            printf '%s%s' "${delimiter}" "${item}"
        fi
    done
}

push_unique() {
    local array_name="$1"
    local value="$2"
    local -n array_ref="${array_name}"
    local item=""

    if [ -z "${value}" ]; then
        return
    fi

    for item in "${array_ref[@]}"; do
        if [ "${item}" = "${value}" ]; then
            return
        fi
    done

    array_ref+=("${value}")
}

collect_connected_serials() {
    local adb_output="$1"
    local line=""
    local serial=""
    local state=""

    CONNECTED_USB_SERIALS=()
    CONNECTED_WIRELESS_SERIALS=()

    while IFS= read -r line; do
        [ -n "${line}" ] || continue
        case "${line}" in
            "List of devices attached"*)
                continue
                ;;
        esac

        read -r serial state _ <<<"${line}"
        [ -n "${serial}" ] || continue
        [ "${state}" = "device" ] || continue

        if [[ "${serial}" == *:* ]]; then
            CONNECTED_WIRELESS_SERIALS+=("${serial}")
        else
            CONNECTED_USB_SERIALS+=("${serial}")
        fi
    done <<<"${adb_output}"
}

collect_discovered_wireless() {
    local mdns_output="$1"
    local line=""
    local endpoint=""
    local service_type=""

    DISCOVERED_TLS_ENDPOINTS=()
    DISCOVERED_LEGACY_ENDPOINTS=()
    DISCOVERED_WIRELESS_ENDPOINTS=()

    while IFS= read -r line; do
        [ -n "${line}" ] || continue
        case "${line}" in
            "List of discovered mdns services"*)
                continue
                ;;
        esac

        read -r _ service_type endpoint _ <<<"${line}"
        [ -n "${endpoint}" ] || continue

        case "${service_type}" in
            _adb-tls-connect._tcp)
                push_unique DISCOVERED_TLS_ENDPOINTS "${endpoint}"
                push_unique DISCOVERED_WIRELESS_ENDPOINTS "${endpoint}"
                ;;
            _adb._tcp)
                push_unique DISCOVERED_LEGACY_ENDPOINTS "${endpoint}"
                push_unique DISCOVERED_WIRELESS_ENDPOINTS "${endpoint}"
                ;;
        esac
    done <<<"${mdns_output}"
}

resolve_connected_target() {
    local status=""
    local transport="none"
    local serial=""
    local message=""

    local usb_count="${#CONNECTED_USB_SERIALS[@]}"
    local wireless_count="${#CONNECTED_WIRELESS_SERIALS[@]}"

    if [ "${usb_count}" -eq 1 ]; then
        status="ready"
        transport="usb"
        serial="${CONNECTED_USB_SERIALS[0]}"
        message="Using Quest USB target ${serial}."
    elif [ "${usb_count}" -gt 1 ]; then
        status="ambiguous"
        message="Multiple USB adb devices are connected. Disconnect extras or target one explicitly."
    elif [ "${wireless_count}" -eq 1 ]; then
        status="ready"
        transport="wireless"
        serial="${CONNECTED_WIRELESS_SERIALS[0]}"
        message="Using wireless adb target ${serial}."
    elif [ "${wireless_count}" -gt 1 ]; then
        status="ambiguous"
        message="Multiple wireless adb devices are connected. Disconnect extras or target one explicitly."
    else
        status="no_device"
        message="No connected adb target was found."
    fi

    printf '%s|%s|%s|%s\n' "${status}" "${transport}" "${serial}" "${message}"
}

resolve_server_conflict() {
    local adb_output="$1"

    if printf '%s\n' "${adb_output}" | grep -Eq 'Address already in use|cannot bind|listener'; then
        printf '%s\n' "The container ADB server socket is colliding with another listener. Confirm ${ADB_SOCKET} is reserved for the container."
        return 0
    fi

    return 1
}

resolve_access_error() {
    local adb_output="$1"

    if printf '%s\n' "${adb_output}" | grep -Eq 'unauthorized'; then
        printf '%s|%s\n' "unauthorized" "Unlock the Quest and accept the USB debugging RSA prompt, then rerun the command."
        return 0
    fi

    if printf '%s\n' "${adb_output}" | grep -Eq 'no permissions'; then
        printf '%s|%s\n' "no_permissions" "The Quest USB node is mounted but not writable by $(id -un). Run 'bash tools/quest-adb.sh repair-usb' and retry."
        return 0
    fi

    return 1
}

choose_discovered_endpoint() {
    if [ "${#DISCOVERED_TLS_ENDPOINTS[@]}" -eq 1 ]; then
        printf '%s\n' "${DISCOVERED_TLS_ENDPOINTS[0]}"
        return 0
    fi

    if [ "${#DISCOVERED_TLS_ENDPOINTS[@]}" -gt 1 ]; then
        return 2
    fi

    if [ "${#DISCOVERED_LEGACY_ENDPOINTS[@]}" -eq 1 ]; then
        printf '%s\n' "${DISCOVERED_LEGACY_ENDPOINTS[0]}"
        return 0
    fi

    if [ "${#DISCOVERED_LEGACY_ENDPOINTS[@]}" -gt 1 ]; then
        return 2
    fi

    return 1
}

emit_resolve_result() {
    local status="$1"
    local transport="$2"
    local serial="$3"
    local message="$4"

    printf 'STATUS=%s\n' "${status}"
    printf 'TARGET_TRANSPORT=%s\n' "${transport}"
    printf 'TARGET_SERIAL=%s\n' "${serial}"
    printf 'USB_SERIALS=%s\n' "$(join_by , "${CONNECTED_USB_SERIALS[@]}")"
    printf 'WIRELESS_SERIALS=%s\n' "$(join_by , "${CONNECTED_WIRELESS_SERIALS[@]}")"
    printf 'DISCOVERED_WIRELESS=%s\n' "$(join_by , "${DISCOVERED_WIRELESS_ENDPOINTS[@]}")"
    printf 'MESSAGE=%s\n' "${message}"
}

resolve_target() {
    local auto_wireless=0
    local adb_output=""
    local mdns_output=""
    local preflight_message=""
    local resolved=""
    local status=""
    local transport=""
    local serial=""
    local message=""
    local connect_target=""
    local connect_output=""

    if [ "${1:-}" = "--auto-wireless" ]; then
        auto_wireless=1
    elif [ $# -gt 0 ]; then
        echo "Unknown resolve-target option: $1" >&2
        exit 1
    fi

    require_adb

    adb_output="$(adb devices -l 2>&1 || true)"
    if preflight_message="$(resolve_server_conflict "${adb_output}")"; then
        collect_connected_serials "${adb_output}"
        mdns_output="$(adb mdns services 2>/dev/null || true)"
        collect_discovered_wireless "${mdns_output}"
        emit_resolve_result "server_conflict" "none" "" "${preflight_message}"
        return 0
    fi

    collect_connected_serials "${adb_output}"
    mdns_output="$(adb mdns services 2>/dev/null || true)"
    collect_discovered_wireless "${mdns_output}"

    resolved="$(resolve_connected_target)"
    IFS='|' read -r status transport serial message <<<"${resolved}"

    if [ "${status}" = "no_device" ] && preflight_message="$(resolve_access_error "${adb_output}")"; then
        IFS='|' read -r status message <<<"${preflight_message}"
    fi

    if [ "${status}" = "no_device" ] && [ "${auto_wireless}" -eq 1 ]; then
        if connect_target="$(choose_discovered_endpoint)"; then
            if ! connect_output="$(adb connect "${connect_target}" 2>&1)"; then
                message="Failed to connect to discovered wireless adb endpoint ${connect_target}: ${connect_output}"
                emit_resolve_result "no_device" "none" "" "${message}"
                return 0
            fi

            adb_output="$(adb devices -l 2>&1 || true)"
            if preflight_message="$(resolve_server_conflict "${adb_output}")"; then
                collect_connected_serials "${adb_output}"
                emit_resolve_result "server_conflict" "none" "" "${preflight_message}"
                return 0
            fi

            collect_connected_serials "${adb_output}"
            resolved="$(resolve_connected_target)"
            IFS='|' read -r status transport serial message <<<"${resolved}"

            if [ "${status}" = "no_device" ] && preflight_message="$(resolve_access_error "${adb_output}")"; then
                IFS='|' read -r status message <<<"${preflight_message}"
            fi

            if [ "${status}" = "ready" ]; then
                message="Connected to discovered wireless adb endpoint ${connect_target} and selected ${serial}."
            else
                message="Connected to discovered wireless adb endpoint ${connect_target}, but target selection is still ${status}."
            fi
        else
            case $? in
                2)
                    status="ambiguous"
                    message="Multiple discoverable wireless adb endpoints were found. Connect one explicitly or disconnect extras."
                    ;;
                *)
                    status="no_device"
                    message="No connected adb target or discoverable wireless adb endpoint was found."
                    ;;
            esac
        fi
    fi

    emit_resolve_result "${status}" "${transport}" "${serial}" "${message}"
}

doctor() {
    local usb_visible="no"
    local quest_usb=""
    local doctor_output=""
    local status=""
    local transport=""
    local serial=""
    local message=""
    local usb_serials=""
    local wireless_serials=""
    local discovered_wireless=""

    require_adb

    if [ -d /dev/bus/usb ]; then
        usb_visible="yes"
    fi

    quest_usb="$(quest_usb_lines)"
    doctor_output="$(resolve_target)"

    while IFS='=' read -r key value; do
        case "${key}" in
            STATUS)
                status="${value}"
                ;;
            TARGET_TRANSPORT)
                transport="${value}"
                ;;
            TARGET_SERIAL)
                serial="${value}"
                ;;
            USB_SERIALS)
                usb_serials="${value}"
                ;;
            WIRELESS_SERIALS)
                wireless_serials="${value}"
                ;;
            DISCOVERED_WIRELESS)
                discovered_wireless="${value}"
                ;;
            MESSAGE)
                message="${value}"
                ;;
        esac
    done <<<"${doctor_output}"

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

    echo "Connected USB adb serials: ${usb_serials:-none}"
    echo "Connected wireless adb serials: ${wireless_serials:-none}"
    echo "Discoverable wireless adb endpoints: ${discovered_wireless:-none}"
    echo "Preferred transport: ${transport:-none}"
    echo "Preferred serial: ${serial:-none}"
    echo "STATUS: ${status}"
    echo "${message}"

    if [ "${status}" = "no_device" ]; then
        if [ "${usb_visible}" = "no" ]; then
            echo "The container cannot see /dev/bus/usb. Rebuild the devcontainer so USB passthrough is applied."
        elif [ -n "${quest_usb}" ]; then
            echo "The Quest is on USB but adb does not see it. Confirm developer mode, unlock the headset, and accept USB debugging."
        else
            echo "No Quest USB device is visible. Check the cable, or enable wireless debugging and rerun the command."
        fi
    fi
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

wireless_auto_connect() {
    local resolve_output=""
    local status=""
    local serial=""
    local message=""

    resolve_output="$(resolve_target --auto-wireless)"
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

    printf '%s\n' "${serial}"
}

wireless_connect() {
    local target="${1:-}"
    require_adb

    if [ -z "${target}" ]; then
        echo "wireless requires <ip[:port]> or --auto." >&2
        exit 1
    fi

    if [ "${target}" = "--auto" ]; then
        wireless_auto_connect
        return 0
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
        resolve-target)
            shift || true
            resolve_target "$@"
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
