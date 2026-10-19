#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing System Clock Preservation (RTC fallback)..."
sudo cp "$SCRIPT_DIR/save-restore-clock.sh" /usr/local/bin/save-restore-clock.sh
sudo chmod +x /usr/local/bin/save-restore-clock.sh

sudo cp "$SCRIPT_DIR/save-restore-clock.service" /etc/systemd/system/
sudo cp "$SCRIPT_DIR/save-clock-periodic.service" /etc/systemd/system/
sudo cp "$SCRIPT_DIR/save-clock-periodic.timer" /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable save-restore-clock.service
sudo systemctl enable --now save-clock-periodic.timer
sudo /usr/local/bin/save-restore-clock.sh save

echo "==> Clock preservation service installed and active!"
