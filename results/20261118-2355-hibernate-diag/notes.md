# Why logind refuses hibernate (2026-11-18, Claude Code via SSH, read-only)

## Symptom
`systemd-logind: Requested hibernate operation is not supported, using regular suspend instead.`
`HandleLidSwitch=hibernate` therefore silently suspends (s2idle). `CanHibernate` over D-Bus returns
`Access denied` even as root, while `CanSuspend` returns `yes`. Seen since at least 2026-11-14.

## Root cause: SELinux label on the swap subvolume
- `/swap` is a btrfs subvolume (`root/swap`, inode 256) holding `/swap/swapfile` (34G, prio 10,
  offset 1655338 = `resume_offset`, `/sys/power/resume` = 8:9).
- Labels: `/swap/swapfile` is `unconfined_u:object_r:unlabeled_t:s0`, `/swap` is unlabeled too;
  policy default (`matchpathcon`) would be `default_t`. No fcontext rule exists for `/swap`.
- SELinux is `Enforcing` (`selinux-policy-targeted-45.21-1.fc45`). The journal holds 25 denials like:
  `avc: denied { search } for comm="systemd-logind" name="swap" dev="sda9" ino=256
   scontext=system_u:system_r:systemd_logind_t:s0 tcontext=system_u:object_r:unlabeled_t:s0 tclass=dir`
  (first on 2026-11-14 13:37). logind cannot inspect the swap file, so its hibernation safety check
  fails and it reports hibernate as unsupported.
- Everything else looks fine: `/sys/power/state` has `disk`, `/sys/power/disk` = `[shutdown]`,
  `SwapFree` 42 GiB vs. `Active(anon)` 1.5 GiB, lockdown `none`, zram (prio 100) is ignored by
  systemd for hibernation. `systemd-hibernate-resume` saying "Unable to resume ... continuing boot"
  is the normal message when no image exists.

## Proposed fix (needs owner approval, changes persistent SELinux config)
```bash
sudo semanage fcontext -a -t swapfile_t '/swap(/.*)?'
sudo restorecon -RFv /swap
```
Then check `CanHibernate` and the journal for new AVCs, and test a real hibernate/resume cycle
(owner presses the power button). Revert: `semanage fcontext -d '/swap(/.*)?' && restorecon -RFv /swap`.

## Fix applied and hibernate test (owner approved, 23:50)
- `semanage fcontext -a -t swapfile_t '/swap(/.*)?'` + `restorecon -RFv /swap`: both relabeled to
  `swapfile_t`. `CanHibernate` -> `yes` (root) / `challenge` (user), no new AVC. **The label fix works.**
- `systemd-run --on-active=30 systemctl hibernate` at 23:51:38. Journal of that boot ends with
  `systemd-sleep: Performing sleep operation 'hibernate'` and `PM: hibernation: hibernation entry`
  (23:51:39); the machine powered off.
- Owner powered on, chose Fedora: boot log, grey screen for a few seconds, then **hang on a dark blue
  screen**. No ping, no SSH. The restore boot left nothing in the journal.
- Owner forced power-off (long press) and booted normally (without `noresume`). That boot logged
  `PM: Image not found (code -22)`, i.e. the hibernation signature was already gone. Together with the
  hang after the boot log, this suggests the restore kernel did load the image and the **hang happened
  while resuming devices in the restored system**, not while writing or finding the image.
  Not proven: no log from the restore boot.
- Kernel cmdline boots `/vmlinuz` with `resume=/dev/sda9 resume_offset=1655338`, not the documented
  `/boot/efi/initrd_native.img` path. scmi-cpufreq was loaded in the hibernated system (new since today).

## Reverted (00:00)
- `semanage fcontext -d '/swap(/.*)?'` + `restorecon -RFv /swap` -> labels now `default_t`,
  `CanHibernate` -> `Access denied` again, so lid close suspends (s2idle) as before.
  Hibernate must stay disabled until resume works.

## Conclusion
Hibernate was never actually happening on this install since at least 2026-11-14 (SELinux), so the
"working hibernate fallback" in HANDOFF is not true for the current setup. Once enabled, resume hangs.
Next: capture the restore boot (e.g. `no_console_suspend`, `printk.devkmsg=on`, pstore/ramoops or a
`pm_test` hibernate level such as `devices`/`platform` via `/sys/power/pm_test`) and test once
without scmi-cpufreq to rule it out.
