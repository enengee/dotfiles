#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

sketchybar --set "$NAME" label="$(date '+%a %d %b %H:%M')"
