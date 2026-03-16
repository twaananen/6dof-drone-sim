#!/usr/bin/env bash
set -euo pipefail

APK_OUT="${APK_OUT:-/tmp/6dof-drone-debug.apk}"
QUEST_DEPLOY_EXPORT_SCRIPT="${QUEST_DEPLOY_EXPORT_SCRIPT:-tools/verify-export.sh}"
QUEST_DEPLOY_RECOVERY_RETRIES="${QUEST_DEPLOY_RECOVERY_RETRIES:-3}"
QUEST_DEPLOY_RECOVERY_DELAY_SECS="${QUEST_DEPLOY_RECOVERY_DELAY_SECS:-1}"

RESOLVE_STATUS=""
RESOLVE_TRANSPORT=""
RESOLVE_SERIAL=""
RESOLVE_MESSAGE=""
RESOLVE_USB_SERIALS=""
RESOLVE_WIRELESS_SERIALS=""
RESOLVE_DISCOVERED_WIRELESS=""

usage() {
    cat <<EOF
Usage:
  bash tools/quest-deploy.sh
  bash tools/quest-deploy.sh export
  bash tools/quest-deploy.sh install
  bash tools/quest-deploy.sh reinstall
  bash tools/quest-deploy.sh doctor

Commands:
  export    Run the existing export verification/export flow and write ${APK_OUT}
  install   Resolve the preferred Quest ADB target, then install ${APK_OUT}
  reinstall Uninstall the existing package from the selected target, then install ${APK_OUT}
  doctor    Run the Quest ADB diagnostics helper

Default behavior with no command:
  export + install
EOF
}

parse_resolve_output() {
    local resolve_output="$1"
    local key=""
    local value=""

    RESOLVE_STATUS=""
    RESOLVE_TRANSPORT=""
    RESOLVE_SERIAL=""
    RESOLVE_MESSAGE=""
    RESOLVE_USB_SERIALS=""
    RESOLVE_WIRELESS_SERIALS=""
    RESOLVE_DISCOVERED_WIRELESS=""

    while IFS='=' read -r key value; do
        case "${key}" in
            STATUS)
                RESOLVE_STATUS="${value}"
                ;;
            TARGET_TRANSPORT)
                RESOLVE_TRANSPORT="${value}"
                ;;
            TARGET_SERIAL)
                RESOLVE_SERIAL="${value}"
                ;;
            USB_SERIALS)
                RESOLVE_USB_SERIALS="${value}"
                ;;
            WIRELESS_SERIALS)
                RESOLVE_WIRELESS_SERIALS="${value}"
                ;;
            DISCOVERED_WIRELESS)
                RESOLVE_DISCOVERED_WIRELESS="${value}"
                ;;
            MESSAGE)
                RESOLVE_MESSAGE="${value}"
                ;;
        esac
    done <<<"${resolve_output}"
}

csv_count() {
    local value="$1"
    local IFS=','
    local -a items=()

    if [ -z "${value}" ]; then
        printf '0\n'
        return
    fi

    read -r -a items <<<"${value}"
    printf '%s\n' "${#items[@]}"
}

run_export() {
    bash "${QUEST_DEPLOY_EXPORT_SCRIPT}"
}

repair_usb_if_available() {
    if [ -d /dev/bus/usb ]; then
        bash tools/quest-adb.sh repair-usb
    fi
}

ensure_apk_exists() {
    if [ ! -f "${APK_OUT}" ]; then
        echo "APK not found at ${APK_OUT}. Run 'bash tools/quest-deploy.sh export' first." >&2
        exit 1
    fi
}

report_next_steps() {
    echo "Next steps:" >&2
    echo "- Plug the Quest in over USB and unlock it." >&2
    echo "- Or enable wireless debugging / SideQuest wireless ADB and rerun the command." >&2
}

report_resolve_failure() {
    local override_message="${1:-}"
    local extra_message="${2:-}"
    local message="${override_message:-${RESOLVE_MESSAGE}}"

    case "${RESOLVE_STATUS}" in
        ambiguous)
            printf '%s\n' "${message}" >&2
            printf 'Connected USB adb serials: %s\n' "${RESOLVE_USB_SERIALS:-none}" >&2
            printf 'Connected wireless adb serials: %s\n' "${RESOLVE_WIRELESS_SERIALS:-none}" >&2
            printf 'Discoverable wireless adb endpoints: %s\n' "${RESOLVE_DISCOVERED_WIRELESS:-none}" >&2
            ;;
        no_device)
            printf '%s\n' "${message}" >&2
            if [ -n "${extra_message}" ]; then
                printf '%s\n' "${extra_message}" >&2
            fi
            report_next_steps
            ;;
        *)
            printf '%s\n' "${message}" >&2
            ;;
    esac

    exit 1
}

emit_selected_target() {
    printf 'Using Quest target: %s (%s)\n' "${RESOLVE_SERIAL}" "${RESOLVE_TRANSPORT}" >&2
    printf '%s\n' "${RESOLVE_SERIAL}"
}

snapshot_recovery_hint() {
    local resolve_output=""

    resolve_output="$(bash tools/quest-adb.sh resolve-target)"
    parse_resolve_output "${resolve_output}"

    if [ "${RESOLVE_TRANSPORT}" = "wireless" ] && [ -n "${RESOLVE_SERIAL}" ]; then
        printf '%s\n' "${RESOLVE_SERIAL}"
        return 0
    fi

    if [ "$(csv_count "${RESOLVE_DISCOVERED_WIRELESS}")" -eq 1 ]; then
        printf '%s\n' "${RESOLVE_DISCOVERED_WIRELESS}"
    fi
}

