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
- **Deckelsensor (Lid Switch) & Display-Aus:** Echter Hardware Hall-Sensor (`gpio-keys` auf TLMM GPIO 92) mit 20 ms Hardware-Entprellung versetzt das Notebook beim Zuklappen in den Standby und weckt es beim Aufklappen sofort wieder auf.
- **Power Management & Suspend-Optimierung (`s2idle` / S4):** Umfassende Energiespar-Anpassungen:
  - PCIe Root Port Bandbreitenreduktion im Sleep (`bridge_d3 = 0` verhindert DWC L2 Timeout Abbrüche).
  - Dynamischer Power Domain Sync für GCC und GPUCC Clock-Controller.
  - Reduktion der Interconnect Sleep-Votes auf 0 MB/s.
  - Automatisches WLAN-Powerdown vor dem Standby und USB-Flapping-Filter.
- **0,00W Tiefschlaf (`suspend-then-hibernate`, Empfohlen):** Automatischer Wechsel in den Festplatten-Ruhezustand (`suspend-then-hibernate`, 0,00W Leistungsaufnahme) für zuverlässigen Schutz vor Akkuentladung im Alltag und bei längerer Lagerung.
- **EL2-Boot & Hardware-DRIPS Forschung:** Vorbereitung und Fahrplan zur Umgehung des Qualcomm Gunyah Hypervisors via `slbounce`, um echten Hardware-Deep-Sleep (`cxsd` / `ddr` Kollaps) auf EL2 zu erreichen.
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
│   ├── honor_deep_sleep_fix/       # Kernelmodul für sichere Runtime-PM & Sleep-Guards (sync_all_suppliers=0)
│   │   ├── honor_deep_sleep_fix.c
│   │   └── Makefile
│   ├── setup_deep_sleep.sh         # Setup für honor_deep_sleep_fix.ko & Udev-Wakeup-Regeln
│   ├── 92-snapdragon-wakeup.rules  # Udev-Regeln gegen Phantom-Wakeups & USB-Flapping
│   ├── honor-sleep.conf            # /etc/modules-load.d/ Autoload-Konfiguration
│   ├── snapdragon-power-saver.sh   # System-Sleep Hook für sicheren PCIe-Standby & Runtime-PM
│   ├── setup_suspend_hibernate.sh  # Empfohlenes 1-Klick Setup für 0,00W Festplatten-Ruhezustand + Rucksack-Not-Aus
│   ├── 10-runtime-pm.rules         # Udev-Regeln für automatisches Runtime-PM
│   ├── hibernate.conf              # systemd-sleep Policy (HibernateMode=shutdown)
│   ├── lid.conf                    # systemd-logind Konfiguration für Deckelaktion (hibernate)
│   └── setup_lid.sh                # Unmasked Suspend-Targets und richtet Basis-Standby ein
├── docs/
│   └── DEEP_SLEEP_BREAKTHROUGH.md  # Technisches Post-Mortem: Warum s2idle (<0,5W) in EL1 & EL2 scheitert, UFS/SMMU-Fallen & Hibernate-Fixes
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

### 5. Standby, Deckelsensor & 0,00W-Hibernate einrichten

