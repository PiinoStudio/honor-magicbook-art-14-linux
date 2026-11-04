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
- **Deckelsensor (Lid Switch) & Display-Aus:** Echter Hardware Hall-Sensor (`gpio-keys` auf TLMM GPIO 92) schaltet beim Zuklappen das Display sofort aus und versetzt das Notebook in den Standby.
- **Echter Deep Sleep (`s2idle` @ 0,389W) & >150h Akkulaufzeit:** Durchbruch beim Snapdragon X Elite Standby! Leistungsaufnahme im Ruhezustand von **~10W auf 0,389W (389 mW)** gesenkt – Akkulaufzeit im Standby steigt von 6 Stunden auf **über 150 Stunden (>6 Tage)** bei sofortigem, 100% stabilem Aufwachen:
  - Vollständiger DDR-Interconnect Kollaps im Sleep-TCS (`MC0`, `SH0`, `SH1`, `SN0`, `CN0`, `QUP0`, `QUP1`, `ACV`, `PCIE_ANOC` auf `0x0`).
  - Spannungsdomänen schalten in `dpm_suspend_noirq` komplett ab (`cx.lvl`, `mx.lvl`, `mmcx.lvl` auf `0,0V`).
  - Hardware-DRIPS (`power-domain-system`, `0x0200c354`) wird sauber betreten.
  - EL1 Physical Timer Mirroring verhindert TrustZone IRQ 30 Freezes.
  - PCIe Root Port `bridge_d3 = 1` Hotplug-Fix.
  - Automatisches WLAN-Powerdown vor Standby und USB-Flapping-Filter.
- **0,00W Tiefschlaf (Optional):** Automatischer Wechsel in den Festplatten-Ruhezustand (`suspend-then-hibernate`, 0W) für wochenlanges Lagern ohne Akkuverlust.
- **Windows 11 Dual-Boot:** Vollständiger UEFI GRUB Chainloader für paralleles Booten von Windows 11 ARM64 und Linux.
- **Mikrofon Ghost-Mute Fix:** Udev-Regel unterdrückt ständige Phantom-Lautstärke/Mute-Popups, die von der Touchscreen-Firmwareschnittstelle (`2808:5662 UNKNOWN`) geflutet werden.
- **RTC-Uhrzeit-Persistenz & System-Updates:** Automatischer Fallback-Dienst sichert die Uhrzeit über Neustarts hinweg, sodass Offline-System-Updates (z. B. GNOME Software / DNF5) nicht mehr an angeblich in der Zukunft liegenden GPG-Paketsignaturen scheitern.

---

## 📁 Struktur des Repositories:

