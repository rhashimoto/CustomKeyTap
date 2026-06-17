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
  var pressed: [Int64: KeyPress] = [:]
  let post: (CGEvent) -> Void

  init(post: @escaping (CGEvent) -> Void) {
    self.post = post
  }

  func handleEvent(_ event: CGEvent) -> CGEvent? {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    var outputs: [CGEvent] = []
    
    if event.type == .keyDown {
      var press = KeyPress(keyCode: keyCode, flags: event.flags, timestamp: event.timestamp)
      if isFlowTap(event) {
        press.resolution = .tap
        lastTapTime = event.timestamp
      }
      if isHomeRowKey(keyCode) {
        
      }
      
      outputs.append(event)
      pressed[keyCode] = press
    } else if event.type == .keyUp {
      pressed.removeValue(forKey: keyCode)
    }
    
    if outputs.isEmpty { return nil }
    for output in outputs {
      if output != event {
        post(output)
      }
    }
    return event
  }
  
  func isHomeRowKey(_ keyCode: Int64) -> Bool {
    return homeRowKeys.keys.contains(keyCode)
  }
  
  func isFlowTap(_ event: CGEvent) -> Bool {
    assert(event.type == .keyDown)
    return event.timestamp - lastTapTime < flowTapTerm
  }
}

enum KeyResolution {
  case pending
  case tap
  case modifier
  case layer
}

struct KeyPress {
  let keyCode: Int64
  let flags: CGEventFlags
  let timestamp: UInt64
  
  var resolution: KeyResolution = .pending
}