> [!WARNING]
> **Wichtige Negativ-Erkenntnisse zu `s2idle`, EL2 (`slbounce`) und Rucksack-Überhitzung (Vor dem Einrichten lesen!):**
> Frühere Berichte über einen `< 0,4 W` `s2idle`-Standby auf dem Honor MagicBook Art 14 (`MRO-XXX`) hielten einer systematischen Hardware-Prüfung **nicht stand**. Um anderen Entwicklern tagelange Sackgassen zu ersparen, hier die verifizierten Fakten:
> 1. **Unter EL1 (Qualcomm Gunyah Hypervisor):** Gunyah fängt PSCI `0x0200c354` (`power-domain-system` / DRIPS) ab und verhindert das Abschalten der physischen `VDD_CX`- und `DDR`-Stromschienen (`qcom_stats/{cxsd,ddr}` bleiben bei `0`, Verbrauch in `s2idle` ca. 3–8 W).
> 2. **Unter EL2 (`slbounce` / `tcblaunch.exe`):** Der Boot in EL2 (inkl. KVM) funktioniert zwar vollautomatisch über `systemd-boot`, aber sobald `dpm_suspend_noirq()` die `cx`-Stromschiene abschaltet (`of_genpd_sync_state` auf `100000.clock-controller` bei `sync_all_suppliers=1`), während in `honor_el2.dtb` die `iommu@15000000` (`arm,smmu-v3`) aktiv ist, **friert der SoC-Bus sofort hart ein**. Ebenso führt der Aufruf von PSCI `0x0200c354` oder das Laden von `qcom_adsp_pwr_lmts` unter EL2 zu einem kompletten Freeze der Honor-TrustZone/AOP/ADSP-Firmware, aus dem weder Hardware-Timer (`CNTHP`/`CNTP`) noch PDC-GPIO-Interrupts (Deckel GPIO 92, Tastatur `1-003a` GPIO 67) das Gerät wieder aufwecken können.
> 3. **NIEMALS `spm_lvl = 3` auf der Micron UFS 4.0 (`1d84000.ufshc`) setzen:** `spm_lvl = 3` führt beim Aufwachen nach einem GDSC-Power-Cycle zu `ufshcd_uic_hibern8_exit: hibern8 exit failed. ret = 5`, wodurch das Root-Dateisystem stirbt und der Bildschirm schwarz bleibt. Unbedingt auf dem Standardwert `spm_lvl = 5` (mit `sync_all_suppliers = 0`) belassen!
> 4. **Warum frühere Hibernate-Skripte im Rucksack überhitzten:** `dracut -f` aktualisiert nur `/boot/initramfs-...`, aber **nicht** `/boot/efi/initrd_native.img`. Ohne `systemd-hibernate-resume` in `initrd_native.img` und ohne `/etc/tmpfiles.d/hibernate-resume.conf` (`8:9` in `/sys/power/resume`) bleibt `/sys/power/resume` auf `0:0`, der Kernel prüft `/dev/zram0` (Priorität 100 > Swapfile Priorität 10), bricht den Ruhezustand mit `-ENODEV` ab und lässt das Notebook bei geschlossenem Deckel im Rucksack wach weiterlaufen!
>
> Die vollständige technische Analyse ist in [docs/DEEP_SLEEP_BREAKTHROUGH.md](docs/DEEP_SLEEP_BREAKTHROUGH.md) dokumentiert.

Für den produktiven Alltag ist **Option A (0,00W-Hibernate mit `HibernateMode=shutdown` und `FailureAction=poweroff` Rucksack-Not-Aus)** die einzig sichere Lösung:

#### Option A: 0,00W Festplatten-Ruhezustand + Rucksack-Not-Aus (Empfohlen)
```bash
cd power
chmod +x setup_suspend_hibernate.sh
./setup_suspend_hibernate.sh
```
Was dieses Skript tut:
1. Erstellt eine unkomprimierte 34 GB Swapdatei auf Btrfs (`/swap/swapfile`) und schreibt `MAJ:MIN` (`8:9`) sowie `resume_offset` nach `/etc/tmpfiles.d/hibernate-resume.conf`.
2. Baut das `dracut`-Initramfs mit dem `resume`-Modul neu **und kopiert es nach `/boot/efi/initrd_native.img`**.
3. Setzt `HibernateMode=shutdown` (Mainboard schaltet nach dem Speichern des RAM-Abbilds physisch komplett ab → **0,00 W**).
4. Richtet `FailureAction=poweroff` für `systemd-hibernate.service` und `systemd-suspend.service` ein: Sollte der Ruhezustand bei geschlossenem Deckel jemals fehlschlagen, schaltet sich das Gerät sofort komplett aus, statt im Rucksack heißzulaufen.

#### Option B: Basis-Standby & Deckelschalter (`s2idle`)
```bash
cd power
chmod +x setup_lid.sh
./setup_lid.sh
```

#### Option C: Runtime-Power-Management Kernelmodul (`honor_deep_sleep_fix.ko`)
```bash
cd power
chmod +x setup_deep_sleep.sh
./setup_deep_sleep.sh
```
Was dieses Modul tut:
1. Baut und installiert `honor_deep_sleep_fix.ko` (`sync_all_suppliers=0`, `hold_usbc_ldos=1`) mit:
   - PCIe Root Port `0004:00:00.0` `bridge_d3 = 0` Fix (verhindert DWC L2 Timeout Abbrüche).
   - Sperre für `power-domain-system` (`0x0200c354`, DRIPS), um Firmware-Freezes zu verhindern.
   - USB-C LDO Hold für Stabilität.
2. Richtet `/etc/modules-load.d/honor-sleep.conf` und `/etc/modprobe.d/honor-sleep.conf` ein.
3. Installiert Udev-Regeln (`92-snapdragon-wakeup.rules`), die Touchpad/USB-Phantom-Wakeups unterdrücken, aber Tastatur (`1-003a`) und Deckel (`gpio-keys`) als Wakeup-Quelle aktiv lassen.
4. Installiert den Sleep-Hook (`snapdragon-power-saver.sh`), der das WLAN vor dem Suspend schont und nach dem Aufwachen automatisch reaktiviert.

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

