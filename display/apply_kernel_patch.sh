#!/usr/bin/env bash
# Kernel Patch Application Script for Honor MagicBook Art 14
# Applies 120Hz OLED + Dual Mixer patches to any Linux kernel source tree
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /path/to/linux/kernel/source"
    exit 1
fi

KERNEL_SRC="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_FILE="${SCRIPT_DIR}/patch_honor_native_120hz_oled.diff"

echo "==> Applying display patch to ${KERNEL_SRC}..."
git -C "${KERNEL_SRC}" apply --check "${PATCH_FILE}"
git -C "${KERNEL_SRC}" apply "${PATCH_FILE}"

echo "Patch successfully applied!"
echo "Now compile the DRM drivers or full kernel:"
echo "  make -C ${KERNEL_SRC} M=drivers/gpu/drm/msm modules"
echo "  make -C ${KERNEL_SRC} M=drivers/gpu/drm/panel modules"
