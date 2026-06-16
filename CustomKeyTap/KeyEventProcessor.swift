import Foundation
import CoreGraphics

class KeyEventProcessor {
    func handleEvent(_ event: CGEvent, post: (CGEvent) -> Void) -> CGEvent? {
        let type = event.type
        let timestamp = event.timestamp
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        let userData = event.getIntegerValueField(.eventSourceUserData)

        _ = type
        _ = timestamp
        _ = keyCode
        _ = flags
        _ = userData

        return event
    }
}
