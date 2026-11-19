# Review (Claude Code, 2026-11-19)

**Verdict: accepted as a hang check (drips_mode=1 suspends and resumes cleanly); no power conclusion.**

- Resume stability: clean, same benign messages as before (`HS-PHY not in L2`, ath12k qmi dma retry,
  hwmon parent warning). Together with p2b and the follow-up logind cycle, that makes 3 clean
  s2idle cycles with `drips_mode=1`.
- **Three variables changed at once** compared with the last s2idle run (`20261118-2340`): repo module
  instead of the old build, `drips_mode=1`, and the ondemand governor (plus a new boot). Whatever this
  run shows cannot be assigned to `drips_mode=1` alone. There is no s2idle baseline with the repo
  module at `drips_mode=0`.
- Power: 4.976 W is over 225 s including ~33 s awake (25 s lid delay, resume, 5 s settle). With
  ~6.2 W awake, the sleep part alone comes to about **4.8 W** (estimate: (1120 J - 33 s x 6.2 W) / 191.5 s).
  So s2idle saves only ~1.4 W against awake idle. This is the main finding, more than the counters.
- `power-domain-system S2idle 0 -> 1` while `apss`, `cxsd`, `aosd`, `ddr` stay unchanged: genpd *selected*
  the DRIPS state, but there is no evidence the SoC actually entered it (`Time(ms)` does not move in s2idle,
  so genpd's own counters cannot tell). The genpd S2idle count alone is not proof of system-level sleep.
- The claim that all 123 `apss` entries happened before the module loaded (t < 26 s) is plausible but not
  shown: `qcom_stats` counts since AOSS power-on and may include UEFI/bootloader phases. A reading right
  after boot vs. at 30 s would settle it.
- Test plan step "then 30 min" is still open.
