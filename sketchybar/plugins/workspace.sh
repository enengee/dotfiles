#!/bin/bash
#
# Repaints, for every monitor, the workspace visible on it and an app icon for
# each window inside that workspace.
#
# This runs on every workspace change, focus change and mode change, so its
# wall time is latency the user feels. Three things keep it down:
#
#   * Forks are the dominant cost, not work. Every `aerospace` call, pipeline
#     and command substitution is a process spawn of 3-25ms, which is why the
#     parsing below uses bash parameter expansion instead of awk, grep, cut and
#     sort. The only forks left are two `aerospace` reads and one `sketchybar`
#     write.
#   * Two AeroSpace reads, not four: `list-workspaces --all` reports the
#     visible *and* focused flags together, and the binding mode is cached.
#   * Per-item diffing against the previous run, cached in $STATE_FILE. Without
#     it every event would rewrite all ~44 items and SketchyBar would visibly
#     re-layout the whole bar; a focus change alters two or three items.
#
# It only ever *sets* items — the item set itself is fixed, created once by
# items/workspace.sh for display ids 1..MAX_DISPLAYS. Plugging or unplugging a
# monitor is therefore an ordinary repaint here, with nothing to add, remove or
# reload; see the note in items/workspace.sh for why that matters.
#
# `#!/bin/bash` rather than `#!/usr/bin/env bash` deliberately: it saves an exec
# on a hot path, and /bin/bash on macOS is 3.2, so the 3.2-only constraints above
# are enforced rather than accidental.

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

# Values below are split on newlines by assigning to arrays with IFS. Pathname
# expansion has to be off or a window belonging to an app named, say, `*` would
# expand to a directory listing.
set -f

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/config.sh"
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"
source "$CONFIG_DIR/plugins/icon_map.sh"

# --- read AeroSpace state ----------------------------------------------------
# Both flags come from one call. Workspaces are read rather than derived from the
# window list because a monitor showing an *empty* workspace still needs its name
# drawn, and an empty workspace contributes no window rows.
workspace_rows=$(aerospace list-workspaces --all \
  --format '%{monitor-appkit-nsscreen-screens-id}|%{workspace}|%{workspace-is-visible}|%{workspace-is-focused}')

# There is no %{window-is-focused} placeholder, so the focused window id has to
# come from somewhere. AeroSpace's on-focus-changed passes it in the trigger, so
# the most frequent event of all needs no extra call; everything else asks.
window_rows=$(aerospace list-windows --all \
  --format '%{workspace}|%{window-id}|%{app-name}')

if [ -n "$FOCUSED_WINDOW_ID" ]; then
  focused_window=$FOCUSED_WINDOW_ID
else
  focused_window=$(aerospace list-windows --focused --format '%{window-id}' 2>/dev/null)
fi

saved_ifs=$IFS
IFS=$'\n'
workspace_lines=($workspace_rows)
window_lines=($window_rows)
IFS=$saved_ifs

# --- binding mode ------------------------------------------------------------
# AeroSpace's menu bar icon appends "(S)" while the service mode is active; do
# the same on the focused monitor's pill.
#
# Cached, because this script also runs on every focus change and
# `aerospace list-modes --current` would put a third CLI round trip on a path
# that has nothing to do with modes.
if [ "$SENDER" = "aerospace_mode_change" ] || [ ! -f "$MODE_STATE_FILE" ]; then
  aerospace list-modes --current >"$MODE_STATE_FILE" 2>/dev/null
fi
read -r mode <"$MODE_STATE_FILE" 2>/dev/null

mode_suffix=""
if [ -n "$mode" ] && [ "$mode" != "main" ]; then
  # "service" -> " (S)", matching AeroSpace's own indicator. The only fork on
  # this branch, and it is reached only on an actual mode change.
  mode_suffix=" ($(printf '%s' "${mode:0:1}" | tr '[:lower:]' '[:upper:]'))"
fi

# --- nothing to do? -----------------------------------------------------------
# Several subscribed events fire without changing anything the bar shows —
# front_app_switched in particular. Comparing the raw AeroSpace output lets those
# return before doing any per-item work.
inputs="$workspace_rows
$window_rows
$focused_window
$mode"

previous_inputs=""
[ -f "$INPUT_STATE_FILE" ] && previous_inputs=$(<"$INPUT_STATE_FILE")
if [ "$inputs" = "$previous_inputs" ] && [ -f "$STATE_FILE" ]; then
  exit 0
fi
printf '%s' "$inputs" >"$INPUT_STATE_FILE"

# --- desired state -----------------------------------------------------------
# Parallel arrays instead of one map: bash 3.2 has no associative arrays. `flat`
# holds the actual sketchybar argv, sliced per item on emit.
names=() sigs=() offsets=() lengths=() flat=()

push_item() {
  local name="$1"
  shift
  names+=("$name")
  sigs+=("$*")
  offsets+=("${#flat[@]}")
  lengths+=("$(($# + 2))")
  flat+=(--set "$name" "$@")
}

