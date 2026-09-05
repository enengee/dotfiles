#!/usr/bin/env bash
#
# Keep-awake toggle, replacing Caffeine.app's menu bar item.
#
# Implemented on macOS's own `caffeinate` rather than by driving Caffeine.app:
# scripting that app would need an Automation (TCC) grant that a SketchyBar-
# spawned script cannot be prompted for, and it exposes no dependable way to read
# its current state. Owning the process here means the icon always matches
# reality.
#
# Usage:
#   caffeine.sh          render the current state
#   caffeine.sh toggle   flip it, then render

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/config.sh"
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

# Awake only if the recorded PID is still alive; a stale file after a crash or
# reboot must not read as "on".
is_awake() {
  local pid
  [ -f "$CAFFEINE_PID_FILE" ] || return 1
  read -r pid <"$CAFFEINE_PID_FILE" || return 1
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

stop() {
  local pid
  if [ -f "$CAFFEINE_PID_FILE" ]; then
    read -r pid <"$CAFFEINE_PID_FILE"
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    rm -f "$CAFFEINE_PID_FILE"
  fi
}

start() {
  # -d display sleep, -i idle sleep, -s system sleep (the last applies on AC
  # only). No -u: without -t it self-expires after 5s, which would silently
  # leave the icon on while the assertion was gone.
  #
  # nohup and & so the assertion outlives this script — SketchyBar reaps the
  # script as soon as it returns, and the child is reparented to launchd.
  nohup caffeinate -dis >/dev/null 2>&1 &
  echo $! >"$CAFFEINE_PID_FILE"
}

if [ "$1" = "toggle" ]; then
  if is_awake; then stop; else start; fi
fi

if is_awake; then
  sketchybar --set "$NAME" icon="$ICON_CAFFEINE" icon.color="$YELLOW" label="on"
else
  sketchybar --set "$NAME" icon="$ICON_CAFFEINE" icon.color="$OVERLAY0" label="off"
fi
