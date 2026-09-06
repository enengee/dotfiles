# dotfiles

AeroSpace tiling window manager and a SketchyBar status bar that shows, per
monitor, the workspace visible on it and an app icon per window inside it.

```
[ 󰍹 2 ] [  ] [  ] [  ]              [  ] [ ⌨ ABC ] [ 󰖩 ] [ 🔉 44% ] [ 🔋 87% ] [ 🕐 Sat 06 Sep 00:14:22 ]
```

Workspace pills are built per monitor and labelled from whichever workspace is
visible there, read from AeroSpace at paint time. No workspace is named anywhere in
the config, so this works unchanged whatever you call them.

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

No binding names a workspace, and `persistent-workspaces` is empty, so nothing
about the workspace set is baked into the config — AeroSpace creates a workspace
on demand and drops it when it empties. `alt-tab` cycles whatever exists, in
alphabetical order, across every monitor: landing on a workspace that lives on
another screen moves focus to that screen.

The flip side is that nothing can address a workspace by name, so there is no
binding that creates one or moves a window to one. If you want either, add a
`workspace <name>` or `move-node-to-workspace <name>` binding, and list the names
in `persistent-workspaces` if they should survive going empty — at which point the
set of names becomes machine-specific.

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
| `alt-tab` | Next workspace, wrapping round — spans all monitors |
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

Items are never created or destroyed after startup. The bar draws the left region
in item *creation* order, so a group of items is created up front for each display
id 1..`MAX_DISPLAYS` (`config.sh`), and ids with no monitor behind them are bound
to a display that does not exist and simply do not draw. Plugging or unplugging a
monitor is then an ordinary repaint. Rebuilding the items on a display change
instead is what used to scramble the tab order: a plug fires a burst of events, so
two rebuilds could run at once and interleave their `--add` calls.

Window items are icon-only by design. Titles were dropped because nothing emits an
event when a title changes, so showing them required a poll.

## Known limitations

- **More than `MAX_DISPLAYS` monitors show an empty left side.** Item groups are
  pre-created for that many display ids; raise it in `config.sh` if you attach
  more.
- **Wi-Fi is icon-only, with no network name.** Since macOS 14 the SSID requires
  Location Services authorization for the calling process, which a script
  SketchyBar spawns cannot get. `ipconfig`, `system_profiler` and `networksetup`
  all refuse; `airport` was removed. The icon colour carries the state instead —
  red off, yellow no usable connection, green connected. See the comment in
  `plugins/wifi.sh`.
- **Unmapped apps show a generic icon.** `plugins/icon_map.sh` is vendored from
  [sketchybar-app-font](https://github.com/kvndrsslr/sketchybar-app-font); apps it
  does not know fall back to `:default:`.
- **Keep-awake resets on reboot**, since its state lives in `$TMPDIR`.
