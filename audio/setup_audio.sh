#!/usr/bin/env bash
# Audio Setup Script for Honor MagicBook Art 14 Snapdragon
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing AudioReach Topology..."
sudo mkdir -p /lib/firmware/qcom/x1e80100
sudo cp "${SCRIPT_DIR}/X1E80100-HONOR-MagicBook-Art-14-Snapdragon-tplg.bin" /lib/firmware/qcom/x1e80100/
# Also create compressed .xz link if needed
xz -k -c "${SCRIPT_DIR}/X1E80100-HONOR-MagicBook-Art-14-Snapdragon-tplg.bin" | sudo tee /lib/firmware/qcom/x1e80100/X1E80100-HONOR-MagicBook-Art-14-Snapdragon-tplg.bin.xz > /dev/null

echo "==> Configuring PipeWire Quad-Speaker Upmix..."
sudo mkdir -p /etc/pipewire/pipewire.conf.d /etc/pipewire/pipewire-pulse.conf.d /etc/pipewire/client.conf.d
sudo cp "${SCRIPT_DIR}/20-upmix.conf" /etc/pipewire/pipewire.conf.d/
sudo cp "${SCRIPT_DIR}/20-upmix.conf" /etc/pipewire/pipewire-pulse.conf.d/
sudo cp "${SCRIPT_DIR}/20-upmix.conf" /etc/pipewire/client.conf.d/

echo "==> Ensuring sound module loads at boot..."
echo "snd-soc-x1e80100" | sudo tee /etc/modules-load.d/sound.conf > /dev/null

echo "==> Setting analog amplifier boost (+6 dB)..."
if command -v amixer >/dev/null 2>&1; then
    amixer -c 0 sset 'WSA EAR SPKR PA Gain' 'G_6_DB' 2>/dev/null || true
    amixer -c 0 sset 'WSA2 EAR SPKR PA Gain' 'G_6_DB' 2>/dev/null || true
    amixer -c 0 sset 'WooferLeft PA' 6 2>/dev/null || true
    amixer -c 0 sset 'TweeterLeft PA' 6 2>/dev/null || true
    amixer -c 0 sset 'WooferRight PA' 6 2>/dev/null || true
    amixer -c 0 sset 'TweeterRight PA' 6 2>/dev/null || true
    sudo alsactl store 2>/dev/null || true
fi

echo "Audio setup complete! Restart pipewire or reboot to take effect."
