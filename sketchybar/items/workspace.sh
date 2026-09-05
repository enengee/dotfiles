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
# Window slots are pre-created and hidden rather than added and removed on
# every event: creating items at runtime is slow and makes the bar flicker.
# MAX_WINDOW_SLOTS caps how many fit; the last slot becomes a "+N" overflow
# marker when a workspace holds more windows than that.

# Custom events fired from aerospace.toml.
sketchybar --add event aerospace_workspace_change
sketchybar --add event aerospace_focus_change
sketchybar --add event aerospace_mode_change

for display in $(aerospace list-monitors --format '%{monitor-appkit-nsscreen-screens-id}'); do
  sketchybar --add item "workspace.$display" left \
    --set "workspace.$display" \
    display="$display" \
    background.drawing=on \
    background.color="$WS_UNFOCUSED_BG" \
    icon="$ICON_WORKSPACE" \
    icon.font="$TEXT_FONT:Bold:13.0" \
    icon.color="$WS_UNFOCUSED_FG" \
    label.font="$TEXT_FONT:Bold:13.0" \
    label.color="$WS_UNFOCUSED_FG"

  # Icon-only window items: no label is ever set on these, so window titles
  # never appear and there is nothing that needs polling to stay fresh.
  #
  # icon.font is set here and never again. The repaint path runs on every focus
  # change, and each property it sends costs bash string work in a 3.2 shell,
  # so constants belong at creation time.
  for i in $(seq 1 "$MAX_WINDOW_SLOTS"); do
    sketchybar --add item "window.$display.$i" left \
      --set "window.$display.$i" \
      display="$display" \
      drawing=off \
      background.drawing=on \
      background.color="$WIN_INACTIVE_BG" \
      icon.font="$APP_FONT:Regular:15.0" \
      icon.color="$WIN_INACTIVE_FG" \
      icon.padding_left=8 \
      icon.padding_right=8 \
      label.drawing=off
  done

  # "+N" marker for windows beyond MAX_WINDOW_SLOTS. Its own item rather than
  # the last window slot, so no slot ever has to switch between the app font and
  # the text font at repaint time.
  sketchybar --add item "overflow.$display" left \
    --set "overflow.$display" \
    display="$display" \
    drawing=off \
    background.drawing=on \
    background.color="$WIN_INACTIVE_BG" \
    icon="$ICON_OVERFLOW" \
    icon.font="$TEXT_FONT:Bold:11.0" \
    icon.color="$WIN_INACTIVE_FG" \
    label.font="$TEXT_FONT:Bold:11.0" \
    label.color="$WIN_INACTIVE_FG"
done

# One invisible item drives every workspace pill and window slot from a single
# script run, instead of giving each slot its own script.
#
# No update_freq: this is purely event-driven. Window titles were the only thing
# that needed polling, and they are no longer displayed.
sketchybar --add item window_watcher left \
  --set window_watcher \
  drawing=off \
  updates=on \
  update_freq=0 \
  script="$PLUGIN_DIR/workspace.sh" \
  --subscribe window_watcher \
  aerospace_workspace_change \
  aerospace_focus_change \
  aerospace_mode_change \
  front_app_switched \
  space_windows_change \
  display_change \
  system_woke
