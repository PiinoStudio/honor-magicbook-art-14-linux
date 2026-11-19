# Phase 2b (`p2b-drips-icc-synced`, 2026-11-19, Antigravity via SSH)

## Setup
- Same boot as `results/20261119-1105-p2-drips-short/` (EL1, kernel `7.2.11-300.fc45.aarch64`, repo `honor_deep_sleep_fix.ko` with `drips_mode=1 hold_usbc_ldos=Y pcie_bridge_d3=0 pcie_icc_tweak=Y sync_all_suppliers=0`).
- CPUFreq governor: `ondemand` active on `policy0`, `policy4`, `policy8`.
- Battery only (`Discharging`), brightness `2/255`, `LID_DELAY=25`.
- Before starting `sleep_diag.sh`, executed `force_sync_state.sh apply-icc` (`sync-apply.txt`):
  - `1700000.interconnect -> state_synced=1`
  - `interconnect-1 -> state_synced=1`
  - Interconnect nodes at `INT_MAX`: `58 -> 0` (confirmed `0` in both `before.txt` and `after.txt`).
  - `gcc` (`100000.clock-controller`) and `gpucc` (`3d90000.clock-controller`) were NOT forced.

## Outcome & Observations
- **Clean suspend and resume (`freeze rc=0`):**
  - Owner was away when the 25 s countdown expired, so the laptop entered `s2idle` with the lid open, stayed suspended cleanly for **`Timekeeping suspended for 411.957 seconds`** (~6.9 min), and woke cleanly on `IRQ 127` when the owner closed the lid.
  - `sleep_diag.sh` held the `handle-lid-switch` inhibitor through `after.txt` (`5 s` post-resume settle) and released it on exit, after which `systemd-logind` suspended once more (`S2idle` 2 -> 3) and the owner woke it cleanly again by opening the lid.
  - Non-fatal kernel messages in `dmesg.txt` match `p2-drips-short`: `dwc3-qcom a{4,6,8}00000.usb: port-* HS-PHY not in L2`, `ath12k_wifi7_pci 0004:01:00.0: qmi dma allocation failed (7274496 B type 1), will try later with small size`, `hwmon hwmon68: PM: parent phy0 should not be sleeping`, plus `set bridge_d3=0` and `pcie-mem icc tag=3, bw=250000`.
- **Power & idle state counters:**
  - `power-domain-system` `S0`: `S2idle` incremented `1 -> 2` during this run (`3` after follow-up `logind` sleep in `genpd-idle-states.txt`; `Time=3757 ms` unchanged).
  - `power-domain-cpu-cluster{0,1,2}` `S1`: `S2idle` incremented `1 -> 2` (and `3` after follow-up sleep).
  - `qcom_stats/apss`: **`123 -> 123` (`0 s` delta)** (unchanged since early boot `t = 0..26 s`).
  - `qcom_stats/{cxsd,aosd,ddr}`: all **`0 -> 0`**.
  - `qcom_stats/adsp`: `66123 -> 69630` (`+3507` entries over `439 s` ≈ `8.0/s`, vs. `+3414` over `219 s` ≈ `15.6/s` in `p2-drips-short`).
  - Power (`446 s` total window = `411.957 s` sleep + `~34 s` awake): `energy_now` `33539000 -> 32956000 uWh` (`583000 uWh` -> **`4.706 W` avg**); `power_now`: `-6.155 W` (`before.txt`), `-5.223 W` (`after.txt`).
