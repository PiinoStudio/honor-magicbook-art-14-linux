#!/bin/bash
# sleep_diag.sh - reproducible s2idle measurements for the Honor MagicBook Art 14 (X1E80100)
#
# Usage (as root):
#   sleep_diag.sh snapshot <label>          # collect state only, no suspend
#   sleep_diag.sh run <label>               # snapshot, s2idle until woken, snapshot, summary
#   sleep_diag.sh ec-probe                  # read-only probe of the EC at I2C5 0x76
#   sleep_diag.sh idle <label> [seconds]    # awake idle power on battery (default 120 s)
#
# Results go to <repo>/results/<YYYYmmdd-HHMM>-<label>/ (override with RESULTS_DIR=...).
# Commit the whole directory unchanged. Do not edit or summarise the raw files.
#
# Env options for "run":
#   LID_DELAY=20        seconds to wait before suspending (time to close the lid)
#   EC_MSTANDBY=1       send EC modern-standby enter/exit (cmd 0x23) around the suspend
#                       (only after "ec-probe" returned a plausible firmware version!)
#   STOP_AUDIO_USER=<user>  stop pipewire/wireplumber of that user before suspending
#   POST_SAMPLES=15     energy samples (every 2 s) after resume, written to energy.txt
#
# SUMMARY.md reports "sleep-only power" from energy_now read right before freeze and right after
# resume. Sleep at least 10 min for comparisons (fuel gauge: 1 mWh steps, ~45 s averaging).
#
# The suspend is entered by writing "freeze" to /sys/power/state directly, so the
# systemd-sleep hooks (snapdragon-power-saver.sh) and FailureAction= overrides are
# NOT involved. A lid-switch inhibitor is held so closing the lid does not trigger
# the logind hibernate policy. Wake the machine by opening the lid or pressing a key.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
DBG=/sys/kernel/debug
TICKS_PER_SEC=19200000   # qcom_stats values are raw 19.2 MHz AOSS ticks

