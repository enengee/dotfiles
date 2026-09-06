#!/usr/bin/env bash
#
# Left side of the bar, built once per monitor:
#   [ 󰍹 workspace-name ]  [ icon ] [ icon ] [ icon ]
#
# Each monitor shows the workspace currently visible on *that* monitor and an
# app icon per window inside it, so the unfocused monitor's bar is populated
# too. The focused monitor's workspace pill is accented, as is the focused
# window's icon.
#
# Items are bound to a display with `display=<n>`, where <n> is AeroSpace's
# %{monitor-appkit-nsscreen-screens-id}. That is the same numbering SketchyBar
# uses, and it is *not* AeroSpace's own %{monitor-id}: on this machine the
# built-in display is monitor-id 2 but appkit/SketchyBar display 1.
#
# Groups are created for display ids 1..MAX_DISPLAYS, not for the monitors that
# happen to be attached right now. The bar draws the left region in item
# *creation* order, so anything that creates items again later can reorder it —
# and a plug or unplug fires a burst of events, so a rebuild triggered from the
# repaint path can end up running twice concurrently, interleaving two sets of
# `--add` calls and scrambling the order for the rest of the session. Creating
# every group up front, once, removes that whole class of failure: ids above the
# attached monitor count are bound to a display that does not exist and simply
# never draw, and they start drawing in the right place when it appears.
#
# Window slots are pre-created and hidden rather than added and removed on
# every event, for the same reason plus a practical one: creating items at
# runtime is slow and makes the bar flicker. MAX_WINDOW_SLOTS caps how many fit;
# a separate "+N" item marks the windows that did not fit.
#
# Everything below is a single `sketchybar` invocation. Each one costs a process
# spawn, and this creates MAX_DISPLAYS * (MAX_WINDOW_SLOTS + MAX_SWITCHER_SLOTS + 2)
# items.

args=(
  # Custom events fired from aerospace.toml.
  --add event aerospace_workspace_change
  --add event aerospace_focus_change
  --add event aerospace_mode_change
  # Fired by the alt-tab script: raise the workspace switcher HUD, and take it
  # down again once tabbing stops.
  --add event aerospace_switcher_open
  --add event aerospace_switcher_close
)

for display in $(seq 1 "$MAX_DISPLAYS"); do
  # drawing=off until the repaint path finds a workspace visible on this
  # display, so a group for a monitor that is not attached stays blank even if
  # SketchyBar is asked to draw it.
  args+=(
    --add item "workspace.$display" left
    --set "workspace.$display"
    display="$display"
    drawing=off
    background.drawing=on
    background.color="$WS_UNFOCUSED_BG"
    icon="$ICON_WORKSPACE"
    icon.font="$TEXT_FONT:Bold:13.0"
    icon.color="$WS_UNFOCUSED_FG"
    label.font="$TEXT_FONT:Bold:13.0"
    label.color="$WS_UNFOCUSED_FG"
  )

  # Icon-only window items: no label is ever set on these, so window titles
  # never appear and there is nothing that needs polling to stay fresh.
  #
  # icon.font is set here and never again. The repaint path runs on every focus
  # change, and each property it sends costs bash string work in a 3.2 shell,
  # so constants belong at creation time.
  for i in $(seq 1 "$MAX_WINDOW_SLOTS"); do
    args+=(
      --add item "window.$display.$i" left
      --set "window.$display.$i"
      display="$display"
      drawing=off
      background.drawing=on
      background.color="$WIN_INACTIVE_BG"
      icon.font="$APP_FONT:Regular:15.0"
      icon.color="$WIN_INACTIVE_FG"
      icon.padding_left=8
      icon.padding_right=8
      label.drawing=off
    )
  done

  # Workspace tabs for the alt-tab switcher HUD, which replaces the window pills
  # while cycling. Created *between* the window slots and the overflow marker on
  # purpose: hidden items take no space, so that one order reads correctly in both
  # modes — pill, windows, "+N" normally, and pill, workspaces, "+N" with the HUD
  # up — and the marker can count the overflow of whichever list is showing.
  #
  # Text font, not the app font: these carry workspace names, and no slot ever has
  # to switch fonts at repaint time.
  for i in $(seq 1 "$MAX_SWITCHER_SLOTS"); do
    args+=(
      --add item "switcher.$display.$i" left
      --set "switcher.$display.$i"
      display="$display"
      drawing=off
      background.drawing=on
      background.color="$SWITCHER_OTHER_BG"
      icon.drawing=off
      label.font="$TEXT_FONT:Bold:13.0"
      label.color="$SWITCHER_OTHER_FG"
      label.padding_left=8
      label.padding_right=8
    )
  done

  # "+N" marker for whatever did not fit — window pills normally, workspace tabs
  # while the switcher HUD is up. Its own item rather than the last slot of either
  # list, so no slot ever has to switch between the app font and the text font at
  # repaint time.
  args+=(
    --add item "overflow.$display" left
    --set "overflow.$display"
    display="$display"
    drawing=off
    background.drawing=on
    background.color="$WIN_INACTIVE_BG"
    icon="$ICON_OVERFLOW"
    icon.font="$TEXT_FONT:Bold:11.0"
    icon.color="$WIN_INACTIVE_FG"
    label.font="$TEXT_FONT:Bold:11.0"
    label.color="$WIN_INACTIVE_FG"
  )
done

# One invisible item drives every workspace pill and window slot from a single
# script run, instead of giving each slot its own script.
#
# No update_freq: this is purely event-driven. Window titles were the only thing
# that needed polling, and they are no longer displayed.
args+=(
  --add item window_watcher left
  --set window_watcher
  drawing=off
  updates=on
  update_freq=0
  script="$PLUGIN_DIR/workspace.sh"
  --subscribe window_watcher
  aerospace_workspace_change
  aerospace_focus_change
  aerospace_mode_change
  aerospace_switcher_open
  aerospace_switcher_close
  front_app_switched
  space_windows_change
  display_change
  system_woke
)

sketchybar "${args[@]}"
