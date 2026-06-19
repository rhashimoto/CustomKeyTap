import Foundation
import CoreGraphics
import Carbon

// Tag for injected events to bypass processing.
let postedEventTag: Int64 = 0xDEADBEEF

// Event tap callback
func myEventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
  print(serializeEvent(event))
  fflush(stdout)

  // Skip events we injected.
  let userData = event.getIntegerValueField(.eventSourceUserData)
  if userData == postedEventTag {
    return Unmanaged.passRetained(event)
  }

  let processor = Unmanaged<KeyEventProcessor>.fromOpaque(refcon!).takeUnretainedValue()
  guard let result = processor.handleEvent(event) else {
    return nil
  }
  return Unmanaged.passRetained(result)
}

func main() {
  print("--- Keyboard Event Tap Logger Startup ---")
  
  // Self-test for deserialization function (including userData in the string)
  let testLine = "2026-06-16T11:05:26.123-07:00|keyDown|keyCode:Space(49), flags:0x0, userData:42"
  if let deserializedEvent = deserializeEvent(testLine) {
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

  let tap: CGEventTapLocation = .cgSessionEventTap

  let processor = KeyEventProcessor(post: { eventToPost in
    // Tag the event as injected before posting.
    eventToPost.setIntegerValueField(.eventSourceUserData, value: postedEventTag)
    eventToPost.post(tap: tap)
  })
  let processorPtr = Unmanaged.passUnretained(processor).toOpaque()

  guard let eventTap = CGEvent.tapCreate(
    tap: tap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: myEventTapCallback,
    userInfo: processorPtr
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
