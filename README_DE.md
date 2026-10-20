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
- **0,00W Tiefschlaf (Suspend-Then-Hibernate):** Schneller Standby (`s2idle`) beim Zuklappen + automatischer Wechsel nach 15 Minuten in den stromlosen Ruhezustand (0W) mit 3-Sekunden-Resume.
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
│   ├── setup_suspend_hibernate.sh          # 1-Klick Setup für 0W Tiefschlaf & Stromspar-Hooks
│   ├── snapdragon-power-saver.sh           # Standby-Hook (deaktiviert USB-Wakeup & kappt WLAN-Verbrauch)
│   ├── 10-runtime-pm.rules                 # Udev-Regeln für automatisches Runtime-PM
│   ├── hibernate.conf                      # systemd-sleep Policy (15 Min Standby -> Hibernate)
│   ├── lid.conf                            # systemd-logind Konfiguration für Deckelaktion
│   └── setup_lid.sh                        # Unmasked Suspend-Targets und richtet Basis-Standby ein
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

### 5. Deckelsensor, Stromspar-Standby & 0W Tiefschlaf (Hibernate)

Snapdragon X Elite Laptops nutzen unter Linux den `s2idle`-Modus, der aktuell ~2W zieht (da diverse Treiber und der Honor Embedded Controller noch Spannungs-Votes offen halten). Um zu verhindern, dass der Laptop im Rucksack warm wird und Akku verliert, nutzen wir **Suspend-Then-Hibernate**:

#### Option A: Schnelles Standby-Setup (Deckelschalter & USB/WLAN-Sparer)
```bash
cd power
chmod +x setup_lid.sh
./setup_lid.sh
```

#### Option B: Vollständiger 0,00W Tiefschlaf (`suspend-then-hibernate`)
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
