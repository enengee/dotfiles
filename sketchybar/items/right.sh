#!/usr/bin/env bash
#
# Status items on the right side of the bar.
#
# `right` prepends, so the first item added ends up furthest right. Added in the
# order below they read, left to right, as:
#   [ caffeine ] [ input ] [ wifi ] [ volume ] [ battery ] [ clock ]

status=(
  background.drawing=off
  # Regular, not Semibold: Hack has no Semibold face, and the font macOS
  # substitutes has proportional digits, so the clock's seconds would change the
  # item's width every tick and nudge the whole bar sideways.
  label.font="$TEXT_FONT:Regular:13.0"
  icon.font="$TEXT_FONT:Regular:14.0"
)

# Seconds require a one-second tick; nothing emits an event for the clock.
sketchybar --add item clock right \
  --set clock "${status[@]}" \
  icon="$ICON_CLOCK" \
  icon.color="$MAUVE" \
  update_freq=1 \
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
  --subscribe volume volume_change \
  \
  --add item wifi right \
  --set wifi "${status[@]}" \
  script="$PLUGIN_DIR/wifi.sh" \
  --subscribe wifi wifi_change system_woke

# Keyboard input source. macOS posts a distributed notification when the
# selection changes, and SketchyBar can turn any such notification into an event,
# which avoids polling for it.
sketchybar --add event input_source_change AppleSelectedInputSourcesChangedNotification

sketchybar --add item input_source right \
  --set input_source "${status[@]}" \
  icon.color="$PEACH" \
  script="$PLUGIN_DIR/input_source.sh" \
  --subscribe input_source input_source_change

# Keep-awake toggle. Click flips it; the plugin owns the `caffeinate` process, so
# there is no external state to read and nothing to poll.
sketchybar --add item caffeine right \
  --set caffeine "${status[@]}" \
  script="$PLUGIN_DIR/caffeine.sh" \
  click_script="$PLUGIN_DIR/caffeine.sh toggle" \
  --subscribe caffeine system_woke
