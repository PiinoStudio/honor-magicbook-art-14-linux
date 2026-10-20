#!/bin/bash
# setup_suspend_hibernate.sh
# Automated 0W Deep Hibernation & Standby Power-Saver Setup for Honor MagicBook Art 14 Snapdragon

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "===================================================================="
echo " Honor MagicBook Art 14: Suspend-Then-Hibernate & Power-Saver Setup"
echo "===================================================================="

# 1. Install suspend power-saver hook
echo "==> [1/6] Installing suspend power-saver script..."
sudo mkdir -p /etc/systemd/system-sleep
sudo cp "$SCRIPT_DIR/snapdragon-power-saver.sh" /etc/systemd/system-sleep/snapdragon-power-saver.sh
sudo chmod +x /etc/systemd/system-sleep/snapdragon-power-saver.sh

# 2. Install udev runtime-pm rules
echo "==> [2/6] Installing udev runtime-pm rules..."
sudo mkdir -p /etc/udev/rules.d
sudo cp "$SCRIPT_DIR/10-runtime-pm.rules" /etc/udev/rules.d/10-runtime-pm.rules
sudo udevadm control --reload-rules || true

# 3. Setup Btrfs Swapfile if not already present
SWAP_PATH="/swap/swapfile"
if ! grep -q "$SWAP_PATH" /proc/swaps 2>/dev/null; then
    echo "==> [3/6] Setting up 34GB swapfile on /swap for hibernation..."
    if [ ! -d "/swap" ]; then
        sudo btrfs subvolume create /swap 2>/dev/null || sudo mkdir -p /swap
        sudo chmod 700 /swap
    fi
    if [ ! -f "$SWAP_PATH" ]; then
        echo "Creating swapfile (size: 34G)..."
        sudo btrfs filesystem mkswapfile --size 34g "$SWAP_PATH"
    fi
    sudo swapon -p 10 "$SWAP_PATH"
    if ! grep -q "$SWAP_PATH" /etc/fstab; then
        echo "$SWAP_PATH none swap defaults,pri=10 0 0" | sudo tee -a /etc/fstab
    fi
else
    echo "==> [3/6] Swapfile $SWAP_PATH is already active."
fi

# 4. Calculate resume parameters
echo "==> [4/6] Determining resume UUID and offset..."
ROOT_DEV="$(findmnt -n -o SOURCE /)"
ROOT_UUID="$(sudo blkid -s UUID -o value "$ROOT_DEV")"
RESUME_OFFSET="$(sudo btrfs inspect-internal map-swapfile -r "$SWAP_PATH" 2>/dev/null || true)"

echo "    Root UUID:     $ROOT_UUID"
echo "    Resume Offset: $RESUME_OFFSET"

# 5. Configure dracut resume module
echo "==> [5/6] Configuring dracut initramfs with resume support..."
sudo mkdir -p /etc/dracut.conf.d
echo 'add_dracutmodules+=" resume "' | sudo tee /etc/dracut.conf.d/resume.conf >/dev/null
echo "    Rebuilding initramfs (this takes ~15 seconds)..."
sudo dracut -f

# 6. Configure systemd suspend-then-hibernate
echo "==> [6/6] Configuring systemd logind and sleep policies..."
sudo mkdir -p /etc/systemd/sleep.conf.d /etc/systemd/logind.conf.d
sudo cp "$SCRIPT_DIR/hibernate.conf" /etc/systemd/sleep.conf.d/hibernate.conf
sudo cp "$SCRIPT_DIR/lid.conf" /etc/systemd/logind.conf.d/lid.conf

sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl restart systemd-logind

echo ""
echo "===================================================================="
echo " SUCCESS! Suspend-then-hibernate is now active."
echo "===================================================================="
echo " IMPORTANT: Ensure your kernel command line in GRUB includes:"
echo "   resume=UUID=$ROOT_UUID resume_offset=$RESUME_OFFSET"
echo ""
echo " Behavior:"
echo "   - Closing lid: Enters instant sleep (s2idle)"
echo "   - After 15 minutes of sleep: Automatically hibernates to disk (0.00W)"
echo "   - Resumes in ~3 seconds upon power on"
echo "===================================================================="
