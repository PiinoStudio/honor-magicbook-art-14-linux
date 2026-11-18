# Awake idle with scmi-cpufreq loaded (2026-11-18, Claude Code via SSH)

Baseline: `results/20261118-2326-cpufreq-before` (same boot, directly before).
Background on the missing driver: `results/20261118-2330-cpufreq-probe/notes.md`.

## Conditions
- Boot after the owner's Fedora offline update (23:18), kernel `7.2.11-300.fc45.aarch64`.
- Battery only (`Discharging`), **brightness 2/255** (set by the owner to reduce the display share;
  not comparable in absolute terms with phase 1a at 52/255). Screen on.
- Interconnects not synced (61 INT_MAX nodes in both runs).
- Both 180 s runs under `systemd-inhibit --what=idle:sleep`, started detached on the Honor, no input.
  GNOME showed an "about to suspend" notice during the second run; the block inhibitor held, no
  suspend happened.
- Between runs: `modprobe scmi-cpufreq` (rc 0), with owner approval. Not persistent (reboot reverts).

## Result
| run | cpufreq | power_now avg | energy_now delta |
|---|---|---|---|
| cpufreq-before | none (clusters at 3.42 / 4.0 / 4.0 GHz) | 9.629 W | 9.940 W |
| cpufreq-scmi | scmi, schedutil | **6.405 W** | **6.380 W** |

**-3.2 W (about -33 %)** awake idle, both metrics agree.

## cpufreq state (`cf-modprobe.txt`)
- Three policies: `policy0` (cpu0-3), `policy4` (cpu4-7), `policy8` (cpu8-11), driver `scmi`,
  governor `schedutil`, 710.4 MHz - 3417.6 MHz, boost OPP 4012.8 MHz on policy4/8.
- `time_in_state` over the run: policy4 and policy8 spent ~97 % at 710.4 MHz; policy0 ~97 % at
  998.4 MHz (the EM marks 710.4 and 806.4 MHz as inefficient for cluster 0, so schedutil skips them).
- `dmesg` after modprobe: only EM lines (`OPP ... is inefficient`, `created perf domain`), no errors.

## Post-run checks (via SSH)
- Display `dpms=On`, `bl_power=0`; Wi-Fi connected; audio card present; `lsusb` 6 entries.
- No new kernel errors or warnings after the modprobe.
- Temperatures 30-36 °C.
- Not checked: keyboard/touchpad, audio playback, flicker (owner).

## Open
- Make persistent: `/etc/modules-load.d/scmi-cpufreq.conf` (needs owner approval), then confirm
  after reboot and with an s2idle run that suspend/resume and hibernate still work.
- Root cause of the missing modalias (Fedora/kernel packaging) is not yet investigated.
- Remaining ~6.4 W at 2/255 is still high; next candidates: ICC sync at low brightness, gcc/gpucc.
