#!/bin/bash
# setup_deep_sleep.sh
# Installs honor_deep_sleep_fix.ko (Runtime PM & safe sleep guards; sync_all_suppliers=0)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "===================================================================="
echo " Honor MagicBook Art 14: Power-Management Kernel Module Setup"
echo "===================================================================="

# 1. Build and install honor_deep_sleep_fix kernel module
echo "==> [1/5] Compiling and installing honor_deep_sleep_fix module..."
cd "$SCRIPT_DIR/honor_deep_sleep_fix"
make
sudo make install

# 2. Configure kernel module autoloading & safe options
echo "==> [2/5] Setting up auto-loading (/etc/modules-load.d/honor-sleep.conf)..."
sudo cp "$SCRIPT_DIR/honor-sleep.conf" /etc/modules-load.d/honor-sleep.conf
echo "options honor_deep_sleep_fix sync_all_suppliers=0 hold_usbc_ldos=1" | sudo tee /etc/modprobe.d/honor-sleep.conf >/dev/null

# 3. Install udev wakeup rules
echo "==> [3/5] Installing udev wakeup rules (/etc/udev/rules.d/92-snapdragon-wakeup.rules)..."
sudo rm -f /etc/udev/rules.d/99-ufs-pm.rules
sudo cp "$SCRIPT_DIR/92-snapdragon-wakeup.rules" /etc/udev/rules.d/92-snapdragon-wakeup.rules
sudo udevadm control --reload-rules || true
sudo udevadm trigger || true

# 4. Install system-sleep power-saver hook
echo "==> [4/5] Installing system-sleep hook (/etc/systemd/system-sleep/snapdragon-power-saver.sh)..."
sudo mkdir -p /etc/systemd/system-sleep
sudo cp "$SCRIPT_DIR/snapdragon-power-saver.sh" /etc/systemd/system-sleep/snapdragon-power-saver.sh
sudo chmod +x /etc/systemd/system-sleep/snapdragon-power-saver.sh

# 5. Load modules immediately if not loaded
echo "==> [5/5] Activating modules..."
sudo modprobe videocc-sm8550 2>/dev/null || true
sudo modprobe honor_deep_sleep_fix 2>/dev/null || true

echo ""
echo "===================================================================="
echo " Done! Note: Pure s2idle cannot collapse CX/DDR on this firmware"
echo " (see docs/DEEP_SLEEP_BREAKTHROUGH.md). Use setup_suspend_hibernate.sh"
echo " for guaranteed 0.00W disk hibernation."
echo "===================================================================="
