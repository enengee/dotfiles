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

# Keep-awake states. An open eye reads as "the display is being held awake" and a
# struck-through eye as "sleep is allowed", so the glyph alone carries the state
# and the item needs no label.
#
# Swap in a different pair by changing only these two, both 3-byte FontAwesome
# glyphs like the ones above:
#   moon / sun    U+F186 '\xef\x86\x86'  U+F185 '\xef\x86\x85'
#   coffee cup    U+F0F4 '\xef\x83\xb4'  (single glyph, no natural "off" form)
printf -v ICON_AWAKE '\xef\x81\xae'     # U+F06E eye
printf -v ICON_ASLEEP '\xef\x81\xb0'    # U+F070 eye-slash

# Keyboard lock, for wiping the keys down.
#
# Deliberately NOT a keyboard glyph. The input source item a couple of slots away
# already draws fa-keyboard (U+F11C, ICON_INPUT above), and two keyboards side by
# side are unreadable at 14pt. A broom reads as "keyboard cleaning" on its own.
#
# One glyph for both states: locked and unlocked differ by colour only, so the
# state lives entirely in icon.color — see plugins/keyboard_lock.sh. That is also
# why this is set on the item in items/right.sh rather than swapped per render the
# way ICON_AWAKE / ICON_ASLEEP are above.
#
# Material Design glyph, so 4-byte UTF-8 rather than the 3-byte FontAwesome
# escapes used elsewhere in this file. Verified present in Hack Nerd Font with
# `fc-list ':charset=f00e2'`.
printf -v ICON_KEYBOARD_LOCK '\xf3\xb0\x83\xa2' # U+F00E2 md-broom

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

export ICON_WORKSPACE ICON_OVERFLOW ICON_CLOCK ICON_WIFI ICON_INPUT
export ICON_AWAKE ICON_ASLEEP
export ICON_KEYBOARD_LOCK
export ICON_BATTERY_100 ICON_BATTERY_75 ICON_BATTERY_50 ICON_BATTERY_25 ICON_BATTERY_0
export ICON_CHARGING
export ICON_VOLUME_HIGH ICON_VOLUME_MID ICON_VOLUME_LOW ICON_VOLUME_MUTE
