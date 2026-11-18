# Standby Analysis (November 2026): What We Missed

This document reviews the repository's power-management setup against what other
Snapdragon X Elite (X1E80100, "Hamoa") Linux projects have published up to November 2026.
It replaces nothing yet: every point below is a **hypothesis until measured** with
[`STANDBY_TEST_PLAN.md`](STANDBY_TEST_PLAN.md).

## TL;DR

1. `honor_deep_sleep_fix.ko` itself makes CXSD impossible (it pins `power-domain-system` on).
2. The module keeps the Wi-Fi root port in D0 (`bridge_d3 = 0`), which keeps a DDR vote alive.
3. The Honor embedded controller (I2C5 `0x76`) is not described in our DTB and never gets a
   modern-standby notification.
4. 3–8 W in s2idle at EL1 is far above other X1E machines (1.0–2.2 W at EL1), so something
   beyond "Gunyah" keeps the SoC busy.
5. Our EL2 failures match pitfalls other projects solved (DCC console, DSP attach, timer
   parking, CL5/SS1 handling, LPASS votes). Other X1E devices reach CXSD + DDR at EL2
   at 0.15–0.28 W.

## 1. `block_drips`: the module forbids the state we are trying to reach

`honor_setup_system_sleep_only()` installs a governor on `power-domain-system` whose
`power_down_ok()` always returns `false`, and additionally increments `sd_count`.

- The domain-idle state of `power-domain-system` is DRIPS (`0x0200c354`), the only path to
  CX/DDR collapse.
- `rpmh-rsc` (`17500000.rsc`, `power-domains = <&system_pd>`) flushes the RPMh sleep/wake
  votes to the AOSS when that domain powers off. If it never powers off, the AOSS never
  receives sleep sets, so `cxsd`/`ddr` stay at `0` regardless of EL1/EL2.

Therefore the EL1 conclusion in `DEEP_SLEEP_BREAKTHROUGH.md` ("Gunyah prevents collapse") is
**confounded** for every test that ran with this module loaded. (Independent reports do agree
that EL1 does not reach CXSD on X1E, but our own data cannot show it.)

Now switchable: `options honor_deep_sleep_fix block_drips=0`.

## 2. `bridge_d3 = 0` keeps a DDR vote through suspend

`honor_enable_pcie_bridge_d3()` sets `bridge_d3 = 0` on `0004:00:00.0` (Wi-Fi). With the
port in D0, `pcie-qcom` keeps its `pcie-mem` interconnect vote during suspend, so DDR cannot
enter low-power mode. CXSD-capable setups do the opposite:

- mainline `d4c79b63d82d` "PCI: Allow D3 for native hotplug-capable Root Ports" (v7.3-rc1),
- or a tiny module that sets `bridge_d3 = 1` (`wifi_port_d3`, used on the Lenovo Slim 5x).

Known trade-off: the Surface Laptop 7 project sees occasional hangs with
`Timeout waiting for L2 entry! LTSSM: 0x11` when the port is allowed into D3cold
(about 4 in 42 suspends); disabling D3cold costs ~0.5 W. This is the same L2 timeout we saw.

Now switchable: `options honor_deep_sleep_fix pcie_bridge_d3=1` (`-1` = leave kernel default).

## 3. Missing embedded controller

