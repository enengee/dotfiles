#!/usr/bin/env bash
#
# Keyboard lock, for wiping the keys down without typing into whatever happens to
# be focused.
#
# Built on macOS's own `hidutil`, which remaps HID usages for the current login
# session. Every key on the keyboard usage page is remapped to "no event
# indicated", so presses are swallowed below the application layer — nothing
# receives them, so no shortcut fires and no text is inserted. Clicking again
# restores the keys.
#
# Why hidutil and not something else:
#   - It is already in the OS (/usr/bin/hidutil), needs no sudo, and needs no
#     Accessibility or Input Monitoring grant, which a SketchyBar-spawned script
#     could never be prompted for anyway.
#   - The mapping is readable back, so the icon is derived from what the OS
#     actually has in force rather than from a state file this script keeps. A
#     stale cache after a crash or reboot therefore cannot make the icon lie.
#   - It does not survive a reboot, which is the ultimate escape hatch (see below).
#
# Recovering if the bar dies while the keys are locked, in order of convenience:
#   1. Click the item again (the normal way).
#   2. Wait: the watchdog below re-enables the keys after KEYBOARD_LOCK_TIMEOUT.
#   3. Reboot from the Apple menu — the remap does not persist.
#   4. System Settings -> Accessibility -> Keyboard -> Accessibility Keyboard, an
#      on-screen keyboard driven entirely by the mouse.
#
# Known limitation: the Mac top row's media and brightness keys are delivered on
# the consumer and vendor usage pages, not the keyboard page, so they still work
# while locked. Pressing them mid-wipe nudges the volume or brightness rather than
# typing, which is harmless for the purpose — blocking them too would mean
# speculatively remapping pages this script has no other reason to touch.
#
# Usage:
#   keyboard_lock.sh              render the current state
#   keyboard_lock.sh toggle       flip it, then render
#   keyboard_lock.sh auto-unlock  what the watchdog runs when it fires

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/config.sh"
source "$CONFIG_DIR/colors.sh"

# Runnable by hand (`keyboard_lock.sh toggle`) as well as by SketchyBar, which is
# what makes recovery step 1 above possible from a terminal; only SketchyBar sets
# $NAME.
NAME="${NAME:-keyboard_lock}"

# HID keyboard usage page is 0x07, so a usage on it is 0x700000000 + usage.
# Usage 0x00 on that page is "no event indicated", which is what every key is
# pointed at to deaden it.
readonly KEY_PAGE=0x700000000
readonly NO_EVENT=0x700000000
# 0x04 (letter A) .. 0xE7 (right GUI) spans every letter, digit, function key,
# arrow, keypad key and modifier. Below 0x04 are only reserved and error codes.
readonly FIRST_KEY=0x04
readonly LAST_KEY=0xE7

# The JSON hidutil wants. Built rather than stored as a literal: it is 228
# entries, and a hand-maintained blob would be unreviewable and easy to leave with
# a hole in it.
lock_mapping() {
  local usage entries=""
  for ((usage = FIRST_KEY; usage <= LAST_KEY; usage++)); do
    entries+="{\"HIDKeyboardModifierMappingSrc\":$((KEY_PAGE + usage)),"
    entries+="\"HIDKeyboardModifierMappingDst\":$((NO_EVENT))},"
  done
  printf '{"UserKeyMapping":[%s]}' "${entries%,}"
}

# Ask the OS, do not trust a cache. hidutil prints the mapping back in decimal, so
# the sentinel is converted from hex here rather than written as a magic number.
#
# The sentinel is the letter A: if A is deadened then this script did it, since
# nothing else has a reason to map A to nothing.
is_locked() {
  local sentinel=$((KEY_PAGE + FIRST_KEY))
  hidutil property --get "UserKeyMapping" 2>/dev/null |
    grep -q "HIDKeyboardModifierMappingSrc = $sentinel;"
}

# Clearing the whole UserKeyMapping is safe here only because nothing else on this
# machine sets one (`hidutil property --get UserKeyMapping` reads back empty when
# unlocked). If a permanent remap is ever added — caps lock to escape, say — it
# would have to be re-applied here instead of blanket-cleared.
restore_keys() {
  hidutil property --set '{"UserKeyMapping":[]}' >/dev/null 2>&1
}

stop_watchdog() {
  local pid
  [ -f "$KEYBOARD_LOCK_PID_FILE" ] || return 0
  read -r pid <"$KEYBOARD_LOCK_PID_FILE" 2>/dev/null
  [ -n "$pid" ] && kill "$pid" 2>/dev/null
  rm -f "$KEYBOARD_LOCK_PID_FILE"
}

# nohup and & so the watchdog outlives this script: SketchyBar reaps a plugin as
# soon as it returns, and the child is reparented to launchd. Same pattern as the
# caffeinate process in caffeine.sh.
start_watchdog() {
  stop_watchdog
  nohup bash -c "sleep $KEYBOARD_LOCK_TIMEOUT; '$0' auto-unlock" >/dev/null 2>&1 &
  echo $! >"$KEYBOARD_LOCK_PID_FILE"
}

lock() {
  # Order matters: arm the watchdog first, so a failure between the two cannot
  # leave the keys dead with nothing scheduled to revive them.
  start_watchdog
  hidutil property --set "$(lock_mapping)" >/dev/null 2>&1
}

unlock() {
  restore_keys
  stop_watchdog
}

case "$1" in
toggle)
  if is_locked; then unlock; else lock; fi
  ;;
auto-unlock)
  # The watchdog fired. Only the mapping needs undoing — the watchdog is this
  # process's parent and is on its way out, so there is nothing to kill.
  restore_keys
  rm -f "$KEYBOARD_LOCK_PID_FILE"
  ;;
esac

# The two states differ by colour only — same broom glyph, no label, no background
# pill — so this sets icon.color and nothing else. Red for dead keys, the same dim
# grey the caffeine toggle uses for its off state when they are live.
if is_locked; then
  sketchybar --set "$NAME" icon.color="$RED"
else
  sketchybar --set "$NAME" icon.color="$OVERLAY0"
fi
