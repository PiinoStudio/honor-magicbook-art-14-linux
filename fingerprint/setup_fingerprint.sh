#!/usr/bin/env bash
# Fingerprint Setup Script for Honor MagicBook Art 14 (Sensor 10a5:9924)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="/tmp/build_libfprint_$$"

echo "==> Preparing build directory in ${WORK_DIR}..."
mkdir -p "${WORK_DIR}"
cd "${WORK_DIR}"

echo "==> Cloning upstream libfprint..."
git clone https://gitlab.freedesktop.org/libfprint/libfprint.git libfprint
cd libfprint
git checkout 8a2123c

echo "==> Applying Honor 10a5:9924 patch..."
git apply "${SCRIPT_DIR}/0001-fpcmoc-add-10a5-9924-experimental-support.patch"

echo "==> Building and installing..."
"${SCRIPT_DIR}/build-install.sh" .

echo "==> Enabling PAM fingerprint authentication..."
if command -v authselect >/dev/null 2>&1; then
    sudo authselect enable-feature with-fingerprint || true
fi

echo "==> Restarting fprintd..."
sudo systemctl restart fprintd || true

echo "==> Cleaning up..."
rm -rf "${WORK_DIR}"

echo "Fingerprint setup complete! Test with: fprintd-enroll"
