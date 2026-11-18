# Standby Test Plan (EL1 first, EL2 later)

Background and reasoning: [`STANDBY_ANALYSIS_2026-11.md`](STANDBY_ANALYSIS_2026-11.md).
Tool: [`power/diag/sleep_diag.sh`](../power/diag/sleep_diag.sh).

## Rules for whoever executes this (human or agent)

1. **Raw data or it didn't happen.** Every phase produces a directory under `results/`.
   Commit it unchanged. Do not delete, trim or paraphrase files in it.
2. **No success claims without numbers.** A phase "passes" only by the criteria written
   below, read from `SUMMARY.md` / `after.txt`. Do not update README or other docs with
   results; write observations into `results/<run>/notes.md` only.
3. **One variable per run.** Change exactly what the phase says, reboot, measure.
4. **Battery only, ≥ 30 min suspended**, lid closed, wake by **opening the lid** (waking with
   a key while the lid is closed lets logind hibernate as soon as the script ends).
   Short runs (2–5 min) are fine for "does it hang / do counters move", not for watts.
5. **If the machine hangs**: hold power 10 s, boot, then save the previous boot's log:
   `journalctl -b -1 -k > results/<run>/journal-prev-boot.txt` and commit it with a
   `notes.md` saying it hung. Do not retry the same phase more than twice.
6. Do not change the DTB, kernel or bootloader in phases 0–5.
7. Keep a hibernate-capable fallback: nothing here touches the hibernate setup.

## Preparation

```bash
sudo dnf install -y i2c-tools
cd ~/honor-magicbook-art-14-linux && git pull
cd power/honor_deep_sleep_fix && make && sudo make install
```

Module options live in `/etc/modprobe.d/honor-sleep.conf`. Each phase below states the
full line to put there. Reboot after every change.

## Phase 0: Inventory (no suspend)

```bash
sudo power/diag/sleep_diag.sh snapshot p0-inventory
sudo power/diag/sleep_diag.sh ec-probe
```

Note in `notes.md`: which DTB/initrd GRUB actually loads, and whether a newer Fedora kernel
than 7.2.11 is installed (`rpm -q kernel`).

## Phase 1: Baseline (current defaults)

```text
options honor_deep_sleep_fix sync_all_suppliers=0 hold_usbc_ldos=1
```
```bash
sudo power/diag/sleep_diag.sh run p1-baseline
```
Expected: `cxsd`/`ddr` count unchanged (blocked by design). Record the W value as baseline.

## Phase 2: Allow DRIPS in s2idle only (`drips_mode=1`)

```text
options honor_deep_sleep_fix sync_all_suppliers=0 drips_mode=1
```
Never use `drips_mode=2` and never `rmmod honor_deep_sleep_fix`: DRIPS from runtime idle
has frozen the SoC before (TrustZone, after the first s2idle).
First a 3-minute run (hang check), then a 30-minute run:
```bash
sudo power/diag/sleep_diag.sh run p2-drips-short
sudo power/diag/sleep_diag.sh run p2-drips
```
Pass: resumes cleanly. Interesting: does `cpuidle s2idle_usage` of the deepest state or
`pm_genpd_summary` show `power-domain-system` off? Any `cxsd`/`aosd`/`ddr` count increase
is a major result (but at EL1 it is not expected).

## Phase 3: Allow the Wi-Fi root port into D3 (`pcie_bridge_d3=1`)

```text
options honor_deep_sleep_fix sync_all_suppliers=0 drips_mode=1 pcie_bridge_d3=1
```
Do **5 short runs + 1 long run**. Pass: no `Timeout waiting for L2 entry`, Wi-Fi works after
resume, `0004:00:00.0 power_state` in `after.txt` was not stuck. Compare W with phase 2.

## Phase 4: Module not loaded at all

Comment out `honor_deep_sleep_fix` in `/etc/modules-load.d/honor-sleep.conf`, reboot.
Note: without the module, runtime-idle DRIPS is not blocked either. If the machine froze in
the past without the module, skip this phase and note it; do a 3-minute run first otherwise.
```bash
sudo power/diag/sleep_diag.sh run p4-no-module
```
This is the "plain kernel" reference for everything else.

## Phase 5: Find the vote holders (no config change, read `after.txt` of phase 2–4)

Fill in `results/p5-holders/notes.md` from the existing snapshots:
- `state_synced` of `100000.clock-controller`, `3d90000.clock-controller`, both interconnects
- `devices_deferred` list
- LPASS `clk_enable_count` values
- PCM substreams not closed
- top consumers in `interconnect_summary` (ebi / llcc_mc / pcie nodes)
- `wakeup_sources` with active_count > 0

Then one A/B run with audio stopped:
```bash
sudo STOP_AUDIO_USER=$USER power/diag/sleep_diag.sh run p5-no-audio
```

## Phase 6: EC modern standby (only if phase 0 `ec-probe` returned bytes, not an error)

Using the best module configuration from phases 2–4:
```bash
sudo power/diag/sleep_diag.sh run p6-ec-off
sudo EC_MSTANDBY=1 power/diag/sleep_diag.sh run p6-ec-on
```
Also note by ear/hand: fan noise, keyboard backlight, chassis temperature after 30 min.

## Phase 7: Newer kernel (≥ 7.3)

Only after phases 0–6 are committed. Requires rebuilding the patched `msm.ko`/`panel-edp.ko`
for the new kernel (the prebuilt modules in `display/fedora45_modules/` are 7.2.11-only).
Repeat phase 4 and the best configuration. v7.3 brings the PCIe root-port D3, geni and LPASS
macro fixes listed in the analysis.

## Phase 8 (later, separate plan): EL2

Do not start before phases 0–7 are evaluated. First check in phase 0 output whether
`serial-getty@hvc0` is active and `/dev/hvc0` exists (DCC lock-up risk at EL2).
