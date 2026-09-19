#!/usr/bin/env bash
#
# Re-register AeroSpace hotkeys after sleep.
#
# RegisterEventHotKey and the alt-release NSEvent monitor both drop across a
# sleep. reload-config re-registers the bindings without bouncing AeroSpace.app
# (which would flash every window and re-run after-startup-command). The
# launchd agent is KeepAlive, but kickstart covers the case where it is still
# up and simply no longer receiving flagsChanged.
#
# Hidden item; only system_woke should fire this. Other senders are ignored so
# a stray --update cannot reload-config in the middle of a session.
#
# Usage:
#   hotkey_wake.sh   no-op unless SENDER=system_woke

export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

[ "${SENDER:-}" = "system_woke" ] || exit 0

aerospace reload-config >/dev/null 2>&1 || true
launchctl kickstart -k "gui/$(id -u)/com.local.aerospace.alt-release-watcher" \
  >/dev/null 2>&1 || true
