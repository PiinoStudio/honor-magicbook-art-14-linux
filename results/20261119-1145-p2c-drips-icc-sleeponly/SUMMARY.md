# Run summary: p2c-drips-icc-sleeponly
kernel: 7.2.11-300.fc45.aarch64
module params: drips_mode=1 hold_usbc_ldos=Y pcie_bridge_d3=0 pcie_icc_tweak=Y sync_all_suppliers=0 
EC_MSTANDBY=0 STOP_AUDIO_USER=

wall clock delta: 728 s   (unreliable if the RTC does not work)
apss sleep delta (AOSS ticks): 0 s
energy_now: 30816000 -> 29828000 (uWh), delta 988000 uWh
average power (whole window incl. awake parts): 4.886 W over 728 s

## Sleep-only power (use this number)
kernel: Timekeeping suspended for 662.656 s
energy right before freeze -> right after resume: 30762000 -> 29882000 uWh over 666.0 s
sleep-only power: 4.757 W
cross-check freeze -> last post sample (696.9 s, incl. ~31 s awake): 4.825 W

| stat | count before | count after | accumulated delta (s) |
|---|---|---|---|
| apss | 123 | 123 | 0 |
| cxsd | 0 | 0 | 0 |
| aosd | 0 | 0 | 0 |
| ddr | 0 | 0 | 0 |
| adsp | 170258 | 177010 | 715 |
| cdsp | ? | ? | 0 |

Errors in kernel log during run:
[ 1662.954546] PM: Triggering wakeup from IRQ 125
[ 1663.521357] ath12k_wifi7_pci 0004:01:00.0: qmi dma allocation failed (7274496 B type 1), will try later with small size
[ 1680.301191] wlP4p1s0: aborting authentication with <ap-mac> by local choice (Reason: 3=DEAUTH_LEAVING)
