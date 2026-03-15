#!/usr/bin/env bash
set -euo pipefail

if [ ! -d /dev/bus/usb ]; then
    exit 0
fi

if ! getent group plugdev >/dev/null 2>&1; then
    exit 0
fi

while IFS= read -r device_path; do
    chgrp plugdev "${device_path}" || true
    chmod g+rw "${device_path}" || true
done < <(find /dev/bus/usb -mindepth 2 -maxdepth 2 -type c 2>/dev/null | sort)
