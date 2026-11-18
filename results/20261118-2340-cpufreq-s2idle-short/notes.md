# Short s2idle hang check with persistent scmi-cpufreq (2026-11-18, Claude Code via SSH)

## Setup
- `/etc/modules-load.d/scmi-cpufreq.conf` (`scmi-cpufreq`) created with owner approval, then rebooted.
  After reboot `scmi_cpufreq` is loaded automatically, policy0/4/8 present, governor `schedutil`.
- Battery, brightness 2/255, module params `hold_usbc_ldos=1 s2idle_wake_sec=0 sync_all_suppliers=0`
  (installed older module build, not the repo version). Interconnects not synced.
- `LID_DELAY=30 sleep_diag.sh run cpufreq-s2idle-short`, started detached.

## What happened (from `dmesg.txt` and the journal)
1. 23:41:10 script writes `freeze`. Slept 13.96 s, woken by IRQ 127 (`msmgpio 92 gpio_keys`) when the
   owner closed the lid.
2. The script's lid inhibitor ends with the `freeze` command, so logind then handled the closed lid:
   `HandleLidSwitch=hibernate` -> **"Requested hibernate operation is not supported, using regular
   suspend instead."** -> second s2idle via systemd-sleep, slept 172.7 s, woken by IRQ 127 (lid open).
3. Both resumes clean: `suspend_stats success=2 fail=0`, owner confirmed the wake worked.

## Numbers (whole window incl. 30 s awake delay, two suspend/resume cycles)
- energy_now delta 272000 uWh over 225 s -> 4.35 W average. Not a clean s2idle figure.
- `apss` accumulated sleep delta 0, `cxsd`/`aosd`/`ddr` counts unchanged (blocked by design at EL1).
- `adsp` +4024 sleep entries.
- Only expected kernel messages: `bridge_d3` disable, `ath12k ... qmi dma allocation failed ... will
  try later` on resume (both cycles).

## Findings
- Pass: s2idle + resume works with scmi-cpufreq loaded, both via direct `freeze` and via
  logind/systemd-sleep.
- **Hibernate is currently not available** (pre-existing, unrelated to cpufreq): logind refuses it and
  falls back to suspend. Same message 13x in boot -4; no successful hibernation in any journaled boot.
  At boot, `systemd-hibernate-resume` reports "Unable to resume from device '/dev/sda9' (8:9) offset
  1655338". Swap is `/swap/swapfile` 34G (offset matches `resume_offset`) plus zram 8G (prio 100).
  Root cause not yet found.
- Script issue: `sleep_diag.sh run` releases the lid inhibitor right after `freeze` returns, so a lid
  closed during the run triggers a second, logind-driven suspend that falls into the measurement window.
