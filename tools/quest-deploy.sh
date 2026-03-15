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
  export   Run the existing export verification/export flow and write ${APK_OUT}
  install  Repair USB permissions, verify Quest ADB readiness, then install ${APK_OUT}
  reinstall Uninstall the existing package, then install ${APK_OUT}
  doctor   Run the Quest ADB diagnostics helper

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

run_install() {
    if [ ! -f "${APK_OUT}" ]; then
        echo "APK not found at ${APK_OUT}. Run 'bash tools/quest-deploy.sh export' first." >&2
        exit 1
    fi

    bash tools/quest-adb.sh repair-usb
    local doctor_output
    doctor_output="$(bash tools/quest-adb.sh doctor)"
    printf '%s\n' "${doctor_output}"

    if ! printf '%s\n' "${doctor_output}" | grep -q '^STATUS: ready$'; then
        echo "Quest is not ready for install." >&2
        exit 1
    fi

    local install_output
    if install_output="$(adb install -r "${APK_OUT}" 2>&1)"; then
        printf '%s\n' "${install_output}"
        return 0
    fi

    printf '%s\n' "${install_output}" >&2

    if printf '%s\n' "${install_output}" | grep -q 'INSTALL_FAILED_UPDATE_INCOMPATIBLE'; then
        local package_name=""
        package_name="$(apk_package_name || true)"
        if [ -n "${package_name}" ]; then
            echo "Uninstall the old package first: adb uninstall ${package_name}" >&2
        fi
    fi

    exit 1
}

run_reinstall() {
    if [ ! -f "${APK_OUT}" ]; then
        echo "APK not found at ${APK_OUT}. Run 'bash tools/quest-deploy.sh export' first." >&2
        exit 1
    fi

    local package_name=""
    package_name="$(apk_package_name || true)"
    if [ -n "${package_name}" ]; then
        adb uninstall "${package_name}" >/dev/null 2>&1 || true
    fi

    run_install
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