The MagicBook Art 14 has an EC at **I2C5 (`i2c@b94000`), address `0x76`, interrupt TLMM GPIO 66**
(`honor,magicbook-art-14-ec` in the [vamanea/linux-magicbook](https://github.com/vamanea/linux-magicbook)
kernel; not present in our DTB nor in the mainline DTS). The Qualcomm reference EC driver
`drivers/platform/arm64/qcom-hamoa-ec.c` sends `EC_MODERN_STANDBY_CMD 0x23` with `0x01`
(enter) on suspend and `0x00` (exit) on resume, plus fan/thermal control.

Whether the Honor EC speaks exactly this protocol is **unverified**; `sleep_diag.sh ec-probe`
does a read-only firmware-version read first. I2C5 is already enabled in our DTB (it carries
the eUSB redrivers), so no DT change is needed for the probe.

## 4. Other known CX/DDR vote holders on X1E

| Holder | Symptom / check | Fix elsewhere |
|---|---|---|
| `gcc` never reaches `sync_state` (GMU node without driver, or `crypto@1dfa000` without driver) | `/sys/bus/platform/devices/100000.clock-controller/state_synced` = 0; all boot-on GDSCs stay on | "drm/msm: Attach a driver to the GMU" (Akhil P Oommen, RFT); `CRYPTO_DEV_QCE`; our `sync_all_suppliers` was a crude version of this |
| LPASS WSA/VA macros hold `LPASS_HW_MACRO`/`LPASS_HW_DCODEC` from probe | `/sys/kernel/debug/clk/LPASS_HW_*/clk_enable_count` > 0 while idle | mainline `eb667d0fbdd3` (va), `cd054a6e272c` (wsa), v7.3 |
| `icc-bwmon` (`24091000.pmu`) keeps ~800 MB/s on `ebi` | `interconnect_summary` | sp11-el2 patch 127 (suspend/resume ops) |
| BT GENI UART keeps clocks/bus vote | | mainline `d0cd9c8d0fd5` (v7.3); our geni hook does the same |
| ADSP wakes 45–100×/s | `wakeup_sources`, `qcom_stats/adsp` | modern-standby / power-limits GLINK message (x1e-sleep), must be a blocking send |
| An open PCM stream (e.g. PipeWire upmix) | `/proc/asound/card*/pcm*/sub*/status` = RUNNING | stop PipeWire before suspend (A/B test) |

We run 7.2.11, i.e. none of the v7.3 fixes above are in our kernel.

## 5. EL2: ingredients used by projects that reach CXSD

Reference results (battery gauge, single units):
Surface Pro 11 0.26 W (CXSD+AOSD+DDR 99.9 % of 73 min), Zenbook A14 0.148 W over 11 h,
Lenovo Slim 5x 1.23 W (92 % residency). EL1 on the same machines: 1.0–2.2 W, `cxsd = 0`.

What they needed, compared with our `honor_el2.dts` attempt:

- **DCC console**: `serial-getty@hvc0` on `hvc_dcc` hard-locks the SoC 10–30 s after boot at
  EL2 (TX never drains without JTAG). `systemctl mask serial-getty@hvc0` or `CONFIG_HVC_DCC=n`.
  Our "hard lock" reports should be re-checked against this first.
- **DSP attach at EL2**: ADSP/CDSP must be taken over by Linux (qebspil, jglathe remoteproc
  attach patches). Without it no CXSD, and the power-limits message can crash the ADSP.
- **Timer parking**: `arch-timer-park-stopped-timers` / `el1tmr`.
- **CL5 (`0x01000054`) system-sleep-only; no SS1 (`0x02000154`) in runtime idle**: firmware
  returns `PSCI_DENIED` or hangs otherwise.
- **`aoss_cxsd_only`**: avoids an hourly reset caused by the AOSD vote.
- They did **not** force `of_genpd_sync_state()` on gcc/gpucc. Forcing CX off with SMMUv3
  active, as our module did with `sync_all_suppliers=1`, matches the bus lock we saw.

## 6. Side findings

- **Mainline DTS exists**: `arch/arm64/boot/dts/qcom/x1e80100-honor-magicbook-art-14.dts`
  (Konstantin Shabanov, series v6, June 2026). Worth rebasing our display/audio deltas on it
  instead of a decompiled blob. Note it uses `wakeup-event-action = <EV_ACT_DEASSERTED>` on the lid.
- **RTC**: "firmware: qcom: scm: Allow QSEECOM on Honor Magicbook Art 14" was applied in
  July 2026. Our DTB already has `qcom,uefi-rtc-info`; with that commit the RTC should work and
  `system/` clock workaround becomes unnecessary. Until then, wall-clock time may not advance
  across suspend, which corrupts W calculations (the diag script uses AOSS ticks instead).

## 7. Second generation (X2 Elite / "Glymur")

Qualcomm upstreams early this time (GPU/display in 6.19, three laptop DTS in 7.4, an
`asus-glymur-ec` driver with suspend notification under review), but no measured low-power
s2idle on mainline was found yet. "Better supported" currently means earlier drivers, not a
solved standby.

## Sources

- [ramonjesusmiranda-debug/sp11-el2](https://github.com/ramonjesusmiranda-debug/sp11-el2)
- [dwhinham/archiso-aarch64-sp11#38](https://github.com/dwhinham/archiso-aarch64-sp11/issues/38)
- [omacom/omarchy-pkgs#1315](https://github.com/omacom/omarchy-pkgs/pull/1315)
- [qBitnaut/omarchy-dragon-sl7#27](https://github.com/qBitnaut/omarchy-dragon-sl7/issues/27)
- [jglathe/linux_ms_dev_kit#94](https://github.com/jglathe/linux_ms_dev_kit/issues/94), [#102](https://github.com/jglathe/linux_ms_dev_kit/issues/102)
- [vamanea/linux-magicbook](https://github.com/vamanea/linux-magicbook)
- [Linaro arm64-laptops: X1E suspend power consumption too high](https://gitlab.com/Linaro/arm64-laptops/linux/-/issues/19)
- [Honor MagicBook Art 14 DTS v6 (LKML)](https://lkml.iu.edu/2606.3/09331.html), [subset applied](https://lkml.iu.edu/2607.1/08446.html)
- [x1e80100: Add deepest idle state v5 (LKML)](https://lkml.iu.edu/2607.1/15928.html)
- [Phoronix: X2 Elite GPU in 6.19](https://www.phoronix.com/news/Qualcomm-X2-Elite-GPU-Linux-619)