die() { echo "ERROR: $*" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || die "run as root (sudo)"
mountpoint -q "$DBG" || mount -t debugfs none "$DBG" 2>/dev/null

cmd="${1:-}"; label="${2:-unnamed}"
label="$(printf '%s' "$label" | tr -c 'A-Za-z0-9_.-' '_')"

new_outdir() {
    local d="${RESULTS_DIR:-$REPO_DIR/results}/$(date +%Y%m%d-%H%M)-$label"
    mkdir -p "$d" || die "cannot create $d"
    echo "$d"
}

# cat a file with a header; never fail
dumpf() { echo "### $1"; cat "$1" 2>&1; echo; }

stat_field() {  # stat_field <qcom_stats file> <field name>
    awk -F': *' -v k="$2" '$1==k {print $2}' "$1" 2>/dev/null | head -1
}

snap_field() {  # snap_field <snapshot file> <qcom_stats file> <field name>
    awk -v h="### $2" -v k="$3" '$0==h {f=1; next} f && /^### / {exit} f { split($0, a, /: */); if (a[1]==k) {print a[2]; exit} }' "$1" 2>/dev/null
}

battery_dir() {
    for b in /sys/class/power_supply/*; do
        [ "$(cat "$b/type" 2>/dev/null)" = "Battery" ] && { echo "$b"; return; }
    done
}

snapshot() {  # snapshot <outfile>
    local out="$1"
    {
        echo "=== date: $(date -Is)  uptime: $(cut -d' ' -f1 /proc/uptime)"
        echo "=== uname: $(uname -a)"
        echo "=== model: $(tr -d '\0' < /proc/device-tree/model 2>/dev/null)"
        echo "=== cmdline: $(cat /proc/cmdline)"
        echo "=== exception level:"; dmesg | grep -m2 -E "started at EL|VHE mode|hyp mode" || echo "(not found in dmesg)"
        echo "=== /sys/power:"; for f in mem_sleep state pm_test resume resume_offset; do echo "$f: $(cat /sys/power/$f 2>&1)"; done
        echo "=== honor_deep_sleep_fix:"
        lsmod | grep -E "^honor_deep_sleep_fix" || echo "(not loaded)"
        for p in /sys/module/honor_deep_sleep_fix/parameters/*; do [ -e "$p" ] && echo "$(basename "$p")=$(cat "$p")"; done
        echo "=== other relevant modules:"; lsmod | grep -E "qcom_adsp_pwr_lmts|el1tmr|aoss_cxsd|qcom.hamoa.ec|ath12k|icc_bwmon|q6prm|lpass" || true
        echo "=== hvc_dcc / serial-getty@hvc0:"
        ls /dev/hvc* 2>/dev/null; systemctl is-active serial-getty@hvc0.service 2>&1
        echo
        echo "=== qcom_stats"
        for f in "$DBG"/qcom_stats/*; do dumpf "$f"; done
        echo "=== sync_state"
        for d in 100000.clock-controller 3d90000.clock-controller 1700000.interconnect interconnect-1 1dfa000.crypto; do
            echo "$d state_synced=$(cat /sys/bus/platform/devices/$d/state_synced 2>&1)  driver=$(basename "$(readlink /sys/bus/platform/devices/$d/driver 2>/dev/null)" 2>/dev/null)"
        done
        echo "=== all devices with state_synced=0"
        for f in $(find /sys/devices -name state_synced 2>/dev/null); do
            [ "$(cat "$f" 2>/dev/null)" = "0" ] && echo "${f%/state_synced}"
        done
        echo "=== interconnect nodes at INT_MAX (boot bandwidth still held): $(grep -cE ' 214[0-9]{7} ' "$DBG/interconnect/interconnect_summary" 2>/dev/null)"
        echo "=== devices waiting for suppliers (deferred probe)"; dumpf "$DBG/devices_deferred"
        echo "=== LPASS macro clocks"
        for c in "$DBG"/clk/*LPASS_HW_MACRO* "$DBG"/clk/*LPASS_HW_DCODEC* "$DBG"/clk/*lpass*macro*; do
            [ -e "$c/clk_enable_count" ] && echo "$(basename "$c") enable_count=$(cat "$c/clk_enable_count") prepare_count=$(cat "$c/clk_prepare_count" 2>/dev/null)"
        done
        echo "=== PCIe"
        for p in /sys/bus/pci/devices/*; do
            echo "$(basename "$p") class=$(cat "$p/class") power_state=$(cat "$p/power_state" 2>/dev/null) runtime=$(cat "$p/power/runtime_status" 2>/dev/null) d3cold_allowed=$(cat "$p/d3cold_allowed" 2>/dev/null) control=$(cat "$p/power/control" 2>/dev/null)"
        done
        echo "=== audio PCM substreams"
        grep -H . /proc/asound/card*/pcm*/sub*/status 2>/dev/null | grep -v closed || echo "(all closed)"
        echo "=== wakeup-enabled devices"
        for w in $(find /sys/devices -path '*/power/wakeup' 2>/dev/null); do
            [ "$(cat "$w" 2>/dev/null)" = "enabled" ] && echo "${w%/power/wakeup}"
        done
        echo "=== wakeup_sources (active_count>0)"
        awk 'NR==1 || $2>0' "$DBG/wakeup_sources" 2>/dev/null
        echo "=== battery"
        local b; b="$(battery_dir)"
        [ -n "$b" ] && for f in status energy_now energy_full power_now current_now voltage_now capacity; do echo "$f=$(cat "$b/$f" 2>/dev/null)"; done
        echo "=== rtc"; ls /sys/class/rtc/ 2>&1; cat /sys/class/rtc/rtc0/since_epoch 2>/dev/null
        echo "=== pm_genpd_summary"; dumpf "$DBG/pm_genpd/pm_genpd_summary"
        echo "=== interconnect_summary"; dumpf "$DBG/interconnect/interconnect_summary"
        echo "=== cpuidle states (cpu0)"
        for s in /sys/devices/system/cpu/cpu0/cpuidle/state*; do echo "$(basename "$s") $(cat "$s/name") usage=$(cat "$s/usage") s2idle_usage=$(cat "$s/s2idle/usage" 2>/dev/null)"; done
    } > "$out" 2>&1
}

