import Testing
import CoreGraphics
import Carbon

@Suite("KeyEventProcessor")
struct KeyEventProcessorTests {
  // Shared capture used by `makeProcessor()` and read back by `process(...)`.
  // Tests must build the object under test via `makeProcessor()` so that its
  // `post` closure writes into this capture.
  final class EventCapture {
    var events: [CGEvent] = []
  }

  let capture = EventCapture()

  func makeProcessor() -> KeyEventProcessor {
    let capture = self.capture
    return KeyEventProcessor(post: { capture.events.append($0) })
  }

  func process(
    objectUnderTest: KeyEventProcessor,
    inputEvents: String
  ) -> [CGEvent] {
    capture.events.removeAll()
    for line in inputEvents.split(whereSeparator: \.isNewline) {
      let trimmed = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmed.isEmpty else { continue }
      guard let event = deserializeEvent(trimmed) else { continue }
      _ = objectUnderTest.handleEvent(event)
    }
    return capture.events
  }

  @Test("Held J with A tap produces Control-A")
  func heldJWithATap_producesControlA() throws {
    let processor = makeProcessor()
    let input = """
    2026-06-20T08:43:51.200-07:00|keyDown|keyCode:J(38), flags:0x100, userData:0
    2026-06-20T08:43:51.701-07:00|keyDown|keyCode:J(38), flags:0x100, userData:0
    2026-06-20T08:43:52.471-07:00|keyDown|keyCode:A(0), flags:0x100, userData:0
    2026-06-20T08:43:52.547-07:00|keyUp|keyCode:A(0), flags:0x100, userData:0
    2026-06-20T08:43:52.850-07:00|keyUp|keyCode:J(38), flags:0x100, userData:0
    """

    let posted = process(objectUnderTest: processor, inputEvents: input)

    try #require(posted.count == 2)

    let aKeyCode = Int64(kVK_ANSI_A)

    #expect(posted[0].type == .keyDown)
    #expect(posted[0].getIntegerValueField(.keyboardEventKeycode) == aKeyCode)
    #expect(posted[0].flags.contains(.maskControl))

    #expect(posted[1].type == .keyUp)
    #expect(posted[1].getIntegerValueField(.keyboardEventKeycode) == aKeyCode)
    #expect(posted[1].flags.contains(.maskControl))
  }
  
  @Test("Quick double tap and hold sends a repeat")
  func doubleTapHold_repeats() throws {
    let processor = makeProcessor()
    let input = """
    2026-06-20T09:39:56.284-07:00|keyDown|keyCode:Space(49), flags:0x100, userData:0
    2026-06-20T09:39:56.361-07:00|keyUp|keyCode:Space(49), flags:0x100, userData:0
    2026-06-20T09:39:56.427-07:00|keyDown|keyCode:Space(49), flags:0x100, userData:0
    2026-06-20T09:39:56.927-07:00|keyDown|keyCode:Space(49), flags:0x100, userData:0
    2026-06-20T09:39:57.010-07:00|keyDown|keyCode:Space(49), flags:0x100, userData:0
    2026-06-20T09:39:57.093-07:00|keyUp|keyCode:Space(49), flags:0x100, userData:0
    """

    let posted = process(objectUnderTest: processor, inputEvents: input)

    try #require(posted.count == 8)

    let spaceKeyCode = Int64(kVK_Space)

    #expect(posted[0].type == .keyDown)
    #expect(posted[0].getIntegerValueField(.keyboardEventKeycode) == spaceKeyCode)
    #expect(posted[1].type == .keyUp)
    #expect(posted[1].getIntegerValueField(.keyboardEventKeycode) == spaceKeyCode)

    #expect(posted[2].type == .keyDown)
    #expect(posted[2].getIntegerValueField(.keyboardEventKeycode) == spaceKeyCode)
    #expect(posted[3].type == .keyUp)
    #expect(posted[3].getIntegerValueField(.keyboardEventKeycode) == spaceKeyCode)

    #expect(posted[4].type == .keyDown)
    #expect(posted[4].getIntegerValueField(.keyboardEventKeycode) == spaceKeyCode)
    #expect(posted[5].type == .keyUp)
    #expect(posted[5].getIntegerValueField(.keyboardEventKeycode) == spaceKeyCode)

    #expect(posted[6].type == .keyDown)
    #expect(posted[6].getIntegerValueField(.keyboardEventKeycode) == spaceKeyCode)
    #expect(posted[7].type == .keyUp)
    #expect(posted[7].getIntegerValueField(.keyboardEventKeycode) == spaceKeyCode)
  }

}
