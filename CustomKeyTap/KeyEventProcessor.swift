import Foundation
import CoreGraphics
import Carbon
import OrderedCollections

// KeyEventProcessor enables tap-hold behavior, which allows keys to
// have one behavior when quickly tapped and released, and another
// behavior when held down. Here we configure some home row keys to
// act like modifier keys when held down.
let homeRowConfigs: [CGKeyCode: CGEventFlags] = [
  CGKeyCode(kVK_ANSI_S): .maskCommand,
  CGKeyCode(kVK_ANSI_D): .maskAlternate,
  CGKeyCode(kVK_ANSI_F): .maskControl,
  CGKeyCode(kVK_ANSI_J): .maskControl,
  CGKeyCode(kVK_ANSI_K): .maskAlternate,
  CGKeyCode(kVK_ANSI_L): .maskCommand,
]

// A different tap-hold scheme, instead of applying a modifier, is to
// arbitrarily redefine both key and modifier. This called an overlay
// or a layer. KeyEventProcessor supports a single such layer.
let layerKeyCode = CGKeyCode(kVK_Space)
struct LayerKey {
  let code: CGKeyCode
  let flags: CGEventFlags

  init(_ virtualKeyCode: Int, _ flags: CGEventFlags = []) {
    self.code = CGKeyCode(virtualKeyCode)
    self.flags = flags
  }
}

let layerKeys: [CGKeyCode: LayerKey] = [
  // Number row acts as function keys.
  CGKeyCode(kVK_ANSI_1): LayerKey(kVK_F1),
  CGKeyCode(kVK_ANSI_2): LayerKey(kVK_F2),
  CGKeyCode(kVK_ANSI_3): LayerKey(kVK_F3),
  CGKeyCode(kVK_ANSI_4): LayerKey(kVK_F4),
  CGKeyCode(kVK_ANSI_5): LayerKey(kVK_F5),
  CGKeyCode(kVK_ANSI_6): LayerKey(kVK_F6),
  CGKeyCode(kVK_ANSI_7): LayerKey(kVK_F7),
  CGKeyCode(kVK_ANSI_8): LayerKey(kVK_F8),
  CGKeyCode(kVK_ANSI_9): LayerKey(kVK_F9),
  CGKeyCode(kVK_ANSI_0): LayerKey(kVK_F10),

  // Standard editing shortcuts.
  CGKeyCode(kVK_ANSI_Z): LayerKey(kVK_ANSI_Z, .maskCommand),
  CGKeyCode(kVK_ANSI_X): LayerKey(kVK_ANSI_X, .maskCommand),
  CGKeyCode(kVK_ANSI_C): LayerKey(kVK_ANSI_C, .maskCommand),
  CGKeyCode(kVK_ANSI_V): LayerKey(kVK_ANSI_V, .maskCommand),

  // Navigation keys.
  CGKeyCode(kVK_ANSI_Q): LayerKey(kVK_Home),
  CGKeyCode(kVK_ANSI_W): LayerKey(kVK_PageUp),
  CGKeyCode(kVK_ANSI_E): LayerKey(kVK_PageDown),
  CGKeyCode(kVK_ANSI_R): LayerKey(kVK_End),

  // Vim navigation.
  // The flags are needed to make Spaces navigation work, but I do not
  // understand why.
  CGKeyCode(kVK_ANSI_H): LayerKey(kVK_LeftArrow, CGEventFlags(rawValue: 0x00a00000)),
  CGKeyCode(kVK_ANSI_J): LayerKey(kVK_DownArrow, CGEventFlags(rawValue: 0x00a00000)),
  CGKeyCode(kVK_ANSI_K): LayerKey(kVK_UpArrow, CGEventFlags(rawValue: 0x00a00000)),
  CGKeyCode(kVK_ANSI_L): LayerKey(kVK_RightArrow, CGEventFlags(rawValue: 0x00a00000)),

  // Emacs line navigation. The mappings here are strange because
  // they assume the Colemak key mapping is applied afterwards.
  CGKeyCode(kVK_ANSI_A): LayerKey(kVK_ANSI_A, .maskControl),
  CGKeyCode(kVK_ANSI_S): LayerKey(kVK_ANSI_B, .maskAlternate),
  CGKeyCode(kVK_ANSI_D): LayerKey(kVK_ANSI_E, .maskAlternate),
  CGKeyCode(kVK_ANSI_F): LayerKey(kVK_ANSI_K, .maskControl),

  // This entry is only used as a marker. It does not produce key events.
  // This is a special case KeyEventProcessor uses to implement
  // Caps Word.
  CGKeyCode(kVK_Delete): LayerKey(kVK_CapsLock),
]

