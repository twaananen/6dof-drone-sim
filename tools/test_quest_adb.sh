#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
FAKE_BIN="${TMP_DIR}/bin"
STATE_DIR="${TMP_DIR}/state"
FAKE_ADB_LOG="${STATE_DIR}/adb.log"
FAKE_ADB_CONNECT_LOG="${STATE_DIR}/adb-connect.log"
FAKE_ADB_DEVICES_FILE="${STATE_DIR}/adb-devices.txt"
FAKE_ADB_MDNS_FILE="${STATE_DIR}/adb-mdns.txt"
FAKE_LSUSB_FILE="${STATE_DIR}/lsusb.txt"
FAKE_APK="${STATE_DIR}/fake.apk"
FAKE_EXPORT_SCRIPT="${STATE_DIR}/fake-verify-export.sh"

mkdir -p "${FAKE_BIN}" "${STATE_DIR}"
touch "${FAKE_ADB_LOG}" "${FAKE_ADB_CONNECT_LOG}" "${FAKE_ADB_DEVICES_FILE}" "${FAKE_ADB_MDNS_FILE}" "${FAKE_LSUSB_FILE}" "${FAKE_APK}"

cleanup() {
    rm -rf "${TMP_DIR}"
}

trap cleanup EXIT

export PATH="${FAKE_BIN}:$PATH"
export FAKE_ADB_LOG
export FAKE_ADB_CONNECT_LOG
export FAKE_ADB_DEVICES_FILE
export FAKE_ADB_MDNS_FILE
export FAKE_LSUSB_FILE
export FAKE_EXPORT_SCRIPT

write_fake_tools() {
    cat > "${FAKE_BIN}/adb" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

serial=""

while [ $# -gt 0 ]; do
    case "$1" in
        -s)
            serial="$2"
            shift 2
            ;;
        -H|-P|-L|-t)
            shift 2
            ;;
        -a|-d|-e|--exit-on-write-error)
            shift
            ;;
        *)
            break
            ;;
    esac
done

cmd="${1:-}"
[ $# -gt 0 ] && shift || true

printf '%s|%s|%s\n' "${serial}" "${cmd}" "$*" >> "${FAKE_ADB_LOG}"

case "${cmd}" in
    devices)
        cat "${FAKE_ADB_DEVICES_FILE}"
        ;;
    mdns)
        case "${1:-}" in
            services)
                cat "${FAKE_ADB_MDNS_FILE}"
                ;;
            check)
                echo "mdns daemon version [adb discovery 0.0.0]"
                ;;
            *)
                exit 0
                ;;
        esac
        ;;
    connect)
        target="${1:-}"
        printf '%s\n' "${target}" >> "${FAKE_ADB_CONNECT_LOG}"
        if [ "${FAKE_ADB_CONNECT_ALWAYS_FAIL:-0}" = "1" ]; then
            echo "failed to connect to ${target}" >&2
            exit 1
        fi
        if [ -n "${FAKE_ADB_CONNECT_SUCCESS_TARGET:-}" ] && [ "${target}" != "${FAKE_ADB_CONNECT_SUCCESS_TARGET}" ]; then
            echo "failed to connect to ${target}" >&2
            exit 1
        fi
        if [ -n "${FAKE_ADB_CONNECTED_DEVICES_FILE:-}" ]; then
            cp "${FAKE_ADB_CONNECTED_DEVICES_FILE}" "${FAKE_ADB_DEVICES_FILE}"
        fi
        echo "connected to ${target}"
        ;;
    get-state)
        echo "${FAKE_ADB_GET_STATE:-device}"
        ;;
    install)
        echo "Success"
        ;;
    uninstall)
        echo "Success"
        ;;
    logcat)
        echo "01-01 00:00:00.000 QUEST_LOG fake"
        ;;
    shell)
        case "${1:-}" in
            pidof)
                echo "${FAKE_ADB_PID:-1234}"
                ;;
            monkey)
                exit 0
                ;;
            *)
                exit 0
                ;;
        esac
        ;;
    tcpip)
        echo "restarting in TCP mode port: ${1:-5555}"
        ;;
    kill-server)
        exit 0
        ;;
    start-server)
        if [ -n "${FAKE_ADB_START_SERVER_DEVICES_FILE:-}" ]; then
            cp "${FAKE_ADB_START_SERVER_DEVICES_FILE}" "${FAKE_ADB_DEVICES_FILE}"
        fi
        if [ -n "${FAKE_ADB_START_SERVER_MDNS_FILE:-}" ]; then
            cp "${FAKE_ADB_START_SERVER_MDNS_FILE}" "${FAKE_ADB_MDNS_FILE}"
        fi
        exit 0
        ;;
    *)
        echo "unsupported fake adb command: ${cmd}" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "${FAKE_BIN}/adb"

    cat > "${FAKE_BIN}/sudo" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "${FAKE_BIN}/sudo"

    cat > "${FAKE_BIN}/lsusb" <<'EOF'
