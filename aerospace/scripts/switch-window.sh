#!/bin/bash
#
# alt-shift-tab: advance the window switcher's highlight by one, within the
# focused workspace, and repaint. The exact analogue of switch-workspace.sh but
# for windows: it changes no focus — commit-window.sh focuses the selected window
# when alt is released.
#
# No separate HUD items: the window pills already show one icon per window in the
# focused workspace, in AeroSpace's order, so the switcher just moves which pill
# is accented. The ring is therefore `list-windows --workspace focused`, the same
# order and count the paint script iterates, so a shared 0-based index lines up
# without the two sharing anything else.

# Homebrew is /opt/homebrew on Apple Silicon and /usr/local on Intel, and
# AeroSpace launches callbacks with a minimal PATH, so set both rather than
# hardcoding one prefix.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/config.sh"

[ -d "$SKETCHYBAR_CACHE_DIR" ] || mkdir -p "$SKETCHYBAR_CACHE_DIR"

# The ring: window ids of the focused workspace, in order. Read as a list so we
# can both count them and map the anchor id to its position.
saved_ifs=$IFS
IFS=$'\n'
ring=($(aerospace list-windows --workspace focused --format '%{window-id}' 2>/dev/null))
IFS=$saved_ifs
ring_count=${#ring[@]}

# Zero or one window: nothing to cycle. Do nothing rather than raise a HUD that
# cannot move.
[ "$ring_count" -gt 1 ] || exit 0

winsw_open=""
[ -f "$WINSW_STATE_FILE" ] && read -r winsw_open <"$WINSW_STATE_FILE" 2>/dev/null

if [ "$winsw_open" = "on" ] && [ -f "$WINSW_INDEX_FILE" ]; then
  read -r index <"$WINSW_INDEX_FILE" 2>/dev/null
else
  # Start of a burst: anchor on the focused window's position, so the first press
  # steps off the window you are on. AEROSPACE_WINDOW_ID is not set for a keybind,
  # so ask.
  focused_id=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)
  index=-1
  i=0
  while [ "$i" -lt "$ring_count" ]; do
    [ "${ring[$i]}" = "$focused_id" ] && index=$i && break
    i=$((i + 1))
  done
fi

case "$index" in '' | *[!0-9-]*) index=-1 ;; esac
index=$(((index + 1) % ring_count))
printf '%s' "$index" >"$WINSW_INDEX_FILE"

# Latch on. commit-window.sh flips this back to "off" as it commits, so it also
# guards against a second Option release committing twice.
#
# Also end any workspace-switch burst: switching modes without releasing Option
# (alt-tab then alt-shift-tab, alt held throughout) must hand over cleanly, or the
# stale flag keeps the workspace HUD showing and lets the release commit the wrong
# mode. Only one switcher is ever "on".
printf 'off' >"$SWITCHER_STATE_FILE"
rm -f "$SWITCHER_INDEX_FILE"
printf 'on' >"$WINSW_STATE_FILE"

# Repaint. No focus change, so this is the only visible effect of the press.
sketchybar --trigger aerospace_switcher_open
