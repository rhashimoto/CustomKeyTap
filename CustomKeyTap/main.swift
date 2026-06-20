import Foundation
import CoreGraphics
import Carbon

// Tag for injected events to bypass processing.
let postedEventTag: Int64 = 0xDEADBEEF

var verboseLogging = false

// Event tap callback
func myEventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
  if verboseLogging {
    print(serializeEvent(event))
    fflush(stdout)
  }

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

func parseMillisOption(_ name: String, _ args: [String]) -> Int? {
  guard let index = args.firstIndex(of: name) else { return nil }
  let valueIndex = index + 1
  guard valueIndex < args.count, let value = Int(args[valueIndex]) else {
    print("Error: \(name) requires an integer millisecond value.")
    exit(1)
  }
  return value
}

func main() {
  print("Starting event tap...")

  let args = Array(CommandLine.arguments.dropFirst())
  let holdMillis = parseMillisOption("--hold", args)
  let flowMillis = parseMillisOption("--flow", args)
  verboseLogging = args.contains("-v")

  let eventMask = (1 << CGEventType.keyDown.rawValue) |
  (1 << CGEventType.keyUp.rawValue) |
  (1 << CGEventType.flagsChanged.rawValue)

  let tap: CGEventTapLocation = .cgSessionEventTap

  let processor = KeyEventProcessor(post: { eventToPost in
    // Tag the event as injected before posting.
    eventToPost.setIntegerValueField(.eventSourceUserData, value: postedEventTag)
    eventToPost.post(tap: tap)
  })
  if let holdMillis {
    processor.setHoldMillis(millis: holdMillis)
  }
  if let flowMillis {
    processor.setFlowMillis(millis: flowMillis)
  }
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