#!/usr/bin/env bash
cat "${FAKE_LSUSB_FILE}"
EOF
    chmod +x "${FAKE_BIN}/lsusb"

    cat > "${FAKE_BIN}/ss" <<'EOF'
#!/usr/bin/env bash
echo "LISTEN 0 128 127.0.0.1:5037 0.0.0.0:*"
EOF
    chmod +x "${FAKE_BIN}/ss"

    cat > "${FAKE_BIN}/aapt" <<'EOF'
#!/usr/bin/env bash
echo "package: name='com.example.app' versionCode='1' versionName='1.0'"
EOF
    chmod +x "${FAKE_BIN}/aapt"

    cat > "${FAKE_EXPORT_SCRIPT}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ -n "${FAKE_EXPORT_POST_DEVICES_FILE:-}" ]; then
    cp "${FAKE_EXPORT_POST_DEVICES_FILE}" "${FAKE_ADB_DEVICES_FILE}"
else
    printf 'List of devices attached\n' > "${FAKE_ADB_DEVICES_FILE}"
fi

if [ -n "${FAKE_EXPORT_POST_MDNS_FILE:-}" ]; then
    cp "${FAKE_EXPORT_POST_MDNS_FILE}" "${FAKE_ADB_MDNS_FILE}"
else
    printf 'List of discovered mdns services\n' > "${FAKE_ADB_MDNS_FILE}"
fi

echo "Export succeeded: ${APK_OUT:-/tmp/6dof-drone-debug.apk} (83M)"
EOF
    chmod +x "${FAKE_EXPORT_SCRIPT}"
}

reset_state() {
    : > "${FAKE_ADB_LOG}"
    : > "${FAKE_ADB_CONNECT_LOG}"
    printf 'List of devices attached\n' > "${FAKE_ADB_DEVICES_FILE}"
    printf 'List of discovered mdns services\n' > "${FAKE_ADB_MDNS_FILE}"
    : > "${FAKE_LSUSB_FILE}"
    unset FAKE_ADB_CONNECT_SUCCESS_TARGET || true
    unset FAKE_ADB_CONNECT_ALWAYS_FAIL || true
    unset FAKE_ADB_CONNECTED_DEVICES_FILE || true
    unset FAKE_ADB_START_SERVER_DEVICES_FILE || true
    unset FAKE_ADB_START_SERVER_MDNS_FILE || true
    unset FAKE_ADB_GET_STATE || true
    unset FAKE_ADB_PID || true
    unset FAKE_EXPORT_POST_DEVICES_FILE || true
    unset FAKE_EXPORT_POST_MDNS_FILE || true
}

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    if ! printf '%s' "${haystack}" | grep -Fq "${needle}"; then
        fail "expected to find '${needle}' in output: ${haystack}"
    fi
}

assert_file_contains() {
    local path="$1"
    local needle="$2"
    if ! grep -Fq "${needle}" "${path}"; then
        fail "expected to find '${needle}' in ${path}"
    fi
}

assert_file_not_contains() {
    local path="$1"
    local needle="$2"
    if grep -Fq "${needle}" "${path}"; then
        fail "did not expect to find '${needle}' in ${path}"
    fi
}

run_and_capture() {
    set +e
    CMD_OUTPUT="$("$@" 2>&1)"
    CMD_STATUS=$?
    set -e
}

write_devices() {
    cat > "${FAKE_ADB_DEVICES_FILE}" <<EOF
List of devices attached
$1
EOF
}

