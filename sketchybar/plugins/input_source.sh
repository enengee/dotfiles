#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

CONFIG_DIR="${CONFIG_DIR:-$HOME/.config/sketchybar}"
source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/icons.sh"

# AppleSelectedInputSources holds the active source. It is read rather than
# AppleCurrentKeyboardLayoutInputSourceID because that key only tracks the
# *keyboard layout*: with a Japanese or Vietnamese IME active it still reports the
# underlying Roman layout, so the indicator would never change.
selected=$(defaults read com.apple.HIToolbox AppleSelectedInputSources 2>/dev/null)

# "Input Mode" is checked before "KeyboardLayout Name" on purpose. When an IME is
# active the selection can contain both, and the input mode is the specific one.
name=$(printf '%s' "$selected" |
  awk -F' = ' '/"Input Mode"/ {gsub(/[";]|^[ \t]+|[ \t]+$/, "", $2); print $2; exit}')

if [ -z "$name" ]; then
  name=$(printf '%s' "$selected" |
    awk -F' = ' '/KeyboardLayout Name/ {gsub(/[";]|^[ \t]+|[ \t]+$/, "", $2); print $2; exit}')
fi

if [ -z "$name" ]; then
  name=$(printf '%s' "$selected" |
    awk -F' = ' '/"Bundle ID"/ {gsub(/[";]|^[ \t]+|[ \t]+$/, "", $2); print $2; exit}')
fi

# Reverse-DNS ids reduce to their last component:
# com.apple.inputmethod.VietnameseSimpleTelex -> VietnameseSimpleTelex
name=${name##*.}

case "$name" in
Japanese | Hiragana | Katakana | Kana) label="JA" ;;
Roman) label="EN" ;;
Vietnamese*) label="VI" ;;
"") label="?" ;;
*) label="${name:0:4}" ;;
esac

sketchybar --set "$NAME" icon="$ICON_INPUT" label="$label"
