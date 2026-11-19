#!/bin/bash
# honor_lock.sh - who may change state on the Honor right now (run ON the Honor, as the login user)
#
#   honor_lock.sh status                       # show holder (exit 0 = free, 1 = held)
#   honor_lock.sh claim <agent> "<what>"       # take the lock (exit 1 if held by someone else)
#   honor_lock.sh release <agent>              # give it back (only the holder)
#   honor_lock.sh release --force              # owner override
#   honor_lock.sh log                          # history
#
# Agents: claude-code, antigravity, owner. Read-only commands need no lock.
# See docs/AGENT_CHANNEL.md for the protocol.

set -u
LOCK="${HONOR_LOCK_FILE:-$HOME/.honor_agent_lock}"
LOG="$LOCK.log"
GUARD="$LOCK.guard"

now() { date '+%Y-%m-%d %H:%M:%S'; }
holder() { [ -s "$LOCK" ] && sed -n 's/^agent=//p' "$LOCK"; }

exec 9>"$GUARD"
flock -w 5 9 || { echo "could not get guard lock" >&2; exit 2; }

case "${1:-}" in
status)
    if [ -s "$LOCK" ]; then echo "HELD"; cat "$LOCK"; exit 1; else echo "FREE"; exit 0; fi
    ;;
claim)
    agent="${2:?agent name}"; what="${3:?what you are going to do}"
    cur="$(holder)"
    if [ -n "$cur" ] && [ "$cur" != "$agent" ]; then
        echo "HELD by $cur:"; cat "$LOCK"; exit 1
    fi
    printf 'agent=%s\nsince=%s\nwhat=%s\nboot_id=%s\n' "$agent" "$(now)" "$what" \
        "$(cat /proc/sys/kernel/random/boot_id)" > "$LOCK"
    echo "$(now) CLAIM $agent: $what" >> "$LOG"
    echo "claimed by $agent"
    ;;
release)
    agent="${2:?agent name or --force}"; cur="$(holder)"
    if [ -z "$cur" ]; then echo "already free"; exit 0; fi
    if [ "$agent" != "--force" ] && [ "$agent" != "$cur" ]; then
        echo "held by $cur, not $agent (owner can use --force)"; exit 1
    fi
    : > "$LOCK"
    echo "$(now) RELEASE $cur (by $agent)" >> "$LOG"
    echo "released"
    ;;
log)
    tail -n "${2:-20}" "$LOG" 2>/dev/null
    ;;
*)
    sed -n '2,10p' "$0"; exit 2
    ;;
esac
