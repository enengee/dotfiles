#!/usr/bin/env bash
#
# Nerd Font glyphs, defined as UTF-8 byte escapes rather than literal
# characters.
#
# Two reasons for the escapes: these codepoints live in the Private Use Area,
# so they are invisible or mangled in most editors and diffs, and /bin/bash on
# macOS is 3.2, which has no $'\uXXXX' support.
#
# `printf -v` rather than `$(printf ...)`: this file is sourced by a script that
# runs on every workspace and focus change, and a command substitution per glyph
# costs a subshell fork each — about 11ms in total for the set below.
#
# Codepoints are Nerd Font / Font Awesome. Look them up at
# https://www.nerdfonts.com/cheat-sheet

printf -v ICON_WORKSPACE '\xef\x84\x88' # U+F108 desktop
printf -v ICON_OVERFLOW '\xef\x85\x81'  # U+F141 ellipsis-h
printf -v ICON_CLOCK '\xef\x80\x97'     # U+F017 clock
printf -v ICON_WIFI '\xef\x87\xab'      # U+F1EB wifi
printf -v ICON_INPUT '\xef\x84\x9c'     # U+F11C keyboard
printf -v ICON_CAFFEINE '\xef\x83\xb4'  # U+F0F4 coffee

printf -v ICON_BATTERY_100 '\xef\x89\x80' # U+F240 battery-full
printf -v ICON_BATTERY_75 '\xef\x89\x81'  # U+F241 battery-three-quarters
printf -v ICON_BATTERY_50 '\xef\x89\x82'  # U+F242 battery-half
printf -v ICON_BATTERY_25 '\xef\x89\x83'  # U+F243 battery-quarter
printf -v ICON_BATTERY_0 '\xef\x89\x84'   # U+F244 battery-empty
printf -v ICON_CHARGING '\xef\x83\xa7'    # U+F0E7 bolt

printf -v ICON_VOLUME_HIGH '\xef\x80\xa8' # U+F028 volume-up
printf -v ICON_VOLUME_MID '\xef\x80\xa7'  # U+F027 volume-down
printf -v ICON_VOLUME_LOW '\xef\x80\xa6'  # U+F026 volume-off
printf -v ICON_VOLUME_MUTE '\xef\x80\xa6' # U+F026 volume-off

export ICON_WORKSPACE ICON_OVERFLOW ICON_CLOCK ICON_WIFI ICON_INPUT ICON_CAFFEINE
export ICON_BATTERY_100 ICON_BATTERY_75 ICON_BATTERY_50 ICON_BATTERY_25 ICON_BATTERY_0
export ICON_CHARGING
export ICON_VOLUME_HIGH ICON_VOLUME_MID ICON_VOLUME_LOW ICON_VOLUME_MUTE
