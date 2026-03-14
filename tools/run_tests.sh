#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_GUT_CONFIG="${ROOT_DIR}/.gutconfig.json"
TEMP_OVERRIDE_CREATED=0
OVERRIDE_CFG="${ROOT_DIR}/override.cfg"

find_godot_bin() {
  if command -v godot >/dev/null 2>&1; then
    command -v godot
    return 0
  fi

  if command -v godot4 >/dev/null 2>&1; then
    command -v godot4
    return 0
  fi

  local app_bin="/Applications/Godot.app/Contents/MacOS/Godot"
  if [[ -x "$app_bin" ]]; then
    printf '%s\n' "$app_bin"
    return 0
  fi

  local found
  found="$(find /Applications -maxdepth 2 -type f -path '*/Contents/MacOS/Godot' 2>/dev/null | head -n 1 || true)"
  if [[ -n "$found" ]]; then
    printf '%s\n' "$found"
    return 0
  fi

  return 1
}

GODOT_BIN="$(find_godot_bin || true)"
if [[ -z "${GODOT_BIN}" ]]; then
  echo "Unable to find a Godot binary in PATH or /Applications." >&2
  exit 1
fi

echo "Using Godot binary: ${GODOT_BIN}"

cleanup() {
  if [[ "${TEMP_OVERRIDE_CREATED}" -eq 1 && -f "${OVERRIDE_CFG}" ]]; then
    rm -f "${OVERRIDE_CFG}"
  fi
}

trap cleanup EXIT

if [[ ! -f "${OVERRIDE_CFG}" ]]; then
  TEMP_OVERRIDE_CREATED=1
  cat > "${OVERRIDE_CFG}" <<'EOF'
[xr]
openxr/enabled=false
shaders/enabled=false
EOF
fi

if [[ -z "${HOME:-}" || ! -w "${HOME}" ]]; then
  export HOME="${TMPDIR:-/tmp}/6dof-drone-sim-test-home"
fi
export XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME}}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}}"
mkdir -p "${HOME}" "${XDG_DATA_HOME}" "${XDG_CONFIG_HOME}"

cd "$ROOT_DIR"
if [[ $# -eq 0 && -f "${DEFAULT_GUT_CONFIG}" ]]; then
  "$GODOT_BIN" --headless --path "$ROOT_DIR" -s res://addons/gut/gut_cmdln.gd -gconfig="${DEFAULT_GUT_CONFIG}"
  exit $?
fi

"$GODOT_BIN" --headless --path "$ROOT_DIR" -s res://addons/gut/gut_cmdln.gd "$@"
