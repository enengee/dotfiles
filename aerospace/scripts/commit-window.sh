#!/bin/bash
#
# Commit the window switcher's highlighted window and end the burst. Run by the
# alt-release helper on Option-up, via commit-switch.sh which dispatches to
# whichever switcher is active. The window analogue of commit-workspace.sh.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/config.sh"

# No burst in progress: not ours.
state=""
[ -f "$WINSW_STATE_FILE" ] && read -r state <"$WINSW_STATE_FILE" 2>/dev/null
[ "$state" = "on" ] || exit 0

# End the burst first, unconditionally, so a failure below cannot leave the pills
# stuck accenting a selection instead of the real focus. Clearing the index makes
# the next alt-shift-tab start fresh from the focused window.
printf 'off' >"$WINSW_STATE_FILE"

index=""
[ -f "$WINSW_INDEX_FILE" ] && read -r index <"$WINSW_INDEX_FILE" 2>/dev/null
rm -f "$WINSW_INDEX_FILE"

# Repaint so the pills drop back to reflecting real focus (which the focus below,
# if any, will then move).
sketchybar --trigger aerospace_switcher_close

case "$index" in '' | *[!0-9]*) exit 0 ;; esac

# Resolve the index against the same ring switch-window.sh used. Re-read rather
# than cache: it is one call, and it keeps the two scripts sharing only the index.
target=$(aerospace list-windows --workspace focused --format '%{window-id}' 2>/dev/null | sed -n "$((index + 1))p")
[ -n "$target" ] || exit 0

exec aerospace focus --window-id "$target"
