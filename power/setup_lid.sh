#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Configuring Lid Close Suspend..."
sudo mkdir -p /etc/systemd/logind.conf.d
sudo cp "$SCRIPT_DIR/lid.conf" /etc/systemd/logind.conf.d/lid.conf

echo "==> Unmasking systemd suspend/sleep targets..."
sudo systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
sudo systemctl restart systemd-logind

echo "==> Lid switch configuration applied successfully!"
