# cpufreq A/B on a settled boot (2026-11-19, Claude Code via SSH)

Repeat requested in Antigravity's review of `20261118-2329-cpufreq-scmi`. Covers
`20261119-1016-ab-A1-schedutil`, `20261119-1020-ab-B-performance-boost`, `20261119-1024-ab-A2-schedutil`.

## Conditions
- Same boot, uptime 2695-3184 s (> 40 min). Battery, brightness 2/255, screen on, no input.
  `scmi-cpufreq` loaded via modules-load.d. 58 interconnect nodes at INT_MAX (not synced).
- A = `schedutil`, boost 0 (current default). B = `performance` + boost 1, i.e. clusters at
  3417.6 / 4012.8 / 4012.8 MHz, which reproduces the "no cpufreq" state measured on 2026-11-18.
  60 s wait after each switch. State per phase in `ab-state.txt`. 180 s per run (last time; the default is now 120 s).

## Result (power_now average after the first 60 s; fuel gauge settles in ~45 s)
| run | governor | after 60 s | energy_now (real duration) |
|---|---|---|---|
| A1 | schedutil | 6.326 W | 6.075 W |
| B | performance + boost | 10.042 W | 9.592 W |
| A2 | schedutil | 6.335 W | 6.386 W |

**cpufreq scaling saves ~3.7 W awake idle** at 2/255 (B vs. mean of A1/A2). A1 and A2 agree within
0.01 W, so the effect is stable on a settled boot. energy_now resolution is 1000 uWh, hence the noisier
second column.

## Anomaly: frequency requests sometimes not applied
`cpufreq_probe.py` under load (1 s busy loop per CPU, `ab-load-probe.txt` and the follow-up checks):
- Most runs reach 3.39-3.42 GHz (boost off), as expected.
- Sometimes a cluster stays at its lowest OPP for the whole second: cpu4 712 MHz, cpu8 712 MHz,
  cpu2 1001 MHz (twice in a row), while a sibling in the same cluster measured right after reaches
  3.42 GHz. In the stuck case `scaling_cur_freq` already reports 2188800, i.e. the governor believes
  the request was applied.
- `schedutil/rate_limit_us` = 45, `cpuinfo_transition_latency` = 30 us, so this is not a governor delay.
- Hypothesis (not verified): an SCMI perf level request (fast channel) is occasionally dropped by the
  firmware; schedutil does not resend an unchanged frequency, so the cluster stays low until the
  requested level changes. Relevant for responsiveness, not for idle power.