find_ec_bus() {
    for a in /sys/bus/i2c/devices/i2c-*; do
        readlink -f "$a/of_node" 2>/dev/null | grep -q "b94000" && { basename "$a" | sed 's/i2c-//'; return; }
        readlink -f "$a" | grep -q "b94000" && { basename "$a" | sed 's/i2c-//'; return; }
    done
}

case "$cmd" in
snapshot)
    out="$(new_outdir)"
    snapshot "$out/snapshot.txt"
    dmesg > "$out/dmesg.txt"
    echo "Wrote $out"
    ;;

run)
    out="$(new_outdir)"
    bat="$(battery_dir)"
    [ -n "$bat" ] || die "no battery found"
    [ "$(cat "$bat/status")" = "Discharging" ] || echo "WARNING: battery is not discharging (AC connected?) - power numbers will be meaningless" | tee "$out/WARNING.txt"

    if [ -n "${STOP_AUDIO_USER:-}" ]; then
        uid="$(id -u "$STOP_AUDIO_USER")"
        sudo -u "$STOP_AUDIO_USER" XDG_RUNTIME_DIR=/run/user/$uid systemctl --user stop pipewire.socket pipewire-pulse.socket pipewire wireplumber pipewire-pulse 2>&1 | tee -a "$out/notes.txt"
    fi

    echo 1 > /sys/power/pm_debug_messages 2>/dev/null
    snapshot "$out/before.txt"
    e0="$(cat "$bat/energy_now")"; t0="$(date +%s)"
    a0="$(stat_field "$DBG/qcom_stats/apss" "Accumulated Duration")"
    dmesg -C 2>/dev/null; : # keep the per-run dmesg small

    echo "Suspending in ${LID_DELAY:-20}s. Close the lid now; open it (or press a key) to wake."
    ec_bus=""
    if [ "${EC_MSTANDBY:-0}" = "1" ]; then
        ec_bus="$(find_ec_bus)"; [ -n "$ec_bus" ] || die "EC bus (b94000) not found"
    fi
    # Hold the lid inhibitor for the whole run (incl. the after-snapshot), so a lid closed while
    # suspended does not trigger a second, logind-driven suspend inside the measurement window.
    systemd-inhibit --what=handle-lid-switch --who=sleep_diag --why="measurement" --mode=block \
        sleep infinity & inh_pid=$!
    trap 'kill $inh_pid 2>/dev/null' EXIT
    # energy.txt: "<epoch.ns> <phase> <energy_now uWh> <power_now uW>", sampled every 2 s while
    # awake, plus one sample right before freeze and right after resume (sleep-only power).
    esample() { echo "$(date +%s.%N) $1 $(cat "$bat/energy_now") $(cat "$bat/power_now")" >> "$out/energy.txt"; }
    : > "$out/energy.txt"
    for _ in $(seq 1 $(( ${LID_DELAY:-20} / 2 ))); do esample pre; sleep 2; done
    [ -n "$ec_bus" ] && i2cset -y "$ec_bus" 0x76 0x23 0x01 && echo 'EC modern standby ENTER sent' | tee -a "$out/notes.txt"
    esample freeze
    echo freeze > /sys/power/state; rc=$?
    esample resume
    [ -n "$ec_bus" ] && i2cset -y "$ec_bus" 0x76 0x23 0x00 && echo 'EC modern standby EXIT sent' | tee -a "$out/notes.txt"
    echo "freeze rc=$rc" | tee -a "$out/notes.txt"

    # let resume settle; keep sampling, the fuel gauge may report a stale value right after resume
    for _ in $(seq 1 "${POST_SAMPLES:-15}"); do sleep 2; esample post; done
    e1="$(cat "$bat/energy_now")"; t1="$(date +%s)"
    a1="$(stat_field "$DBG/qcom_stats/apss" "Accumulated Duration")"
    snapshot "$out/after.txt"
    dmesg > "$out/dmesg.txt"
    journalctl -b -k --since "-$(( t1 - t0 + 120 ))s" > "$out/journal-kernel.txt" 2>/dev/null

    {
        echo "# Run summary: $label"
        echo "kernel: $(uname -r)"
        echo "module params: $(for p in /sys/module/honor_deep_sleep_fix/parameters/*; do [ -e "$p" ] && printf '%s=%s ' "$(basename "$p")" "$(cat "$p")"; done)"
        echo "EC_MSTANDBY=${EC_MSTANDBY:-0} STOP_AUDIO_USER=${STOP_AUDIO_USER:-}"
        echo
        echo "wall clock delta: $(( t1 - t0 )) s   (unreliable if the RTC does not work)"
        if [ -n "$a0" ] && [ -n "$a1" ]; then
            echo "apss sleep delta (AOSS ticks): $(( (a1 - a0) / TICKS_PER_SEC )) s"
        fi
        echo "energy_now: $e0 -> $e1 (uWh), delta $(( e0 - e1 )) uWh"
        dt=$(( t1 - t0 ))
        if [ -n "$a0" ] && [ -n "$a1" ] && [ $(( (a1 - a0) / TICKS_PER_SEC )) -gt "$dt" ]; then
            dt=$(( (a1 - a0) / TICKS_PER_SEC )); echo "(using apss delta as duration)"
        fi
        [ "$dt" -gt 0 ] && awk -v e=$(( e0 - e1 )) -v t="$dt" 'BEGIN{printf "average power (whole window incl. awake parts): %.3f W over %d s\n", e/1e6/(t/3600), t}'
        echo
        echo "## Sleep-only power (use this number)"
        ts="$(grep -m1 -oE 'Timekeeping suspended for [0-9.]+' "$out/dmesg.txt" | awk '{print $4}')"
        echo "kernel: Timekeeping suspended for ${ts:-?} s"
        awk -v ts="${ts:-0}" '
            $2=="freeze"{tf=$1; ef=$3}
            $2=="resume"{tr=$1; er=$3}
            $2=="post"{lp_t=$1; lp_e=$3; if(!fp_t){fp_t=$1; fp_e=$3}}
            END{
              if(!tf||!tr){print "freeze/resume samples missing"; exit}
              d=tr-tf
              printf "energy right before freeze -> right after resume: %d -> %d uWh over %.1f s\n", ef, er, d
              if(d>0 && ef>er) printf "sleep-only power: %.3f W\n", (ef-er)/1e6/(d/3600)
              else print "sleep-only power: n/a (fuel gauge did not update across the sleep)"
              if(lp_t && lp_t>tf) printf "cross-check freeze -> last post sample (%.1f s, incl. ~%.0f s awake): %.3f W\n", lp_t-tf, lp_t-tr, (ef-lp_e)/1e6/((lp_t-tf)/3600)
              if(ts>0 && ts<600) print "NOTE: sleep < 10 min; fuel-gauge resolution and averaging make this figure rough"
            }' "$out/energy.txt"
        echo
        echo "| stat | count before | count after | accumulated delta (s) |"
        echo "|---|---|---|---|"
        for s in apss cxsd aosd ddr adsp cdsp; do
            f="$DBG/qcom_stats/$s"; [ -e "$f" ] || continue
            cb="$(snap_field "$out/before.txt" "$f" "Count")"
            ca="$(snap_field "$out/after.txt" "$f" "Count")"
            ab="$(snap_field "$out/before.txt" "$f" "Accumulated Duration")"
            aa="$(snap_field "$out/after.txt" "$f" "Accumulated Duration")"
            echo "| $s | ${cb:-?} | ${ca:-?} | $(( (${aa:-0} - ${ab:-0}) / TICKS_PER_SEC )) |"
        done
        echo
        echo "Errors in kernel log during run:"
        grep -iE "timeout|fail|error|hibern8|L2 entry|abort|wakeup.*irq|PM: .*wakeup" "$out/dmesg.txt" | head -40
    } > "$out/SUMMARY.md"
    cat "$out/SUMMARY.md"
    echo; echo "Wrote $out - commit the whole directory."
    ;;

