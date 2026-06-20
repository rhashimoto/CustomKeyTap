import Foundation
import CoreGraphics
import Carbon
import OrderedCollections

// Mapping from the home row keycode to its associated modifier flags.
let homeRowConfigs: [CGKeyCode: CGEventFlags] = [
  CGKeyCode(kVK_ANSI_S): .maskCommand,
  CGKeyCode(kVK_ANSI_D): .maskAlternate,
  CGKeyCode(kVK_ANSI_F): .maskControl,
  CGKeyCode(kVK_ANSI_J): .maskControl,
  CGKeyCode(kVK_ANSI_K): .maskAlternate,
  CGKeyCode(kVK_ANSI_L): .maskCommand,
]

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
  CGKeyCode(kVK_ANSI_Z): LayerKey(kVK_ANSI_Z, .maskCommand),
  CGKeyCode(kVK_ANSI_X): LayerKey(kVK_ANSI_X, .maskCommand),
  CGKeyCode(kVK_ANSI_C): LayerKey(kVK_ANSI_C, .maskCommand),
  CGKeyCode(kVK_ANSI_V): LayerKey(kVK_ANSI_V, .maskCommand),

  // Navigation keys
  CGKeyCode(kVK_ANSI_Q): LayerKey(kVK_Home),
  CGKeyCode(kVK_ANSI_W): LayerKey(kVK_PageUp),
  CGKeyCode(kVK_ANSI_E): LayerKey(kVK_PageDown),
  CGKeyCode(kVK_ANSI_R): LayerKey(kVK_End),

  // Vim navigation
  CGKeyCode(kVK_ANSI_H): LayerKey(kVK_LeftArrow),
  CGKeyCode(kVK_ANSI_J): LayerKey(kVK_DownArrow),
  CGKeyCode(kVK_ANSI_K): LayerKey(kVK_UpArrow),
  CGKeyCode(kVK_ANSI_L): LayerKey(kVK_RightArrow),

  // Emacs line navigation
  CGKeyCode(kVK_ANSI_A): LayerKey(kVK_ANSI_A, .maskControl),
  CGKeyCode(kVK_ANSI_S): LayerKey(kVK_ANSI_B, .maskAlternate),
  CGKeyCode(kVK_ANSI_D): LayerKey(kVK_ANSI_F, .maskAlternate),
  CGKeyCode(kVK_ANSI_F): LayerKey(kVK_ANSI_E, .maskControl),

  // Caps lock. This entry is only used as a marker. It does
  // not produce key events.
  CGKeyCode(kVK_Delete): LayerKey(kVK_CapsLock),
]

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
  CGKeyCode(kVK_ANSI_P),
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
  var holdNanos: UInt64 = 235 * 1_000_000

  // Any keypress less than this many nanoseconds after the last tap
  // is another tap, not a hold.
  var flowNanos: UInt64 = 100 * 1_000_000

  var lastTapTime: UInt64 = 0
  // All currently-held keys. The action distinguishes still-undecided
  // (.pending) presses from those resolved as .tap, .modifier, or .layer.
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
         isRepeatedTap(eventCode, event) {
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
              lastTapTime = press.event.timestamp
            }
          } else {
            // Use flags from the original event, plus our modifiers.
            postTap(
              keyCode: pressCode,
              flags: press.event.flags.union(flags))
            lastTapTime = press.event.timestamp
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

  func resolvedHoldAction(for keyCode: CGKeyCode) -> KeyAction {
    return homeRowConfigs.keys.contains(keyCode) ? .modifier : .layer
  }

  func isTapHold(_ keyCode: CGKeyCode) -> Bool {
    return keyCode == layerKeyCode
      || homeRowConfigs.keys.contains(keyCode)
  }

  func isFlowTap(_ event: CGEvent) -> Bool {
    assert(event.type == .keyDown)
    return event.timestamp - lastTapTime < flowNanos
  }

  func postTap(keyCode: CGKeyCode, flags: CGEventFlags) {
    var capsWordFlags: CGEventFlags = []
    if isCapsWordActive && capsWordTargets.contains(keyCode) {
      capsWordFlags = .maskShift
    }

    // Generate key tap press and release.
    for isDown in [true, false] {
      let syntheticEvent = CGEvent(
        keyboardEventSource: nil,
        virtualKey: keyCode,
        keyDown: isDown)!
      syntheticEvent.flags = flags.union(capsWordFlags)
      post(syntheticEvent)
    }
  }

  func isRepeatedTap(_ keyCode: CGKeyCode, _ event: CGEvent) -> Bool {
    assert(event.type == .keyDown)
    if let press = pressed[keyCode], press.action == .tap {
      let resolvedCount = pressed.values.filter { $0.action != .pending }.count
      return resolvedCount == 1
    }
    return false
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
