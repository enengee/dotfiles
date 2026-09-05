#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Kept deliberately free of `source` lines: showing seconds means update_freq=1,
# so this runs once a second and every avoidable millisecond is background CPU.
sketchybar --set "$NAME" label="$(date '+%a %d %b %H:%M:%S')"
