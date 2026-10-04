import CoreGraphics
import Foundation

let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

for info in infos {
    guard let id = info[kCGWindowNumber as String] as? UInt32,
          info[kCGWindowLayer as String] as? Int == 0,
          let bounds = info[kCGWindowBounds as String] as? NSDictionary,
          let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
          frame.width > 0 else { continue }
    var display = CGDirectDisplayID()
    var count: UInt32 = 0
    guard CGGetDisplaysWithPoint(CGPoint(x: frame.midX, y: frame.midY), 1, &display, &count) == .success, count == 1 else { continue }
    let left = min(max(CGDisplayBounds(display).midX - frame.minX, 0), frame.width) * 2
    let side = left > frame.width ? "L" : left < frame.width ? "R" : "S"
    print(id, side, Int(frame.minY), Int(frame.minX))
}
