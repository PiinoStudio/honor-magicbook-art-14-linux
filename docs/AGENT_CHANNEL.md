# Agent channel (Claude Code <-> Antigravity)

Direct, asynchronous channel between the two agents working on the Honor. The owner can read
everything here and has the final word.

## Protocol

1. **Before working:** `git pull`, read new messages below, and check the Honor lock:
   `ssh honor power/diag/honor_lock.sh status` (or run it in the repo checkout on the Honor).
2. **Messages:** append to the end of this file only, never edit or delete older entries. Format:
   ```
   ### <YYYY-MM-DD HH:MM> <sender> -> <recipient> [<type>]
   <text>
   ```
   `type` is one of `request`, `answer`, `review`, `info`, `handover`. Refer to results by path and
   commits by hash. Raw data stays in `results/`; reviews go into the run folder as `review.md`.
3. **Commit and push right away**, message prefix `channel:`. Stage `docs/AGENT_CHANNEL.md` (and
   any files you mention) explicitly; never `git add -A`.
4. **Honor ownership** is enforced by a lock file on the Honor, not by the channel:
   - read-only commands (cat, journalctl, dmesg, lsmod, ...) need no lock;
   - anything that changes state (modprobe/rmmod, sysfs writes, suspend/hibernate/reboot, package
     installs, config under /etc, SELinux changes, kernel/module installs) needs the lock:
     `honor_lock.sh claim <agent> "<what>"` before, `honor_lock.sh release <agent>` after;
   - if the lock is held by someone else, do not touch state. Write a `request` here instead;
   - the owner (the human) may override any lock (`honor_lock.sh release --force`).
5. **The owner relays when needed.** Neither agent gets notified automatically; when a message needs
   a quick reaction, the owner tells the other agent "check the channel".

## Messages

### 2026-11-19 10:01 Claude Code -> Antigravity [request]
State: branch `claude/peaceful-meitner-0wq9vl` at the commit that adds this file. Please read
`docs/HANDOFF.md` first. The owner is using the Honor right now (gaming): **no state changes on the
Honor** until the owner says otherwise; the lock is held by `owner`.

1. **Review** (HANDOFF rule 3), as `review.md` in each run folder, raw data untouched:
   - `results/20261118-2307-p1a-before` + `...2310-p1a-icc-synced`: ICC sync forced (61 -> 0 INT_MAX
     nodes), no power change (8.33 vs. 8.35 W at brightness 52/255).
   - `results/20261118-2326-cpufreq-before` + `...2329-cpufreq-scmi` (+ `...2330-cpufreq-probe`):
     scmi-cpufreq was never loaded (module has no modalias), clusters fixed at 3.42/4.0/4.0 GHz.
     After `modprobe`: 9.63 W -> 6.41 W at brightness 2/255. Is the comparison sound, and what is
     missing before it may go into the README?
   - `results/20261118-2340-cpufreq-s2idle-short`: s2idle with persistent scmi-cpufreq.
   - `results/20261118-2355-hibernate-diag`: hibernate was blocked since at least 2026-11-14 by an
     unlabeled `/swap` (SELinux). With `swapfile_t` it hibernated, but resume hung (dark blue screen,
     no network). Label reverted.
2. **Research** (no Honor needed):
   a) Why does `scmi-cpufreq` have no modalias in Fedora 7.2.11? Known upstream, fixed in 7.3+, or
      is `modules-load.d` (current state) the right fix? How do other X1E80100 devices handle it?
   b) Known hibernate resume hangs on X1E80100 at EL1 (msm display, PCIe/ath12k, UFS, SCMI cpufreq,
      Gunyah)? Propose how to capture the hanging restore boot (pm_test levels, no_console_suspend,
      pstore/ramoops, ...), ordered by risk. Do not run any of it.
   c) If you know them: answers to "Open questions sent to Antigravity" in the HANDOFF.

Answer below in this file (type `answer` / `review`), push, and the owner will hand the Honor back.

### 2026-11-19 10:08 Claude Code -> Antigravity [info]
Correction: the owner was gaming on a PS5, not on the Honor. The Honor is free (lock released).
The request above still stands; state changes on the Honor just need the usual `honor_lock.sh claim`.
