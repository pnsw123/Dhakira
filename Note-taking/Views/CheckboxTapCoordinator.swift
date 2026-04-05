#if canImport(UIKit)
import UIKit
import Combine

// MARK: - CheckboxTapCoordinator
// Handles taps on CheckboxAttachment characters inside the UITextView.
// Uses a published `toggleVersion` counter so TaskDetailView can observe
// each toggle event without needing a mutable Binding captured in a closure.

final class CheckboxTapCoordinator: NSObject, ObservableObject, UIGestureRecognizerDelegate {
    @Published private(set) var toggleVersion: Int = 0
    private(set) var lastToggledText: NSAttributedString? = nil

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let tv = gesture.view as? UITextView,
              let text = tv.attributedText else { return }

        let point = gesture.location(in: tv)
        // Convert UITextView coordinates to text container coordinates.
        // lineFragmentPadding is intentionally NOT subtracted — characterIndex(for:in:)
        // works in text-container space which already accounts for it.
        let adjustedPoint = CGPoint(
            x: point.x - tv.textContainerInset.left,
            y: point.y - tv.textContainerInset.top
        )
        let charIndex = tv.layoutManager.characterIndex(
            for: adjustedPoint,
            in: tv.textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard charIndex < text.length else { return }

        // Check the tapped character AND the one before it: a tap can land on the
        // space that immediately follows the checkbox (U+FFFC), so we check both.
        func isCheckbox(at idx: Int) -> Bool {
            guard idx >= 0, idx < text.length else { return false }
            return text.attributes(at: idx, effectiveRange: nil)[.attachment] is CheckboxAttachment
        }
        guard isCheckbox(at: charIndex) || isCheckbox(at: charIndex - 1) else { return }
        let checkboxIndex = isCheckbox(at: charIndex) ? charIndex : charIndex - 1

        var mutableText = NSAttributedString(attributedString: text)
        RichEditorCommands.toggleCheckbox(at: checkboxIndex, attributedText: &mutableText)
        tv.attributedText = mutableText

        // Publish the result so TaskDetailView can sync its @State binding.
        lastToggledText = mutableText
        toggleVersion += 1
    }

    // Allow this gesture to fire simultaneously with UITextView's built-in gestures
    // so normal cursor placement is not blocked.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }
}

#endif