// Caps Word is a smart caps lock that automatically deactivates
// itself at the end of a word. It also treats the hyphen key
// as underscore, which makes typing programming constants
// easier. The targets here are the keys that Caps Word
// capitalizes.
// https://docs.qmk.fm/features/caps_word
let capsWordTargets: Set<CGKeyCode> = [
  CGKeyCode(kVK_ANSI_A),
  CGKeyCode(kVK_ANSI_B),
  CGKeyCode(kVK_ANSI_C),
  CGKeyCode(kVK_ANSI_D),
  CGKeyCode(kVK_ANSI_E),
  CGKeyCode(kVK_ANSI_F),
  CGKeyCode(kVK_ANSI_G),
  CGKeyCode(kVK_ANSI_H),
  CGKeyCode(kVK_ANSI_I),
  CGKeyCode(kVK_ANSI_J),
  CGKeyCode(kVK_ANSI_K),
  CGKeyCode(kVK_ANSI_L),
  CGKeyCode(kVK_ANSI_M),
  CGKeyCode(kVK_ANSI_N),
  CGKeyCode(kVK_ANSI_O),
//  CGKeyCode(kVK_ANSI_P), // Colemak maps to ;
  CGKeyCode(kVK_ANSI_Semicolon), // Colemak maps to letter O
  CGKeyCode(kVK_ANSI_Q),
  CGKeyCode(kVK_ANSI_R),
  CGKeyCode(kVK_ANSI_S),
  CGKeyCode(kVK_ANSI_T),
  CGKeyCode(kVK_ANSI_U),
  CGKeyCode(kVK_ANSI_V),
  CGKeyCode(kVK_ANSI_W),
  CGKeyCode(kVK_ANSI_X),
  CGKeyCode(kVK_ANSI_Y),
  CGKeyCode(kVK_ANSI_Z),
  CGKeyCode(kVK_ANSI_Minus)
]

// These are keys that Caps Word does not capitalize but they
// do not terminate Caps Word.
let capsWordNeutral: Set<CGKeyCode> = [
  CGKeyCode(kVK_ANSI_0),
  CGKeyCode(kVK_ANSI_1),
  CGKeyCode(kVK_ANSI_2),
  CGKeyCode(kVK_ANSI_3),
  CGKeyCode(kVK_ANSI_4),
  CGKeyCode(kVK_ANSI_5),
  CGKeyCode(kVK_ANSI_6),
  CGKeyCode(kVK_ANSI_7),
  CGKeyCode(kVK_ANSI_8),
  CGKeyCode(kVK_ANSI_9),
  CGKeyCode(kVK_Delete),
  CGKeyCode(kVK_ForwardDelete)
]

class KeyEventProcessor {
  // A tap-hold key held for at least this many nanoseconds is considered
  // to be held.
  var holdNanos: UInt64 = 235 * 1_000_000

  // Any keypress less than this many nanoseconds after the last tap
  // is another tap, not a hold.
  var flowNanos: UInt64 = 150 * 1_000_000
  var flowTapTime: UInt64 = 0
  
  // All currently-held keys.
  var pressed: OrderedDictionary<CGKeyCode, KeyPress> = [:]
  
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
    let eventCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

    // Check whether enough time has passed to establish holds.
    for code in pressed.keys {
      guard let press = pressed[code], press.action == .pending else { continue }
      if event.timestamp - press.event.timestamp > holdNanos {
        pressed[code]?.action = resolvedHoldAction(for: code)
      }
    }

