#!/bin/bash
# setup_suspend_hibernate.sh
# Automated 0.00W Disk Hibernation & Backpack Failsafe Setup for Honor MagicBook Art 14 Snapdragon

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "===================================================================="
echo " Honor MagicBook Art 14: 0.00W Hibernation & Backpack Failsafe Setup"
echo "===================================================================="

# 1. Install suspend power-saver hook
echo "==> [1/7] Installing suspend power-saver script..."
sudo mkdir -p /etc/systemd/system-sleep
sudo cp "$SCRIPT_DIR/snapdragon-power-saver.sh" /etc/systemd/system-sleep/snapdragon-power-saver.sh
sudo chmod +x /etc/systemd/system-sleep/snapdragon-power-saver.sh

# 2. Install udev runtime-pm rules (Note: do NOT set spm_lvl=3 on 1d84000.ufshc; keep default 5!)
echo "==> [2/7] Installing udev runtime-pm rules..."
sudo mkdir -p /etc/udev/rules.d
sudo rm -f /etc/udev/rules.d/99-ufs-pm.rules
sudo cp "$SCRIPT_DIR/10-runtime-pm.rules" /etc/udev/rules.d/10-runtime-pm.rules
sudo udevadm control --reload-rules || true

# 3. Setup Btrfs Swapfile if not already present
SWAP_PATH="/swap/swapfile"
if ! grep -q "$SWAP_PATH" /proc/swaps 2>/dev/null; then
    echo "==> [3/7] Setting up 34GB swapfile on /swap for hibernation..."
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
    echo "==> [3/7] Swapfile $SWAP_PATH is already active."
fi

# 4. Calculate resume parameters & configure /etc/tmpfiles.d/hibernate-resume.conf
echo "==> [4/7] Determining resume device major:minor and offset..."
ROOT_DEV="$(findmnt -n -o SOURCE / | sed 's/\[.*\]//')"
ROOT_UUID="$(sudo blkid -s UUID -o value "$ROOT_DEV")"
ROOT_MAJMIN="$(lsblk -n -o MAJ:MIN "$ROOT_DEV" | tr -d ' ')"
RESUME_OFFSET="$(sudo btrfs inspect-internal map-swapfile -r "$SWAP_PATH" 2>/dev/null || true)"

echo "    Root Device:   $ROOT_DEV ($ROOT_MAJMIN, UUID=$ROOT_UUID)"
echo "    Resume Offset: $RESUME_OFFSET"

sudo mkdir -p /etc/tmpfiles.d
cat <<EOF | sudo tee /etc/tmpfiles.d/hibernate-resume.conf >/dev/null
w /sys/power/resume - - - - $ROOT_MAJMIN
w /sys/power/resume_offset - - - - $RESUME_OFFSET
EOF
sudo systemd-tmpfiles --create /etc/tmpfiles.d/hibernate-resume.conf

# 5. Configure dracut resume module and sync to /boot/efi/initrd_native.img
echo "==> [5/7] Configuring dracut initramfs with resume support..."
sudo mkdir -p /etc/dracut.conf.d
echo 'add_dracutmodules+=" resume "' | sudo tee /etc/dracut.conf.d/resume.conf >/dev/null
echo "    Rebuilding initramfs (this takes ~15 seconds)..."
sudo dracut -f
if [ -f "/boot/initramfs-$(uname -r).img" ] && [ -d "/boot/efi" ]; then
    echo "    Copying rebuilt initramfs to /boot/efi/initrd_native.img..."
    sudo cp "/boot/initramfs-$(uname -r).img" /boot/efi/initrd_native.img
fi

# 6. Configure systemd hibernation & lid policies
echo "==> [6/7] Configuring systemd logind and sleep policies (HibernateMode=shutdown)..."
sudo mkdir -p /etc/systemd/sleep.conf.d /etc/systemd/logind.conf.d
sudo rm -f /etc/systemd/sleep.conf.d/s2idle.conf
sudo cp "$SCRIPT_DIR/hibernate.conf" /etc/systemd/sleep.conf.d/hibernate.conf
sudo cp "$SCRIPT_DIR/lid.conf" /etc/systemd/logind.conf.d/lid.conf

# 7. Configure Backpack Overheat Failsafe (FailureAction=poweroff)
echo "==> [7/7] Installing FailureAction=poweroff backpack failsafe..."
sudo mkdir -p /etc/systemd/system/systemd-hibernate.service.d /etc/systemd/system/systemd-suspend.service.d
cat <<EOF | sudo tee /etc/systemd/system/systemd-hibernate.service.d/override.conf >/dev/null
[Unit]
FailureAction=poweroff
EOF
cat <<EOF | sudo tee /etc/systemd/system/systemd-suspend.service.d/override.conf >/dev/null
[Unit]
FailureAction=poweroff
EOF

sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl restart systemd-logind

echo ""
echo "===================================================================="
echo " SUCCESS! 0.00W Disk Hibernation & Backpack Failsafe are now active."
echo "===================================================================="
echo " IMPORTANT: Ensure your kernel command line in GRUB includes:"
echo "   resume=$ROOT_DEV resume_offset=$RESUME_OFFSET"
echo "===================================================================="
