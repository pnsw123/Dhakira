#if canImport(UIKit)
import UIKit
import Combine

// MARK: - ColorLongPressCoordinator
// Adds a UILongPressGestureRecognizer to the UITextView.
// When the user holds without selecting text, fires and publishes the caret rect
// in global (window) coordinates so TaskDetailView can anchor and show the color palette.
// Runs simultaneously with UITextView's built-in long-press (system copy/paste menu).

final class ColorLongPressCoordinator: NSObject, ObservableObject, UIGestureRecognizerDelegate {

    /// Non-nil when a long press fires — drives color palette presentation in TaskDetailView.
    @Published private(set) var pressGlobalRect: CGRect? = nil

    func clear() { pressGlobalRect = nil }

    // MARK: - Long press handling

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let tv = gesture.view as? UITextView else { return }

        let point = gesture.location(in: tv)

        // Get the caret rect at the press location and convert to window coordinates
        guard let textPosition = tv.closestPosition(to: point) else { return }
        let caretRect = tv.caretRect(for: textPosition)
        pressGlobalRect = tv.convert(caretRect, to: nil)
    }

    // MARK: - UIGestureRecognizerDelegate

    /// Allow our long press to fire at the same time as UITextView's built-in
    /// long press (which handles text selection and system copy/paste menu).
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}

#endif