write_mdns() {
    cat > "${FAKE_ADB_MDNS_FILE}" <<EOF
List of discovered mdns services
$1
EOF
}

write_connected_devices_after_connect() {
    local path="${STATE_DIR}/connected-devices.txt"
    cat > "${path}" <<EOF
List of devices attached
$1
EOF
    export FAKE_ADB_CONNECTED_DEVICES_FILE="${path}"
}

write_empty_devices_file() {
    local path="${STATE_DIR}/empty-devices.txt"
    printf 'List of devices attached\n' > "${path}"
    printf '%s\n' "${path}"
}

write_empty_mdns_file() {
    local path="${STATE_DIR}/empty-mdns.txt"
    printf 'List of discovered mdns services\n' > "${path}"
    printf '%s\n' "${path}"
}

write_devices_file() {
    local path="$1"
    local body="$2"
    cat > "${path}" <<EOF
List of devices attached
${body}
EOF
}

write_mdns_file() {
    local path="$1"
    local body="$2"
    cat > "${path}" <<EOF
List of discovered mdns services
${body}
EOF
}

test_resolve_usb_only() {
    reset_state
    write_devices "USB123 device product:eureka model:Quest_3 device:eureka transport_id:1"
    run_and_capture bash "${ROOT_DIR}/tools/quest-adb.sh" resolve-target
    [ "${CMD_STATUS}" -eq 0 ] || fail "resolve-target usb-only failed"
    assert_contains "${CMD_OUTPUT}" "STATUS=ready"
    assert_contains "${CMD_OUTPUT}" "TARGET_TRANSPORT=usb"
    assert_contains "${CMD_OUTPUT}" "TARGET_SERIAL=USB123"
}

test_resolve_wireless_only() {
    reset_state
    write_devices "192.168.0.76:40373 device product:eureka model:Quest_3 device:eureka transport_id:1"
    run_and_capture bash "${ROOT_DIR}/tools/quest-adb.sh" resolve-target
    [ "${CMD_STATUS}" -eq 0 ] || fail "resolve-target wireless-only failed"
    assert_contains "${CMD_OUTPUT}" "STATUS=ready"
    assert_contains "${CMD_OUTPUT}" "TARGET_TRANSPORT=wireless"
    assert_contains "${CMD_OUTPUT}" "TARGET_SERIAL=192.168.0.76:40373"
}

test_resolve_prefers_usb() {
    reset_state
    write_devices $'USB123 device product:eureka model:Quest_3 device:eureka transport_id:1\n192.168.0.76:40373 device product:eureka model:Quest_3 device:eureka transport_id:2'
    run_and_capture bash "${ROOT_DIR}/tools/quest-adb.sh" resolve-target
    [ "${CMD_STATUS}" -eq 0 ] || fail "resolve-target usb preference failed"
    assert_contains "${CMD_OUTPUT}" "TARGET_TRANSPORT=usb"
    assert_contains "${CMD_OUTPUT}" "TARGET_SERIAL=USB123"
}

test_resolve_auto_tls() {
    reset_state
    write_mdns "adb-quest _adb-tls-connect._tcp 192.168.0.76:36139"
    export FAKE_ADB_CONNECT_SUCCESS_TARGET="192.168.0.76:36139"
    write_connected_devices_after_connect "192.168.0.76:36139 device product:eureka model:Quest_3 device:eureka transport_id:1"
    run_and_capture bash "${ROOT_DIR}/tools/quest-adb.sh" resolve-target --auto-wireless
    [ "${CMD_STATUS}" -eq 0 ] || fail "resolve-target auto tls failed"
    assert_contains "${CMD_OUTPUT}" "STATUS=ready"
    assert_contains "${CMD_OUTPUT}" "TARGET_SERIAL=192.168.0.76:36139"
    assert_file_contains "${FAKE_ADB_CONNECT_LOG}" "192.168.0.76:36139"
}

