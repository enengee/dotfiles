// alt-release-watcher — fire a command when the Option (alt) key is released.
//
// The alt-tab workspace switcher wants cmd-tab semantics: cycle a highlight
// while alt is held, commit to the highlighted workspace the instant alt comes
// up. Nothing in AeroSpace or SketchyBar can see a modifier being released —
// AeroSpace's events are press-only and SketchyBar cannot read modifiers at all
// — so that one signal has to come from AppKit, which is why this tiny helper
// exists rather than living in the shell scripts with everything else.
//
// It is a global NSEvent monitor on .flagsChanged, which is event-driven: the
// process sleeps in the run loop until the OS delivers a modifier change. No
// polling, no timer. On each change it compares the Option bit against the
// previous sample and, on a true->false transition, runs $COMMIT_SCRIPT.
//
// A global monitor sees events destined for other apps but cannot alter or
// consume them, so this only observes; alt-tab is still handled entirely by
// AeroSpace. Observing other apps' key events is exactly what macOS gates behind
// Input Monitoring, so the binary needs that permission granted once (the launchd
// agent triggers the prompt on first run). It reads modifier *flags* only, never
// keycodes or characters.
//
// COMMIT_SCRIPT is passed in the environment by the launchd agent. Kept as one
// explicit path rather than discovered, so the helper has no knowledge of the
// repo layout.

import AppKit
import Foundation

guard let commitScript = ProcessInfo.processInfo.environment["COMMIT_SCRIPT"],
      !commitScript.isEmpty else {
    FileHandle.standardError.write(Data("COMMIT_SCRIPT not set\n".utf8))
    exit(1)
}

// Only one commit may run at a time. A release fires a short-lived shell; if the
// user tabs and releases again before it finishes, serialize rather than overlap.
let commitQueue = DispatchQueue(label: "alt-release-commit")

// Debounced against spurious repeats: macOS can deliver more than one
// .flagsChanged for a single physical change, and only a genuine down->up edge
// should commit.
var optionWasDown = false

func optionIsDown(_ flags: NSEvent.ModifierFlags) -> Bool {
    flags.contains(.option)
}

func runCommit() {
    commitQueue.async {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-lc", commitScript]
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            FileHandle.standardError.write(Data("commit failed: \(error)\n".utf8))
        }
    }
}

NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
    let down = optionIsDown(event.modifierFlags)
    if optionWasDown && !down {
        runCommit()
    }
    optionWasDown = down
}

// A global monitor needs a running run loop but no app activation, windows, or
// Dock presence — LSUIElement in the agent keeps it invisible. This never
// returns.
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
