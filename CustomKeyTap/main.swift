import Foundation
import CoreGraphics

// Global boot time reference to align event.timestamp (monotonic) with calendar date
let bootTime = Date().addingTimeInterval(-ProcessInfo.processInfo.systemUptime)

// Helper to convert CGEventType to String
func eventTypeToString(_ type: CGEventType) -> String {
    switch type {
    case .keyDown: return "keyDown"
    case .keyUp: return "keyUp"
    case .flagsChanged: return "flagsChanged"
    @unknown default: return "unknown(\(type.rawValue))"
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

// Deserialization function producing a CGEvent with its timestamp set
func deserializeLogLine(_ line: String) -> CGEvent? {
    let components = line.split(separator: "|")
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
    
    // Parse keyCode
    guard let keyCodeRange = detailsStr.range(of: "keyCode:"),
          let commaRange = detailsStr.range(of: ",", range: keyCodeRange.upperBound..<detailsStr.endIndex) else {
        return nil
    }
    let keyCodeStr = detailsStr[keyCodeRange.upperBound..<commaRange.lowerBound].trimmingCharacters(in: .whitespaces)
    guard let keyCodeVal = Int64(keyCodeStr) else { return nil }
    
    // Parse flags
    guard let flagsRange = detailsStr.range(of: "flags:0x") else { return nil }
    let flagsStr = detailsStr[flagsRange.upperBound..<detailsStr.endIndex].trimmingCharacters(in: .whitespaces)
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

// Event tap callback
func myEventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let eventTimestampNs = event.timestamp
    let eventDate = bootTime.addingTimeInterval(Double(eventTimestampNs) / 1_000_000_000.0)
    
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    let timestampStr = formatter.string(from: eventDate)
    
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags.rawValue
    
    let eventTypeStr = eventTypeToString(type)
    print("\(timestampStr)|\(eventTypeStr)|keyCode:\(keyCode), flags:0x\(String(flags, radix: 16))")
    fflush(stdout)
    
    return Unmanaged.passRetained(event)
}

func main() {
    print("--- Keyboard Event Tap Logger Startup ---")
    
    // Self-test for deserialization function
    let testLine = "2026-06-16T11:05:26.123-07:00|keyDown|keyCode:49, flags:0x0"
    if let deserializedEvent = deserializeLogLine(testLine) {
        print("Deserialization test PASSED:")
        print("  Parsed Timestamp (ns since epoch): \(deserializedEvent.timestamp)")
        print("  Parsed Event Type: \(deserializedEvent.type.rawValue) (\(eventTypeToString(deserializedEvent.type)))")
        print("  Parsed KeyCode: \(deserializedEvent.getIntegerValueField(.keyboardEventKeycode))")
        print("  Parsed Flags: 0x\(String(deserializedEvent.flags.rawValue, radix: 16))")
    } else {
        print("Deserialization test FAILED")
    }
    
    print("Starting event tap...")
    
    let eventMask = (1 << CGEventType.keyDown.rawValue) |
                    (1 << CGEventType.keyUp.rawValue) |
                    (1 << CGEventType.flagsChanged.rawValue)
    
    guard let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: CGEventMask(eventMask),
        callback: myEventTapCallback,
        userInfo: nil
    ) else {
        print("Error: Failed to create event tap.")
        print("IMPORTANT: This app requires Accessibility permissions to capture global keyboard events.")
        print("Go to System Settings -> Privacy & Security -> Accessibility and enable this app/terminal.")
        exit(1)
    }
    
    guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
        print("Error: Failed to create RunLoop source.")
        exit(1)
    }
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    
    print("Listening for keyboard events (Ctrl+C to exit)...")
    CFRunLoopRun()
}

main()
