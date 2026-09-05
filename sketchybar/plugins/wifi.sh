#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

# This shows the IP rather than the network name, because on current macOS a
# script simply cannot read the SSID. Do not "fix" this by reaching for one of
# the usual commands — all of them have been checked on macOS 26:
#
#   ipconfig getsummary en0      -> "SSID : <redacted>" (literally that string)
#   system_profiler SPAirPortDataType
#                               -> network name also "<redacted>", and it takes
#                                  3.6s, far too slow for a bar item
#   networksetup -getairportnetwork en0
#                               -> "You are not associated with an AirPort
#                                  network" even while connected
#   airport -I                  -> removed; the Apple80211 private binary is gone
#
# Since macOS 14 the SSID is gated behind Location Services authorization for the
# *calling* process. Getting it would mean shipping a signed .app bundle with
# NSLocationUsageDescription that asks via CLLocationManager, then calling that
# helper from here. `sudo wdutil info` also reveals it, but wiring passwordless
# sudo into a status bar trades a real privilege for a cosmetic label.
#
# Association is still detectable: the SSID *line* is present when associated,
# only its value is redacted.

interface=$(networksetup -listallhardwareports 2>/dev/null |
  awk '/Hardware Port: Wi-Fi/ { getline; print $2; exit }')
[ -n "$interface" ] || interface=en0

power=$(networksetup -getairportpower "$interface" 2>/dev/null)

if [ "${power##*: }" = "Off" ]; then
  sketchybar --set "$NAME" icon="$ICON_WIFI" icon.color="$RED" label="off"
elif ipconfig getsummary "$interface" 2>/dev/null | grep -q ' SSID : '; then
  address=$(ipconfig getifaddr "$interface" 2>/dev/null)
  sketchybar --set "$NAME" \
    icon="$ICON_WIFI" \
    icon.color="$GREEN" \
    label="${address:-up}"
else
  sketchybar --set "$NAME" icon="$ICON_WIFI" icon.color="$YELLOW" label="—"
fi
