#!/bin/bash
#
# alt-tab: advance the switcher's highlight by one and repaint the HUD. This does
# NOT change the focused workspace — cmd-tab style, the switch is committed only
# when alt is released, by commit-workspace.sh, which the alt-release helper runs.
#
# Splitting selection from commit is the whole point of the redesign: holding alt
# and tabbing moves a highlight through the ring with no visible workspace changes,
# so intermediate workspaces never flash up on the way to the one you want.
#
# The ring is "every workspace on every monitor, alphabetical" — what
# `list-workspaces --all` returns. The highlight is an index into that list, kept
# in SWITCHER_INDEX_FILE; the paint script reads the same list and the same index,
# so the two agree on order without sharing anything else.

# Homebrew is /opt/homebrew on Apple Silicon and /usr/local on Intel, and
# AeroSpace launches callbacks with a minimal PATH, so set both rather than
# hardcoding one prefix.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/config.sh"

# sketchybarrc creates this, but do not depend on load order: without it every
# write below fails and the HUD simply never appears.
[ -d "$SKETCHYBAR_CACHE_DIR" ] || mkdir -p "$SKETCHYBAR_CACHE_DIR"

# The ring, and how many are in it. One call, shared with the paint script by
# convention (same command, same order).
ring_count=$(aerospace list-workspaces --all --count 2>/dev/null)
[ -n "$ring_count" ] && [ "$ring_count" -gt 0 ] || exit 0

# Where the highlight sits now. Absent (first press of a fresh burst) means start
# from the focused workspace, so the first alt-tab steps off *where you are* rather
# than off the top of the list.
switcher_open=""
[ -f "$SWITCHER_STATE_FILE" ] && read -r switcher_open <"$SWITCHER_STATE_FILE" 2>/dev/null

if [ "$switcher_open" = "on" ] && [ -f "$SWITCHER_INDEX_FILE" ]; then
  read -r index <"$SWITCHER_INDEX_FILE" 2>/dev/null
else
  # Start of a burst: anchor on the focused workspace's position in the ring.
  focused=$(aerospace list-workspaces --focused 2>/dev/null)
  index=$(aerospace list-workspaces --all | grep -nxF "$focused" 2>/dev/null | head -1)
  index=${index%%:*}
  # grep -n is 1-based; the ring is 0-based. Empty (focused not listed) -> -1 so
  # the first advance lands on 0.
  if [ -n "$index" ]; then index=$((index - 1)); else index=-1; fi
fi

case "$index" in '' | *[!0-9-]*) index=-1 ;; esac
index=$(((index + 1) % ring_count))
printf '%s' "$index" >"$SWITCHER_INDEX_FILE"

# Latch the HUD on. commit-workspace.sh flips this back to "off" as it commits, so
# it also serves as the commit's idempotency guard: a second Option release with
# no press in between finds "off" and does nothing.
printf 'on' >"$SWITCHER_STATE_FILE"

# Repaint. No workspace change, so this is the only thing that makes the press
# visible.
sketchybar --trigger aerospace_switcher_open
