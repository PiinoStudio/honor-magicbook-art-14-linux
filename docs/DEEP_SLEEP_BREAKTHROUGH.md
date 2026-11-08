# Technical Post-Mortem: Power Management, `s2idle` & EL2 (`slbounce`) Findings on the Honor MagicBook Art 14 (X1E80100)

> [!WARNING]
> **Correction of Earlier Claims:**
> Earlier revisions of this document claimed a `0.389 W` `s2idle` breakthrough and a working `suspend-then-hibernate` script. Subsequent systematic kernel testing (`pm_test=devices`, `pm_test=platform`, and live EL1/EL2 hardware traces) proved those claims false and uncovered critical pitfalls that caused the laptop either to hard-lock in sleep or to abort hibernation and overheat inside a closed backpack.
>
> This document records our **verified negative findings and root-cause analyses** so that other developers working on the Honor MagicBook Art 14 (`MRO-XXX`, Snapdragon X Elite `X1E80100`) do not repeat the same dead ends.

---

## 1. Why Pure `s2idle` Cannot Achieve `< 0.5 W` on This Device Today

### A. Running in EL1 (Factory Qualcomm Gunyah Hypervisor)
- Under the factory boot chain, Linux boots at **EL1** beneath the Qualcomm Gunyah hypervisor (`CPU: All CPU(s) started at EL1`).
- When Linux enters `s2idle` and issues PSCI `CPU_SUSPEND(0x0200c354)` (`power-domain-system` / DRIPS), Gunyah intercepts the PSCI call (`hyp/vm/psci_osi/src/psci_osi.c`) and aggregates virtual machine power states rather than handing direct control of the physical power rails to Linux.
- As a result, `/sys/kernel/debug/qcom_stats/cxsd` and `/sys/kernel/debug/qcom_stats/ddr` remain at **`Count: 0`**, and actual standby power draw in `s2idle` remains at **~3 W to 8 W**.

