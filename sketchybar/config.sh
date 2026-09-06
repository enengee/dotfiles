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

# How many workspace tabs the alt-tab switcher HUD can show per monitor. Extra
# workspaces are counted by the "+N" marker, the same one the window pills use.
export MAX_SWITCHER_SLOTS=12

# Where plugins/workspace.sh caches the last painted state, so it can send only
# the items that actually changed, and the current AeroSpace binding mode. These
# are private to SketchyBar's own children, which all inherit one TMPDIR.
export STATE_FILE="${TMPDIR:-/tmp}/sketchybar-workspace.state"
export INPUT_STATE_FILE="${TMPDIR:-/tmp}/sketchybar-inputs.state"
export MODE_STATE_FILE="${TMPDIR:-/tmp}/sketchybar-mode.state"

# Switcher HUD state: whether it is up, and the index alt-tab has highlighted
# (0-based, into the ring order below). Written by the alt-tab scripts, read by
# plugins/workspace.sh.
#
# NOT under TMPDIR, unlike the files above, because these are the only state
# shared across process trees: the writers are children of AeroSpace (and of the
# launchd helper) and the reader a child of the SketchyBar daemon.
# `${TMPDIR:-/tmp}` resolves per environment, so the sides would silently pick
# different paths whenever one is launched without a TMPDIR — the HUD then never
# appears, with nothing anywhere to say why.
export SKETCHYBAR_CACHE_DIR="$HOME/.cache/sketchybar"
export SWITCHER_STATE_FILE="$SKETCHYBAR_CACHE_DIR/switcher.state"
export SWITCHER_INDEX_FILE="$SKETCHYBAR_CACHE_DIR/switcher.index"

# The ring the switcher cycles and the HUD draws is "every workspace on every
# monitor, alphabetical" — exactly what `aerospace list-workspaces --all` returns.
# Both the cycling script and the paint script derive the index from that one
# call, so they agree on order without sharing anything but the integer index.

# PID of the `caffeinate` process the caffeine item owns, when it is on.
export CAFFEINE_PID_FILE="${TMPDIR:-/tmp}/sketchybar-caffeinate.pid"
