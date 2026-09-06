#!/usr/bin/env bash
#
# Shared settings for sketchybarrc, items/ and plugins/.
#
# This has to be *sourced* by every script that needs these values. Exporting
# them from sketchybarrc is not enough: sketchybarrc and the plugin scripts are
# both children of the SketchyBar daemon, so a variable exported in one is not
# visible in the other. Getting this wrong silently produces malformed values
# like `icon.font=::10.00`.

# Text font: any installed Nerd Font. App icons: sketchybar-app-font.
#   brew install --cask font-hack-nerd-font font-sketchybar-app-font
export TEXT_FONT="Hack Nerd Font"
export APP_FONT="sketchybar-app-font"

# How many window items to pre-create per monitor. The last slot becomes a "+N"
# overflow marker when a workspace holds more windows than this.
export MAX_WINDOW_SLOTS=10

# How many monitors to pre-create item groups for. Groups are keyed by
# AeroSpace's %{monitor-appkit-nsscreen-screens-id}, which is always 1..N, so
# ids above the number of attached monitors just never draw.
#
# This is a fixed count rather than the live monitor count on purpose: the bar
# orders items by creation order, so creating them once at config load is what
# keeps the left side in a stable order across plugging and unplugging a
# monitor. Raise it if you ever attach more than this many displays — the extra
# monitor's bar would otherwise have an empty left side.
export MAX_DISPLAYS=4

# Where plugins/workspace.sh caches the last painted state, so it can send only
# the items that actually changed, and the current AeroSpace binding mode.
export STATE_FILE="${TMPDIR:-/tmp}/sketchybar-workspace.state"
export INPUT_STATE_FILE="${TMPDIR:-/tmp}/sketchybar-inputs.state"
export MODE_STATE_FILE="${TMPDIR:-/tmp}/sketchybar-mode.state"

# PID of the `caffeinate` process the caffeine item owns, when it is on.
export CAFFEINE_PID_FILE="${TMPDIR:-/tmp}/sketchybar-caffeinate.pid"
