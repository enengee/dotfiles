# window-sides

A one-shot helper for the `alt-shift-comma` re-layout
(`../scripts/relayout-columns.sh`). It prints one line per on-screen window:

    <window-id> <L|R|S> <y> <x>

`L`/`R` means more than half of the window's width lies in the left/right half
of the monitor that holds the window's center; `S` means exactly half. The script
uses `y`/`x` to keep each column's top-to-bottom order.

AeroSpace cannot report window positions, and reading its layout order means
moving focus window to window, which fires `on-focus-changed` for every step and
races SketchyBar's repaints. This helper reads `CGWindowListCopyWindowInfo`
instead, which needs no permission and changes no focus. `install.sh` builds it
to `~/.local/bin/window-sides`; without it, `alt-shift-comma` does nothing.
