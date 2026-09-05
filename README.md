# dotfiles

AeroSpace tiling window manager and a SketchyBar status bar that shows, per
monitor, the workspace visible on it and an app icon per window inside it.

```
[ 󰍹 personal ] [  ] [  ] [  ]              [  ] [ ⌨ ABC ] [ 󰖩 192.168.0.2 ] [ 🔉 44% ] [ 🔋 87% ] [ 🕐 Sat 06 Sep 00:14:22 ]
```

## Install

```sh
./install.sh
```

Installs the packages, symlinks `sketchybar/` and `aerospace/` into `~/.config`,
and starts the services. Re-runnable; anything it would overwrite is moved to
`*.backup` first.

## Machine-specific settings

Everything else is portable, but these four assume something about the machine
they were written on. Check them on a new Mac.

### Top gap must match your displays

`gaps.outer.top` in `aerospace.toml` is a per-monitor value:

```toml
gaps.outer.top = [{ monitor."built-in" = 4 }, 36]
```

Displays differ in how much space macOS already reserves at the top, and
AeroSpace's usable area starts below whatever is reserved. A notched built-in
reserves 32pt, so it needs only the visual gap (4). An external with the menu bar
hidden reserves nothing, so its gap must also cover the 32pt bar (32 + 4 = 36).

Wrong values mean windows either slide under the bar or leave a dead band. Measure
with:

```sh
osascript -l JavaScript -e 'ObjC.import("AppKit"); var s=$.NSScreen.screens;
  var o=[]; for (var i=0;i<s.count;i++){var c=s.objectAtIndex(i);
  o.push(ObjC.unwrap(c.localizedName)+" "+JSON.stringify(
  [ObjC.deepUnwrap(c.frame),ObjC.deepUnwrap(c.visibleFrame)]));} o.join("\n")'
```

`frame.height - visibleFrame.height` is what that display reserves. The gap for it
is `4` if that equals the bar height, otherwise `bar height + 4`.

This also assumes the macOS menu bar is set to auto-hide. Leave it visible and
externals start reserving ~24pt themselves, making 36 too much.

### Workspace names

`persistent-workspaces` and the `ctrl-alt-N` / `alt-shift-N` bindings in
`aerospace.toml` name specific workspaces. Rename all three places together.

### Floating applications

The `[[on-window-detected]]` blocks at the end of `aerospace.toml` list apps that
should never tile. `if.app-id` is an exact match and a wrong id fails silently, so
get ids from `aerospace list-windows --all --format '%{app-bundle-id}|%{app-name}'`
rather than guessing. Rules apply to windows detected *after* they are added —
reopen a window, or float it once with `alt-shift-;` then `f`.

### Fonts

Hack Nerd Font ships **Regular, Bold, Italic, BoldItalic only**. Asking for a
weight it lacks (`Semibold`) makes macOS silently substitute a different font with
proportional digits, which makes the clock's seconds resize the item and shift the
whole bar sideways. SketchyBar reports the font you asked for, not the one that got
resolved, so this fails invisibly. Swap `TEXT_FONT` in `sketchybar/config.sh` only
for a font whose weights you have.

## Keys

`alt` is the modifier throughout.

| Keys | Action |
| --- | --- |
| `alt-1` … `alt-9`, `alt-0` | Focus the Nth window of the workspace, matching the bar's icon order |
| `alt-h/j/k/l` | Focus left / down / up / right |
| `alt-shift-h/j/k/l` | Move window |
| `ctrl-alt-1` … `ctrl-alt-4` | Switch workspace |
| `alt-shift-1` … `alt-shift-4` | Move window to workspace |
| `alt-tab` | Previous workspace |
| `alt-shift-tab` | Move workspace to next monitor |
| `alt-f` | Fullscreen |
| `alt-minus` / `alt-equal` | Resize |
| `alt-shift-;` | Service mode (`esc` exits, `f` toggles float, `r` resets layout) |
| `alt-shift-r` | Reload SketchyBar |

## How the bar updates

Entirely event-driven — no polling except the clock, which has to tick for
seconds. AeroSpace pushes `exec-on-workspace-change`, `on-focus-changed` and
`on-mode-changed` into SketchyBar as custom events; the input source rides a macOS
distributed notification.

One hidden item (`window_watcher`) repaints every workspace pill and window slot
from a single script run, diffing against a cached state file so an event touches
only the items that changed. Rewriting all of them made the bar visibly re-layout.

Window items are icon-only by design. Titles were dropped because nothing emits an
event when a title changes, so showing them required a poll.

## Known limitations

- **Wi-Fi shows the IP, not the SSID.** Since macOS 14 the network name requires
  Location Services authorization for the calling process, which a script
  SketchyBar spawns cannot get. `ipconfig`, `system_profiler` and `networksetup`
  all refuse; `airport` was removed. See the comment in `plugins/wifi.sh`.
- **Unmapped apps show a generic icon.** `plugins/icon_map.sh` is vendored from
  [sketchybar-app-font](https://github.com/kvndrsslr/sketchybar-app-font); apps it
  does not know fall back to `:default:`.
- **Keep-awake resets on reboot**, since its state lives in `$TMPDIR`.
