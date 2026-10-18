# Honor MagicBook Art 14 Snapdragon (X1E80100) — Linux Support Toolkit (Deutsch)

> [!IMPORTANT]
> **Status / Disclaimer:**
> - Diese Konfiguration und Patches wurden bisher **nur auf einem einzigen Gerät** (*Honor MagicBook Art 14 Snapdragon*, Modell `MRO-XXX`, Snapdragon X Elite X1E80100) und **ausschließlich unter Fedora 45 Beta (Kernel 7.2.11 ARM64)** getestet.
> - Da die Hardware-Unterstützung für Snapdragon X Elite unter Linux noch in aktiver Entwicklung ist, erfolgt die Nutzung auf eigene Verantwortung.
> - Feedback, Tests und Bug-Reports für andere Distributionen (*Ubuntu, Arch Linux, Debian*) oder Kernel-Versionen sind ausdrücklich erwünscht!

---

## 🌟 Was mit diesem Toolkit funktioniert:
- **Display:** Natives 3.1K OLED ($3120 \times 2080$) mit echten **120 Hz**, Adreno X1-85 GPU Hardware-Beschleunigung, nahtloser Dual-Layer-Mixer (kein Zeilenflimmern, kein geteilter Mauszeiger).
- **Audio:** Vollständiges 4-Lautsprecher-System (**Quad Speakers:** 2x Woofer unten + 2x Hochtöner neben der Tastatur via Qualcomm Aqstic WSA8845), 3.5mm Klinke (WCD9385) und 4x interne Mikrofone.
- **Fingerprint:** Biometrische Anmeldung & `sudo` über den integrierten Sensor (`10a5:9924 FPC`).
- **Konnektivität:** Wi-Fi 7 (FastConnect 7800 / `ath12k`), Bluetooth.
- **Eingabe & Energie:** Multitouch-Touchpad, Tastaturbeleuchtung, Akkustandsanzeige & Ladekontrolle (`qcom-battmgr`).

---

## 📁 Struktur des Repositories:

```text
.
├── README.md               # English Documentation & Quickstart
├── README_DE.md            # Deutsche Dokumentation
├── display/
│   ├── patch_honor_native_120hz_oled.diff  # Universeller Kernel-Patch (EDO 0x4179 Modeline + eDP Widebus + Dual-Mixer Offset)
│   ├── honor_native_edp_fix.dtb            # Kompiliertes Device Tree Binary für den Bootloader
│   ├── honor_native_edp_fix.dts            # Vollständiger Device Tree Quellcode
│   ├── apply_kernel_patch.sh               # Skript zum Patchen eines Kernels
│   └── fedora45_modules/                   # Vorgebaute Module für Fedora 45 (msm.ko, panel-edp.ko)
├── audio/
│   ├── X1E80100-HONOR-MagicBook-Art-14-Snapdragon-tplg.bin # Qualcomm AudioReach Topologie
│   ├── 20-upmix.conf                       # PipeWire Quad-Speaker Konfiguration
│   └── setup_audio.sh                      # 1-Klick Sound-Installationsskript
├── fingerprint/
│   ├── 0001-fpcmoc-add-10a5-9924-experimental-support.patch # libfprint-Treiberpatch für FPC 10a5:9924
│   ├── setup_fingerprint.sh                # 1-Klick Build- & PAM-Setup für Fingerabdruck
│   ├── build-install.sh
│   └── apply-patch.sh
└── boot/
    ├── cmdline.txt                         # Erforderliche Boot-Parameter für Snapdragon X Elite
    └── grub.cfg.example                    # Beispiel-Konfiguration für GRUB 2
```

---

## 🚀 Schritt-für-Schritt Anleitung:

### 1. Bootloader & Kernel-Parameter einrichten
Kopiere `display/honor_native_edp_fix.dtb` in deine EFI-Partition (z. B. nach `/boot/efi/dtb/`).
Füge in deiner Bootloader-Konfiguration (GRUB / systemd-boot) folgende Kernel-Argumente hinzu:
```text
clk_ignore_unused pd_ignore_unused regulator_ignore_unused arm_smmu.disable_bypass=0 arm-smmu.disable_bypass=0 efi=noruntime efi=novamap arm64.nopauth softlockup_panic=0 panic=0
```
Und lade das Device Tree Binary mit:
```text
devicetree /dtb/honor_native_edp_fix.dtb
```

