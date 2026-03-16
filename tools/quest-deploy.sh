#!/usr/bin/env bash
set -euo pipefail

APK_OUT="${APK_OUT:-/tmp/6dof-drone-debug.apk}"

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

run_export() {
    bash tools/verify-export.sh
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

resolve_install_target() {
    local resolve_output=""
    local status=""
    local transport=""
    local serial=""
    local message=""
    local usb_serials=""
    local wireless_serials=""
    local discovered_wireless=""

    resolve_output="$(bash tools/quest-adb.sh resolve-target --auto-wireless)"

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
    done <<<"${resolve_output}"

    case "${status}" in
        ready)
            printf 'Using Quest target: %s (%s)\n' "${serial}" "${transport}" >&2
            printf '%s\n' "${serial}"
            ;;
        ambiguous)
            printf '%s\n' "${message}" >&2
            printf 'Connected USB adb serials: %s\n' "${usb_serials:-none}" >&2
            printf 'Connected wireless adb serials: %s\n' "${wireless_serials:-none}" >&2
            printf 'Discoverable wireless adb endpoints: %s\n' "${discovered_wireless:-none}" >&2
            exit 1
            ;;
        no_device)
            printf '%s\n' "${message}" >&2
            echo "Next steps:" >&2
            echo "- Plug the Quest in over USB and unlock it." >&2
            echo "- Or enable wireless debugging / SideQuest wireless ADB and rerun the command." >&2
            exit 1
            ;;
        *)
            printf '%s\n' "${message}" >&2
            exit 1
            ;;
    esac
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

    if [ ! -f "${APK_OUT}" ]; then
        echo "APK not found at ${APK_OUT}. Run 'bash tools/quest-deploy.sh export' first." >&2
        exit 1
    fi

    if [ -d /dev/bus/usb ]; then
        bash tools/quest-adb.sh repair-usb
    fi

    target_serial="$(resolve_install_target | tail -n 1)"
    run_install_for_serial "${target_serial}"
}

run_reinstall() {
    local target_serial=""
    local package_name=""

    if [ ! -f "${APK_OUT}" ]; then
        echo "APK not found at ${APK_OUT}. Run 'bash tools/quest-deploy.sh export' first." >&2
        exit 1
    fi

    if [ -d /dev/bus/usb ]; then
        bash tools/quest-adb.sh repair-usb
    fi

    target_serial="$(resolve_install_target | tail -n 1)"

    package_name="$(apk_package_name || true)"
    if [ -n "${package_name}" ]; then
        adb -s "${target_serial}" uninstall "${package_name}" >/dev/null 2>&1 || true
    fi

    run_install_for_serial "${target_serial}"
}

main() {
    local command="${1:-deploy}"

    case "${command}" in
        deploy)
            run_export
            run_install
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