test_resolve_auto_legacy() {
    reset_state
    write_mdns "adb-quest _adb._tcp 192.168.0.76:5555"
    export FAKE_ADB_CONNECT_SUCCESS_TARGET="192.168.0.76:5555"
    write_connected_devices_after_connect "192.168.0.76:5555 device product:eureka model:Quest_3 device:eureka transport_id:1"
    run_and_capture bash "${ROOT_DIR}/tools/quest-adb.sh" resolve-target --auto-wireless
    [ "${CMD_STATUS}" -eq 0 ] || fail "resolve-target auto legacy failed"
    assert_contains "${CMD_OUTPUT}" "STATUS=ready"
    assert_contains "${CMD_OUTPUT}" "TARGET_SERIAL=192.168.0.76:5555"
    assert_file_contains "${FAKE_ADB_CONNECT_LOG}" "192.168.0.76:5555"
}

test_resolve_ambiguous_discovery() {
    reset_state
    write_mdns $'adb-a _adb-tls-connect._tcp 192.168.0.10:30000\nadb-b _adb-tls-connect._tcp 192.168.0.11:30001'
    run_and_capture bash "${ROOT_DIR}/tools/quest-adb.sh" resolve-target --auto-wireless
    [ "${CMD_STATUS}" -eq 0 ] || fail "resolve-target ambiguous discovery command failed"
    assert_contains "${CMD_OUTPUT}" "STATUS=ambiguous"
    assert_file_not_contains "${FAKE_ADB_CONNECT_LOG}" "192.168.0."
}

test_resolve_unauthorized() {
    reset_state
    write_devices "USB123 unauthorized usb:1-1 transport_id:1"
    run_and_capture bash "${ROOT_DIR}/tools/quest-adb.sh" resolve-target
    [ "${CMD_STATUS}" -eq 0 ] || fail "resolve-target unauthorized failed"
    assert_contains "${CMD_OUTPUT}" "STATUS=unauthorized"
}

test_resolve_no_permissions() {
    reset_state
    write_devices $'USB123\tno permissions (missing udev rules?); see [http://developer.android.com/tools/device.html]'
    run_and_capture bash "${ROOT_DIR}/tools/quest-adb.sh" resolve-target
    [ "${CMD_STATUS}" -eq 0 ] || fail "resolve-target no_permissions failed"
    assert_contains "${CMD_OUTPUT}" "STATUS=no_permissions"
}

test_doctor_reports_wireless_ready() {
    reset_state
    write_devices "192.168.0.76:40373 device product:eureka model:Quest_3 device:eureka transport_id:1"
    run_and_capture bash "${ROOT_DIR}/tools/quest-adb.sh" doctor
    [ "${CMD_STATUS}" -eq 0 ] || fail "doctor failed"
    assert_contains "${CMD_OUTPUT}" "STATUS: ready"
    assert_contains "${CMD_OUTPUT}" "Preferred transport: wireless"
}

test_wireless_auto_command() {
    reset_state
    write_mdns "adb-quest _adb-tls-connect._tcp 192.168.0.76:36139"
    export FAKE_ADB_CONNECT_SUCCESS_TARGET="192.168.0.76:36139"
    write_connected_devices_after_connect "192.168.0.76:36139 device product:eureka model:Quest_3 device:eureka transport_id:1"
    run_and_capture bash "${ROOT_DIR}/tools/quest-adb.sh" wireless --auto
    [ "${CMD_STATUS}" -eq 0 ] || fail "wireless --auto failed"
    assert_contains "${CMD_OUTPUT}" "192.168.0.76:36139"
}

test_deploy_install_uses_wireless_fallback() {
    reset_state
    write_mdns "adb-quest _adb-tls-connect._tcp 192.168.0.76:36139"
    export FAKE_ADB_CONNECT_SUCCESS_TARGET="192.168.0.76:36139"
    write_connected_devices_after_connect "192.168.0.76:36139 device product:eureka model:Quest_3 device:eureka transport_id:1"
    run_and_capture env ANDROID_HOME= APK_OUT="${FAKE_APK}" bash "${ROOT_DIR}/tools/quest-deploy.sh" install
    [ "${CMD_STATUS}" -eq 0 ] || fail "quest-deploy install failed"
    assert_file_contains "${FAKE_ADB_LOG}" "192.168.0.76:36139|install|-r ${FAKE_APK}"
}

