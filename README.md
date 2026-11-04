# Honor MagicBook Art 14 Snapdragon (X1E80100) — Linux Support Toolkit

[![Platform](https://img.shields.io/badge/Platform-Qualcomm%20Snapdragon%20X%20Elite%20(X1E80100)-blue.svg)](#)
[![OS Tested](https://img.shields.io/badge/Tested%20on-Fedora%2045%20Beta%20(Linux%207.2.11%20ARM64)-brightgreen.svg)](#)
[![Display](https://img.shields.io/badge/Display-Native%203.1K%20OLED%20%40%20120Hz-orange.svg)](#)
[![License](https://img.shields.io/badge/License-GPL--2.0%20%2F%20BSD-lightgrey.svg)](#)

> [!IMPORTANT]
> **Status / Disclaimer:**
> - These patches and configurations have currently been **validated on a single hardware unit** (*Honor MagicBook Art 14 Snapdragon*, Model `MRO-XXX`, Qualcomm Snapdragon X Elite X1E80100) and **exclusively tested under Fedora 45 Beta (Rawhide / Linux Kernel 7.2.11 ARM64)**.
> - As mainline Linux support for Snapdragon X Elite platforms is actively evolving, use at your own discretion.
> - Feedback, testing reports, and contributions for other distributions (*Ubuntu, Arch Linux, Debian*) and firmware revisions are warmly welcome!
>
> *(Deutsche Dokumentation: Eine deutsche Fassung dieser Anleitung findest du in [README_DE.md](README_DE.md).)*

---

## 🌟 Working Features

- **Display:** Flawless native 3.1K OLED ($3120 \times 2080$) at **120 Hz** refresh rate.
  - Full Adreno X1-85 GPU 3D acceleration.
  - Seamless Dual Layer Mixer scanout across split planes without tearing, line flickering, or duplicate mouse cursor artifacts.
- **Audio:** Complete internal 4-speaker array (**Quad Speakers:** 2x bottom Woofers + 2x top Tweeters via Qualcomm Aqstic WSA8845 smart amplifiers).
  - 3.5mm Headphone / Headset jack via Qualcomm WCD9385 codec.
  - 4x Internal digital microphones (`VA DMIC`).
- **Fingerprint Reader:** Biometric authentication for system login and `sudo` elevation via the integrated `10a5:9924` Fingerprint Cards (FPC) match-on-host sensor.
- **Wireless & Networking:** Qualcomm FastConnect 7800 Wi-Fi 7 (`ath12k_wifi7_pci`) and Bluetooth.
- **Input & Power:** Multitouch trackpad, keyboard backlight, battery status monitoring and charging management via `qcom-battmgr`.
- **Lid Sensor & Display Suspend:** Hardware Hall-effect lid switch (`gpio-keys` on TLMM GPIO 92) with 20 ms hardware debouncing automatically suspends the laptop when closed and resumes instantly upon opening.
- **Power Management & Suspend (`s2idle` / S4):** Comprehensive power optimizations:
  - PCIe Root Port interconnect bandwidth reduction during sleep (`bridge_d3 = 0` preventing DWC L2 timeout aborts).
  - Dynamic power domain sync for GCC and GPUCC clock controllers.
  - Interconnect sleep vote reduction to 0 MB/s.
  - Automated Wi-Fi safe suspend/resume and USB flapping filter.
- **0.00W Deep Hibernation (`suspend-then-hibernate`, Recommended):** Automated transition to disk hibernation (`suspend-then-hibernate`, 0.00W power draw) for overnight and multi-week shelf storage without battery drain.
- **EL2 Boot & True Hardware DRIPS Research:** Documentation and roadmap for bypassing the Qualcomm Gunyah hypervisor via `slbounce` to achieve native EL2 hardware sleep (`cxsd` / `ddr` collapse).
- **Windows 11 Dual-Boot:** Reliable UEFI GRUB chainloading configuration to dual-boot Windows 11 ARM64 alongside Linux.
- **Microphone Ghost Mute Fix:** Udev rule suppresses bogus `KEY_MICMUTE` repeat storms emitted by the touchscreen I2C firmware interface (`2808:5662 UNKNOWN`).
- **RTC Clock Persistence:** Automated fallback service preserves the system clock across reboots, preventing offline package update failures caused by future OpenPGP signature timestamps.

---

## 📁 Repository Structure

```text
.
├── README.md               # English Documentation & Quickstart
├── README_DE.md            # Deutsche Dokumentation
├── display/
│   ├── patch_honor_native_120hz_oled.diff  # Unified patch (EDO 0x4179 modeline + eDP widebus + dual mixer offset)
│   ├── honor_native_edp_fix.dtb            # Compiled Device Tree Binary for bootloader (includes lid switch)
│   ├── honor_native_edp_fix.dts            # Decompiled human-readable Device Tree source
│   ├── apply_kernel_patch.sh               # Helper script to apply patch to any Linux kernel tree
│   └── fedora45_modules/                   # Pre-compiled stripped modules for Fedora 45 (msm.ko, panel-edp.ko)
├── audio/
│   ├── X1E80100-HONOR-MagicBook-Art-14-Snapdragon-tplg.bin # AudioReach DSP topology binary
│   ├── 20-upmix.conf                       # PipeWire configuration for quad-speaker stereo upmixing
│   └── setup_audio.sh                      # One-click installation script for sound
├── fingerprint/
│   ├── 0001-fpcmoc-add-10a5-9924-experimental-support.patch # libfprint patch for FPC 10a5:9924
│   ├── setup_fingerprint.sh                # Automated build, install & PAM configuration script
│   ├── build-install.sh
│   └── apply-patch.sh
├── power/
│   ├── honor_deep_sleep_fix/       # Kernel module for EL1 timer mirroring, genpd sync, bridge_d3, LDO hold
│   │   ├── honor_deep_sleep_fix.c
│   │   └── Makefile
│   ├── setup_deep_sleep.sh         # One-click installer for 0.389W native deep sleep
│   ├── 92-snapdragon-wakeup.rules  # Udev rules suppressing flapping USB devices & spurious wakes
│   ├── honor-sleep.conf            # /etc/modules-load.d/ autoload configuration
│   ├── snapdragon-power-saver.sh   # System-sleep hook for PCIe Wi-Fi safe suspend & runtime PM
│   ├── setup_suspend_hibernate.sh  # (Optional) One-click installer for 0W deep hibernation
│   ├── 10-runtime-pm.rules         # Persistent udev runtime power management rules
│   ├── hibernate.conf              # systemd-sleep policy (15min timeout to hibernate)
│   ├── lid.conf                    # systemd-logind policy (suspend-then-hibernate)
│   └── setup_lid.sh                # Unmasks suspend targets and installs lid configuration
├── docs/
│   └── DEEP_SLEEP_BREAKTHROUGH.md  # Detailed technical log, ftrace analysis, and power measurements
├── input/
│   ├── 99-ignore-ghost-micmute.rules       # Udev rule to silence touchscreen mic-mute spam
│   └── setup_input.sh                      # One-click installation for input fix
├── system/
│   ├── save-restore-clock.sh               # Clock save/restore helper script
│   ├── save-restore-clock.service          # Early boot systemd clock restore service
│   ├── save-clock-periodic.service         # Periodic clock save service
│   ├── save-clock-periodic.timer           # Periodic clock save timer
│   └── setup_clock.sh                      # One-click installation for RTC clock fallback
└── boot/
    ├── cmdline.txt                         # Required kernel boot arguments
    └── grub.cfg.example                    # Sample GRUB 2 configuration (Linux + Windows 11 Dual-Boot)
```

---

## 🚀 Step-by-Step Installation

### 1. Bootloader & Kernel Parameters
Copy `display/honor_native_edp_fix.dtb` to your EFI partition (e.g., `/boot/efi/dtb/honor_native_edp_fix.dtb`).

Add the following kernel parameters to your bootloader (GRUB / systemd-boot):
```text
arm_smmu.disable_bypass=0 arm-smmu.disable_bypass=0 efi=noruntime efi=novamap arm64.nopauth softlockup_panic=0 panic=0
```
> [!NOTE]
> Do **not** use `clk_ignore_unused pd_ignore_unused regulator_ignore_unused` in daily use! Keeping unused power domains on prevents the Snapdragon SoC from clock-gating unused IP blocks and increases idle battery drain.

And instruct your bootloader to load the device tree:
```text
devicetree /dtb/honor_native_edp_fix.dtb
```
*(See `boot/grub.cfg.example` for a complete dual-boot GRUB configuration).*

---

### 2. Enable Native 120Hz 3.1K OLED Display

* **Method A (Apply patch to kernel source):**
  Apply the patch to your distribution kernel source tree:
  ```bash
  cd /path/to/linux-source
  patch -p1 < display/patch_honor_native_120hz_oled.diff
  ```
  Then recompile the DRM subsystem modules:
  ```bash
  make M=drivers/gpu/drm/msm modules
  make M=drivers/gpu/drm/panel modules
  ```

* **Method B (Fedora 45 Rawhide / Kernel 7.2.11):**
  Pre-compiled stripped modules are provided in `display/fedora45_modules/`. You can embed them directly into your `initramfs` or copy them to:
  ```bash
  sudo cp display/fedora45_modules/msm.ko /lib/modules/$(uname -r)/kernel/drivers/gpu/drm/msm/
  sudo cp display/fedora45_modules/panel-edp.ko /lib/modules/$(uname -r)/kernel/drivers/gpu/drm/panel/
  sudo depmod -a
  ```

---

### 3. Enable Audio (Quad Speakers & Jack)
Run the automated audio setup script:
```bash
cd audio
chmod +x setup_audio.sh
./setup_audio.sh
```

#### Achieving Full Laptop Volume & Rich Sound:
Under Linux, audio plays in studio-flat mode by default without proprietary DSP processing. To achieve punchy sound comparable to Windows or macOS:
1. Install **EasyEffects**:
   ```bash
   sudo dnf install -y easyeffects lsp-plugins   # Fedora
   # or: sudo apt install easyeffects            # Ubuntu / Debian
   ```
2. Enable **AutoGain**, **Bass Enhancer**, and **Limiter** inside EasyEffects.

---

### 4. Enable Fingerprint Reader (FPC `10a5:9924`)
Run the automated build and PAM configuration script:
```bash
cd fingerprint
chmod +x setup_fingerprint.sh build-install.sh apply-patch.sh
./setup_fingerprint.sh
```
Once installed, enroll your fingerprint:
```bash
fprintd-enroll
```
Or open **GNOME Settings → Users → Fingerprint Login** to add your prints.

---

### 5. Configure Suspend, Lid Switch & Power Savers

On Snapdragon X Elite laptops running under the factory Qualcomm Gunyah Hypervisor (EL1), regular Linux `s2idle` cannot collapse physical SoC power rails (`cxsd` and `ddr` stay at 0 due to Gunyah VM state aggregation). In pure `s2idle`, the laptop draws ~3 to 8W.

Therefore, for real-world daily use, **Option A (`suspend-then-hibernate`) is the recommended configuration**: the laptop suspends instantly upon lid close, and transitions after a few minutes to disk hibernation, reducing battery drain to **0.00W**.

#### Option A: 0.00W Deep Hibernation (`suspend-then-hibernate`, Recommended)
```bash
cd power
chmod +x setup_suspend_hibernate.sh
./setup_suspend_hibernate.sh
```
What this does:
1. Configures a 34GB Btrfs swapfile on `/swap/swapfile` and calculates kernel resume parameters.
2. Updates `dracut` initramfs with the `resume` module.
3. Sets systemd policies:
   - Immediate `s2idle` upon lid close.
   - Automatic hibernation to disk after 15 minutes of sleep (**0.00W power draw**).
   - Fast resume (~3 seconds) upon pressing the power button.

#### Option B: Standby Power-Saver Hooks & Lid Switch Only (`s2idle`)
```bash
cd power
chmod +x setup_lid.sh
./setup_lid.sh
```

#### Option C: Native Power-Management Kernel Module (`honor_deep_sleep_fix.ko`)
```bash
cd power
chmod +x setup_deep_sleep.sh
./setup_deep_sleep.sh
```
What this installs:
1. Compiles and installs `honor_deep_sleep_fix.ko` with:
   - PCIe Root Port `0004:00:00.0` `bridge_d3 = 0` fix (preventing DWC L2 timeout aborts).
   - Dynamic power domain sync for GCC and GPUCC clock controllers.
   - System-sleep-only governor for `power-domain-system` (`0x0200c354`, DRIPS).
   - USB-C LDO hold for stability.
2. Autoloading `/etc/modules-load.d/honor-sleep.conf` (ensures `videocc-sm8550` and `honor_deep_sleep_fix` load at boot).
3. Udev rules (`92-snapdragon-wakeup.rules`) disabling spurious wakeups and silencing the flapping FPC fingerprint USB sensor.
4. System-sleep power-saver hook (`snapdragon-power-saver.sh`) powering down Wi-Fi before sleep to prevent PCIe L2 timeouts and reconnecting automatically upon wake.
1. Allocates an uncompressed, nocow 34GB swapfile on Btrfs (`/swap/swapfile`).
2. Configures the kernel `resume` module in `dracut` and rebuilds the initramfs.
3. Sets systemd to sleep instantly (`s2idle`) on lid close, and transition to **0.00W disk hibernation** after 15 minutes.
4. Resumes within **~3 seconds** from the high-speed Micron UFS storage upon pressing the power button.

---

### 6. Silence Touchscreen Ghost Mic-Mute Popups
On firmware versions where the touchscreen subdevice (`2808:5662 UNKNOWN`) floods the system with `KEY_MICMUTE` repeat events, install the udev inhibition rule:
```bash
cd input
chmod +x setup_input.sh
./setup_input.sh
```

---

### 7. Fix Offline Updates & RTC Clock Drift
Because Snapdragon X Elite laptops currently lack a persistent hardware RTC in upstream Linux, early boot defaults to a fallback timestamp. This causes offline package managers (like GNOME Software / DNF5) to reject updates because package OpenPGP signatures appear to come from the future.

Install the automated clock preservation service:
```bash
cd system
chmod +x setup_clock.sh save-restore-clock.sh
./setup_clock.sh
```
This saves the system clock on shutdown and every 10 minutes, restoring it in early boot before `system-update.target` runs.

---

### 8. Dual-Booting with Windows 11 ARM64
To dual-boot alongside factory Windows 11 without boot order collisions:
1. Keep the original Windows EFI boot files in `/EFI/Microsoft/Boot/bootmgfw.efi`.
2. Add the chainloader stanza to your `/boot/efi/EFI/Boot/grub.cfg` (see `boot/grub.cfg.example`):
   ```grub
   menuentry "Windows 11" --class windows --class os {
       insmod fat
       insmod part_gpt
       insmod chain
       search --no-floppy --file --set=root /EFI/Microsoft/Boot/bootmgfw.efi
       chainloader ($root)/EFI/Microsoft/Boot/bootmgfw.efi
   }
   ```

---

## ❓ FAQ & Technical Notes

### Why doesn't Linux drop down to 0.3W in regular Standby like Windows?
In Windows, Qualcomm ships a monolithic 4.7 MB driver (`qcpep8380.sys`) which directly programs the Resource Power Manager Hardened (RPMh) and Always-On Processor (AOP) via internal QMP/GLINK mailboxes. 

Under Linux, power management is decentralized across 40+ independent subsystem drivers (`genpd`, `rpmh-rsc`, `drm/msm`, `dwc3-qcom`). RPMh uses hardware voting aggregation ($\text{Rail} = \max(\text{Votes})$); if even one driver or the proprietary Honor Embedded Controller maintains a retention vote, the SoC cannot collapse the `VDD_CX` rail. Using **Suspend-Then-Hibernate** completely bypasses this limitation by cutting power to 0.00W after 15 minutes.

### What is the 73.4 MB `Persisted_Capsules.bin` file in the EFI partition?
If you inspect `/boot/efi/Persisted_Capsules.bin`, you may wonder if an unapplied BIOS update is pending. Hex analysis reveals that 73,400,306 bytes out of 73,400,320 bytes are zeroes (`0x00`). It is a pre-allocated EFI capsule reservation created during factory deployment so future UEFI capsule updates have contiguous disk space; it is **not** a pending update.

---

## 🤝 Upstream Contribution Goals
The long-term goal of this project is to submit these fixes (eDP Widebus support, DPU dual-mixer SSPP offset calculation, panel modeline, and device tree) upstream to the official Linux kernel mailing lists (`linux-arm-msm` and `dri-devel`) so that all future distributions support the Honor MagicBook Art 14 out of the box.

---

## 🙏 Credits & Acknowledgments

This project stands on the shoulders of giants in the Linux, Qualcomm, and open-source communities. We gratefully acknowledge:

- **Fingerprint Reader Support (`10a5:9924`):**
  - Special thanks to **[Terrydaktal](https://github.com/Terrydaktal)** for reverse-engineering the FPC sensor initialization sequence (`0x12` + `0x14` + `0x90`) and authoring the [libfprint-fpc-10a5-9924](https://github.com/Terrydaktal/libfprint-fpc-10a5-9924) patch.
  - The **[libfprint](https://gitlab.freedesktop.org/libfprint/libfprint)** upstream maintainers at freedesktop.org.
- **Audio & SoundWire Subsystem:**
  - **Srinivas Kandagatla** (Linaro / Qualcomm) and **Krzysztof Kozlowski** for developing the ASoC AudioReach (`q6apm`), SoundWire (`soundwire_qcom`), and WSA884x amplifier drivers in the mainline Linux kernel.
  - The **[ALSA Project](https://github.com/alsa-project/alsa-ucm-conf)** and **[linux-firmware](https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git)** maintainers for UCM2 profiles and AudioReach topology frameworks.
  - The **[PipeWire](https://gitlab.freedesktop.org/pipewire/pipewire)** team for low-latency audio and spatial quad-speaker upmixing support.
  - **[EasyEffects](https://github.com/wwmm/easyeffects)** and **[LSP Plugins](https://lsp-plug.in/)** for DSP equalization and laptop loudness management.
- **Qualcomm Snapdragon Display & Graphics:**
  - **Dmitry Baryshkov**, **Rob Clark**, and the Linux MSM DRM team for the Snapdragon Display Processing Unit (`msm/dpu`) and DisplayPort (`msm/dp`) drivers.
  - **Douglas Anderson** and upstream contributors for the generic `panel-edp` driver framework.
- **Device Tree & Community:**
  - The **Linaro Qualcomm Working Group** and the broader Snapdragon X Elite Linux community for ongoing reverse-engineering and bring-up work on ARM64 laptops.
- **Power Management & Deep Sleep Research:**
  - **[justririll](https://github.com/justririll)** for pioneering the [x1e-sleep](https://github.com/justririll/x1e-sleep) project on Snapdragon X Elite (`X1E80100`), uncovering the ADSP Modern Standby GLINK interface (`qcom_adsp_pwr_lmts`), and demonstrating hardware low-power states.
  - **[n1c0la84](https://github.com/n1c0la84)** for the in-depth [book4-edge-linux](https://github.com/n1c0la84/book4-edge-linux) power investigations comparing EL1/Gunyah vs. EL2/slbounce suspend architectures and LPASS macro runtime PM fixes.

---

## 📄 License
- Kernel patches and Device Trees are provided under **GPL-2.0** / **BSD-2-Clause**.
- Fingerprint patches are licensed under **LGPL-2.1** (matching upstream `libfprint`).
