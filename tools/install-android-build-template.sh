#!/usr/bin/env bash
set -euo pipefail

GODOT_VERSION="$(cat .godot-version | tr -d '[:space:]')"
GODOT_VER_NUM="${GODOT_VERSION%-stable}"
SOURCE_ZIP="$HOME/.local/share/godot/export_templates/${GODOT_VER_NUM}.stable/android_source.zip"
TARGET_DIR="android/build"
VERSION_FILE="android/.build_version"
EXPECTED_VERSION="${GODOT_VER_NUM}.stable"
BUILD_FILE="${TARGET_DIR}/build.gradle"
GODOT_IGNORE_FILE="${TARGET_DIR}/.gdignore"
MAIN_MANIFEST="${TARGET_DIR}/src/main/AndroidManifest.xml"
META_DEBUG_AAR="addons/godotopenxrvendors/.bin/android/debug/godotopenxr-meta-debug.aar"
META_RELEASE_AAR="addons/godotopenxrvendors/.bin/android/release/godotopenxr-meta-release.aar"

ensure_meta_vendor_aars() {
    mkdir -p "${TARGET_DIR}/libs/debug" "${TARGET_DIR}/libs/release"

    if [ -f "${META_DEBUG_AAR}" ]; then
        cp "${META_DEBUG_AAR}" "${TARGET_DIR}/libs/debug/"
    fi

    if [ -f "${META_RELEASE_AAR}" ]; then
        cp "${META_RELEASE_AAR}" "${TARGET_DIR}/libs/release/"
    fi
}

ensure_meta_manifest_features() {
    if [ ! -f "${MAIN_MANIFEST}" ]; then
        return 0
    fi

    if ! grep -Fq 'com.oculus.feature.PASSTHROUGH' "${MAIN_MANIFEST}"; then
        local tmp_manifest
        tmp_manifest="$(mktemp)"
        awk '
            /<application/ && !injected {
                print "    <uses-feature android:name=\"com.oculus.feature.PASSTHROUGH\" android:required=\"false\" />"
                print "    <uses-feature android:name=\"com.oculus.feature.RENDER_MODEL\" android:required=\"false\" />"
                print ""
                injected = 1
            }
            { print }
        ' "${MAIN_MANIFEST}" > "${tmp_manifest}"
        mv "${tmp_manifest}" "${MAIN_MANIFEST}"
    fi
}

sanitize_template_dir() {
    if [ ! -d "${TARGET_DIR}" ]; then
        return 0
    fi

    # Prevent Godot from scanning the generated Android template as project content.
    printf '# Managed by tools/install-android-build-template.sh\n' > "${GODOT_IGNORE_FILE}"

    # Exports repopulate these directories, but leaving stale data causes recursive asset copies.
    rm -rf "${TARGET_DIR}/src/main/assets" "${TARGET_DIR}/src/instrumented/assets/.godot"

    find "${TARGET_DIR}" -type d -name '.godot' -prune -exec rm -rf {} +
    find "${TARGET_DIR}" -type f -name '*.import' -delete

    # Remove the old local workaround that caused copyAndRenameBinary to rebuild
    # without the export_* properties Godot passes to the main assemble step.
    if [ -f "${BUILD_FILE}" ]; then
        sed -i '/^\/\/ 6dof-drone-sim copyAndRenameBinary dependency fix:/,/^}/d' "${BUILD_FILE}"
    fi

    ensure_meta_vendor_aars
    ensure_meta_manifest_features
}

if [ -f "${TARGET_DIR}/build.gradle" ] && [ -f "${TARGET_DIR}/src/main/AndroidManifest.xml" ] && [ -f "${VERSION_FILE}" ]; then
    if [ "$(cat "${VERSION_FILE}")" = "${EXPECTED_VERSION}" ]; then
        sanitize_template_dir
        exit 0
    fi
fi

if [ ! -f "${SOURCE_ZIP}" ]; then
    echo "Android build template archive is missing: ${SOURCE_ZIP}" >&2
    exit 1
fi

rm -rf "${TARGET_DIR}"
mkdir -p "${TARGET_DIR}"
(
    cd "${TARGET_DIR}"
    jar xf "${SOURCE_ZIP}"
)
printf '%s\n' "${EXPECTED_VERSION}" > "${VERSION_FILE}"
chmod +x "${TARGET_DIR}/gradlew" 2>/dev/null || true
sanitize_template_dir
