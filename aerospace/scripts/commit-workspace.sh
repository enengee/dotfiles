#!/bin/bash
#
# Commit the switcher's highlighted workspace and take the HUD down. Run by the
# alt-release helper the instant Option comes up, which is what gives the switcher
# its cmd-tab feel: cycle while held, land on release.
#
# It fires on *every* Option release, most of which have nothing to do with the
# switcher, so the first thing it does is check whether a switch is actually in
# progress and return if not. That check is why alt used as an ordinary modifier
# (alt-h to focus left, say) does not trigger a workspace change.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/config.sh"

# No burst in progress: this release is not ours. The common case by far.
state=""
[ -f "$SWITCHER_STATE_FILE" ] && read -r state <"$SWITCHER_STATE_FILE" 2>/dev/null
[ "$state" = "on" ] || exit 0

# Close the HUD first, unconditionally, so a failure below can never strand it up.
# Clearing the index ends the burst: the next alt-tab starts fresh from the
# focused workspace.
printf 'off' >"$SWITCHER_STATE_FILE"

index=""
[ -f "$SWITCHER_INDEX_FILE" ] && read -r index <"$SWITCHER_INDEX_FILE" 2>/dev/null
rm -f "$SWITCHER_INDEX_FILE"

sketchybar --trigger aerospace_switcher_close

# Repaint dismissed the HUD; now act on the selection. A malformed or empty index
# means there is nothing to commit — the HUD is already down, so just stop.
case "$index" in '' | *[!0-9]*) exit 0 ;; esac

# Resolve the index against the same ring the HUD drew from. sed is 1-based.
target=$(aerospace list-workspaces --all 2>/dev/null | sed -n "$((index + 1))p")
[ -n "$target" ] || exit 0

# Already focused (you tabbed a full loop back to where you started): nothing to
# do, and asking would print a harmless "already focused" warning.
focused=$(aerospace list-workspaces --focused 2>/dev/null)
[ "$target" != "$focused" ] || exit 0

exec aerospace workspace "$target"
