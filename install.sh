#!/usr/bin/env bash
#
# Sets up the AeroSpace + SketchyBar configs on a fresh machine: installs the
# packages they depend on, symlinks them into ~/.config, and starts the services.
#
# Safe to re-run. Existing files that are not already the right symlink are moved
# aside with a .backup suffix rather than overwritten.

set -euo pipefail

# pwd -P so the symlinks point at the real location even when the repo is reached
# through a symlinked path.
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1"; }

[ "$(uname -s)" = "Darwin" ] || {
  warn "macOS only."
  exit 1
}

command -v brew >/dev/null || {
  warn "Homebrew is required: https://brew.sh"
  exit 1
}

info "Installing packages"
# sketchybar and borders live in felixkratz/formulae, AeroSpace in
# nikitabobko/tap. Brew resolves the taps from these fully qualified names.
brew install --quiet \
  felixkratz/formulae/sketchybar \
  felixkratz/formulae/borders

brew install --quiet --cask \
  nikitabobko/tap/aerospace \
  font-hack-nerd-font \
  font-sketchybar-app-font

# font-hack-nerd-font       text and glyphs (Regular/Bold only — see README)
# font-sketchybar-app-font  per-application icons in the window list

link() {
  local source=$1 target=$2

  # Compared by device+inode rather than by string: the same directory can be
  # reached through different paths (here $HOME/workplace is a symlink to a
  # mounted volume), and a string compare would relink a correct link. Note the
  # -L: BSD stat does not follow symlinks by default, so without it this compares
  # the link itself against the directory and never matches.
  if [ -L "$target" ] &&
    [ "$(stat -L -f '%d:%i' "$target" 2>/dev/null)" = "$(stat -L -f '%d:%i' "$source" 2>/dev/null)" ]; then
    printf '    ok   %s\n' "$target"
    return
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    mv "$target" "$target.backup"
    warn "moved existing $target to $target.backup"
  fi

  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  printf '    link %s -> %s\n' "$target" "$source"
}

info "Linking configs into ~/.config"
# SketchyBar reads the whole directory; AeroSpace only reads aerospace.toml, so
# the helper scripts are linked separately next to it.
link "$REPO/sketchybar" "$HOME/.config/sketchybar"
link "$REPO/aerospace/aerospace.toml" "$HOME/.config/aerospace/aerospace.toml"
link "$REPO/aerospace/scripts" "$HOME/.config/aerospace/scripts"

info "Starting services"
brew services restart sketchybar
open -a AeroSpace 2>/dev/null || warn "start AeroSpace.app manually"

cat <<'MANUAL'

==> Three things this script cannot do for you

  1. Hide the macOS menu bar
     System Settings > Control Center > Automatically hide and show the menu bar
     > Always. The config assumes this; see the gaps note in README.md if you
     leave it visible.

  2. Check the top gap against your displays
     gaps.outer.top in aerospace.toml is calibrated to a notched built-in display
     plus externals that reserve nothing. On other hardware windows will either
     overlap the bar or leave a gap. README.md has the measuring command.

  3. Rename the workspaces
     persistent-workspaces and the ctrl-alt-N / alt-shift-N bindings in
     aerospace.toml use names that are almost certainly not yours.

MANUAL
