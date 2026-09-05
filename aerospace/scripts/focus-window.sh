#!/bin/bash
#
# Focus the Nth window of the focused workspace — the "switch tabs" binding for
# alt-1 .. alt-9 / alt-0.
#
# AeroSpace has no native "focus window by position" command, so the index is
# resolved against its own window list here.
#
# The order deliberately comes from `list-windows --workspace focused`, which is
# the same order SketchyBar's window items are built from (verified identical to
# `list-windows --all` filtered by workspace). That is what makes alt-3 focus the
# third icon you can see rather than an arbitrary window.
#
# Out-of-range indices exit quietly: pressing alt-7 in a workspace holding three
# windows should do nothing, not error.

index=$1

case "$index" in
'' | *[!0-9]*) exit 1 ;;
esac
[ "$index" -ge 1 ] || exit 1

id=$(/opt/homebrew/bin/aerospace list-windows --workspace focused \
  --format '%{window-id}' 2>/dev/null | sed -n "${index}p")

[ -n "$id" ] || exit 0

exec /opt/homebrew/bin/aerospace focus --window-id "$id"
