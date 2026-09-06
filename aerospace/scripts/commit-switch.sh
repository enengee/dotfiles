#!/bin/bash
#
# Dispatch an Option-release to whichever switcher is mid-burst. Run by the
# alt-release helper on every Option-up (COMMIT_SCRIPT points here).
#
# There are two switchers — workspace (alt-tab) and window (alt-shift-tab) — but
# the helper runs one command, and only one switcher can be open at a time (both
# use Option; you cannot be holding it for two bursts at once). So this just calls
# both commit scripts; each is a no-op unless its own state flag is "on", which is
# the check that also makes an ordinary Option release (alt-h, alt-f, …) do
# nothing. Order does not matter, since at most one has state "on".

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

DIR="$HOME/.config/aerospace/scripts"
"$DIR/commit-workspace.sh"
"$DIR/commit-window.sh"
