#!/usr/bin/env bash
# Catppuccin Macchiato palette
# https://github.com/catppuccin/catppuccin

export BASE=0xff24273a
export MANTLE=0xff1e2030
export CRUST=0xff181926

export SURFACE0=0xff363a4f
export SURFACE1=0xff494d64
export SURFACE2=0xff5b6078

export TEXT=0xffcad3f5
export SUBTEXT0=0xffa5adcb
export OVERLAY0=0xff6e738d

export BLUE=0xff8aadf4
export SAPPHIRE=0xff7dc4e4
export GREEN=0xffa6da95
export YELLOW=0xffeed49f
export PEACH=0xfff5a97f
export RED=0xffed8796
export MAUVE=0xffc6a0f6

export TRANSPARENT=0x00000000

# --- Semantic aliases used by the config ---
export BAR_COLOR=0xf024273a       # bar background (slightly translucent)
export ITEM_BG_COLOR=$SURFACE0    # default item background
export ACCENT_COLOR=$BLUE         # focused workspace / highlights
export LABEL_COLOR=$TEXT
export ICON_COLOR=$TEXT

# Workspace name pill (first item on the left, one per monitor)
export WS_FOCUSED_BG=$BLUE        # monitor that currently has focus
export WS_FOCUSED_FG=$CRUST
export WS_UNFOCUSED_BG=$SURFACE1  # the other monitor's visible workspace
export WS_UNFOCUSED_FG=$SUBTEXT0

# Window pills (one per window in the focused workspace)
export WIN_FOCUSED_BG=$SURFACE2   # the window that currently has focus
export WIN_FOCUSED_FG=$TEXT
export WIN_INACTIVE_BG=$SURFACE0
export WIN_INACTIVE_FG=$SUBTEXT0

# Workspace switcher HUD (replaces the window pills while alt-tab cycles)
export SWITCHER_CURRENT_BG=$MAUVE # where alt-tab has landed
export SWITCHER_CURRENT_FG=$CRUST
export SWITCHER_OTHER_BG=$SURFACE0
export SWITCHER_OTHER_FG=$SUBTEXT0
