# Phase 2 short hang check (`p2-drips-short`, 2026-11-19, Antigravity via SSH)

## Setup
- Kernel `7.2.11-300.fc45.aarch64`, EL1 (`CPU: All CPU(s) started at EL1`).
- Repo build of `honor_deep_sleep_fix.ko` loaded at boot with:
  `drips_mode=1 hold_usbc_ldos=Y pcie_bridge_d3=0 pcie_icc_tweak=Y sync_all_suppliers=0`.
- `dmesg` confirms: `honor_deep_sleep_fix: drips_mode=1: runtime DRIPS blocked on power-domain-system, s2idle DRIPS allowed`.
- Note on CPUFreq governor: after reboot `tuned.service` had reset `scaling_governor` back to `schedutil` because `cpufreq-ondemand.service` lacked `tuned.service` in `After=`. Updated `/etc/systemd/system/cpufreq-ondemand.service` to `After=systemd-modules-load.service tuned.service` with `printf ondemand | tee /sys/devices/system/cpu/cpufreq/policy*/scaling_governor >/dev/null` and verified `ondemand` persisted on `policy0`, `policy4`, `policy8` before starting this run.
- Battery only (`Discharging`), brightness `2/255`, interconnects NOT synced (`58` `INT_MAX` nodes), `LID_DELAY=25`.

## Outcome & Observations
- **Clean suspend and resume (`freeze rc=0`)**:
  - `PM: suspend-to-idle`, `Timekeeping suspended for 191.545 seconds`.
  - Woken cleanly by lid open (`PM: Triggering wakeup from IRQ 127`).
  - Owner reported the machine woke unlocked (already unlocked on lid open) with display/system responsive.
  - Non-fatal kernel messages in `dmesg.txt`: `dwc3-qcom a{4,6,8}00000.usb: port-* HS-PHY not in L2`, `ath12k_wifi7_pci 0004:01:00.0: qmi dma allocation failed (7274496 B type 1), will try later with small size`, `hwmon hwmon68: PM: parent phy0 should not be sleeping` (plus `set bridge_d3=0` and `pcie-mem icc tag=3, bw=250000`). No hangs, no L2 timeout, Wi-Fi reconnected.
- **Power & idle state counters:**
  - `power-domain-system` (`S0`, DRIPS): `S2idle = 1` (`Time=3757 ms`, `Usage=244`, `Rejected=10` — from early boot + s2idle entry).
  - `power-domain-cpu-cluster{0,1,2}` (`S1`): `S2idle = 1` on all three clusters (`genpd-idle-states.txt`).
  - `cpu0` `cpuidle state1 cpu-sleep-0`: `s2idle_usage: 0 -> 1`.
  - `qcom_stats/apss`: **`123 -> 123` (`0 s` accumulated delta)** (all 123 prior entries happened during early boot before `honor_deep_sleep_fix` loaded at 26.36 s).
  - `qcom_stats/{cxsd,aosd,ddr}`: all **`0 -> 0`**.
  - `qcom_stats/adsp`: `24063 -> 27477` (`+3414` entries, `219 s` accumulated).
  - Power over the full `225 s` window (includes 25 s awake countdown + 5 s post-resume settle): `energy_now` `34535000 -> 34224000 uWh` (`311000 uWh` -> **`4.976 W`** avg); `power_now` `-6.158 W` (`before.txt`) and `-5.406 W` (`after.txt`).
