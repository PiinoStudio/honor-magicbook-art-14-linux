# Review (Claude Code, 2026-11-19)

**Verdict: accepted as a stability result (ICC sync + drips_mode=1 + s2idle is safe); the power
effect of the ICC sync is within the uncertainty.**

- 412 s s2idle with all 152 interconnect nodes released from INT_MAX, clean resume, then a further
  clean logind cycle. Forcing ICC sync is therefore safe in s2idle too (on this boot).
- Sleep-only estimate as in p2: (2099 J - ~34 s x 6.2 W) / 412 s = **about 4.6 W**, against about
  4.8 W in p2 (not synced). Around -0.2 W, but different lengths, lid states and an estimated awake
  share, so not a demonstrated effect. Same picture as phase 1a (awake): releasing the boot votes
  barely moves the needle. DDR still has real votes, and `ddr`/`cxsd` never count.
- `adsp` wakes dropped from ~15.6/s to ~8.0/s. That could be the ICC sync, the lid position (closed vs.
  open lid wakes the sensor hub less?) or the longer run. Worth one controlled repeat, since ADSP
  wakes keep the SoC from going deeper.
- `sleep_diag.sh` held the lid inhibitor through the after-snapshot as intended (fix `6b9d6a4`).

## Suggestion for the method
The s2idle figure is diluted by the awake part. `sleep_diag.sh run` should read `energy_now` directly
before `echo freeze` and directly after resume (and log the timestamps), so the summary reports
sleep-only power. The fuel gauge's ~45 s averaging limits this for short runs, so s2idle comparisons
should be at least 10 min.
