#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Configuring Lid Close Suspend & Power Savers..."
sudo mkdir -p /etc/systemd/logind.conf.d /etc/systemd/system-sleep /etc/udev/rules.d
sudo cp "$SCRIPT_DIR/lid.conf" /etc/systemd/logind.conf.d/lid.conf

if [ -f "$SCRIPT_DIR/snapdragon-power-saver.sh" ]; then
    echo "==> Installing Snapdragon USB/Wi-Fi standby power-saver hook..."
    sudo cp "$SCRIPT_DIR/snapdragon-power-saver.sh" /etc/systemd/system-sleep/snapdragon-power-saver.sh
    sudo chmod +x /etc/systemd/system-sleep/snapdragon-power-saver.sh
fi

if [ -f "$SCRIPT_DIR/10-runtime-pm.rules" ]; then
    echo "==> Installing udev runtime power management rules..."
    sudo cp "$SCRIPT_DIR/10-runtime-pm.rules" /etc/udev/rules.d/10-runtime-pm.rules
    sudo udevadm control --reload-rules 2>/dev/null || true
fi

echo "==> Unmasking systemd suspend/sleep targets..."
sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl restart systemd-logind

echo "==> Lid switch & power-saver configuration applied successfully!"
echo "    Tip: For full 0W deep hibernation (suspend-then-hibernate), run: ./setup_suspend_hibernate.sh"
