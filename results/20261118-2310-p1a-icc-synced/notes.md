# Phase 1a, second attempt (2026-11-18, Claude Code via SSH)

Repeat of phase 1a with the fixed `force_sync_state.sh` (`printf 1`, commit `dd93450`).
Same boot as the first attempt (uptime ~1 h, no reboot in between; the first apply had no effect).
Baseline run: `results/20261118-2307-p1a-before`.

## Conditions
- Battery only: `qcom-battmgr-bat` = Discharging, AC/USB/WLS `online=0`.
- Brightness `52/255` for both runs, screen on (`dpms=On`, `bl_power=0`).
- Both 180 s runs under `systemd-inhibit --what=idle:sleep`, started detached on the Honor
  (`setsid nohup`), no user input, one idle SSH session open.

## Result
| run | INT_MAX nodes | power_now avg | energy_now delta |
|---|---|---|---|
| p1a-before | 61 | 8.329 W | 8.420 W |
| p1a-icc-synced | 0 | 8.350 W | 8.720 W |

- `apply-icc` worked this time: `1700000.interconnect` and `interconnect-1` -> `state_synced=1`,
  INT_MAX nodes 61 -> 0 (`sync-apply.txt`).
- **No measurable power reduction.** The difference is within run-to-run noise
  (first attempt baseline was 8.8-9.0 W on the same boot).
- After the sync, DDR still carries real votes: `ebi@interconnect-1` avg 1984020 / peak 2188000,
  `qns_llcc` avg 1984020 (checked directly after the run, not part of the snapshot).
  So the boot INT_MAX vote was not what kept power at ~8.4 W, at least awake with the display on.

## Post-apply checks (via SSH)
- Display: `dpms=On`, connector `connected`, `bl_power=0`. Physical flicker not checked (owner).
- Wi-Fi: `wlP4p1s0` connected, SSH kept working throughout.
- Audio: `aplay -l` lists card 0 `X1E80100-HONOR-MagicBook-Art-14`. Playback not tested.
- USB: `lsusb` lists 6 entries (root hubs).
- Keyboard/touchpad: not checked (owner).
- `dmesg` after apply: only the marker line, no new errors or warnings (`dmesg-after-apply.txt`,
  `dmesg-after-run.txt`).

## Side observations (not acted on)
- **No cpufreq at all**: `/sys/devices/system/cpu/cpufreq` does not exist, `cpu0/` has no
  `cpufreq` directory. SCMI probes (`Protocol v2.0 'Qualcomm:'`) but logs
  `[Firmware Bug]: Failed to add opps_by_lvl at 3417600 for NCC - ret:-16`. If the CPUs stay at the
  firmware boot frequency, this is a strong candidate for the high awake idle power.
- `qcom-iris aa00000.video-codec`: firmware `qcvss8380.mbn` missing, `core init failed`, but logs
  `video hw is power on` before failing. Check whether the video core power domain stays on.
- The interconnect sync is still in effect until reboot.

## Verdict
Pass on stability (nothing broke), fail on the hypothesis: forcing ICC sync alone does not lower
awake idle power. Not yet tested: s2idle with ICC synced, which is where a DDR vote matters most.
