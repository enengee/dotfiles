#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

info=$(pmset -g batt)
percent=$(printf '%s' "$info" | grep -Eo '[0-9]+%' | head -1 | tr -d '%')
charging=$(printf '%s' "$info" | grep -c 'AC Power')

[ -z "$percent" ] && exit 0

color=$TEXT
case "$percent" in
9[0-9] | 100) icon=$ICON_BATTERY_100 ;;
[6-8][0-9]) icon=$ICON_BATTERY_75 ;;
[3-5][0-9]) icon=$ICON_BATTERY_50 ;;
[1-2][0-9]) icon=$ICON_BATTERY_25 ; color=$PEACH ;;
*) icon=$ICON_BATTERY_0 ; color=$RED ;;
esac

if [ "$charging" -eq 1 ]; then
  icon=$ICON_CHARGING
  color=$GREEN
fi

sketchybar --set "$NAME" icon="$icon" icon.color="$color" label="$percent%"
