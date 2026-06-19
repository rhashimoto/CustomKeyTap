import Foundation
import CoreGraphics
import Carbon

// Global boot time reference to align event.timestamp (monotonic) with calendar date
let bootTime = Date().addingTimeInterval(-ProcessInfo.processInfo.systemUptime)

let cvtKeyCodeToString: [Int: String] = [
  // Letter keys
  kVK_ANSI_A: "A",                          // 0
  kVK_ANSI_B: "B",                          // 11
  kVK_ANSI_C: "C",                          // 8
  kVK_ANSI_D: "D",                          // 2
  kVK_ANSI_E: "E",                          // 14
  kVK_ANSI_F: "F",                          // 3
  kVK_ANSI_G: "G",                          // 5
  kVK_ANSI_H: "H",                          // 4
  kVK_ANSI_I: "I",                          // 34
  kVK_ANSI_J: "J",                          // 38
  kVK_ANSI_K: "K",                          // 40
  kVK_ANSI_L: "L",                          // 37
  kVK_ANSI_M: "M",                          // 46
  kVK_ANSI_N: "N",                          // 45
  kVK_ANSI_O: "O",                          // 31
  kVK_ANSI_P: "P",                          // 35
  kVK_ANSI_Q: "Q",                          // 12
  kVK_ANSI_R: "R",                          // 15
  kVK_ANSI_S: "S",                          // 1
  kVK_ANSI_T: "T",                          // 17
  kVK_ANSI_U: "U",                          // 32
  kVK_ANSI_V: "V",                          // 9
  kVK_ANSI_W: "W",                          // 13
  kVK_ANSI_X: "X",                          // 7
  kVK_ANSI_Y: "Y",                          // 16
  kVK_ANSI_Z: "Z",                          // 6

  // Number keys
  kVK_ANSI_0: "0",                          // 29
  kVK_ANSI_1: "1",                          // 18
  kVK_ANSI_2: "2",                          // 19
  kVK_ANSI_3: "3",                          // 20
  kVK_ANSI_4: "4",                          // 21
  kVK_ANSI_5: "5",                          // 23
  kVK_ANSI_6: "6",                          // 22
  kVK_ANSI_7: "7",                          // 26
  kVK_ANSI_8: "8",                          // 28
  kVK_ANSI_9: "9",                          // 25

  // Punctuation keys
  kVK_ANSI_Backslash: "Backslash",          // 42
  kVK_ANSI_Comma: "Comma",                  // 43
  kVK_ANSI_Equal: "Equal",                  // 24
  kVK_ANSI_Grave: "Grave",                  // 50
  kVK_ANSI_LeftBracket: "LeftBracket",      // 33
  kVK_ANSI_Minus: "Minus",                  // 27
  kVK_ANSI_Period: "Period",                // 47
  kVK_ANSI_Quote: "Quote",                  // 39
  kVK_ANSI_RightBracket: "RightBracket",    // 30
  kVK_ANSI_Semicolon: "Semicolon",          // 41
  kVK_ANSI_Slash: "Slash",                  // 44

  // Modifier keys
  kVK_CapsLock: "CapsLock",                 // 57
  kVK_Command: "Command",                   // 55
  kVK_Control: "Control",                   // 59
  kVK_Function: "Function",                 // 63
  kVK_Option: "Option",                     // 58
  kVK_Shift: "Shift",                       // 56
  kVK_RightCommand: "RightCommand",         // 54
  kVK_RightControl: "RightControl",         // 62
  kVK_RightOption: "RightOption",           // 61
  kVK_RightShift: "RightShift",             // 60

  // Special keys
  kVK_ContextualMenu: "ContextualMenu",     // 110
  kVK_Delete: "Delete",                     // 51
  kVK_Escape: "Escape",                     // 53
  kVK_Return: "Return",                     // 36
  kVK_Space: "Space",                       // 49
  kVK_Tab: "Tab",                           // 48

  // Function keys
  kVK_F1: "F1",                             // 122
  kVK_F2: "F2",                             // 120
  kVK_F3: "F3",                             // 99
  kVK_F4: "F4",                             // 118
  kVK_F5: "F5",                             // 96
  kVK_F6: "F6",                             // 97
  kVK_F7: "F7",                             // 98
  kVK_F8: "F8",                             // 100
  kVK_F9: "F9",                             // 101
  kVK_F10: "F10",                           // 109
  kVK_F11: "F11",                           // 103
  kVK_F12: "F12",                           // 111
  kVK_F13: "F13",                           // 105
  kVK_F14: "F14",                           // 107
  kVK_F15: "F15",                           // 113
  kVK_F16: "F16",                           // 106
  kVK_F17: "F17",                           // 64
  kVK_F18: "F18",                           // 79
  kVK_F19: "F19",                           // 80
  kVK_F20: "F20",                           // 90

  // Arrow keys
  kVK_DownArrow: "DownArrow",               // 125
  kVK_LeftArrow: "LeftArrow",               // 123
  kVK_RightArrow: "RightArrow",             // 124
  kVK_UpArrow: "UpArrow",                   // 126

  // Navigation keys
  kVK_End: "End",                           // 119
  kVK_ForwardDelete: "ForwardDelete",       // 117
  kVK_Help: "Help",                         // 114
  kVK_Home: "Home",                         // 115
  kVK_PageDown: "PageDown",                 // 121
  kVK_PageUp: "PageUp",                     // 116

  // Keypad keys
  kVK_ANSI_Keypad0: "Keypad0",              // 82
  kVK_ANSI_Keypad1: "Keypad1",              // 83
  kVK_ANSI_Keypad2: "Keypad2",              // 84
  kVK_ANSI_Keypad3: "Keypad3",              // 85
  kVK_ANSI_Keypad4: "Keypad4",              // 86
  kVK_ANSI_Keypad5: "Keypad5",              // 87
  kVK_ANSI_Keypad6: "Keypad6",              // 88
  kVK_ANSI_Keypad7: "Keypad7",              // 89
  kVK_ANSI_Keypad8: "Keypad8",              // 91
  kVK_ANSI_Keypad9: "Keypad9",              // 92
  kVK_ANSI_KeypadClear: "KeypadClear",      // 71
  kVK_ANSI_KeypadDecimal: "KeypadDecimal",  // 65
  kVK_ANSI_KeypadDivide: "KeypadDivide",    // 75
  kVK_ANSI_KeypadEnter: "KeypadEnter",      // 76
  kVK_ANSI_KeypadEquals: "KeypadEquals",    // 81
  kVK_ANSI_KeypadMinus: "KeypadMinus",      // 78
  kVK_ANSI_KeypadMultiply: "KeypadMultiply",// 67
  kVK_ANSI_KeypadPlus: "KeypadPlus",        // 69

  // Media keys
  kVK_Mute: "Mute",                         // 74
  kVK_VolumeDown: "VolumeDown",             // 73
  kVK_VolumeUp: "VolumeUp",                 // 72
]

