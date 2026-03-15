#!/usr/bin/env bash
set -euo pipefail

sudo bash .devcontainer/repair-usb-permissions.sh >/dev/null 2>&1 || true
