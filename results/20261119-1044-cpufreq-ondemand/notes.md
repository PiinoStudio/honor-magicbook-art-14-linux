# SCMI `schedutil` vs `userspace`/`ondemand` check + awake idle audit (2026-11-19, Antigravity via SSH)

## Setup
- Same settled boot as `20261119-1016..1024-ab-*` (uptime `4344 s` at end of run).
- Battery only (`Discharging`), brightness `2/255`, screen on, interconnects not synced (`58` `INT_MAX` nodes).
- Governor switched temporarily to `ondemand` for this 120 s run (15 s pre-settle + 120 s measurement), then restored to `schedutil`.
- Also installed the repo build of `honor_deep_sleep_fix.ko` to `/lib/modules/7.2.11-300.fc45.aarch64/extra/` (`make install && depmod -a`) without unloading the running module (takes effect on next reboot).

## SCMI frequency scaling anomaly (isolated)
Tested `cpufreq_probe.py` across governors on the same boot (`dmesg` confirms `Enabling SCMI Quirk [quirk_perf_level_get_fc_force]`):

1. **`schedutil` (`scmi_cpufreq_fast_switch()` atomic path) — 3 trials:**
   - Trial 1: `cpu0: 3420 MHz`, `cpu4: 3420 MHz`, `cpu8: 1001 MHz`
   - Trial 2: `cpu0: 3409 MHz`, `cpu4: 713 MHz`, `cpu8: 712 MHz`
   - Trial 3: `cpu0: 3406 MHz`, `cpu4: 712 MHz`, `cpu8: 712 MHz`
2. **`userspace` (`target_index` non-atomic path):**
   - Stepped OPPs on `policy4`/`policy8`: `1920000` -> `1922/1922 MHz`, `2976000` -> `2978/2978 MHz`, `3206400` -> `3209/3208 MHz`, `3417600` -> `3419/3419 MHz`.
   - Direct jump `710400 -> 3417600`: `cpu4: 3420 MHz`, `cpu8: 3419 MHz`.
   - Note: when `userspace` wrote `3417600` immediately after `schedutil` Trial 3 (where `policy->cur` was already cached at `3417600` despite hardware being at `712 MHz`), `__cpufreq_driver_target` skipped the driver call and `cpu4`/`cpu8` remained at `712 MHz`.
3. **`ondemand` (`target_index` non-atomic path, no `fast_switch`) — 3 trials:**
   - Trial 1: `cpu0: 3418 MHz`, `cpu4: 4007 MHz`, `cpu8: 3984 MHz`
   - Trial 2: `cpu0: 3414 MHz`, `cpu4: 4000 MHz`, `cpu8: 3998 MHz`
   - Post-idle probe (`ondemand-load-probe.txt`): `cpu0: 3417 MHz`, `cpu4: 4001 MHz`, `cpu8: 4005 MHz`

Conclusion: The stuck-at-712-MHz anomaly is specific to `schedutil`'s `fast_switch` path on clusters 1 & 2 (`policy4`/`policy8`). `ondemand` (using `target_index`) scales all 3 clusters to full speed (including 4.0 GHz boost) on every single trial.

## Awake idle power under `ondemand` (2/255, 120 s)
- `power_now`: avg `-6.243 W`, min `-6.517 W`, max `-6.146 W` (60 samples).
- `power_now after 60 s`: **`-6.188 W`** (30 samples) — slightly lower than `schedutil` (`-6.326 / -6.335 W` in `20261119-1016..1024-ab-*`).
- `energy_now` delta: `210000 uWh` over `123.0 s` -> **`6.145 W`**.

## Additional 6.3 W awake-idle audit findings (read-only)
- `qcom-iris` (`vcodec0_core` / `mvxc`): **OFF** in `pm_genpd_summary` (not holding power despite the missing `qcvss8380.mbn` init message).
- **USB runtime PM:** All 6 root hubs (`usb1`..`usb6`) show `ctrl=auto, status=suspended`, yet all 3 xHCI hosts (`xhci-hcd.{1,2,3}.auto`) and all 3 `dwc3-qcom` parents (`a400000.usb`, `a600000.usb`, `a800000.usb`) remain `status=active`, keeping all 10 `gcc_usb*_gdsc` domains `on` (`sec`/`prim`/`mp` at perf state `256`).
- **LPASS clocks:** `LPASS_HW_MACRO` and `LPASS_HW_DCODEC` remain at `enable_count = 5..6` while idle with all PCM substreams closed (patched `snd-soc-lpass-*-macro.ko` from Nov 3 are still installed on disk).
