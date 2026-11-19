# Review (Claude Code, 2026-11-19)

**Verdict: accepted as a workaround for the stuck-frequency anomaly; the idle-power claim is not
supported.**

## What holds
- Governor comparison on one boot: schedutil got stuck in 5 of 9 cluster probes (here plus mine),
  ondemand in 0 of 9, userspace stepping in 0. The `policy->cur` caching explanation (the governor
  believes the level was set, so an unchanged target is never resent) fits my observation that
  `scaling_cur_freq` showed 2.19 GHz while the core ran at 712 MHz. Pointing at the fast-switch path
  is plausible, not proven: the sample is small and only the ondemand probe is saved as a raw file.
  The schedutil and userspace trials exist only as text in `notes.md`.
- The audit findings (iris power domain off, USB controllers `active` with suspended root hubs, LPASS
  macro clocks held) are useful leads for the awake idle draw.

## What does not hold
- "ondemand idles slightly lower than schedutil (6.19 vs. 6.33 W)": this is one 120 s run, 30 min
  later on the same boot, against two schedutil runs. `power_now` still drifts inside the run
  (-6.41 at the start, -6.15 in the middle, -6.28 at the end), and A1/A2 already differed by 0.01 W
  under identical settings. A 0.14 W difference needs an interleaved A/B (schedutil / ondemand /
  schedutil) before it counts. The safe claim is that ondemand does not cost idle power.
- The 4.0 GHz in the ondemand probes was not a default. My A/B left `scaling_max_freq` of policy4/8
  at 4012800 after switching boost back off. After the reboot, `boost=0` and `scaling_max_freq=3417600`,
  so ondemand now tops out at 3.42 GHz on all clusters. My mistake, noted here so nobody reads
  "ondemand reaches 4.0 GHz" as a governor property.

## Configuration left on the Honor (checked read-only, 11:34)
- `cpufreq-ondemand.service` (oneshot, `After=tuned.service`) is enabled, and all three policies
  are on `ondemand`. tuned is active (`balanced-battery`) and owns the governor setting: a profile
  switch, e.g. on AC plug, can reset it to schedutil after the oneshot service has run. More robust:
  a tuned profile override (`[cpu] governor=ondemand`) instead of a service racing tuned. Please verify
  once with AC plugged and unplugged.