    if event.type == .keyDown {
      var press = KeyPress(event: event)
      if let action = pressed[eventCode]?.action, action != .tap {
        // Ignore key repeat for possible modifier/layer holds.
      } else if !isTapHold(eventCode) ||
         isFlowTap(event) ||
         isRepeatedTap(eventCode, event) ||
         isLayerKeyHeld(eventCode) {
        // We can already classify this as a tap.
        // Remove any existing entry so the new press is appended at the end,
        // preserving press order for iteration.
        pressed.removeValue(forKey: eventCode)
        pressed[eventCode] = press
      } else {
        // Defer until we can distinguish tap or hold behavior.
        press.action = .pending
        pressed[eventCode] = press
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
      if let keyPress = pressed[eventCode] {
        for code in pressed.keys {
          guard let pendingPress = pressed[code],
                pendingPress.action == .pending else { continue }
          if pendingPress.event.timestamp < keyPress.event.timestamp {
            pressed[code]?.action = resolvedHoldAction(for: code)
          } else {
            pressed[code]?.action = .tap
          }
        }
      } else {
        // TODO: output warning
      }
    } else {
      isCapsWordActive = false
      return event
    }

    let hasPending = pressed.values.contains(where: { $0.action == .pending })
    if !hasPending {
      // Process resolved keys in the order they were pressed to build
      // the modifier and layer state for taps.
      var flags: CGEventFlags = []
      var isLayerActive = false
      for (pressCode, press) in pressed {
        if press.action == .modifier {
          flags.formUnion(homeRowConfigs[pressCode]!)
        } else if press.action == .layer {
          isLayerActive = true
        } else if !press.posted {
          if isLayerActive, let layerKey = layerKeys[pressCode] {
            if layerKey.code == CGKeyCode(kVK_CapsLock) {
              isCapsWordActive = !isCapsWordActive
            } else {
              postTap(
                keyCode: layerKey.code,
                flags: press.event.flags.union(layerKey.flags).union(flags))
              flowTapTime = press.event.timestamp
            }
          } else {
            // Use flags from the original event, plus our modifiers.
            postTap(
              keyCode: pressCode,
              flags: press.event.flags.union(flags))
            flowTapTime = press.event.timestamp
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

  // Returns the tap-hold type.
  func resolvedHoldAction(for keyCode: CGKeyCode) -> KeyAction {
    return homeRowConfigs.keys.contains(keyCode) ? .modifier : .layer
  }

  // Returns true if keyCode is a tap-hold key.
  func isTapHold(_ keyCode: CGKeyCode) -> Bool {
    return keyCode == layerKeyCode
      || homeRowConfigs.keys.contains(keyCode)
  }

  // Returns true if key should be considered a tap because it quickly
  // follows another tap.
  func isFlowTap(_ event: CGEvent) -> Bool {
    assert(event.type == .keyDown)
    return event.timestamp - flowTapTime < flowNanos
  }

  // Send a synthesized key down/up event pair.
  func postTap(keyCode: CGKeyCode, flags: CGEventFlags) {
    var capsWordFlags: CGEventFlags = []
    if isCapsWordActive && capsWordTargets.contains(keyCode) {
      capsWordFlags = .maskShift
    }

    // Generate key tap press and release.
    for keyDown in [true, false] {
      let syntheticEvent = CGEvent(
        keyboardEventSource: nil,
        virtualKey: keyCode,
        keyDown: keyDown)!
      syntheticEvent.flags = flags.union(capsWordFlags)
      post(syntheticEvent)
    }
  }

  func isRepeatedTap(_ keyCode: CGKeyCode, _ event: CGEvent) -> Bool {
    assert(event.type == .keyDown)
    return pressed[keyCode]?.action == .tap
  }

  // Returns true if the layer key is currently pressed and keyCode is
  // not already pressed.
  func isLayerKeyHeld(_ keyCode: CGKeyCode) -> Bool {
    return keyCode != layerKeyCode
      && pressed[layerKeyCode] != nil
      && pressed[keyCode] == nil
  }
}

enum KeyAction {
  case pending
  case tap
  case modifier
  case layer
}

struct KeyPress {
  let event: CGEvent
  var action: KeyAction = .tap
  var posted = false
}
