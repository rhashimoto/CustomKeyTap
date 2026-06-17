import Foundation
import CoreGraphics

let tapTerm : UInt64 = 235

// Any keypress less than this many milliseconds after the last tap
// is another tap, not a hold.
let flowTapTerm: UInt64 = 100

struct HomeRowModifier {
  // Keycode for the modifier this key activates when held.
  let modKeyCode: UInt64
  
  // Modifier flags.
  let modFlags: UInt64
}

// Mapping from the home row keycode to its associated modifier.
let homeRowKeys: [Int64: HomeRowModifier] = [
   1: HomeRowModifier(modKeyCode: 55, modFlags: CGEventFlags.maskCommand.rawValue   | 0x0008), // S command
   2: HomeRowModifier(modKeyCode: 58, modFlags: CGEventFlags.maskAlternate.rawValue | 0x0020), // D alt
   3: HomeRowModifier(modKeyCode: 59, modFlags: CGEventFlags.maskControl.rawValue   | 0x0001), // F control
  38: HomeRowModifier(modKeyCode: 62, modFlags: CGEventFlags.maskControl.rawValue   | 0x2000), // J control
  40: HomeRowModifier(modKeyCode: 61, modFlags: CGEventFlags.maskAlternate.rawValue | 0x0040), // K alt
  37: HomeRowModifier(modKeyCode: 54, modFlags: CGEventFlags.maskCommand.rawValue   | 0x0010), // L command
]

class KeyEventProcessor {
  var lastTapTime: UInt64 = 0
  let post: (CGEvent) -> Void

  init(post: @escaping (CGEvent) -> Void) {
    self.post = post
  }

  func handleEvent(_ event: CGEvent) -> CGEvent? {
    let type = event.type
    let timestamp = event.timestamp
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags
    
    if event.type == .keyDown {
      if homeRowKeys.keys.contains(keyCode) {
        
      }
    } else if event.type == .keyUp {
      
    }
    _ = type
    _ = timestamp
    _ = keyCode
    _ = flags
    
    return event
  }
}
