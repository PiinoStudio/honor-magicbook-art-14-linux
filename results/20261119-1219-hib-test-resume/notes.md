# Hibernate: pm_test levels and test_resume (2026-11-19, Claude Code via SSH, owner present)

Covers `20261119-1206-hib-pmtest` and `20261119-1219-hib-test-resume`. Same boot as the p2c s2idle run
(repo module `drips_mode=1`, ondemand, ICC synced). `/swap` SELinux label unchanged (`default_t`):
hibernation was triggered by writing to `/sys/power/state` directly, which bypasses logind. Lid policy
unchanged (still falls back to s2idle).

## pm_test (`echo <level> > /sys/power/pm_test; echo disk > /sys/power/state`)
| level | result |
|---|---|
| freezer | rc 0 |
| devices | rc 0 (freeze 0.54 s, restore 0.70 s) |
| platform | rc 0 |
| processors | rc 0 (non-boot CPUs off/on; harmless `IRQ12x: set affinity failed(-22)`) |
| core | rc 0 |
`dmesg-*.txt` only captured freezer and devices (dmesg buffer timing); the complete kernel log of all
levels is in `journal-kernel-pmtest.txt`.

## test_resume (`echo test_resume > /sys/power/disk; echo disk > /sys/power/state`)
- rc 0. Image created (1 545 329 pages, ~5.9 GiB), written to `/swap/swapfile`, read back and restored in
  the same boot: `Timekeeping suspended for 28.543 seconds`, `Hibernation image restored successfully`.
  System fully usable afterwards, SSH and Wi-Fi back. `/sys/power/disk` reset to `shutdown`.
- 52 `WARNING`s during restore, all `clk_core_unprepare`/`clk_core_disable` from
  `amba_pm_runtime_suspend` ("qdss already disabled/unprepared"): CoreSight/QDSS debug components
  disabling an already-off clock. Noise, not a hang candidate.

## Conclusion
Everything the running kernel does for hibernate works: freezing, device freeze/restore, CPU
hotplug, syscore, writing and reading the image, jumping back into it. Yesterday's hang is therefore
in what only the **cold-boot restore** adds: firmware/UEFI/Gunyah re-init after power-off and the
**boot kernel + initrd** (`initrd_native.img` loads `msm`, `panel-edp`, plymouth and `qcom-adsp`
before `systemd-hibernate-resume`).

## Next test (needs the owner at the machine for GRUB)
Real hibernate via `/sys/power/state` (no SELinux change), restore boot with a one-shot GRUB edit:
`modprobe.blacklist=msm,qcom_q6v5_pas rd.plymouth=0 plymouth.enable=0 no_console_suspend`
(keep `resume=`/`resume_offset=`). If that resumes, rebuild the resume initrd without msm/adsp.
If not, add `initcall_debug ignore_loglevel` and photograph the last lines.
