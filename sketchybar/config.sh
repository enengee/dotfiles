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

# How long the switcher HUD stays up after the last alt-tab press, in seconds.
#
# This is a one-shot `sleep` spawned per press, not a poll: nothing waits on it,
# so it adds no latency to the HUD appearing or to any other repaint — it only
# decides when the HUD goes away. A later press supersedes an earlier sleeper
# through SWITCHER_GEN_FILE, so holding alt and tabbing never hides mid-cycle.
#
# It exists because nothing observable tells us when alt is released: AeroSpace
# has no key-release event and SketchyBar cannot see modifiers, so "the user has
# finished switching" has to be inferred. Raise it if the HUD vanishes too eagerly.
export SWITCHER_HIDE_DELAY=0.9

# Where plugins/workspace.sh caches the last painted state, so it can send only
# the items that actually changed, and the current AeroSpace binding mode. These
# are private to SketchyBar's own children, which all inherit one TMPDIR.
export STATE_FILE="${TMPDIR:-/tmp}/sketchybar-workspace.state"
export INPUT_STATE_FILE="${TMPDIR:-/tmp}/sketchybar-inputs.state"
export MODE_STATE_FILE="${TMPDIR:-/tmp}/sketchybar-mode.state"

# Switcher HUD state: whether it is up, and the press counter its one-shot hide
# checks. Written by the alt-tab script, read by plugins/workspace.sh.
#
# NOT under TMPDIR, unlike the files above, because these two are the only state
# shared across process trees: the writer is a child of AeroSpace and the reader a
# child of the SketchyBar daemon. `${TMPDIR:-/tmp}` resolves per environment, so
# the two would silently pick different paths whenever one of them is launched
# without a TMPDIR — the HUD then never appears, with nothing anywhere to say why.
export SKETCHYBAR_CACHE_DIR="$HOME/.cache/sketchybar"
export SWITCHER_STATE_FILE="$SKETCHYBAR_CACHE_DIR/switcher.state"
export SWITCHER_GEN_FILE="$SKETCHYBAR_CACHE_DIR/switcher.gen"

# PID of the `caffeinate` process the caffeine item owns, when it is on.
export CAFFEINE_PID_FILE="${TMPDIR:-/tmp}/sketchybar-caffeinate.pid"