test_deploy_recovers_with_cached_connected_wireless_target() {
    local empty_devices=""
    local empty_mdns=""

    reset_state
    write_devices "192.168.0.76:5555 device product:eureka model:Quest_3 device:eureka transport_id:1"
    export FAKE_ADB_CONNECT_SUCCESS_TARGET="192.168.0.76:5555"
    write_connected_devices_after_connect "192.168.0.76:5555 device product:eureka model:Quest_3 device:eureka transport_id:1"
    empty_devices="$(write_empty_devices_file)"
    empty_mdns="$(write_empty_mdns_file)"
    export FAKE_EXPORT_POST_DEVICES_FILE="${empty_devices}"
    export FAKE_EXPORT_POST_MDNS_FILE="${empty_mdns}"

    run_and_capture env ANDROID_HOME= APK_OUT="${FAKE_APK}" QUEST_DEPLOY_EXPORT_SCRIPT="${FAKE_EXPORT_SCRIPT}" QUEST_DEPLOY_RECOVERY_DELAY_SECS=0 bash "${ROOT_DIR}/tools/quest-deploy.sh"
    [ "${CMD_STATUS}" -eq 0 ] || fail "quest-deploy deploy recovery with cached target failed"
    assert_contains "${CMD_OUTPUT}" "Quest deploy export likely reset the ADB session; attempting wireless recovery."
    assert_file_contains "${FAKE_ADB_LOG}" "|start-server|"
    assert_file_contains "${FAKE_ADB_CONNECT_LOG}" "192.168.0.76:5555"
    assert_file_contains "${FAKE_ADB_LOG}" "192.168.0.76:5555|install|-r ${FAKE_APK}"
}

test_deploy_recovers_with_cached_discovered_endpoint() {
    local empty_devices=""
    local empty_mdns=""

    reset_state
    write_mdns "adb-quest _adb._tcp 192.168.0.76:5555"
    export FAKE_ADB_CONNECT_SUCCESS_TARGET="192.168.0.76:5555"
    write_connected_devices_after_connect "192.168.0.76:5555 device product:eureka model:Quest_3 device:eureka transport_id:1"
    empty_devices="$(write_empty_devices_file)"
    empty_mdns="$(write_empty_mdns_file)"
    export FAKE_EXPORT_POST_DEVICES_FILE="${empty_devices}"
    export FAKE_EXPORT_POST_MDNS_FILE="${empty_mdns}"

    run_and_capture env ANDROID_HOME= APK_OUT="${FAKE_APK}" QUEST_DEPLOY_EXPORT_SCRIPT="${FAKE_EXPORT_SCRIPT}" QUEST_DEPLOY_RECOVERY_DELAY_SECS=0 bash "${ROOT_DIR}/tools/quest-deploy.sh"
    [ "${CMD_STATUS}" -eq 0 ] || fail "quest-deploy deploy recovery with cached discovery failed"
    assert_file_contains "${FAKE_ADB_CONNECT_LOG}" "192.168.0.76:5555"
    assert_file_contains "${FAKE_ADB_LOG}" "192.168.0.76:5555|install|-r ${FAKE_APK}"
}

test_deploy_recovers_after_start_server_retry() {
    local empty_devices=""
    local empty_mdns=""
    local start_mdns="${STATE_DIR}/start-mdns.txt"

    reset_state
    export FAKE_ADB_CONNECT_SUCCESS_TARGET="192.168.0.76:36139"
    write_connected_devices_after_connect "192.168.0.76:36139 device product:eureka model:Quest_3 device:eureka transport_id:1"
    empty_devices="$(write_empty_devices_file)"
    empty_mdns="$(write_empty_mdns_file)"
    write_mdns_file "${start_mdns}" "adb-quest _adb-tls-connect._tcp 192.168.0.76:36139"
    export FAKE_EXPORT_POST_DEVICES_FILE="${empty_devices}"
    export FAKE_EXPORT_POST_MDNS_FILE="${empty_mdns}"
    export FAKE_ADB_START_SERVER_MDNS_FILE="${start_mdns}"

    run_and_capture env ANDROID_HOME= APK_OUT="${FAKE_APK}" QUEST_DEPLOY_EXPORT_SCRIPT="${FAKE_EXPORT_SCRIPT}" QUEST_DEPLOY_RECOVERY_DELAY_SECS=0 bash "${ROOT_DIR}/tools/quest-deploy.sh"
    [ "${CMD_STATUS}" -eq 0 ] || fail "quest-deploy deploy recovery after start-server failed"
    assert_file_contains "${FAKE_ADB_LOG}" "|start-server|"
    assert_file_contains "${FAKE_ADB_CONNECT_LOG}" "192.168.0.76:36139"
    assert_file_contains "${FAKE_ADB_LOG}" "192.168.0.76:36139|install|-r ${FAKE_APK}"
}

