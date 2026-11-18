# Handoff: Standby investigation (state 2026-11-18)

For the next agent session (Claude Code on the Mac with SSH to the Honor, and Antigravity).
Read this first, then `docs/STANDBY_ANALYSIS_2026-11.md` and `docs/STANDBY_TEST_PLAN.md`.
Working branch: `claude/peaceful-meitner-0wq9vl`.

## Setup

- Hardware: Honor MagicBook Art 14 (X1E80100), Fedora 45, kernel `7.2.11-300.fc45.aarch64`,
  boots at **EL1** (Gunyah). Windows 11 on the same disk; never touch Windows partitions.
- The owner works from a Mac. Two agents have SSH access to the Honor: Claude Code (local
  session on the Mac) and Antigravity. The Mac repo folder lives inside a larger folder that
  also contains **private files (USB-stick backup, job applications, firmware dumps,
  a separate "bootkit")**. Never read, add or commit those. They are listed in
  `.git/info/exclude` (local only, deliberately not in `.gitignore`).

## Collaboration rules

1. **One owner of the Honor at a time.** Proposed split: Claude Code runs experiments and
   measurements on the Honor; Antigravity prepares the newer kernel (test plan phase 7) and
   reviews results. Hand over explicitly via the owner.
2. **Raw data in `results/`, unchanged.** Observations go into `notes.md` of the run. Only
   redact host/user names and IPs with placeholders.
3. **No success claims without numbers** from `SUMMARY.md`. README/docs are only updated after
   a result has been reviewed by the other agent. (History: a "0.389 W breakthrough" was
   published and had to be retracted.)
4. Never `git add -A` / `git add .`; stage explicit paths only.
5. The git history was rewritten on 2026-11-18 (credentials removed). Old clones must not
   push; re-clone or reset to `origin` first.

## Hard-won knowledge (do not lose)

- **DRIPS (`power-domain-system`, PSCI `0x0200c354`) must never be entered from runtime idle.**
  It froze the SoC (TrustZone) after the first s2idle. The module's governor prevents that.
  Consequence: **never `rmmod honor_deep_sleep_fix`**, and running without the module carries
  the same risk.
- Two mechanisms in genpd: the governor (`power_down_ok`) is only asked for runtime idle; a
  pinned `sd_count` also blocks the s2idle path (`genpd_sync_power_off()`). The old module
  did both, so CXSD was impossible by construction. `drips_mode=1` keeps the governor block but
  allows DRIPS in s2idle (= "system-sleep only", as other X1E projects do). Not yet tested.
- `bridge_d3=0` on the Wi-Fi root port `0004:00:00.0` keeps a DDR vote in suspend;
  `bridge_d3=1` risks `Timeout waiting for L2 entry! LTSSM: 0x11` hangs (seen elsewhere ~4/42).
- `spm_lvl=3` on UFS kills resume (hibern8 exit failure). Keep the default.
- Hibernate (`HibernateMode=shutdown`, `FailureAction=poweroff`, initrd copied to
  `/boot/efi/initrd_native.img`) is the working fallback. Do not break it.
- Forcing `of_genpd_sync_state()` on gcc during suspend with SMMUv3 active (EL2) locked the bus.

## Phase 0 results (`results/20261118-2228-p0-inventory_/`)

- **Interconnects never synced** (`1700000.interconnect`, `interconnect-1`): 61/152 nodes at
  `2147483647`, incl. `ebi` (DDR) and `llcc_mc`. The ICC core keeps boot votes until *all*
  providers sync, so DDR runs at maximum permanently. Prime suspect for 3–8 W. Suspected
  blockers: `modprobe.blacklist=qcrypto` (crypto@1dfa000 never probes), GMU without driver.
  `fw_devlink.sync_state=timeout` did not trigger (no "Forcing sync_state()" in dmesg).
- `gcc`/`gpucc` unsynced too: unused boot-on GDSCs stay on.
- RTC: `qseecom: untested machine, skipping` -> no UEFI vars -> `rtc@6100` deferred.
- LPASS macro clocks `enable_count=5` with all PCM streams closed.
- ADSP ~107 sleep entries/s although `qcom_adsp_pwr_lmts` is loaded.
- EC probe at bus 3 (`i2c@b94000`) 0x76: FW read `00 00 00 00`, thermal read failed.
  Inconclusive; **no writes to the EC** until the protocol is confirmed.
- Installed `honor_deep_sleep_fix` is an older local build (has `s2idle_wake_sec`), not the
  repo version. The repo version adds `drips_mode`, `pcie_bridge_d3`, `pcie_icc_tweak`,
  `hold_usbc_ldos`; it has been compiled on the Honor but not installed.

## Phase 1a (first attempt, `results/20261118-2248-p1a-before`, `...2251-p1a-icc-synced`)

