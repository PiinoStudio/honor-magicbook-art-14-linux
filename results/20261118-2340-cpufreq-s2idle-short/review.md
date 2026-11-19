# Review: Short `s2idle` check with persistent `scmi-cpufreq` — `20261118-2340-cpufreq-s2idle-short`

Reviewer: Antigravity (2026-11-19)

## Raw-data verification
- Checked `SUMMARY.md`, `before.txt`, `after.txt`, `dmesg.txt`, `journal-kernel.txt`, `notes.txt`, and `notes.md`.
- Persistent `scmi-cpufreq` loaded cleanly at boot, and **both** `s2idle` cycles resumed cleanly (`cpuidle state1 cpu-sleep-0 s2idle_usage: 0 -> 2`, `PM: suspend exit` logged twice with zero fatal errors).
- `qcom_stats`: `apss` `27 -> 27` (`0 s` delta), `cxsd`/`aosd`/`ddr` all `0 -> 0` (expected because the installed module still pins `power-domain-system` `sd_count`), `adsp` `7564 -> 11588` (`+4024` entries, `219 s` accumulated).

## Findings & observations from the raw logs
1. **Why the first suspend woke after `13.964 s` (`IRQ 127`):**
   - `before.txt` was taken at `23:40:38` (`uptime 56.67 s`), `LID_DELAY=30` caused `echo freeze` at `23:41:10`, and the owner closed the lid ~14 s *after* `freeze` started.
   - Because `switch-lid` (`msmgpio 92`, `IRQ 127`) has `wakeup-source;` without `wakeup-event-action` (configured `EDGE_BOTH` to avoid the TLMM polarity-switch glitch), closing the lid *after* entering `s2idle` fires `IRQ 127` and wakes the machine!
   - Then `sleep_diag.sh` released its `systemd-inhibit` lock immediately after `freeze` returned, so `systemd-logind` saw the lid closed, tried `hibernate`, logged `Requested hibernate operation is not supported, using regular suspend instead`, and ran a second `s2idle` (`172.745 s`) woken cleanly by lid-open (`IRQ 127`).
2. **Power number (`4.352 W`) is NOT a valid `s2idle` figure** (correctly flagged in `notes.md`):
   - The `225 s` window contains ~38 s awake (including boot-settling draw of `-10.6 W` in `before.txt` and two full resume/display link-train/BT firmware reload sequences) plus `186.7 s` (`13.96 + 172.75 s`) actually in `Timekeeping suspended`.
   - Note that `after.txt` (taken 5 s after waking from the 172.7 s sleep) still shows `power_now=-4.224 W` (fuel-gauge RC filter), consistent with ~3.5–4.0 W during `s2idle` with `drips_mode=0` and unsynced interconnects.
3. **Additional raw log details worth tracking for later phases:**
   - All 4 USB HS-PHYs logged `port-X HS-PHY not in L2` on both suspends (`a800000.usb`, `a600000.usb`, `a400000.usb` port-1 & port-2).
   - `i2c_hid_of 2-005d: device returned incorrect report (255 vs 3 expected)` on both suspend and resume (touchpad).
   - `ath12k_wifi7_pci 0004:01:00.0: qmi dma allocation failed (7274496 B type 1), will try later with small size` and `hwmon hwmon68: PM: parent phy0 should not be sleeping` on both resumes (non-fatal, Wi-Fi recovered).
   - Note: `dmesg.txt` / `journal-kernel.txt` line 15 contains a Wi-Fi AP BSSID MAC address (`wlP4p1s0: deauthenticating from ...`); left untouched per rule 2, flag if MAC redaction is desired in future scripts.
4. **Script fix confirmed needed in `sleep_diag.sh run`:** Hold `systemd-inhibit --what=handle-lid-switch` across the entire `run` (including the 5 s post-resume settle), and instruct the user to close the lid *before* `LID_DELAY` expires so lid-close does not trigger an `EDGE_BOTH` wake.

## Verdict
**Reviewed and accepted** as a pass for `scmi-cpufreq` `s2idle` resume stability and as the trigger that exposed the pre-existing SELinux hibernate block and the `sleep_diag.sh` inhibitor bug. Not a valid standby watt measurement.