---

### 2. Natives 120Hz 3.1K OLED aktivieren
* **Option A (Bestehender Kernel gepatcht):**
  Wende den Patch auf deinen Distributions-Kernel an:
  ```bash
  cd /pfad/zum/kernel-source
  patch -p1 < display/patch_honor_native_120hz_oled.diff
  ```
* **Option B (Fedora 45):**
  Kopiere einfach die vorgebauten Module aus `display/fedora45_modules/` in dein initramfs oder `/lib/modules/$(uname -r)/kernel/drivers/gpu/drm/`.

---

### 3. Ton & 4 Lautsprecher aktivieren
Führe einfach das Audioskript aus:
```bash
cd audio
chmod +x setup_audio.sh
./setup_audio.sh
```
*Tipp:* Für noch mehr Lautstärke und Punch installiere zusätzlich **EasyEffects** (`sudo dnf install easyeffects` bzw. `apt install easyeffects`).

---

### 4. Fingerabdrucksensor aktivieren
Führe das Fingerprint-Setup aus:
```bash
cd fingerprint
chmod +x setup_fingerprint.sh build-install.sh apply-patch.sh
./setup_fingerprint.sh
```
Registriere anschließend deinen Finger:
```bash
fprintd-enroll
```

---

## 🙏 Danksagung & Quellen (Credits)

Dieses Projekt baut auf der Vorarbeit und den Beiträgen herausragender Entwickler der Linux-, Qualcomm- und Open-Source-Community auf:

- **Fingerabdrucksensor-Treiber (`10a5:9924`):**
  - Großer Dank an **[Terrydaktal](https://github.com/Terrydaktal)** für das Reverse-Engineering der FPC-Initialisierungssequenz (`0x12` + `0x14` + `0x90`) und den Patch [libfprint-fpc-10a5-9924](https://github.com/Terrydaktal/libfprint-fpc-10a5-9924).
  - Den Maintainern des Upstream-Projekts **[libfprint](https://gitlab.freedesktop.org/libfprint/libfprint)** bei freedesktop.org.
- **Audio & SoundWire Subsystem:**
  - **Srinivas Kandagatla** (Linaro / Qualcomm) und **Krzysztof Kozlowski** für die Treiber-Entwicklung von ASoC AudioReach (`q6apm`), SoundWire (`soundwire_qcom`) und den WSA884x-Verstärkern im offiziellen Linux-Kernel.
  - Den Entwicklern des **[ALSA-Projekts](https://github.com/alsa-project/alsa-ucm-conf)** und **[linux-firmware](https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git)** für die UCM2-Profile und Topologien.
  - Dem **[PipeWire](https://gitlab.freedesktop.org/pipewire/pipewire)**-Team für latenzarmes Audio und die 4-Kanal-Upmix-Architektur.
  - **[EasyEffects](https://github.com/wwmm/easyeffects)** und den **[LSP Plugins](https://lsp-plug.in/)** für DSP-Equalization und Lautstärkeanpassung.
- **Qualcomm Snapdragon Display & GPU:**
  - **Dmitry Baryshkov**, **Rob Clark** und dem Linux MSM DRM-Team für die Treiber des Display Processors (`msm/dpu`) und DisplayPort (`msm/dp`).
  - **Douglas Anderson** für das generische `panel-edp` Framework im Kernel.
- **Device Tree & Community:**
  - Der **Linaro Qualcomm Working Group** und der gesamten Snapdragon X Elite Linux-Community für Pionierarbeit bei der Hardware-Unterstützung unter ARM64.

---

## 📄 Lizenz
- Kernel-Patches und Device Trees unterliegen der **GPL-2.0** / **BSD-2-Clause**.
- Der Fingerprint-Patch steht unter der **LGPL-2.1** (wie Upstream `libfprint`).