resolve_install_target() {
    local resolve_output=""

    resolve_output="$(bash tools/quest-adb.sh resolve-target --auto-wireless)"
    parse_resolve_output "${resolve_output}"

    if [ "${RESOLVE_STATUS}" = "ready" ]; then
        emit_selected_target
        return 0
    fi

    report_resolve_failure
}

resolve_install_target_with_recovery() {
    local recovery_hint="${1:-}"
    local resolve_output=""
    local initial_no_device_message=""
    local attempt=1
    local connect_output=""

    resolve_output="$(bash tools/quest-adb.sh resolve-target --auto-wireless)"
    parse_resolve_output "${resolve_output}"

    if [ "${RESOLVE_STATUS}" = "ready" ]; then
        emit_selected_target
        return 0
    fi

    if [ "${RESOLVE_STATUS}" != "no_device" ]; then
        report_resolve_failure
    fi

    initial_no_device_message="${RESOLVE_MESSAGE}"
    echo "Quest deploy export likely reset the ADB session; attempting wireless recovery." >&2
    adb start-server >/dev/null 2>&1 || true

    while [ "${attempt}" -le "${QUEST_DEPLOY_RECOVERY_RETRIES}" ]; do
        resolve_output="$(bash tools/quest-adb.sh resolve-target --auto-wireless)"
        parse_resolve_output "${resolve_output}"

        if [ "${RESOLVE_STATUS}" = "ready" ]; then
            emit_selected_target
            return 0
        fi

        if [ "${RESOLVE_STATUS}" != "no_device" ]; then
            report_resolve_failure
        fi

        if [ -n "${recovery_hint}" ]; then
            if connect_output="$(adb connect "${recovery_hint}" 2>&1)"; then
                printf '%s\n' "${connect_output}" >&2
            elif [ -n "${connect_output}" ]; then
                printf '%s\n' "${connect_output}" >&2
            fi

            resolve_output="$(bash tools/quest-adb.sh resolve-target --auto-wireless)"
            parse_resolve_output "${resolve_output}"

            if [ "${RESOLVE_STATUS}" = "ready" ]; then
                emit_selected_target
                return 0
            fi

            if [ "${RESOLVE_STATUS}" != "no_device" ]; then
                report_resolve_failure
            fi
        fi

        if [ "${attempt}" -lt "${QUEST_DEPLOY_RECOVERY_RETRIES}" ]; then
            sleep "${QUEST_DEPLOY_RECOVERY_DELAY_SECS}"
        fi

        attempt=$((attempt + 1))
    done

    RESOLVE_STATUS="no_device"
    RESOLVE_MESSAGE="${initial_no_device_message}"
    report_resolve_failure \
        "${initial_no_device_message}" \
        "Export appears to have reset ADB and the recovery pass could not re-establish the Quest wireless target."
}

apk_package_name() {
    local aapt_bin=""

    if [ -n "${ANDROID_HOME:-}" ] && [ -x "${ANDROID_HOME}/build-tools/35.0.1/aapt" ]; then
        aapt_bin="${ANDROID_HOME}/build-tools/35.0.1/aapt"
    elif command -v aapt >/dev/null 2>&1; then
        aapt_bin="$(command -v aapt)"
    fi

    if [ -z "${aapt_bin}" ]; then
        return 1
    fi

    "${aapt_bin}" dump badging "${APK_OUT}" | sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p" | head -n 1
}

run_install_for_serial() {
    local target_serial="$1"
    local install_output=""

    if install_output="$(adb -s "${target_serial}" install -r "${APK_OUT}" 2>&1)"; then
        printf '%s\n' "${install_output}"
        return 0
    fi

    printf '%s\n' "${install_output}" >&2

    if printf '%s\n' "${install_output}" | grep -q 'INSTALL_FAILED_UPDATE_INCOMPATIBLE'; then
        local package_name=""
        package_name="$(apk_package_name || true)"
        if [ -n "${package_name}" ]; then
            echo "Uninstall the old package first: adb -s ${target_serial} uninstall ${package_name}" >&2
        fi
    fi

    exit 1
}

run_install() {
    local target_serial=""

    ensure_apk_exists
    repair_usb_if_available

    target_serial="$(resolve_install_target | tail -n 1)"
    run_install_for_serial "${target_serial}"
}

run_install_with_hint() {
    local recovery_hint="${1:-}"
    local target_serial=""

    ensure_apk_exists
    repair_usb_if_available

    target_serial="$(resolve_install_target_with_recovery "${recovery_hint}" | tail -n 1)"
    run_install_for_serial "${target_serial}"
}

run_reinstall() {
    local target_serial=""
    local package_name=""

    ensure_apk_exists
    repair_usb_if_available

    target_serial="$(resolve_install_target | tail -n 1)"

    package_name="$(apk_package_name || true)"
    if [ -n "${package_name}" ]; then
        adb -s "${target_serial}" uninstall "${package_name}" >/dev/null 2>&1 || true
    fi

    run_install_for_serial "${target_serial}"
}

main() {
    local command="${1:-deploy}"
    local recovery_hint=""

    case "${command}" in
        deploy)
            recovery_hint="$(snapshot_recovery_hint || true)"
            run_export
            run_install_with_hint "${recovery_hint}"
            ;;
        export)
            run_export
            ;;
        install)
            run_install
            ;;
        reinstall)
            run_reinstall
            ;;
        doctor)
            bash tools/quest-adb.sh doctor
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
