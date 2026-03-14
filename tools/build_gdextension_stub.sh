#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT_DIR}/tools/gdextension_stub/noop_vendor_stub.c"
HEADER="${ROOT_DIR}/third_party/godot_headers/gdextension_interface.h"
OUT_DIR="${ROOT_DIR}/addons/godotopenxrvendors/.bin/stubs"

mkdir -p "${OUT_DIR}/macos" "${OUT_DIR}/linux/x86_64" "${OUT_DIR}/linux/arm64"

clang \
  -dynamiclib \
  -arch arm64 \
  -arch x86_64 \
  -I"${ROOT_DIR}/third_party/godot_headers" \
  -o "${OUT_DIR}/macos/libgodotopenxrvendors_stub.dylib" \
  "${SRC}"

if command -v zig >/dev/null 2>&1; then
  zig cc \
    -target x86_64-linux-gnu \
    -shared \
    -fPIC \
    -I"${ROOT_DIR}/third_party/godot_headers" \
    -o "${OUT_DIR}/linux/x86_64/libgodotopenxrvendors_stub.so" \
    "${SRC}"

  zig cc \
    -target aarch64-linux-gnu \
    -shared \
    -fPIC \
    -I"${ROOT_DIR}/third_party/godot_headers" \
    -o "${OUT_DIR}/linux/arm64/libgodotopenxrvendors_stub.so" \
    "${SRC}"
else
  echo "zig not found; skipped Linux stub builds" >&2
fi
