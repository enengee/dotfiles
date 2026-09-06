#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

# Icon-only: the colour carries the state, and there is no label.
#
#   red     Wi-Fi is powered off
#   yellow  powered on but not usable — either not associated with a network, or
#           associated with no address, which is what a failed DHCP lease looks
#           like
#   green   associated and holding an address
#
# There is deliberately no network name here, because on current macOS a script
# simply cannot read the SSID. Do not "fix" that by reaching for one of the usual
# commands — all of them have been checked on macOS 26:
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
  color=$RED
elif ipconfig getsummary "$interface" 2>/dev/null | grep -q ' SSID : ' &&
  ipconfig getifaddr "$interface" >/dev/null 2>&1; then
  color=$GREEN
else
  color=$YELLOW
fi

sketchybar --set "$NAME" icon="$ICON_WIFI" icon.color="$color"