// Helper to convert CGEventType to String
func eventTypeToString(_ type: CGEventType) -> String {
  switch type {
  case .keyDown: return "keyDown"
  case .keyUp: return "keyUp"
  case .flagsChanged: return "flagsChanged"
  default: return "unknown(\(type.rawValue))"
  }
}

// Helper to convert String back to CGEventType
func stringToEventType(_ str: String) -> CGEventType? {
  switch str {
  case "keyDown": return .keyDown
  case "keyUp": return .keyUp
  case "flagsChanged": return .flagsChanged
  default:
    if str.hasPrefix("unknown("),
       let rawStr = str.split(separator: "(").last?.dropLast(),
       let rawValue = UInt32(rawStr) {
      return CGEventType(rawValue: rawValue)
    }
    return nil
  }
}

// Serialize a CGEvent into a single log line.
func serializeEvent(_ event: CGEvent) -> String {
  let eventTimestampNs = event.timestamp
  let eventDate = bootTime.addingTimeInterval(Double(eventTimestampNs) / 1_000_000_000.0)

  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
  formatter.locale = Locale(identifier: "en_US_POSIX")
  formatter.timeZone = TimeZone.current
  let timestampStr = formatter.string(from: eventDate)

  let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
  let flags = event.flags.rawValue
  let userData = event.getIntegerValueField(.eventSourceUserData)

  let eventTypeStr = eventTypeToString(event.type)
  let keyCodeStr = cvtKeyCodeToString[Int(keyCode)] ?? ""
  return "\(timestampStr)|\(eventTypeStr)|keyCode:\(keyCodeStr)(\(keyCode)), flags:0x\(String(flags, radix: 16)), userData:\(userData)"
}

// Deserialize a log line into a CGEvent with its timestamp set.
func deserializeEvent(_ s: String) -> CGEvent? {
  let components = s.split(separator: "|")
  guard components.count >= 3 else { return nil }

  // 1. Parse timestamp (ISO 8601 with milliseconds) and convert to nanoseconds
  let isoString = String(components[0])
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
  formatter.locale = Locale(identifier: "en_US_POSIX")
  guard let date = formatter.date(from: isoString) else { return nil }
  let timestampNs = UInt64(date.timeIntervalSince1970 * 1_000_000_000)

  // 2. Parse event type
  let eventTypeStr = String(components[1])
  guard let eventType = stringToEventType(eventTypeStr) else { return nil }

  // 3. Parse keycode and flags
  let detailsStr = String(components[2])

  // Parse keyCode (format: "keyCode:Name(123)" where Name may be empty)
  guard let keyCodeRange = detailsStr.range(of: "keyCode:"),
        let openParenRange = detailsStr.range(of: "(", range: keyCodeRange.upperBound..<detailsStr.endIndex),
        let closeParenRange = detailsStr.range(of: ")", range: openParenRange.upperBound..<detailsStr.endIndex) else {
    return nil
  }
  let keyCodeStr = detailsStr[openParenRange.upperBound..<closeParenRange.lowerBound].trimmingCharacters(in: .whitespaces)
  guard let keyCodeVal = Int64(keyCodeStr) else { return nil }

  // Parse flags
  guard let flagsRange = detailsStr.range(of: "flags:0x") else { return nil }
  // Flags are bounded by the end of the flags:0x prefix up to either the next comma (before userData) or the end of the string
  let searchStart = flagsRange.upperBound
  let flagsStr: String
  if let commaAfterFlags = detailsStr.range(of: ",", range: searchStart..<detailsStr.endIndex) {
    flagsStr = detailsStr[searchStart..<commaAfterFlags.lowerBound].trimmingCharacters(in: .whitespaces)
  } else {
    flagsStr = detailsStr[searchStart..<detailsStr.endIndex].trimmingCharacters(in: .whitespaces)
  }
  guard let flagsVal = UInt64(flagsStr, radix: 16) else { return nil }

  // 4. Recreate CGEvent
  let isKeyDown = (eventType == .keyDown)
  guard let event = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(keyCodeVal), keyDown: isKeyDown) else {
    return nil
  }

  event.type = eventType
  event.flags = CGEventFlags(rawValue: flagsVal)
  event.setIntegerValueField(.keyboardEventKeycode, value: keyCodeVal)
  event.timestamp = timestampNs

  return event
}
