#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/icons.sh"

# $INFO is the new volume for volume_change; query directly on first run.
volume="$INFO"
if [ -z "$volume" ]; then
  volume=$(osascript -e 'output volume of (get volume settings)')
fi

case "$volume" in
100 | 9[0-9] | 8[0-9] | 7[0-9] | 6[0-9]) icon=$ICON_VOLUME_HIGH ;;
5[0-9] | 4[0-9] | 3[0-9] | 2[0-9]) icon=$ICON_VOLUME_MID ;;
1[0-9] | [1-9]) icon=$ICON_VOLUME_LOW ;;
0) icon=$ICON_VOLUME_MUTE ;;
*) icon=$ICON_VOLUME_MID ;;
esac

sketchybar --set "$NAME" icon="$icon" label="$volume%"
