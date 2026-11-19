# Review: Phase 1a (second attempt) — `20261118-2307-p1a-before` + `20261118-2310-p1a-icc-synced`

Reviewer: Antigravity (2026-11-19)

## Raw-data verification
- Checked `power_now.txt`, `snapshot.txt`, `SUMMARY.md`, `sync-list.txt`, `sync-apply.txt`, and `dmesg-after-*.txt` in both folders.
- Both runs were on battery (`status=Discharging`, AC/USB/WLS `online=0`), same boot (uptime `3623.9 s` -> `3814.4 s`), same brightness (`52/255`), `dpms=On`, `bl_power=0`, 90 samples each, 0 zero-samples.
- Recomputed statistics from `power_now.txt`:
  - `p1a-before`: mean `-8.329 W`, median `-8.259 W`, stdev `0.254 W`, range `-8.960 .. -7.985 W`, wall span `182 s`.
  - `p1a-icc-synced`: mean `-8.350 W`, median `-8.377 W`, stdev `0.181 W`, range `-8.754 .. -7.945 W`, wall span `182 s`.
- `snapshot.txt` confirms `INT_MAX` nodes dropped `61 -> 0` and real votes remained on `ebi@interconnect-1` (`avg 1984020`, `peak 2188000`), `llcc_mc@interconnect-1` (`avg 1984020`, `peak 2188000`), and `qns_llcc@26400000.interconnect` (`avg 1984020`, `peak 4800000`) — held by `ae00000.display-subsystem` (`1984020 / 800000`) and `1c08000.pcie` (`0 / 1969000`).

## Findings & methodological notes
1. **Conclusion is sound for awake idle with screen on:** Forcing `state_synced=1` on `1700000.interconnect` and `interconnect-1` dropped all 61 `INT_MAX` boot votes to 0 with no kernel errors and no measurable change in awake idle power (`8.33 W` vs `8.35 W`, well within run-to-run noise).
2. **Two minor measurement bugs in `sleep_diag.sh` (affecting `SUMMARY.md` only, not raw files):**
   - `max 0.000 W` in `SUMMARY.md` is a bug: `power_now` is negative on `qcom-battmgr-bat` while discharging, and `if($2>max)max=$2` initializes `max` to `0` instead of checking `max==""`. Actual max values were `-7.985 W` and `-7.945 W`.
   - `energy_now delta` divides by nominal `secs=180`, while the 90x `sleep 2` loop took `182 s` wall time (plus ~2 s around the loop), inflating `energy_now`-derived W by ~1–2 % relative to `power_now`.
3. **Confounder noted properly in `notes.md`:** Both runs occurred *without* `scmi-cpufreq` loaded (clusters pinned at 3.42 / 4.0 / 4.0 GHz) and at brightness `52/255`. Repeating awake ICC sync at `2/255` *with* `scmi-cpufreq` loaded (and especially testing `s2idle` with ICC synced) is still warranted because display/CPU draw may mask a smaller DDR/NoC saving, and `ae00000.display-subsystem`'s `1.98 GB/s` vote drops only when the display suspends.
4. **Physical checks still open:** Display flicker, audio playback, keyboard, and touchpad were not physically checked after `apply-icc` (only sysfs/SSH checks).

## Verdict
**Reviewed and accepted** as a valid negative result for awake idle power at `52/255` (without `scmi-cpufreq`). Not README-ready as a standalone feature; keep as diagnostic baseline.
