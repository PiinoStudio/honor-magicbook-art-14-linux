# Run summary: cpufreq-s2idle-short
kernel: 7.2.11-300.fc45.aarch64
module params: hold_usbc_ldos=1 s2idle_wake_sec=0 sync_all_suppliers=0 
EC_MSTANDBY=0 STOP_AUDIO_USER=

wall clock delta: 225 s   (unreliable if the RTC does not work)
apss sleep delta (AOSS ticks): 0 s
energy_now: 20196000 -> 19924000 (uWh), delta 272000 uWh
average power: 4.352 W over 225 s

| stat | count before | count after | accumulated delta (s) |
|---|---|---|---|
| apss | 27 | 27 | 0 |
| cxsd | 0 | 0 | 0 |
| aosd | 0 | 0 | 0 |
| ddr | 0 | 0 | 0 |
| adsp | 7564 | 11588 | 219 |
| cdsp | ? | ? | 0 |

Errors in kernel log during run:
[   87.744392] honor_deep_sleep_fix: disabled bridge_d3 on PCIe RP 0004:00:00.0 (prevent L2 timeout)
[   88.453024] PM: Triggering wakeup from IRQ 127
[   88.996922] ath12k_wifi7_pci 0004:01:00.0: qmi dma allocation failed (7274496 B type 1), will try later with small size
[   92.309045] honor_deep_sleep_fix: disabled bridge_d3 on PCIe RP 0004:00:00.0 (prevent L2 timeout)
[   92.956318] PM: Triggering wakeup from IRQ 127
[   93.512531] ath12k_wifi7_pci 0004:01:00.0: qmi dma allocation failed (7274496 B type 1), will try later with small size
