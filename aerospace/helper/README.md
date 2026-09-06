# alt-release-watcher

A ~40-line Swift helper that fires a command when the **Option (alt)** key is
released. It exists for one reason: the alt-tab workspace switcher commits its
selection on release, cmd-tab style, and nothing else in this setup can see a
modifier come up.

## Why it has to exist

The switcher wants to cycle a highlight while alt is held and switch to the
highlighted workspace the instant alt is let go. That needs a key-*release*
signal, and neither tool in the stack produces one:

- **AeroSpace** bindings fire on key *press* only. Its event stream is
  `focus-changed`, `focused-monitor-changed`, `focused-workspace-changed`,
  `mode-changed`, `window-detected`, `binding-triggered` — no key-up, no modifier
  state. A binding mode does not help either: while alt is physically held,
  pressing tab still produces `alt-tab`, never a bare `tab` to bind separately.
- **SketchyBar** cannot read modifiers at all.

macOS *does* expose it, through AppKit's `.flagsChanged` events, but only to a
native process. Hence this helper rather than more shell.

## What it does

Registers an `NSEvent` global monitor on `.flagsChanged` and runs
`$COMMIT_SCRIPT` on each true→false transition of the Option flag. It is fully
event-driven — the process blocks in the run loop until the OS delivers a
modifier change, so there is no polling and no timer, and the commit lands the
moment you release.

A global monitor can only *observe* events bound for other apps, never modify or
consume them, so alt-tab is still handled entirely by AeroSpace; this just watches
alongside. It reads modifier flags only — never keycodes or characters.

## Permission

Observing other apps' key events is what macOS gates behind **Input Monitoring**,
so the compiled binary must be granted it once per machine:

    System Settings > Privacy & Security > Input Monitoring > enable "alt-release-watcher"

The launchd agent triggers the prompt on first run. Until it is granted, alt-tab
still highlights workspaces but never switches — the release is simply never seen.

The grant is bound to the binary's path, so `install.sh` compiles to a stable
`~/.local/bin/alt-release-watcher` and the permission survives reinstalls.

## Files

- `alt-release-watcher.swift` — the helper.
- `com.local.aerospace.alt-release-watcher.plist` — launchd agent template;
  `install.sh` fills in the binary, commit-script and log paths and loads it into
  the GUI session. `RunAtLoad` + `KeepAlive` keep it running from login onward.

The commit itself lives in `../scripts/commit-workspace.sh`, passed to the helper
as `COMMIT_SCRIPT`, so the binary knows nothing about workspaces or the repo
layout.

## Checking on it

    launchctl print gui/$(id -u)/com.local.aerospace.alt-release-watcher
    cat ~/.cache/sketchybar/alt-release-watcher.log   # stderr, if it ever complains
    launchctl kickstart -k gui/$(id -u)/com.local.aerospace.alt-release-watcher  # restart
