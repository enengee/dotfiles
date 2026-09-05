#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

MAX_SSID_CHARS=18

# `ipconfig getsummary` rather than the more obvious alternatives, both of which
# are dead ends on current macOS:
#
#   * `airport -I` was removed (the Apple80211 private framework binary is gone).
#   * `networksetup -getairportnetwork en0` answers "You are not associated with
#     an AirPort network" even while connected, unless the calling binary holds
#     Location Services permission.
interface=$(route -n get default 2>/dev/null | awk '/interface:/ {print $2; exit}')
[ -n "$interface" ] || interface=en0

ssid=$(ipconfig getsummary "$interface" 2>/dev/null |
  awk -F' SSID : ' '/ SSID : / {print $2; exit}')

# Fall back to en0 when the default route is not the Wi-Fi interface, for example
# while a dock's Ethernet is plugged in.
if [ -z "$ssid" ] && [ "$interface" != "en0" ]; then
  ssid=$(ipconfig getsummary en0 2>/dev/null |
    awk -F' SSID : ' '/ SSID : / {print $2; exit}')
fi

if [ -n "$ssid" ]; then
  if [ "${#ssid}" -gt "$MAX_SSID_CHARS" ]; then
    ssid="${ssid:0:$MAX_SSID_CHARS}…"
  fi
  sketchybar --set "$NAME" icon="$ICON_WIFI" icon.color="$GREEN" label="$ssid"
else
  sketchybar --set "$NAME" icon="$ICON_WIFI" icon.color="$RED" label="off"
fi