```text
.
├── README.md               # English Documentation & Quickstart
├── README_DE.md            # Deutsche Dokumentation
├── display/
│   ├── patch_honor_native_120hz_oled.diff  # Universeller Kernel-Patch (EDO 0x4179 Modeline + eDP Widebus + Dual-Mixer Offset)
│   ├── honor_native_edp_fix.dtb            # Kompiliertes Device Tree Binary für den Bootloader (inkl. Lid Switch)
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
├── power/
│   ├── honor_deep_sleep_fix/       # Kernelmodul (EL1 Timer Mirroring, GenPD Sync, bridge_d3, LDO Hold)
│   │   ├── honor_deep_sleep_fix.c
│   │   └── Makefile
│   ├── setup_deep_sleep.sh         # 1-Klick Setup für 0,389W echten Deep Sleep
│   ├── 92-snapdragon-wakeup.rules  # Udev-Regeln gegen Phantom-Wakeups & USB-Flapping
│   ├── honor-sleep.conf            # /etc/modules-load.d/ Autoload-Konfiguration
│   ├── snapdragon-power-saver.sh   # System-Sleep Hook für sicheren PCIe-Standby & Runtime-PM
│   ├── setup_suspend_hibernate.sh  # (Optional) 1-Klick Setup für 0W Festplatten-Ruhezustand
│   ├── 10-runtime-pm.rules         # Udev-Regeln für automatisches Runtime-PM
│   ├── hibernate.conf              # systemd-sleep Policy (15 Min Standby -> Hibernate)
│   ├── lid.conf                    # systemd-logind Konfiguration für Deckelaktion
│   └── setup_lid.sh                # Unmasked Suspend-Targets und richtet Basis-Standby ein
├── docs/
│   └── DEEP_SLEEP_BREAKTHROUGH.md  # Vollständige Ftrace-Analyse, Register-Dumps & Leistungsmessungen
├── input/
│   ├── 99-ignore-ghost-micmute.rules       # Udev-Regel zur Unterdrückung der Phantom-Mute-Events
│   └── setup_input.sh                      # 1-Klick Setup für die Eingabegeräte-Korrektur
├── system/
│   ├── save-restore-clock.sh               # Skript zum Speichern/Wiederherstellen der Systemzeit
│   ├── save-restore-clock.service          # Frühstart-Systemd-Dienst zur Wiederherstellung der Uhrzeit
│   ├── save-clock-periodic.service         # Periodische Sicherung der Uhrzeit
│   ├── save-clock-periodic.timer           # Timer für periodische Sicherung
│   └── setup_clock.sh                      # 1-Klick Setup für RTC-Uhrzeit-Persistenz
└── boot/
    ├── cmdline.txt                         # Erforderliche Boot-Parameter für Snapdragon X Elite
    └── grub.cfg.example                    # Beispiel-Konfiguration für GRUB 2 (Linux + Windows 11 Dual-Boot)
```

---

## 🚀 Schritt-für-Schritt Anleitung:

### 1. Bootloader & Kernel-Parameter einrichten
Kopiere `display/honor_native_edp_fix.dtb` in deine EFI-Partition (z. B. nach `/boot/efi/dtb/`).
Füge in deiner Bootloader-Konfiguration (GRUB / systemd-boot) folgende Kernel-Argumente hinzu:
```text
arm_smmu.disable_bypass=0 arm-smmu.disable_bypass=0 efi=noruntime efi=novamap arm64.nopauth softlockup_panic=0 panic=0
```
> [!NOTE]
> Die Parameter `clk_ignore_unused pd_ignore_unused regulator_ignore_unused` sollten im Alltag **nicht** verwendet werden, da sie das automatische Abschalten ungenutzter SoC-Bereiche verhindern und den Standby-Verbrauch erhöhen.

Und lade das Device Tree Binary mit:
```text
devicetree /dtb/honor_native_edp_fix.dtb
```
*(Siehe `boot/grub.cfg.example` für eine vollständige Dual-Boot GRUB-Konfiguration).*

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

### 4. Fingerabdruck-Sensor aktivieren (FPC `10a5:9924`)
```bash
cd fingerprint
chmod +x setup_fingerprint.sh build-install.sh apply-patch.sh
./setup_fingerprint.sh
```
Danach Fingerabdrücke registrieren:
```bash
fprintd-enroll
```

---

### 5. Echten Deep Sleep (<0,39W), Deckelsensor & Stromsparer einrichten

Bisher litten Snapdragon X Elite Geräte unter Linux unter erheblichem Standby-Verbrauch (~10W, Akku nach ca. 6 Stunden leer), da TrustZone-Timer blockierten, Interconnect-Votes offen blieben, PCIe-Root-Ports in D0 feststeckten und Video-Clock-Controller fehlten.

Mit dem neuen Kernelmodul `honor_deep_sleep_fix` und unseren Tuning-Skripten sinkt der Standby-Verbrauch auf **sensationelle 0,389W (Akkulaufzeit im Standby >150 Stunden / über 6 Tage)** bei sofortigem, fehlerfreiem Aufwachen!

