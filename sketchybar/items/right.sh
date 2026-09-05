#!/usr/bin/env bash
# Status items on the right side of the bar.

status=(
  background.drawing=off
  label.font="$TEXT_FONT:Semibold:13.0"
  icon.font="$TEXT_FONT:Regular:14.0"
)

sketchybar --add item clock right \
  --set clock "${status[@]}" \
  icon="$ICON_CLOCK" \
  icon.color="$MAUVE" \
  update_freq=10 \
  script="$PLUGIN_DIR/clock.sh" \
  \
  --add item battery right \
  --set battery "${status[@]}" \
  update_freq=120 \
  script="$PLUGIN_DIR/battery.sh" \
  --subscribe battery system_woke power_source_change \
  \
  --add item volume right \
  --set volume "${status[@]}" \
  icon.color="$SAPPHIRE" \
  script="$PLUGIN_DIR/volume.sh" \
  --subscribe volume volume_change
