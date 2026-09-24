#!/usr/bin/env bash
#
# Status items on the right side of the bar.
#
# `right` prepends, so the first item added ends up furthest right. Added in the
# order below they read, left to right, as:
#   [ keyboard lock ] [ caffeine ] [ input ] [ wifi ] [ volume ] [ battery ] [ clock ]

status=(
  background.drawing=off
  # Regular, not Semibold: Hack has no Semibold face, and the font macOS
  # substitutes has proportional digits, so the clock's seconds would change the
  # item's width every tick and nudge the whole bar sideways.
  label.font="$TEXT_FONT:Regular:13.0"
  icon.font="$TEXT_FONT:Regular:14.0"
)

# Seconds require a one-second tick; nothing emits an event for the clock.
#
# label.width is fixed because a monospace font alone does not give a constant
# width: SketchyBar sizes text by the glyphs' *ink* bounds, rounded to whole
# points, so the label measures 147-149pt depending on which digit ends it, and
# every item to the clock's left shifts by a point as the seconds tick.
# 159 = widest case (149, e.g. "Mon 08 Jan 18:08:04") + label padding 4 + 6.
# Re-measure if the font, its size, the paddings or the date format change.
sketchybar --add item clock right \
  --set clock "${status[@]}" \
  icon="$ICON_CLOCK" \
  icon.color="$MAUVE" \
  label.width=159 \
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
  label.drawing=off \
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
# there is no external state to read and nothing to poll. Icon-only: the glyph
# itself distinguishes the two states.
sketchybar --add item caffeine right \
  --set caffeine "${status[@]}" \
  label.drawing=off \
  icon.font="$TEXT_FONT:Regular:15.0" \
  script="$PLUGIN_DIR/caffeine.sh" \
  click_script="$PLUGIN_DIR/caffeine.sh toggle" \
  --subscribe caffeine system_woke

# Keyboard lock, for wiping the keys down: click deadens every key, click again
# restores them. Grouped next to the caffeine toggle because both are click-to-
# flip switches rather than readouts.
#
# No update_freq and no events: the lock only ever changes because this bar
# changed it, so there is nothing to poll for. The plugin reads the live state
# from `hidutil` on each render anyway, so the icon cannot drift.
#
# Its icon is a broom, not a keyboard, so it cannot be mistaken for the
# input_source item above — see the note in icons.sh.
# Locked and unlocked differ by colour and nothing else — same glyph, no label, no
# background pill — so the plugin sets only icon.color and the glyph is declared
# once here, the way the clock and battery items do it.
sketchybar --add item keyboard_lock right \
  --set keyboard_lock "${status[@]}" \
  icon="$ICON_KEYBOARD_LOCK" \
  icon.color="$OVERLAY0" \
  label.drawing=off \
  icon.font="$TEXT_FONT:Regular:15.0" \
  script="$PLUGIN_DIR/keyboard_lock.sh" \
  click_script="$PLUGIN_DIR/keyboard_lock.sh toggle"