#### Option A: Echten Deep Sleep aktivieren (Empfohlen)
```bash
cd power
chmod +x setup_deep_sleep.sh
./setup_deep_sleep.sh
```
Was dieses Skript tut:
1. Baut und installiert `honor_deep_sleep_fix.ko` mit:
   - EL1 Physical Timer Mirroring (`CNTV` -> `CNTP` mit `CTL_MASK`).
   - PCIe Root Port `0004:00:00.0` `bridge_d3 = 1` Fix (senkt PCIe DDR-Interconnect-Votes auf 0).
   - Dynamic Power-Domain Synchronisation für GCC und GPUCC Clock-Controller.
   - System-Sleep-Only Governor für `power-domain-system` (`0x0200c354`, DRIPS).
   - USB-C LDO Hold für felsenfeste Stabilität.
2. Richtet `/etc/modules-load.d/honor-sleep.conf` ein (lädt `videocc-sm8550` und `honor_deep_sleep_fix` automatisch beim Booten).
3. Installiert Udev-Regeln (`92-snapdragon-wakeup.rules`), die Phantom-Wakeups verhindern und den flatternden USB-Fingerprint-Reader stilllegen.
4. Installiert den Sleep-Hook (`snapdragon-power-saver.sh`), der das WLAN vor dem Suspend schont und nach dem Aufwachen automatisch reaktiviert.

#### Option B: Schnelles Basis-Standby (Nur Deckelschalter & USB/WLAN-Sparer)
```bash
cd power
chmod +x setup_lid.sh
./setup_lid.sh
```

#### Option C: Vollständiger 0,00W Tiefschlaf (`suspend-then-hibernate` für wochenlanges Lagern)
```bash
cd power
chmod +x setup_suspend_hibernate.sh
./setup_suspend_hibernate.sh
```
Was dieses Skript tut:
1. Erstellt eine unkomprimierte 34 GB Swapdatei auf Btrfs (`/swap/swapfile`).
2. Bindet das `resume`-Modul in Dracut ein und baut das Initramfs neu.
3. Richtet systemd so ein, dass beim Zuklappen sofort `s2idle` aktiv wird, und nach 15 Minuten Inaktivität automatisch in den **vollständig stromlosen Ruhezustand (0,00W)** gewechselt wird.
4. Beim Aufklappen/Starten ist das System in **ca. 3 Sekunden** von der UFS-SSD wieder voll da.

---

### 6. Touchscreen Phantom-Mute-Popups stummschalten
```bash
cd input
chmod +x setup_input.sh
./setup_input.sh
```

---

### 7. Offline-Updates & RTC-Uhrzeit sichern
```bash
cd system
chmod +x setup_clock.sh save-restore-clock.sh
./setup_clock.sh
```

---

### 8. Windows 11 Dual-Boot einrichten
Um Windows 11 parallel zu Linux über das GRUB-Menü zu starten, trage den Chainloader-Block in `/boot/efi/EFI/Boot/grub.cfg` ein (siehe `boot/grub.cfg.example`):
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

## ❓ FAQ & Technische Hintergründe

### Warum geht Linux im Standby nicht auf 0,3W wie Windows?
Windows nutzt den monolithischen Treiber `qcpep8380.sys` (4,7 MB), der direkt über interne Hardware-Kanäle (QMP/AOP) die Stromschienen abdreht. In Linux arbeiten über 40 dezentrale Treiber (`genpd`, `rpmh-rsc`, `drm/msm`). Der Qualcomm-Hardware-Aggregator (RPMh) verlangt Einstimmigkeit: Wenn auch nur ein Treiber oder der proprietäre Honor-EC einen Vote hält, bricht die SoC-Hauptschiene (`cxsd`) nicht zusammen. **Suspend-Then-Hibernate** löst das Problem elegant, indem nach 15 Minuten 0,00 Watt verbraucht werden.

### Was ist die 73,4 MB große Datei `Persisted_Capsules.bin` in der EFI-Partition?
Hex-Analysen zeigen, dass 73.400.306 von 73.400.320 Bytes reine Nullen (`0x00`) sind. Es handelt sich um einen ab Werk reservierten Puffer für künftige UEFI-Kapseln, nicht um ein fehlgeschlagenes oder anstehendes Update.

---

