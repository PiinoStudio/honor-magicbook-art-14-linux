# cpufreq investigation (2026-11-18, Claude Code via SSH, read-only)

Fresh boot after the owner installed Fedora updates (offline update, reboot at 23:18).
Kernel still `7.2.11-300.fc45.aarch64`. Interconnects back to 61 INT_MAX nodes (sync not forced).
Nothing was changed on the Honor in this step.

## Findings
- `/sys/devices/system/cpu/cpufreq` does not exist: no cpufreq policy, no governor.
- Kernel: `CONFIG_CPU_FREQ=y`, `CONFIG_ARM_SCMI_CPUFREQ=m`, `CONFIG_CPUFREQ_DT=m`.
  `scmi-cpufreq.ko.xz` is installed but **not loaded**; `modinfo scmi-cpufreq` shows **no alias**,
  so udev never autoloads it. `modprobe -n -v scmi-cpufreq` would insmod it (not blacklisted).
- Device tree is fine (mainline style): every CPU has `power-domain-names = "psci", "perf"`,
  perf domains 0/1/2 on `/firmware/scmi/protocol@13`.
- SCMI protocol 0x13 is bound only to `scmi-perf-domain` (`scmi_dev.3`, "Initialized 3 performance
  domains"). The genpd domains `NCC_0`, `NCC_1`, `NCC_2` are `on` with performance state `0`
  (no vote from anyone).
- `[Firmware Bug]: Failed to add opps_by_lvl at 3417600 for NCC - ret:-16` (4x) is a duplicate OPP
  in the firmware table; it appears during SCMI perf init.
- **Measured clock under a 1 s busy loop** (`power/diag/cpufreq_probe.py`, PMU cycles / CPU time):

| cluster | cores | clock |
|---|---|---|
| 0 | cpu0, cpu3 | 3420 MHz |
| 1 | cpu4, cpu7 | 4000 MHz |
| 2 | cpu8, cpu11 | 4005 MHz |

  So without cpufreq the firmware runs cluster 0 at 3.42 GHz and clusters 1/2 at the 4.0 GHz boost
  level permanently. Nothing scales down at light load.

## Interpretation (not yet measured)
Every wakeup runs at the top voltage/frequency point. Strong candidate for the ~8.3 W awake idle
draw, independent of the interconnect result in phase 1a.

## Proposed next step (needs owner approval)
`modprobe scmi-cpufreq` (reversible by reboot), check that policies appear, then
`sleep_diag.sh idle` 180 s before and after, same conditions as phase 1a. If it helps:
make it persistent via `/etc/modules-load.d/scmi-cpufreq.conf`.
