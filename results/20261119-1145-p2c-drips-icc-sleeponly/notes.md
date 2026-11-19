# s2idle with sleep-only measurement (2026-11-19, Claude Code via SSH)

First run of `sleep_diag.sh run` with sleep-only power (`fbf67d4`). Same state as phase 2b:
repo `honor_deep_sleep_fix` (`drips_mode=1 hold_usbc_ldos=Y pcie_bridge_d3=0 pcie_icc_tweak=Y`),
ICC forced synced (0 INT_MAX nodes, still from Antigravity's apply on this boot), governor `ondemand`,
battery, brightness 2/255. `LID_DELAY=30`, lid open the whole time, woken by a key press (IRQ 125).
GNOME had already auto-suspended the machine once before this run (11:38-11:44).

## Result
- Slept **662.7 s** (kernel `Timekeeping suspended`).
- **Sleep-only power: 4.757 W** (energy 30762000 -> 29882000 uWh between the samples right before
  `freeze` and right after resume, 666.0 s). Cross-check including 31 s awake afterwards: 4.825 W.
- The value right after resume is not stale: the post samples continue from it in ~8 mWh steps every
  ~4 s at ~6 W awake, as expected. `power_now` right after resume read -4.93 W (gauge average still
  dominated by the sleep). So the method works.
- `apss`, `cxsd`, `aosd`, `ddr` unchanged (0 delta). `adsp` +6752 entries in ~700 s (~9.6/s).
- Phase 2b's estimate (~4.6 W) is confirmed within ~0.15 W.

## Wi-Fi after resume
Owner noticed Wi-Fi came back late. Journal: resume at epoch ...831, NetworkManager `activated` at
...855, i.e. **~24 s**. dmesg shows a first auth attempt with a randomized MAC at +17 s that was aborted
(`DEAUTH_LEAVING`, local choice), then a successful association at +26 s (kernel time). Likely
NetworkManager scan/MAC-randomization behavior after `ath12k` resume (plus the known
`qmi dma allocation failed ... will try later` retry). Not a hang, but noticeably slow.

## Conclusion
s2idle at EL1 with the current stack costs ~4.76 W, only ~1.4 W below awake idle (~6.2 W). The SoC
never reaches a system-level low-power state (`cxsd`/`ddr` = 0). Further tuning of individual votes
will not change the order of magnitude until CX collapse happens at all.
