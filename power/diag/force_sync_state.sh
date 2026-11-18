#!/bin/bash
# force_sync_state.sh - list / force sync_state() of providers that never reached it
#
#   force_sync_state.sh list                  # all devices with state_synced=0 and why
#   force_sync_state.sh apply-icc             # force only interconnect providers
#   force_sync_state.sh apply <dev> [...]     # force named platform devices
#
# Background: the interconnect core keeps EVERY node at its boot bandwidth
# (INT_MAX, i.e. DDR/LLCC at maximum) until ALL interconnect providers have
# reached sync_state(). One provider whose consumer never probes (e.g. a
# blacklisted crypto driver, or the GMU node that has no driver on 7.2) keeps
# the whole SoC at maximum bandwidth. Likewise genpd keeps boot-on power domains
# of a clock controller on until that controller's sync_state().
#
# Writing 1 to the device's state_synced attribute forces sync_state() through
# the official driver-core interface. Effect lasts until reboot.

set -u
[ "$(id -u)" -eq 0 ] || { echo "run as root" >&2; exit 1; }
DBG=/sys/kernel/debug
mountpoint -q "$DBG" || mount -t debugfs none "$DBG" 2>/dev/null

icc_count() { grep -cE ' 214[0-9]{7} ' "$DBG/interconnect/interconnect_summary" 2>/dev/null; }

is_icc_provider() { [ -e "$1/of_node/#interconnect-cells" ]; }

unsynced() {
    for f in $(find /sys/devices -name state_synced 2>/dev/null); do
        [ "$(cat "$f" 2>/dev/null)" = "0" ] && echo "${f%/state_synced}"
    done
}

force() {  # force <device sysfs path>
    local d="$1"
    # the kernel compares the buffer with "1" exactly, so no trailing newline
    if printf 1 > "$d/state_synced" 2>/dev/null; then
        echo "forced: $(basename "$d") -> state_synced=$(cat "$d/state_synced")"
    else
        echo "FAILED: $(basename "$d") (attribute not writable on this kernel?)"
    fi
}

case "${1:-}" in
list)
    echo "interconnect nodes at INT_MAX: $(icc_count)"
    for d in $(unsynced); do
        kind=""; is_icc_provider "$d" && kind="[interconnect provider]"
        [ -e "$d/of_node/#power-domain-cells" ] && kind="$kind[power-domain provider]"
        [ -e "$d/of_node/#clock-cells" ] && kind="$kind[clock provider]"
        echo "== $(basename "$d") $kind driver=$(basename "$(readlink "$d/driver" 2>/dev/null)" 2>/dev/null)"
        # consumers that have not probed (devlink status != active)
        for l in "$d"/consumer:*; do
            [ -e "$l" ] || continue
            st="$(cat "$l/status" 2>/dev/null)"
            [ "$st" = "active" ] || echo "   waiting on consumer: ${l##*/consumer:} (link status: $st)"
        done
    done
    ;;
apply-icc)
    echo "before: interconnect nodes at INT_MAX: $(icc_count)"
    for d in $(unsynced); do is_icc_provider "$d" && force "$d"; done
    sleep 1
    echo "after:  interconnect nodes at INT_MAX: $(icc_count)"
    ;;
apply)
    shift
    for n in "$@"; do
        d="/sys/bus/platform/devices/$n"
        [ -e "$d/state_synced" ] && force "$(readlink -f "$d")" || echo "no state_synced for $n"
    done
    echo "interconnect nodes at INT_MAX: $(icc_count)"
    ;;
*)
    sed -n '2,6p' "$0"; exit 1 ;;
esac
