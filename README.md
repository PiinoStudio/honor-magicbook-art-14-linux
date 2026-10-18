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

---

## 📁 Repository Structure

```text
.
├── README.md               # English Documentation & Quickstart
├── README_DE.md            # Deutsche Dokumentation
├── display/
│   ├── patch_honor_native_120hz_oled.diff  # Unified patch (EDO 0x4179 modeline + eDP widebus + dual mixer offset)
│   ├── honor_native_edp_fix.dtb            # Compiled Device Tree Binary for bootloader
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
└── boot/
    ├── cmdline.txt                         # Required kernel boot arguments
    └── grub.cfg.example                    # Sample GRUB 2 configuration
```

---

## 🚀 Step-by-Step Installation

### 1. Bootloader & Kernel Parameters
Copy `display/honor_native_edp_fix.dtb` to your EFI partition (e.g., `/boot/efi/dtb/honor_native_edp_fix.dtb`).

Add the following kernel parameters to your bootloader (GRUB / systemd-boot):
```text
clk_ignore_unused pd_ignore_unused regulator_ignore_unused arm_smmu.disable_bypass=0 arm-smmu.disable_bypass=0 efi=noruntime efi=novamap arm64.nopauth softlockup_panic=0 panic=0
```
And instruct your bootloader to load the device tree:
```text
devicetree /dtb/honor_native_edp_fix.dtb
```
*(See `boot/grub.cfg.example` for a complete GRUB configuration).*

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

## 🤝 Upstream Contribution Goals
The long-term goal of this project is to submit these fixes (eDP Widebus support, DPU dual-mixer SSPP offset calculation, panel modeline, and device tree) upstream to the official Linux kernel mailing lists (`linux-arm-msm` and `dri-devel`) so that all future distributions support the Honor MagicBook Art 14 out of the box.

---

## 📄 License
- Kernel patches and Device Trees are provided under **GPL-2.0** / **BSD-2-Clause**.
- Fingerprint patches are licensed under **LGPL-2.1**.
