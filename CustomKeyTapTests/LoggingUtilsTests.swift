import Testing
import CoreGraphics
import Carbon

@Suite("Logging round trip")
struct LoggingUtilsTests {
  @Test("Serialize then deserialize preserves event")
  func roundTrip() throws {
    let original = try #require(
      CGEvent(keyboardEventSource: nil,
              virtualKey: CGKeyCode(kVK_ANSI_K),
              keyDown: true)
    )
    original.flags = [.maskShift, .maskCommand]
    let serialized = serializeEvent(original)
    let restored = try #require(deserializeEvent(serialized))
    
    #expect(restored.type == original.type)
    #expect(
      restored.getIntegerValueField(.keyboardEventKeycode)
      == original.getIntegerValueField(.keyboardEventKeycode)
    )
    #expect(restored.flags == original.flags)
  }
}
