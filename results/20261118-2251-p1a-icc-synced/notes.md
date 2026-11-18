# Phase 1a Observations (2026-11-18)

- Power source: Battery only (`status=Discharging`, AC/USB/WLS `online=0`).
- Screen: On (`dpms=On`, `bl_power=0`), brightness unchanged at `52/255` before, between, and after both 180 s runs (`systemd-inhibit --what=idle:sleep`).
- `force_sync_state.sh apply-icc`: failed to write `1` to `1700000.interconnect/state_synced` and `interconnect-1/state_synced` (both files show mode `-rw-r--r--`); `INT_MAX` node count remained `61`.
- `dmesg-after-apply.txt`: 0 new kernel log lines after `apply-icc`.
- Post-apply device checks (via SSH):
  - Display: `dpms=On`, `bl_power=0`, `brightness=52/255`.
  - Wi-Fi: `wlP4p1s0` remained connected (SSH active throughout).
  - Audio: `aplay -l` lists `Karte 0: X1E80100HONORMa` (MultiMedia1, 2, 5, 6).
  - USB: `lsusb` lists Bus 001–006 root hubs.
  - Keyboard/touchpad/physical display flicker/audio playback: not physically verified yet via SSH (user check pending).
