#!/bin/bash
#
# alt-tab: advance the workspace ring and raise SketchyBar's switcher HUD, the
# strip of workspace tabs that replaces the window pills while you cycle.
#
# The ring itself is AeroSpace's, fed a global list: `workspace next` on its own
# is scoped to the focused monitor, so a workspace parked on another screen would
# be unreachable. `list-workspaces --all` replaces that list via --stdin, keeping
# AeroSpace's alphabetical order, and --wrap-around closes the circle.
#
# `--all` rather than a filtered list because it is the only form guaranteed to
# contain the *focused* workspace, including when that workspace is empty; without
# the current position in the list there is nothing to advance from.

# Homebrew is /opt/homebrew on Apple Silicon and /usr/local on Intel, and
# AeroSpace launches callbacks with a minimal PATH, so set both rather than
# hardcoding one prefix.
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/config.sh"

# sketchybarrc creates this, but do not depend on load order: without it every
# write below fails and the HUD simply never appears. The test avoids the fork on
# the common path.
[ -d "$SKETCHYBAR_CACHE_DIR" ] || mkdir -p "$SKETCHYBAR_CACHE_DIR"

# Latch the HUD on *before* switching, not after. Changing workspace fires its own
# repaint, and a repaint that starts while the flag is still off paints the
# ordinary window pills — then finishes after ours and wins, leaving the HUD
# stillborn. Writing the flag first means every repaint the switch provokes
# already agrees the HUD is up, whichever order they happen to run in.
printf 'on' >"$SWITCHER_STATE_FILE"

# Claim a press number, which supersedes any hide still pending: only the newest
# sleeper is allowed to act, so holding alt and tabbing never hides mid-cycle.
generation=0
[ -f "$SWITCHER_GEN_FILE" ] && read -r generation <"$SWITCHER_GEN_FILE" 2>/dev/null
generation=$((generation + 1))
printf '%s' "$generation" >"$SWITCHER_GEN_FILE"

aerospace list-workspaces --all | aerospace workspace --wrap-around --stdin next

# Repaint now that the ring has moved, so the HUD highlights where you landed.
sketchybar --trigger aerospace_switcher_open

# Take the HUD down once tabbing stops. Nothing observable says when alt is
# released — AeroSpace has no key-release event and SketchyBar cannot see
# modifiers — so the end of a switching burst has to be inferred from a quiet
# period.
#
# One `sleep` per press, not a poll: nothing waits on it, so it adds no latency to
# the HUD appearing or to any other repaint, and a superseded sleeper exits
# without touching a thing.
(
  sleep "$SWITCHER_HIDE_DELAY"
  current=""
  [ -f "$SWITCHER_GEN_FILE" ] && read -r current <"$SWITCHER_GEN_FILE" 2>/dev/null
  [ "$current" = "$generation" ] || exit 0
  printf 'off' >"$SWITCHER_STATE_FILE"
  sketchybar --trigger aerospace_switcher_close
) >/dev/null 2>&1 &
