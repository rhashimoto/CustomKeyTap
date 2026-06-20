import Foundation
import CoreGraphics
import Carbon

// Mapping from the home row keycode to its associated modifier flags.
let homeRowConfigs: [Int64: UInt64] = [
  Int64(kVK_ANSI_S): CGEventFlags.maskCommand.rawValue,
  Int64(kVK_ANSI_D): CGEventFlags.maskAlternate.rawValue,
  Int64(kVK_ANSI_F): CGEventFlags.maskControl.rawValue,
  Int64(kVK_ANSI_J): CGEventFlags.maskControl.rawValue,
  Int64(kVK_ANSI_K): CGEventFlags.maskAlternate.rawValue,
  Int64(kVK_ANSI_L): CGEventFlags.maskCommand.rawValue,
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
  
  // Caps lock. This entry is only used as a marker. It does
  // not produce key events.
  Int64(kVK_Delete): LayerKey(kVK_CapsLock, CGEventFlags()),
]

let capsWordKeyCode = Int64(kVK_Delete)
let capsWordTargets: Set<Int64> = [
  Int64(kVK_ANSI_A),
  Int64(kVK_ANSI_B),
  Int64(kVK_ANSI_C),
  Int64(kVK_ANSI_D),
  Int64(kVK_ANSI_E),
  Int64(kVK_ANSI_F),
  Int64(kVK_ANSI_G),
  Int64(kVK_ANSI_H),
  Int64(kVK_ANSI_I),
  Int64(kVK_ANSI_J),
  Int64(kVK_ANSI_K),
  Int64(kVK_ANSI_L),
  Int64(kVK_ANSI_M),
  Int64(kVK_ANSI_N),
  Int64(kVK_ANSI_O),
  Int64(kVK_ANSI_P),
  Int64(kVK_ANSI_Q),
  Int64(kVK_ANSI_R),
  Int64(kVK_ANSI_S),
  Int64(kVK_ANSI_T),
  Int64(kVK_ANSI_U),
  Int64(kVK_ANSI_V),
  Int64(kVK_ANSI_W),
  Int64(kVK_ANSI_X),
  Int64(kVK_ANSI_Y),
  Int64(kVK_ANSI_Z),
  Int64(kVK_ANSI_Minus)
]
let capsWordNeutral: Set<Int64> = [
  Int64(kVK_ANSI_0),
  Int64(kVK_ANSI_1),
  Int64(kVK_ANSI_2),
  Int64(kVK_ANSI_3),
  Int64(kVK_ANSI_4),
  Int64(kVK_ANSI_5),
  Int64(kVK_ANSI_6),
  Int64(kVK_ANSI_7),
  Int64(kVK_ANSI_8),
  Int64(kVK_ANSI_9),
  Int64(kVK_Delete),
  Int64(kVK_ForwardDelete)
]
  
class KeyEventProcessor {
  var holdNanos: UInt64 = 235 * 1_000_000

  // Any keypress less than this many nanoseconds after the last tap
  // is another tap, not a hold.
  var flowNanos: UInt64 = 100 * 1_000_000

  var lastTapTime: UInt64 = 0
  var pending: [Int64: KeyPress] = [:]
  var pressed: [Int64: KeyPress] = [:]
  let post: (CGEvent) -> Void

  var isCapsWordActive: Bool = false
  
  init(post: @escaping (CGEvent) -> Void) {
    self.post = post
  }
  
  func setHoldMillis(millis: Int) {
    holdNanos = UInt64(millis) * 1_000_000
  }
  
  func setFlowMillis(millis: Int) {
    flowNanos = UInt64(millis) * 1_000_000
  }
  
  func handleEvent(_ event: CGEvent) -> CGEvent? {
    let eventCode = event.getIntegerValueField(.keyboardEventKeycode)
    
    // Check whether enough time has passed to establish holds.
    for (pressCode, var press) in pending {
      if event.timestamp - press.event.timestamp > holdNanos {
        resolvePendingHold(pressCode, &press)
      }
    }
    
    if event.type == .keyDown {
      var press = KeyPress(event: event)
      if pending.keys.contains(eventCode) ||
         pressed[eventCode]?.action == .modifier ||
         pressed[eventCode]?.action == .layer {
        // Ignore key repeat for possible modifier/layer holds.
      } else if !isTapHold(eventCode) ||
         isFlowTap(event) ||
         isRepeatedTap(eventCode, event) {
        // We can already classify this as a tap.
        pressed[eventCode] = press
      } else {
        // Defer until we can distinguish tap or hold behavior.
        press.action = homeRowConfigs.keys.contains(eventCode) ?
          .modifier :
          .layer
        pending[eventCode] = press
      }
      
      // Reset caps word at the end of a "word" (letters, numbers
      // underscore). In addition, backspace and delete do not reset
      // caps word.
      if !capsWordTargets.contains(eventCode) &&
         !capsWordNeutral.contains(eventCode) {
        isCapsWordActive = false
      }
    } else if event.type == .keyUp {
      // A keyUp event resolves all pending key actions. A pending press
      // before the key was pressed is a hold, otherwise it is a tap.
      if let keyPress = pending[eventCode] ?? pressed[eventCode] {
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
      isCapsWordActive = false
      return event
    }
    
    if pending.isEmpty {
      // Process pressed keys in the order they were pressed to build
      // the modifier and layer state for taps.
      var flags: UInt64 = 0
      var isLayerActive = false
      for (pressCode, press) in pressed.sorted(by: { $0.value.event.timestamp < $1.value.event.timestamp }) {
        if press.action == .modifier {
          flags |= homeRowConfigs[pressCode]!
        } else if press.action == .layer {
          isLayerActive = true
        } else if !press.posted {
          if isLayerActive, let layerKey = layerKeys[pressCode] {
            if (layerKey.code == Int64(kVK_CapsLock)) {
              isCapsWordActive = !isCapsWordActive
            } else {
              postTap(
                keyCode: layerKey.code,
                flags: press.event.flags.rawValue | layerKey.flags | flags)
            }
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
        pressed.removeValue(forKey: eventCode)
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
    pressed[keyCode] = press
    pending.removeValue(forKey: keyCode)
  }
  
  func isTapHold(_ keyCode: Int64) -> Bool {
    return keyCode == layerKeyCode
      || homeRowConfigs.keys.contains(keyCode)
  }
  
  func isFlowTap(_ event: CGEvent) -> Bool {
    assert(event.type == .keyDown)
    return event.timestamp - lastTapTime < flowNanos
  }
  
  func postTap(keyCode: Int64, flags: UInt64) {
    var capsWordFlags: UInt64 = 0
    if isCapsWordActive && capsWordTargets.contains(keyCode) {
      capsWordFlags = CGEventFlags.maskShift.rawValue
    }
    
    // Generate key tap press and release.
    for isDown in [true, false] {
      let syntheticEvent = CGEvent(
        keyboardEventSource: nil,
        virtualKey: CGKeyCode(keyCode),
        keyDown: isDown)!
      syntheticEvent.flags = CGEventFlags(rawValue: flags | capsWordFlags)
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
  var posted = false
}
