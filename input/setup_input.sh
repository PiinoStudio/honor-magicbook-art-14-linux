#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing udev rule to silence touchscreen ghost mic-mute events..."
sudo cp "$SCRIPT_DIR/99-ignore-ghost-micmute.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules
sudo udevadm trigger --subsystem-match=input

echo "==> Ghost mic-mute fix applied successfully!"
