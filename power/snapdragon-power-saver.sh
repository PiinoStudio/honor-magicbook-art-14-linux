#!/bin/bash
# Honor MagicBook Art 14 Snapdragon - Suspend Power Saver
# Automatically installed to /etc/systemd/system-sleep/snapdragon-power-saver.sh

case "$1" in
    pre)
        # 1. Disable wakeup triggers on USB controllers to avoid false wake locks
        for c in /sys/bus/platform/devices/*.usb; do
            if [ -f "$c/power/wakeup" ]; then
                echo disabled > "$c/power/wakeup" 2>/dev/null || true
            fi
        done

        # 2. Put USB controllers, PHYs, and PCIe devices into runtime PM auto
        for dev in /sys/bus/platform/devices/*.usb /sys/bus/platform/devices/*.phy /sys/bus/pci/devices/*; do
            if [ -f "$dev/power/control" ]; then
                echo auto > "$dev/power/control" 2>/dev/null || true
            fi
        done

        # 3. Disable Wi-Fi radio before sleep to allow FastConnect 7800 / WCN7850 to drop power votes
        nmcli radio wifi off 2>/dev/null || true
        ;;
    post)
        # Restore Wi-Fi radio on resume
        nmcli radio wifi on 2>/dev/null || true

        # Re-enforce runtime PM auto on wake
        for dev in /sys/bus/platform/devices/*.usb /sys/bus/platform/devices/*.phy /sys/bus/pci/devices/*; do
            if [ -f "$dev/power/control" ]; then
                echo auto > "$dev/power/control" 2>/dev/null || true
            fi
        done
        ;;
esac
exit 0
