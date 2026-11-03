#!/bin/bash
# Snapdragon X Elite Deep Suspend Power Saver
# Installed to /etc/systemd/system-sleep/snapdragon-power-saver.sh

case "$1" in
    pre)
        # 1. Kill USB Wakeup and force USB PHYs into low-power runtime PM
        for u in /sys/devices/platform/soc@0/a*00000.usb; do
            [ -f "$u/power/wakeup" ] && echo disabled > "$u/power/wakeup" 2>/dev/null
            [ -f "$u/power/control" ] && echo auto > "$u/power/control" 2>/dev/null
        done
        for p in /sys/bus/pci/devices/*; do
            [ -f "$p/power/control" ] && echo auto > "$p/power/control" 2>/dev/null
        done
        for f in /sys/devices/platform/soc@0/*.phy; do
            [ -f "$f/power/control" ] && echo auto > "$f/power/control" 2>/dev/null
        done

        # 2. Power down Wi-Fi PCIe link before entering sleep to prevent L2 timeouts & drop votes
        nmcli radio wifi off 2>/dev/null || true

        # 3. Flush disk caches
        sync
        ;;
    post)
        # 1. Restore Wi-Fi radio upon wakeup
        nmcli radio wifi on 2>/dev/null || true
        (sleep 2 && nmcli device connect wlP4p1s0 2>/dev/null || true) &

        # 2. Keep runtime PM on auto
        for u in /sys/devices/platform/soc@0/a*00000.usb; do
            [ -f "$u/power/control" ] && echo auto > "$u/power/control" 2>/dev/null
        done
        for p in /sys/bus/pci/devices/*; do
            [ -f "$p/power/control" ] && echo auto > "$p/power/control" 2>/dev/null
        done
        ;;
esac
exit 0
