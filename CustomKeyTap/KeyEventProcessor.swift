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
  
  init(_ flags: CGEventFlags) {
    self.flags = flags.rawValue
  }
}

// Mapping from the home row keycode to its associated modifier.
let homeRowConfigs: [Int64: HomeRowConfig] = [
//  Int64(kVK_ANSI_Q): HomeRowConfig(.maskShift),
  Int64(kVK_ANSI_S): HomeRowConfig(.maskCommand),
  Int64(kVK_ANSI_D): HomeRowConfig(.maskAlternate),
  Int64(kVK_ANSI_F): HomeRowConfig(.maskControl),
  Int64(kVK_ANSI_J): HomeRowConfig(.maskControl),
  Int64(kVK_ANSI_K): HomeRowConfig(.maskAlternate),
  Int64(kVK_ANSI_L): HomeRowConfig(.maskCommand),
]

let layerKeyCode = Int64(kVK_Space)

struct LayerKey {
  let code: Int64
  let flags: UInt64
  
  init(_ virtualKeyCode: Int, _ flags: CGEventFlags) {
    self.code = Int64(virtualKeyCode)
    self.flags = flags.rawValue
  }
}

let layerKeys: [Int64: LayerKey] = [
  Int64(kVK_ANSI_Z): LayerKey(kVK_ANSI_Z, CGEventFlags.maskCommand),
  Int64(kVK_ANSI_X): LayerKey(kVK_ANSI_X, CGEventFlags.maskCommand),
  Int64(kVK_ANSI_C): LayerKey(kVK_ANSI_C, CGEventFlags.maskCommand),
  Int64(kVK_ANSI_V): LayerKey(kVK_ANSI_V, CGEventFlags.maskCommand),
  
  // Navigation keys
  Int64(kVK_ANSI_Q): LayerKey(kVK_Home, CGEventFlags()),
  Int64(kVK_ANSI_W): LayerKey(kVK_PageUp, CGEventFlags()),
  Int64(kVK_ANSI_E): LayerKey(kVK_PageDown, CGEventFlags()),
  Int64(kVK_ANSI_R): LayerKey(kVK_End, CGEventFlags()),

  // Vim navigation
  Int64(kVK_ANSI_H): LayerKey(kVK_LeftArrow, CGEventFlags()),
  Int64(kVK_ANSI_J): LayerKey(kVK_DownArrow, CGEventFlags()),
  Int64(kVK_ANSI_K): LayerKey(kVK_UpArrow, CGEventFlags()),
  Int64(kVK_ANSI_L): LayerKey(kVK_RightArrow, CGEventFlags()),
  
  // Emacs line navigation
  Int64(kVK_ANSI_A): LayerKey(kVK_ANSI_A, CGEventFlags.maskControl),
  Int64(kVK_ANSI_S): LayerKey(kVK_ANSI_B, CGEventFlags.maskAlternate),
  Int64(kVK_ANSI_D): LayerKey(kVK_ANSI_F, CGEventFlags.maskAlternate),
  Int64(kVK_ANSI_F): LayerKey(kVK_ANSI_E, CGEventFlags.maskControl),
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
      // A keyUp event resolves all pending key actions. A pending press
      // before the key was pressed is a hold, otherwise it is a tap.
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
    
    if pending.isEmpty {
      // Process pressed keys in the order they were pressed to build
      // the modifier and layer state for taps.
      var flags: UInt64 = 0
      for (pressCode, press) in pressed.sorted(by: { $0.value.event.timestamp < $1.value.event.timestamp }) {
        if press.action == .modifier {
          flags |= press.flags
        } else if !press.posted {
          if press.action == .layer, let layerKey = layerKeys[pressCode] {
            postTap(
              keyCode: layerKey.code,
              flags: press.event.flags.rawValue | layerKey.flags | flags)
          } else {
            // Use flags from the original event, plus our modifiers.
            postTap(
              keyCode: pressCode,
              flags: press.event.flags.rawValue | flags)
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
    return keyCode == layerKeyCode
      || homeRowConfigs.keys.contains(keyCode)
  }
  
  func isFlowTap(_ event: CGEvent) -> Bool {
    assert(event.type == .keyDown)
    return event.timestamp - lastTapTime < flowTapTerm
  }
  
  func postTap(keyCode: Int64, flags: UInt64) {
    // Generate key tap press and release.
    for isDown in [true, false] {
      let syntheticEvent = CGEvent(
        keyboardEventSource: nil,
        virtualKey: CGKeyCode(keyCode),
        keyDown: isDown)!
      syntheticEvent.flags = CGEventFlags(rawValue: flags)
      post(syntheticEvent)
    }
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
  var flags: UInt64 = 0
  var posted = false
}
