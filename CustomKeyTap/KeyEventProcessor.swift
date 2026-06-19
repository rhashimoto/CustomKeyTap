import Foundation
import CoreGraphics
import Carbon

let tapTerm : UInt64 = 235 * 1_000_000

// Any keypress less than this many nanoseconds after the last tap
// is another tap, not a hold.
let flowTapTerm: UInt64 = 100 * 1_000_000

struct HomeRowConfig {
  // CGEventFlags for a modifier.
  let flags: UInt64
}

// Mapping from the home row keycode to its associated modifier.
let homeRowConfigs: [Int64: HomeRowConfig] = [
  Int64(kVK_ANSI_Q): HomeRowConfig(flags: CGEventFlags.maskShift.rawValue),
//   1: HomeRowModifier(modKeyCode: 55, modFlags: CGEventFlags.maskCommand.rawValue   | 0x0008), // S command
//   2: HomeRowModifier(modKeyCode: 58, modFlags: CGEventFlags.maskAlternate.rawValue | 0x0020), // D alt
//   3: HomeRowModifier(modKeyCode: 59, modFlags: CGEventFlags.maskControl.rawValue   | 0x0001), // F control
//  38: HomeRowModifier(modKeyCode: 62, modFlags: CGEventFlags.maskControl.rawValue   | 0x2000), // J control
//  40: HomeRowModifier(modKeyCode: 61, modFlags: CGEventFlags.maskAlternate.rawValue | 0x0040), // K alt
//  37: HomeRowModifier(modKeyCode: 54, modFlags: CGEventFlags.maskCommand.rawValue   | 0x0010), // L command
]

class KeyEventProcessor {
  var lastTapTime: UInt64 = 0
  var pending: [Int64: KeyPress] = [:]
  var pressed: [Int64: KeyPress] = [:]
  var shift = false
  let post: (CGEvent) -> Void
  
  init(post: @escaping (CGEvent) -> Void) {
    self.post = post
  }
  
  func handleEvent(_ event: CGEvent) -> CGEvent? {
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    
    // Check whether enough time has passed to establish holds.
    for (pressKeyCode, var press) in pending {
      if event.timestamp - press.event.timestamp > tapTerm {
        resolvePendingHold(pressKeyCode, &press)
      }
    }
    
    if event.type == .keyDown {
      var press = KeyPress(event: event)
      if pending.keys.contains(keyCode) ||
         pressed[keyCode]?.action == .modifier ||
         pressed[keyCode]?.action == .layer {
        // Ignore key repeat for possible modifier/layer holds.
      } else if !isTapHold(keyCode) ||
         isFlowTap(event) ||
         isRepeatedTap(keyCode, event) {
        // We can already classify this as a tap.
        pressed[keyCode] = press
      } else {
        // Defer until we can distinguish tap or hold behavior.
        if let homeRowConfig = homeRowConfigs[keyCode] {
          press.action = .modifier
          press.flags = homeRowConfig.flags
        } else {
          press.action = .layer
        }
        pending[keyCode] = press
      }
    } else if event.type == .keyUp {
      // A key release resolves all pending key actions. A pending press
      // before the key was pressed is a hold, otherwise a tap
      if let keyPress = pending[keyCode] ?? pressed[keyCode] {
        for (pendingCode, var pendingPress) in pending {
          if pendingPress.event.timestamp < keyPress.event.timestamp {
            resolvePendingHold(pendingCode, &pendingPress)
          } else {
            resolvePendingTap(pendingCode, &pendingPress)
          }
        }
      } else {
        // TODO: output warning
      }
    } else {
      return event
    }
    
    print("pressed \(pressed)")
    if pending.isEmpty {
      var flags: UInt64 = 0
      for (pressCode, press) in pressed.sorted(by: { $0.value.event.timestamp < $1.value.event.timestamp }) {
        if press.action == .modifier {
          flags |= press.flags
        } else if press.action == .layer {
          // TODO
        } else if !press.posted {
          // Generate 
          for isDown in [true, false] {
            let syntheticEvent = CGEvent(
              keyboardEventSource: nil,
              virtualKey: CGKeyCode(pressCode),
              keyDown: isDown)!
            syntheticEvent.flags = (press.event.flags)
            syntheticEvent.flags.insert(CGEventFlags(rawValue: flags))
            post(syntheticEvent)
          }
          pressed[pressCode]?.posted = true
        }
      }
      
      if event.type == .keyUp {
        pressed.removeValue(forKey: keyCode)
      }
    }
    
    return nil
  }
  
  func resolvePendingHold(_ keyCode: Int64, _ press: inout KeyPress) {
    pressed[keyCode] = press
    pending.removeValue(forKey: keyCode)
  }
  
  func resolvePendingTap(_ keyCode: Int64, _ press: inout KeyPress) {
    press.action = .tap
    press.flags = 0
    pressed[keyCode] = press
    pending.removeValue(forKey: keyCode)
  }
  
  func isTapHold(_ keyCode: Int64) -> Bool {
    return homeRowConfigs.keys.contains(keyCode)
  }
  
  func isFlowTap(_ event: CGEvent) -> Bool {
    assert(event.type == .keyDown)
    return event.timestamp - lastTapTime < flowTapTerm
  }
  
  func isRepeatedTap(_ keyCode: Int64, _ event: CGEvent) -> Bool {
    assert(event.type == .keyDown)
    if let press = pressed[keyCode] {
      return pressed.count == 1 && press.action == .tap
    }
    return false
  }
}

enum KeyAction {
  case tap
  case modifier
  case layer
}

struct KeyPress {
  let event: CGEvent
  var action: KeyAction = .tap
  var code: Int64 = -1
  var flags: UInt64 = 0
  var posted = false
}
