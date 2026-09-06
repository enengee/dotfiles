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

# --- switcher HUD state ------------------------------------------------------
# Read, never written here: the alt-tab scripts own these files and set them
# before triggering the repaint, so that every repaint the burst provokes —
# including ones this script is running concurrently for other events — agrees on
# whether the HUD is up and which tab is highlighted. Deriving either from SENDER
# would make the answer depend on which of those runs finished last.
#
# The highlight is an index into the ring (list-workspaces --all order), NOT the
# focused workspace: while switching, focus has deliberately not moved yet.
switcher=""
[ -f "$SWITCHER_STATE_FILE" ] && read -r switcher <"$SWITCHER_STATE_FILE" 2>/dev/null
switcher_index=-1
[ -f "$SWITCHER_INDEX_FILE" ] && read -r switcher_index <"$SWITCHER_INDEX_FILE" 2>/dev/null
case "$switcher_index" in '' | *[!0-9-]*) switcher_index=-1 ;; esac

# Window switcher (alt-shift-tab): same idea, cycling the focused workspace's
# windows. When on, the window pills accent this selected index instead of the
# genuinely focused window, since focus has not moved yet.
winsw=""
[ -f "$WINSW_STATE_FILE" ] && read -r winsw <"$WINSW_STATE_FILE" 2>/dev/null
winsw_index=-1
[ -f "$WINSW_INDEX_FILE" ] && read -r winsw_index <"$WINSW_INDEX_FILE" 2>/dev/null
case "$winsw_index" in '' | *[!0-9-]*) winsw_index=-1 ;; esac

