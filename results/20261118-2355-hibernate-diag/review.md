# Review: Hibernate SELinux diagnosis & resume hang — `20261118-2355-hibernate-diag`

Reviewer: Antigravity (2026-11-19)

## Raw-data & logic review
- Checked `notes.md` (note: no separate raw journal/AVC files were saved alongside `notes.md` in this folder, only quoted excerpts in `notes.md` — acceptable since the restore boot produced no journal, though saving the `ausearch`/AVC lines and the hibernation-entry boot journal excerpt into a `.txt` file would have been cleaner).
- **SELinux diagnosis is completely solid:**
  - `/swap` (Btrfs subvolume `root/swap`) had `unlabeled_t` (reverted to `default_t`), causing `avc: denied { search }` for `systemd_logind_t` since at least 2026-11-14.
  - Applying `semanage fcontext -a -t swapfile_t '/swap(/.*)?'` + `restorecon -RFv /swap` immediately flipped `CanHibernate` to `yes` with zero AVCs and allowed `systemctl hibernate` to write the image and power off.
- **Resume hang analysis is well-reasoned and appropriately cautious:**
  - Observing: boot log -> grey screen (a few seconds) -> **dark blue screen hang** -> no ping/SSH -> next boot logs `PM: Image not found (code -22)`.
  - Clearing of the swap signature proves `swsusp_read()` in the boot kernel succeeded in locating and reading the image.
  - **One important nuance to add:** The grey screen before the dark blue screen is almost certainly `plymouth` running on `msm.ko` DRM inside `/boot/efi/initrd_native.img` (which contains `msm.ko`, `panel-edp.ko`, `plymouth`, AND `qcom-adsp`!). Therefore the hang can occur either during the **boot kernel's `PMSG_FREEZE` / `swsusp_arch_resume()` handoff** (with `msm` DPU/GMU and `qcom-adsp` already live in initramfs) OR during the **restored kernel's `syscore_resume()` / `PMSG_RESTORE` device resume**. Both leave the swap header cleared and nothing in the journal.
- **Correct safety decision:** Reverting the SELinux label so lid-close falls back to working `s2idle` instead of hanging on every resume was the right call. Note also that `README.md` / `README_DE.md` / `HANDOFF.md` should NOT claim "working 0.00W hibernate" until restore is proven and reviewed.
- **Minor wording typo in `notes.md` line 44–45:** "Kernel cmdline boots `/vmlinuz` with `resume=/dev/sda9 resume_offset=1655338`, not the documented `/boot/efi/initrd_native.img` path" — GRUB *does* load `initrd /initrd_native.img` (which is `/boot/efi/initrd_native.img` relative to `hd0,gpt2`) alongside `linux /vmlinuz` and `resume=/dev/sda9 resume_offset=1655338`; what differed from the older docs was `resume=/dev/sda9` instead of `resume=UUID=...`.

## Verdict
**Reviewed and accepted.** Root cause of the silent hibernate refusal (SELinux `unlabeled_t`/`default_t` on `/swap`) is proven; hibernate restore is confirmed broken (hang after image load) and must remain disabled until diagnosed (see research & risk-ordered capture plan in `docs/AGENT_CHANNEL.md`).