# Display groups are walked in ascending id order, and every group is emitted on
# every run — including the ones with no monitor behind them. Two reasons:
#
#   * The diff below is positional, so the emit order has to be the same on
#     every run or it reports changes that are not there. AeroSpace lists
#     workspaces by name, so driving the loop off its output would reorder the
#     items whenever the visible workspace names sorted differently.
#   * A group whose monitor is gone has to be blanked, not skipped. Its items
#     keep whatever was last painted, and that stale content would flash back
#     onto the bar the moment the display id exists again.
#
# Emitting the hidden groups is close to free: their signatures do not change
# between runs, so the diff sends nothing.
display=0
while [ "$display" -lt "$MAX_DISPLAYS" ]; do
  display=$((display + 1))

  # The workspace visible on this display, if any. A monitor showing an *empty*
  # workspace still needs its name drawn, which is why this comes from the
  # workspace list rather than being derived from the window list.
  workspace="" is_focused="false" has_monitor=0
  for line in "${workspace_lines[@]}"; do
    # display|workspace|is-visible|is-focused
    [ "${line%%|*}" = "$display" ] || continue
    rest=${line#*|}
    candidate=${rest%%|*}
    rest=${rest#*|}
    [ "${rest%%|*}" = "true" ] || continue
    workspace=$candidate
    is_focused=${rest#*|}
    has_monitor=1
    break
  done

  if [ "$has_monitor" = "0" ]; then
    push_item "workspace.$display" drawing=off label=""
    slot=0
    while [ "$slot" -lt "$MAX_WINDOW_SLOTS" ]; do
      slot=$((slot + 1))
      push_item "window.$display.$slot" drawing=off icon="" click_script=""
    done
    push_item "overflow.$display" drawing=off label=""
    continue
  fi

  # Accent the pill on the monitor that has focus; dim the other one. The mode
  # indicator goes on the focused pill only, since the mode is global and that
  # is where you are looking.
  if [ "$is_focused" = "true" ]; then
    push_item "workspace.$display" \
      drawing=on \
      label="$workspace$mode_suffix" \
      background.color="$WS_FOCUSED_BG" \
      icon.color="$WS_FOCUSED_FG" \
      label.color="$WS_FOCUSED_FG"
  else
    push_item "workspace.$display" \
      drawing=on \
      label="$workspace" \
      background.color="$WS_UNFOCUSED_BG" \
      icon.color="$WS_UNFOCUSED_FG" \
      label.color="$WS_UNFOCUSED_FG"
  fi

  # Windows in this workspace, in AeroSpace's order. Counted first so the
  # overflow marker knows how many are hidden.
  ids=() apps=()
  for window_line in "${window_lines[@]}"; do
    [ "${window_line%%|*}" = "$workspace" ] || continue
    rest=${window_line#*|}
    ids+=("${rest%%|*}")
    apps+=("${rest#*|}")
  done
  total=${#ids[@]}

  slot=0
  while [ "$slot" -lt "$MAX_WINDOW_SLOTS" ] && [ "$slot" -lt "$total" ]; do
    index=$slot
    slot=$((slot + 1))

    __icon_map "${apps[$index]}"

    if [ "${ids[$index]}" = "$focused_window" ]; then
      background=$WIN_FOCUSED_BG foreground=$WIN_FOCUSED_FG
    else
      background=$WIN_INACTIVE_BG foreground=$WIN_INACTIVE_FG
    fi

    push_item "window.$display.$slot" \
      drawing=on \
      background.color="$background" \
      icon.color="$foreground" \
      icon="$icon_result" \
      click_script="aerospace focus --window-id ${ids[$index]}"
  done

  # Hide the slots this workspace does not need.
  while [ "$slot" -lt "$MAX_WINDOW_SLOTS" ]; do
    slot=$((slot + 1))
    push_item "window.$display.$slot" drawing=off icon="" click_script=""
  done

  if [ "$total" -gt "$MAX_WINDOW_SLOTS" ]; then
    push_item "overflow.$display" drawing=on label="$((total - MAX_WINDOW_SLOTS))"
  else
    push_item "overflow.$display" drawing=off label=""
  fi
done

# --- diff against the previous run -------------------------------------------
previous_names=() previous_sigs=()
if [ -f "$STATE_FILE" ]; then
  while IFS=$'\t' read -r previous_name previous_sig; do
    previous_names+=("$previous_name")
    previous_sigs+=("$previous_sig")
  done <"$STATE_FILE"
fi

changed=()
index=0
while [ "$index" -lt "${#names[@]}" ]; do
  if [ "${names[$index]}" != "${previous_names[$index]:-}" ] ||
    [ "${sigs[$index]}" != "${previous_sigs[$index]:-}" ]; then
    changed+=("${flat[@]:${offsets[$index]}:${lengths[$index]}}")
  fi
  index=$((index + 1))
done

if [ "${#changed[@]}" -gt 0 ]; then
  sketchybar "${changed[@]}"

  # Built as one string and written once, rather than appending per line.
  state=""
  index=0
  while [ "$index" -lt "${#names[@]}" ]; do
    state+="${names[$index]}	${sigs[$index]}
"
    index=$((index + 1))
  done
  printf '%s' "$state" >"$STATE_FILE"
fi