## 🤝 Upstream-Beitragsziele
Das langfristige Ziel dieses Projekts ist es, diese Fixes (eDP Widebus-Unterstützung, DPU Dual-Mixer SSPP-Offset-Berechnung, Panel-Modeline und Device Tree) upstream an die offiziellen Linux-Kernel-Mailinglisten (`linux-arm-msm` und `dri-devel`) zu übermitteln, damit künftige Distributionen das Honor MagicBook Art 14 direkt ab Werk unterstützen.

---

## 🙏 Danksagungen & Credits

Dieses Projekt baut auf der Arbeit herausragender Entwickler und Communities in den Linux-, Qualcomm- und Open-Source-Ökosystemen auf. Unser besonderer Dank gilt:

- **Fingerabdrucksensor-Unterstützung (`10a5:9924`):**
  - Besonderer Dank an **[Terrydaktal](https://github.com/Terrydaktal)** für das Reverse-Engineering der FPC-Sensor-Initialisierungssequenz (`0x12` + `0x14` + `0x90`) und die Entwicklung des [libfprint-fpc-10a5-9924](https://github.com/Terrydaktal/libfprint-fpc-10a5-9924)-Patches.
  - Den Upstream-Maintainern von **[libfprint](https://gitlab.freedesktop.org/libfprint/libfprint)** auf freedesktop.org.
- **Audio- & SoundWire-Subsystem:**
  - **Srinivas Kandagatla** (Linaro / Qualcomm) und **Krzysztof Kozlowski** für die Entwicklung der ASoC AudioReach (`q6apm`), SoundWire (`soundwire_qcom`) und WSA884x-Verstärkertreiber im Mainline-Linux-Kernel.
  - Den Maintainern des **[ALSA Project](https://github.com/alsa-project/alsa-ucm-conf)** und von **[linux-firmware](https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git)** für die UCM2-Profile und AudioReach-Topologie-Frameworks.
  - Dem Team von **[PipeWire](https://gitlab.freedesktop.org/pipewire/pipewire)** für Low-Latency-Audio und räumliches Quad-Speaker-Upmixing.
  - **[EasyEffects](https://github.com/wwmm/easyeffects)** und **[LSP Plugins](https://lsp-plug.in/)** für DSP-Equalization und Lautstärkemanagement.
- **Qualcomm Snapdragon Display & Grafik:**
  - **Dmitry Baryshkov**, **Rob Clark** und dem Linux MSM DRM-Team für die Treiber der Snapdragon Display Processing Unit (`msm/dpu`) und des DisplayPorts (`msm/dp`).
  - **Douglas Anderson** und Upstream-Contributors für das generische `panel-edp`-Treiber-Framework.
- **Device Tree & Community:**
  - Der **Linaro Qualcomm Working Group** und der breiteren Snapdragon X Elite Linux-Community für kontinuierliche Reverse-Engineering- und Bring-up-Arbeit auf ARM64-Laptops.
- **Power Management & Deep Sleep-Forschung:**
  - **[justririll](https://github.com/justririll)** für die Pionierarbeit im [x1e-sleep](https://github.com/justririll/x1e-sleep)-Projekt auf Snapdragon X Elite (`X1E80100`), das Aufdecken der ADSP Modern Standby GLINK-Schnittstelle (`qcom_adsp_pwr_lmts`) und den Nachweis von Hardware-Low-Power-Zuständen.
  - **[n1c0la84](https://github.com/n1c0la84)** für die tiefgehenden Stromspar-Untersuchungen in [book4-edge-linux](https://github.com/n1c0la84/book4-edge-linux), den Vergleich der Suspend-Architekturen zwischen EL1/Gunyah und EL2/slbounce sowie LPASS-Macro-Runtime-PM-Fixes.

---

## 📄 Lizenz
- Kernel-Patches und Device Trees stehen unter **GPL-2.0** / **BSD-2-Clause**.
- Fingerabdruck-Patches sind unter **LGPL-2.1** lizenziert (analog zu Upstream-`libfprint`).