# --- switcher detail line ----------------------------------------------------
# "App — title" for whatever the active switcher has highlighted, shown at the
# tail of the left region. Computed once here (it is display-independent) and
# emitted by whichever branch draws the focused monitor below.
#
# The extra `list-windows` calls here run ONLY during a burst — the common
# repaint path (focus changes, window changes) leaves detail_label empty and
# pays nothing. Titles contain '|', so these queries use a tab separator and are
# read with IFS=tab, unlike the '|' rows above which never carry a title.
detail_label=""
if [ "$winsw" = "on" ]; then
  # The highlighted window itself: index into the focused workspace's window list.
  detail_row=$(aerospace list-windows --workspace focused \
    --format '%{app-name}	%{window-title}' 2>/dev/null | sed -n "$((winsw_index + 1))p")
  detail_app=${detail_row%%	*}
  detail_title=${detail_row#*	}
  if [ -n "$detail_app" ]; then
    if [ -n "$detail_title" ] && [ "$detail_title" != "$detail_app" ]; then
      detail_label="$detail_app — $detail_title"
    else
      detail_label="$detail_app"
    fi
  fi
elif [ "$switcher" = "on" ] && [ "$switcher_index" -ge 0 ]; then
  # A workspace has no single window, so show its *focused* window as a stand-in
  # for what you would land on. The ring order is list-workspaces --all.
  detail_ws=$(aerospace list-workspaces --all 2>/dev/null | sed -n "$((switcher_index + 1))p")
  if [ -n "$detail_ws" ]; then
    detail_row=$(aerospace list-windows --workspace "$detail_ws" \
      --format '%{app-name}	%{window-title}' 2>/dev/null | sed -n '1p')
    detail_app=${detail_row%%	*}
    detail_title=${detail_row#*	}
    if [ -n "$detail_app" ]; then
      if [ -n "$detail_title" ] && [ "$detail_title" != "$detail_app" ]; then
        detail_label="$detail_app — $detail_title"
      else
        detail_label="$detail_app"
      fi
    fi
    # Empty workspace: name it, so the panel is not blank.
    [ -n "$detail_label" ] || detail_label="$detail_ws (empty)"
  fi
fi

# --- nothing to do? -----------------------------------------------------------
# Several subscribed events fire without changing anything the bar shows —
# front_app_switched in particular. Comparing the raw AeroSpace output lets those
# return before doing any per-item work.
inputs="$workspace_rows
$window_rows
$focused_window
$mode
$switcher
$switcher_index
$winsw
$winsw_index
$detail_label"

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

# Blanking a whole list is needed from two places each, so both are functions.
hide_window_slots() {
  local slot=0
  while [ "$slot" -lt "$MAX_WINDOW_SLOTS" ]; do
    slot=$((slot + 1))
    push_item "window.$1.$slot" drawing=off icon="" click_script=""
  done
}

hide_switcher_slots() {
  local slot=0
  while [ "$slot" -lt "$MAX_SWITCHER_SLOTS" ]; do
    slot=$((slot + 1))
    push_item "switcher.$1.$slot" drawing=off label="" click_script=""
  done
}

# The detail panel shows on the focused monitor while a burst is up (detail_label
# non-empty), and is hidden everywhere else. Called from every display's branch so
# the diff sees a definite state for it on each monitor every run.
emit_detail() {
  local display=$1 focused=$2
  if [ -n "$detail_label" ] && [ "$focused" = "true" ]; then
    push_item "detail.$display" drawing=on label="$detail_label"
  else
    push_item "detail.$display" drawing=off label=""
  fi
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
    hide_window_slots "$display"
    hide_switcher_slots "$display"
    push_item "overflow.$display" drawing=off label=""
    emit_detail "$display" "false"
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

  # With the switcher HUD up, this monitor's window pills give way to a tab per
  # workspace — the whole alt-tab ring, in ring order, with the *highlighted* tab
  # accented. Highlight follows switcher_index, not focus: the whole point of the
  # redesign is that focus has not moved yet while you cycle.
  #
  # Drawn on the monitor that currently has focus. Focus does not move during a
  # burst, so this stays put on the screen you started tabbing from — which is
  # where you are looking — until the commit on release moves it.
  if [ "$switcher" = "on" ] && [ "$is_focused" = "true" ]; then
    hide_window_slots "$display"

    slot=0
    for ring_line in "${workspace_lines[@]}"; do
      [ "$slot" -lt "$MAX_SWITCHER_SLOTS" ] || break
      ring_index=$slot
      slot=$((slot + 1))

      # display|workspace|is-visible|is-focused — only the name is needed; the
      # accent comes from the selected index, not any AeroSpace flag.
      rest=${ring_line#*|}
      ring_name=${rest%%|*}

      if [ "$ring_index" = "$switcher_index" ]; then
        background=$SWITCHER_CURRENT_BG foreground=$SWITCHER_CURRENT_FG
      else
        background=$SWITCHER_OTHER_BG foreground=$SWITCHER_OTHER_FG
      fi

      push_item "switcher.$display.$slot" \
        drawing=on \
        background.color="$background" \
        label="$ring_name" \
        label.color="$foreground" \
        click_script="aerospace workspace '$ring_name'"
    done

    hidden=$slot
    while [ "$hidden" -lt "$MAX_SWITCHER_SLOTS" ]; do
      hidden=$((hidden + 1))
      push_item "switcher.$display.$hidden" drawing=off label="" click_script=""
    done

    ring_total=${#workspace_lines[@]}
    if [ "$ring_total" -gt "$MAX_SWITCHER_SLOTS" ]; then
      push_item "overflow.$display" drawing=on label="$((ring_total - MAX_SWITCHER_SLOTS))"
    else
      push_item "overflow.$display" drawing=off label=""
    fi

    emit_detail "$display" "$is_focused"
    continue
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

    # Which pill is accented. Normally the genuinely focused window; but while the
    # alt-shift-tab window switcher is up on this (focused) monitor, focus has not
    # moved yet, so accent the *selected* index instead — the same
    # highlight-then-commit-on-release model the workspace switcher uses.
    if [ "$winsw" = "on" ] && [ "$is_focused" = "true" ]; then
      if [ "$index" = "$winsw_index" ]; then
        background=$WIN_FOCUSED_BG foreground=$WIN_FOCUSED_FG
      else
        background=$WIN_INACTIVE_BG foreground=$WIN_INACTIVE_FG
      fi
    elif [ "${ids[$index]}" = "$focused_window" ]; then
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
  hide_switcher_slots "$display"

  if [ "$total" -gt "$MAX_WINDOW_SLOTS" ]; then
    push_item "overflow.$display" drawing=on label="$((total - MAX_WINDOW_SLOTS))"
  else
    push_item "overflow.$display" drawing=off label=""
  fi

  emit_detail "$display" "$is_focused"
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