- Awake idle on battery, brightness 52/255: **~8.8–9.0 W** (very high).
- Forcing the interconnect sync **failed**: the script wrote `"1\n"`, but
  `state_synced_store()` accepts only an exact `"1"` (`strcmp`). Fixed in `dd93450`
  (`printf 1`). INT_MAX count stayed at 61, so the second run is just a repeat of the baseline.
- `force_sync_state.sh list` confirms the blockers: interconnects wait on
  `1dfa000.crypto` (qcrypto blacklisted), `gcc`/`gpucc` wait on `3d6a000.gmu` (no driver).
- Installed module source is now in `results/installed-module/`.

## Phase 1a (second attempt, `results/20261118-2307-p1a-before`, `...2310-p1a-icc-synced`)

- Fixed script worked: INT_MAX nodes 61 -> 0, nothing broke over SSH, no new dmesg lines.
- **Power unchanged**: 8.33 W before vs. 8.35 W after (power_now avg). ICC boot votes are not
  the cause of the awake idle draw. DDR still has real votes after sync (`ebi` avg ~1.98 GB/s).
- New lead: **no cpufreq policies exist** (scmi-cpufreq does not register; SCMI logs
  `Failed to add opps_by_lvl ... for NCC - ret:-16`). Also `qcom-iris` says `video hw is power on`
  before its init fails. Details in the run's `notes.md`.
- Not yet reviewed by Antigravity. Open: s2idle with ICC synced.

## cpufreq (`results/20261118-2330-cpufreq-probe/`, read-only)

- `scmi-cpufreq` is built as a module but has no modalias, so it is never loaded. DT and SCMI
  perf domains are fine; `NCC_0..2` sit at perf state 0.
- Measured: cluster 0 fixed at 3.42 GHz, clusters 1/2 fixed at 4.0 GHz (`power/diag/cpufreq_probe.py`).
- Loaded it (owner approved), `results/20261118-2326-cpufreq-before` vs. `...2329-cpufreq-scmi`,
  brightness 2/255: **9.63 W -> 6.41 W awake idle (-3.2 W)**, schedutil keeps all clusters at the
  lowest OPP ~97 % of the time, nothing broke. Not yet reviewed by Antigravity.
- From now on the owner measures at brightness 2/255 to keep the display share small.
- Made persistent: `/etc/modules-load.d/scmi-cpufreq.conf` on the Honor (owner approved). Loads at
  boot. Short s2idle check passed (`results/20261118-2340-cpufreq-s2idle-short`, 2 clean resumes).
- **Hibernate fallback is NOT working** (pre-existing, also in boot -4): logind says "Requested
  hibernate operation is not supported, using regular suspend instead", so `HandleLidSwitch=hibernate`
  silently suspends. Root cause open (see the run's `notes.md`).
- **Next actions:** fix hibernate availability; repeat ICC sync at 2/255; let the lid inhibitor in
  `sleep_diag.sh run` cover the whole run.

## Open questions sent to Antigravity

Answers may be in its chat rather than in the repo; ask the owner:
- where the source of the installed module is (to be saved in `results/installed-module/`),
- why `qcrypto` is blacklisted and why `fw_devlink.sync_state=timeout`, `pcie_port_pm=force`,
  `pcie_aspm.policy=powersupersave` were added,
- origin of `qcom_adsp_pwr_lmts`,
- `srcversion` comparison of installed vs. repo module.

## Next steps (proposal, in order)

1. Evaluate phase 1a. If forcing ICC sync lowers power without breakage: find the real blocker
   (`force_sync_state.sh list` shows unprobed consumers), fix it at the root (e.g. why qcrypto
   is blacklisted) or make the forced sync a boot-time unit; then a 30 min s2idle run.
2. Same for `gcc`/`gpucc` separately (riskier: GDSCs switch off), one at a time, awake first.
3. Install the repo module, then phases 1-3 of the test plan (`drips_mode=1`, then
   `pcie_bridge_d3=1`), each with a 3 min hang check before a 30 min run.
4. Phase 5/6 (vote holders, EC only after protocol clarified).
5. Phase 7 (Antigravity in parallel): kernel >= 7.3 with the 120 Hz display patch rebased;
   brings PCIe root-port D3, GENI, LPASS macro fixes and (7.3/7.4) the QSEECOM allowlist for
   this machine, which should fix the RTC. Consider the mainline DTS
   `x1e80100-honor-magicbook-art-14.dts` as the new base.
6. EL2 only after that (see analysis section 5: DCC console, DSP attach, timer parking,
   CL5/SS1, aoss_cxsd_only). Expectation: EL1 at best ~1–2 W; < 0.3 W has only been reached at EL2.