idle)
    out="$(new_outdir)"
    bat="$(battery_dir)"; [ -n "$bat" ] || die "no battery found"
    secs="${3:-120}"   # fuel gauge settles in ~45 s; the "after 60 s" average is the number to use
    [ "$(cat "$bat/status")" = "Discharging" ] || die "unplug the charger first (status=$(cat "$bat/status"))"
    snapshot "$out/snapshot.txt"
    echo "Measuring awake idle power for ${secs}s. Do not touch the machine." | tee "$out/notes.txt"
    e0="$(cat "$bat/energy_now")"; t0="$(date +%s.%N)"
    : > "$out/power_now.txt"
    for _ in $(seq 1 $(( secs / 2 ))); do
        echo "$(date +%s) $(cat "$bat/power_now")" >> "$out/power_now.txt"; sleep 2
    done
    e1="$(cat "$bat/energy_now")"; t1="$(date +%s.%N)"
    {
        echo "# Idle summary: $label"
        echo "kernel: $(uname -r)"
        echo "uptime at end: $(cut -d' ' -f1 /proc/uptime) s"
        echo "cpufreq policies: $(ls /sys/devices/system/cpu/cpufreq 2>/dev/null | tr '\n' ' ')"
        echo "interconnect nodes at INT_MAX: $(grep -cE ' 214[0-9]{7} ' "$DBG/interconnect/interconnect_summary" 2>/dev/null)"
        # min/max initialised from the first sample (power_now is negative while discharging)
        awk '{s+=$2; n++; if(n==1||$2<min)min=$2; if(n==1||$2>max)max=$2} END{printf "power_now: avg %.3f W, min %.3f W, max %.3f W (%d samples)\n", s/n/1e6, min/1e6, max/1e6, n}' "$out/power_now.txt"
        # the fuel gauge averages over ~45 s, so also report the part after the first 60 s
        awk 'NR==1{t0=$1} $1>=t0+60{s+=$2; n++} END{if(n) printf "power_now after 60 s: avg %.3f W (%d samples)\n", s/n/1e6, n}' "$out/power_now.txt"
        awk -v e=$(( e0 - e1 )) -v t0="$t0" -v t1="$t1" 'BEGIN{t=t1-t0; printf "energy_now delta: %d uWh over %.1f s -> %.3f W\n", e, t, e/1e6/(t/3600)}'
        echo "brightness: $(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1)/$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1)"
    } > "$out/SUMMARY.md"
    cat "$out/SUMMARY.md"; echo "Wrote $out"
    ;;

ec-probe)
    out="$(new_outdir)"
    command -v i2cget >/dev/null || die "install i2c-tools first (dnf install i2c-tools)"
    modprobe i2c-dev 2>/dev/null
    bus="$(find_ec_bus)"
    {
        echo "EC bus (i2c@b94000): ${bus:-NOT FOUND}"
        [ -n "$bus" ] || exit 0
        echo "bound clients on this bus:"; ls -d /sys/bus/i2c/devices/$bus-* 2>/dev/null
        if [ -e "/sys/bus/i2c/devices/$bus-0076/driver" ]; then
            echo "0x76 already bound to a driver: $(readlink /sys/bus/i2c/devices/$bus-0076/driver) - not touching it"; exit 0
        fi
        echo "FW version read (cmd 0x0e, 4 bytes, I2C block read):"
        i2cget -y "$bus" 0x76 0x0e i 4 2>&1
        echo "Thermal capability read (cmd 0x42, 3 bytes):"
        i2cget -y "$bus" 0x76 0x42 i 3 2>&1
    } 2>&1 | tee "$out/ec-probe.txt"
    ;;

*)
    sed -n '2,22p' "$0"; exit 1 ;;
esac
