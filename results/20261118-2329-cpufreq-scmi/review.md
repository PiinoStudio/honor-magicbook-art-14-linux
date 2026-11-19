# Review: `scmi-cpufreq` awake idle — `20261118-2326-cpufreq-before` + `20261118-2329-cpufreq-scmi` (+ `20261118-2330-cpufreq-probe`)

Reviewer: Antigravity (2026-11-19)

## Raw-data verification
- Checked `power_now.txt`, `snapshot.txt`, `SUMMARY.md`, `cf-modprobe.txt`, `cf-dmesg-after-*.txt`, and `notes.md` across all three directories.
- Both runs were on the same boot (uptime `433.2 s` -> `622.5 s`, fresh boot after Fedora offline update), battery only (`Discharging`), same brightness (`2/255`), same unsynced interconnects (`61` `INT_MAX` nodes), 90 samples each, 0 zero-samples.
- Recomputed statistics from `power_now.txt`:
  - `cpufreq-before`: mean `-9.629 W`, median `-9.652 W`, stdev `0.236 W`, range `-10.176 .. -9.046 W`, wall span `182 s`, `energy_now` delta `497 mWh` (`9.831 W` over 182 s; `SUMMARY.md` reports `9.940 W` over nominal 180 s).
  - `cpufreq-scmi`: mean `-6.405 W`, median `-6.216 W`, stdev `0.527 W`, range `-8.694 .. -6.080 W`, wall span `183 s`, `energy_now` delta `319 mWh` (`6.275 W` over 183 s; `SUMMARY.md` reports `6.380 W` over nominal 180 s).
- `cf-modprobe.txt` confirms `policy0/4/8` registered on `scmi` with `schedutil`, and `time_in_state` shows ~97 % residency at the lowest efficient OPP (`998.4 MHz` on cluster 0, `710.4 MHz` on clusters 1 and 2).

## Is the comparison sound?
**Yes — the effect is clearly real (~3.2–3.5 W reduction, >10x measurement noise), with two important caveats visible in the raw data:**

1. **Settling transient in `cpufreq-scmi` actually *underestimates* the saving:**
   - Looking at `power_now.txt` sample by sample, `cpufreq-scmi` started right after `modprobe` at `-8.694 W` (`t+0s`) and decayed smoothly over ~45 s (`t+15s: -7.205 W`, `t+31s: -6.495 W`, `t+45s: -6.282 W`) to a flat steady state of **`-6.10 W` (`-6.080 .. -6.123 W`)** in the final minute. This matches the `qcom-battmgr` fuel-gauge averaging time constant.
   - True steady-state awake idle power at `2/255` with `scmi-cpufreq` is ~**6.1 W** (not 6.4 W), so the real steady-state drop on that boot was ~**3.5 W** (`9.63 -> 6.11 W`).
2. **Baseline (`9.63 W` at `2/255`) was 1.3 W higher than `p1a-before` (`8.33 W` at `52/255`):**
   - `cpufreq-before` ran at uptime `433 s` (~7 min after a major Fedora offline update reboot), whereas `p1a-before` ran at uptime `3623 s` (~1 h uptime). Background post-boot / post-update activity (e.g. `dnf`/`tracker`/GNOME indexing, or transient CPU activity — `snapshot.txt` shows 7 CPU power domains active at snapshot time vs 4 in `p1a-before`) likely raised the `cpufreq-before` baseline.
   - Because `cpufreq-scmi` ran immediately after `cpufreq-before` on the same boot, part of the 9.63 -> 6.11 W drop could theoretically include post-boot settling — **except** that the sharp exponential drop starting *at the exact second of `modprobe scmi-cpufreq`* (`-8.694 W` -> `-6.282 W` in 45 s) proves the overwhelming majority of the drop is directly caused by `scmi-cpufreq`.
   - Still, quoting an exact "−3.2 W" or "9.6 W -> 6.4 W" figure publicly without a settled-boot repeat (or A/B/A check) risks overstating the baseline if 9.6 W had ~1 W of post-update noise.
3. **Minor `sleep_diag.sh` bugs** (same as Phase 1a): `max 0.000 W` awk bug on negative values, and `energy_now` divided by `180` instead of actual `182–183 s`. Also GNOME popped up an "about to suspend" notification during run 2 (inhibitor held, no suspend).

## What is missing before this may go into the README?
1. **Repeat A/B measurement on a settled boot** (uptime ≥ 15–20 min, no recent offline update, plus wait 60 s after `modprobe` before starting the 180 s window so the fuel-gauge filter settles) — or compare two clean boots (with vs. without `scmi-cpufreq.conf`) at identical uptime and brightness `2/255` — to publish a clean, reproducible W delta.
2. **Functional & performance verification under `scmi-cpufreq`:**
   - Confirm under load (e.g. `cpufreq_probe.py` or a short benchmark) that clusters actually scale *up* to 3.42 / 4.0 GHz (and boost works, noting `4012800` had `0` residency in idle as expected) — no stuck-at-min-freq regression.
   - Confirm physical owner checks (audio playback, display flicker, keyboard/touchpad, gaming/normal desktop responsiveness).
3. **Explain the workaround scope clearly:** Document that `/etc/modules-load.d/scmi-cpufreq.conf` is a workaround for Fedora/distro kernels shipping `CONFIG_ARM_SCMI_CPUFREQ=m` without upstream SCMI bus modalias/device-precreation patches, and that it lowers *awake* idle power (distinct from `s2idle` collapse).

## Verdict
**Effect verified (real, large awake idle win).** Hold off on README numbers until one settled-boot repeat (with 60 s fuel-gauge settle time) and an upward-scaling check confirm the exact delta and absence of regressions.