### B. Running in EL2 via `slbounce` (`tcblaunch.exe` Secure Launch)
Using `systemd-boot` with [`TravMurav/slbounce`](https://github.com/TravMurav/slbounce) (`slbounceaa64.efi` in `/EFI/systemd/drivers/` and `tcblaunch.exe` from the Windows 11 26100.1 RTM recovery image in `/boot/efi/tcblaunch.exe`) successfully boots the Honor MagicBook Art 14 into native **EL2** (`CPU: All CPU(s) started at EL2`, `kvm [1]: VHE mode initialized successfully`) without a USB stick or manual UEFI Shell commands.

However, attempting deep `s2idle` (`cxsd` / `ddr` collapse) under EL2 on the Honor MagicBook Art 14 hits **two fatal hardware/firmware roadblocks**:

1. **`dpm_suspend_noirq` Bus Hard-Lock When `cx` Collapses (`sync_all_suppliers = 1`):**
   - To allow `cx` (`cx.lvl`, `0x30000`) to drop to `0` during `s2idle`, an earlier version of `honor_deep_sleep_fix.ko` called `of_genpd_sync_state()` on `100000.clock-controller` (`gcc-x1e80100`) and `3d90000.clock-controller` (`gpucc-x1e80100`).
   - Note that in the Linux kernel (`kernel/power/suspend.c`), `pm_test=platform` stops **before** `dpm_suspend_noirq()` in `s2idle_loop()`.
   - When a full `s2idle` cycle runs (`pm_test=none`), `dpm_suspend_noirq()` powers off all `gcc_*_gdsc` domains and drops `cx.lvl` to `0`.
   - In `honor_el2.dtb`, `iommu@15000000` (`arm,smmu-v3`) must be enabled (`status = "okay"`) with `iommu-map` on the PCIe controllers (whereas under EL1 it is `status = "reserved"` and managed by Gunyah). When `cx` collapses in `dpm_suspend_noirq()` under EL2 without Gunyah saving/restoring SMMU and RSC context, the SoC immediately **hard-locks on the bus** before even reaching `s2idle_enter()`.
2. **PSCI `0x0200c354` (DRIPS) & `qcom_adsp_pwr_lmts` Firmware Freeze:**
   - Even when isolating PSCI system power-down (`0x0200c354`) or sending the 24-byte `MODERN_STANDBY_STATE = 1` GLINK notification via `qcom_adsp_pwr_lmts.ko` (as used in `justririll/x1e-sleep` on Lenovo/ASUS models), the Honor MagicBook Art 14 firmware hangs inside TrustZone/AOP/ADSP.
   - Once locked, **no wakeup source can recover the SoC**—neither the EL2/EL02 architectural hardware timers (`CNTHP_CVAL_EL2` / `SYS_CNTP_CVAL_EL02`), nor PDC-routed GPIO interrupts (Lid switch GPIO 92 / Keyboard `1-003a` GPIO 67), nor the PMIC power button. Only a 10-second forced power-off recovers the machine.

---

## 2. Critical Traps & False Fixes Uncovered During Debugging

### Trap 1: Setting `spm_lvl = 3` on Micron UFS 4.0 (`1d84000.ufshc`) Breaks Resume
- **The False Fix:** An earlier handoff claimed that setting `/sys/devices/platform/soc@0/1d84000.ufshc/spm_lvl` to `3` (`UIC_LINK_HIBERN8_STATE`) via `/etc/udev/rules.d/99-ufs-pm.rules` prevented UFS crashes.
- **What Actually Happened (Proven via `pm_test=platform`):**
  When `gcc_ufs_phy_gdsc` powers down during suspend while `spm_lvl = 3`, `ufshcd` assumes the link stayed in Hibern8 with power maintained and skips full HBA re-initialization. Upon resume, `ufshcd_uic_hibern8_exit` fails:
  ```text
  ufshcd-qcom 1d84000.ufshc: pwr ctrl cmd 0x18 with (MIBattribute 0x0, mode 0x0) failed, host upmcrs:0x5
  ufshcd-qcom 1d84000.ufshc: ufshcd_uic_hibern8_exit: hibern8 exit failed. ret = 5
  ufshcd-qcom 1d84000.ufshc: __ufshcd_wl_resume: hibern8 exit failed 5
  ```
  This leaves the root UFS drive dead (`Device power mode=2, UIC link state=2`). Worse, because `systemd-sleep` freezes `user.slice` (`gnome-shell`) before suspend and runs `/usr/lib/systemd/system-sleep/` hooks (which call `sync`) *before* thawing `user.slice`, `systemd-sleep` hangs forever in D-state waiting on dead UFS I/O—leaving the OLED screen permanently black or the GNOME lockscreen completely unresponsive!
- **Correct Setting:** **Never set `spm_lvl = 3` when UFS GDSCs power down.** Keep the kernel default `spm_lvl = 5` (`UIC_LINK_OFF_STATE`), which cleanly shuts down the link before suspend and performs a full `ufshcd_hba_enable` + `ufshcd_link_startup` on resume, and set `sync_all_suppliers = 0` in `honor_deep_sleep_fix`.

### Trap 2: Removing `wakeup-source;` from `switch-lid` and Disabling `1-003a` Keyboard Wakeup
- **The False Fix:** Earlier commits stripped `wakeup-source;` from `switch-lid` (GPIO 92, IRQ 129) in `honor_native_edp_fix.dts` / `honor_el2.dts` and disabled wakeup on `1-003a` (I2C keyboard, GPIO 67, IRQ 127) in `92-snapdragon-wakeup.rules`.
- **What Actually Happened:**
  - Removing `wakeup-source;` from `switch-lid` caused `gpio-keys` to never register `/sys/devices/platform/gpio-keys/power/wakeup` at all (`button[0].wakeup = 0`), so `enable_irq_wake(129)` was never called on suspend.
  - Because `pmic_pwrkey` (IRQ 202) is routed through `pmic_arb` (GICv3 SPI) rather than the Qualcomm PDC (`pdc@b220000`), disabling both `switch-lid` (PDC GPIO 92) and `1-003a` (PDC GPIO 67) left **zero PDC wakeup sources armed** during deep sleep!
- **Correct Setting:** Keep `wakeup-source;` and `debounce-interval = <0x14>;` (without `wakeup-event-action = <0x02>;`) inside `switch-lid` in the DTB, and keep `/sys/bus/i2c/devices/1-003a/power/wakeup` set to `enabled` (only disable `2-005d` touchpad wakeup).

### Trap 3: Why Hibernation Failed Previously and Overheated in a Backpack
- **What Went Wrong in Earlier Scripts:**
  1. `setup_suspend_hibernate.sh` ran `dracut -f`, which rebuilt `/boot/initramfs-7.2.11-300.fc45.aarch64.img` on `/dev/sda8` (`/boot`), **not** `/boot/efi/initrd_native.img` on `/dev/sda2` (`/boot/efi`), which is the actual initramfs loaded by GRUB!
  2. Because `/boot/efi/initrd_native.img` lacked the `resume` dracut module (`systemd-hibernate-resume`), `/sys/power/resume` remained `0:0` at runtime even though `resume=UUID=...` was on the kernel command line.
  3. On Fedora 45, `/dev/zram0` has swap priority `100`, while `/swap/swapfile` has priority `10`. When `/sys/power/resume` is `0:0`, the kernel's `swsusp_swap_check()` inspects the highest-priority swap device (`zram0`), rejects it (`-ENODEV`), and aborts hibernation.
  4. When hibernation (or `suspend-then-hibernate` after 15 minutes) aborted—or when `spm_lvl = 3` crashed the UFS drive during the `dpm_freeze` snapshot phase—`systemd` simply aborted the sleep operation and **left the laptop running wide awake inside a closed backpack**!

---

## 3. Safe Production Configuration (`0.00 W` Hibernate + Backpack Failsafe)

Until Qualcomm and Honor upstream EL2-safe SMMU/RSC/ADSP suspend support for the `MRO-XXX` firmware, the only safe configuration that guarantees **0.00 W** drain and zero backpack overheating is:

1. **Ensure `/boot/efi/initrd_native.img` includes the `resume` dracut module** (`systemd-hibernate-resume`) and pass `resume=/dev/sda9 resume_offset=<offset>` on the kernel command line.
2. **Explicitly program `/sys/power/resume` at boot** via `/etc/tmpfiles.d/hibernate-resume.conf`:
   ```text
   w /sys/power/resume - - - - 8:9
   w /sys/power/resume_offset - - - - 1655338
   ```
3. **Force `HibernateMode=shutdown`** in `/etc/systemd/sleep.conf.d/hibernate.conf` so the mainboard physically powers off after writing the image (`0.00 W`).
4. **Configure `FailureAction=poweroff` on `systemd-hibernate.service` and `systemd-suspend.service`:**
   ```ini
   # /etc/systemd/system/systemd-hibernate.service.d/override.conf
   [Unit]
   FailureAction=poweroff
   ```
   If hibernation or suspend ever fails for any reason while the lid is closed, `systemd` immediately executes a clean `poweroff` instead of leaving the machine running in a bag.
5. **Disable `sync_all_suppliers` and `0x0200c354` in `honor_deep_sleep_fix.ko`:**
   Pass `options honor_deep_sleep_fix sync_all_suppliers=0 hold_usbc_ldos=1` and increment `power-domain-system`'s `sd_count` so neither `cx` nor `0x0200c354` can hard-lock the bus.
