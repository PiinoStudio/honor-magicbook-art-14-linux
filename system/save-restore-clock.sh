#!/bin/bash
CLOCK_FILE="/var/lib/system-clock-saved"
case "$1" in
    save)
        date -u +%s > "$CLOCK_FILE"
        ;;
    restore)
        if [ -s "$CLOCK_FILE" ]; then
            SAVED=$(cat "$CLOCK_FILE" 2>/dev/null)
            CURRENT=$(date -u +%s)
            if [ -n "$SAVED" ] && [ "$SAVED" -gt "$CURRENT" ] 2>/dev/null; then
                date -u -s "@$SAVED"
            fi
        fi
        ;;
esac
