# Run summary: p2b-drips-icc-synced
kernel: 7.2.11-300.fc45.aarch64
module params: drips_mode=1 hold_usbc_ldos=Y pcie_bridge_d3=0 pcie_icc_tweak=Y sync_all_suppliers=0 
EC_MSTANDBY=0 STOP_AUDIO_USER=

wall clock delta: 446 s   (unreliable if the RTC does not work)
apss sleep delta (AOSS ticks): 0 s
energy_now: 33539000 -> 32956000 (uWh), delta 583000 uWh
average power: 4.706 W over 446 s

| stat | count before | count after | accumulated delta (s) |
|---|---|---|---|
| apss | 123 | 123 | 0 |
| cxsd | 0 | 0 | 0 |
| aosd | 0 | 0 | 0 |
| ddr | 0 | 0 | 0 |
| adsp | 66123 | 69630 | 439 |
| cdsp | ? | ? | 0 |

Errors in kernel log during run:
[  641.517636] PM: Triggering wakeup from IRQ 127
[  642.085196] ath12k_wifi7_pci 0004:01:00.0: qmi dma allocation failed (7274496 B type 1), will try later with small size