test_deploy_recovery_failure_reports_guidance() {
    local empty_devices=""
    local empty_mdns=""

    reset_state
    write_devices "192.168.0.76:5555 device product:eureka model:Quest_3 device:eureka transport_id:1"
    empty_devices="$(write_empty_devices_file)"
    empty_mdns="$(write_empty_mdns_file)"
    export FAKE_EXPORT_POST_DEVICES_FILE="${empty_devices}"
    export FAKE_EXPORT_POST_MDNS_FILE="${empty_mdns}"
    export FAKE_ADB_CONNECT_ALWAYS_FAIL=1

    run_and_capture env ANDROID_HOME= APK_OUT="${FAKE_APK}" QUEST_DEPLOY_EXPORT_SCRIPT="${FAKE_EXPORT_SCRIPT}" QUEST_DEPLOY_RECOVERY_RETRIES=2 QUEST_DEPLOY_RECOVERY_DELAY_SECS=0 bash "${ROOT_DIR}/tools/quest-deploy.sh"
    [ "${CMD_STATUS}" -ne 0 ] || fail "quest-deploy deploy failure test unexpectedly succeeded"
    assert_contains "${CMD_OUTPUT}" "Quest deploy export likely reset the ADB session; attempting wireless recovery."
    assert_contains "${CMD_OUTPUT}" "Export appears to have reset ADB and the recovery pass could not re-establish the Quest wireless target."
    assert_contains "${CMD_OUTPUT}" "Next steps:"
}

test_deploy_reinstall_uses_same_serial() {
    reset_state
    write_devices "USB123 device product:eureka model:Quest_3 device:eureka transport_id:1"
    run_and_capture env ANDROID_HOME= APK_OUT="${FAKE_APK}" bash "${ROOT_DIR}/tools/quest-deploy.sh" reinstall
    [ "${CMD_STATUS}" -eq 0 ] || fail "quest-deploy reinstall failed"
    assert_file_contains "${FAKE_ADB_LOG}" "USB123|uninstall|com.example.app"
    assert_file_contains "${FAKE_ADB_LOG}" "USB123|install|-r ${FAKE_APK}"
}

test_logcat_prefers_usb() {
    reset_state
    write_devices $'USB123 device product:eureka model:Quest_3 device:eureka transport_id:1\n192.168.0.76:40373 device product:eureka model:Quest_3 device:eureka transport_id:2'
    run_and_capture bash "${ROOT_DIR}/tools/quest_logcat.sh" --full
    [ "${CMD_STATUS}" -eq 0 ] || fail "quest_logcat --full failed"
    assert_contains "${CMD_OUTPUT}" "QUEST_LOG fake"
    assert_file_contains "${FAKE_ADB_LOG}" "USB123|get-state|"
    assert_file_contains "${FAKE_ADB_LOG}" "USB123|logcat|-v time"
}

main() {
    write_fake_tools

    test_resolve_usb_only
    test_resolve_wireless_only
    test_resolve_prefers_usb
    test_resolve_auto_tls
    test_resolve_auto_legacy
    test_resolve_ambiguous_discovery
    test_resolve_unauthorized
    test_resolve_no_permissions
    test_doctor_reports_wireless_ready
    test_wireless_auto_command
    test_deploy_install_uses_wireless_fallback
    test_deploy_recovers_with_cached_connected_wireless_target
    test_deploy_recovers_with_cached_discovered_endpoint
    test_deploy_recovers_after_start_server_retry
    test_deploy_recovery_failure_reports_guidance
    test_deploy_reinstall_uses_same_serial
    test_logcat_prefers_usb

    echo "Quest ADB shell tests passed."
}

main "$@"
