#if canImport(UIKit)
import UIKit
import Combine

// MARK: - CheckboxTapCoordinator
// Handles taps on CheckboxAttachment characters inside the UITextView.
// Edits textStorage directly to avoid scroll position reset.

final class CheckboxTapCoordinator: NSObject, ObservableObject, UIGestureRecognizerDelegate {
    @Published private(set) var toggleVersion: Int = 0
    private(set) var lastToggledText: NSAttributedString? = nil

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let tv = gesture.view as? UITextView,
              let text = tv.attributedText else { return }

        let point = gesture.location(in: tv)
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

        func isCheckbox(at idx: Int) -> Bool {
            guard idx >= 0, idx < text.length else { return false }
            return text.attributes(at: idx, effectiveRange: nil)[.attachment] is CheckboxAttachment
        }
        guard isCheckbox(at: charIndex) || isCheckbox(at: charIndex - 1) else { return }
        let checkboxIndex = isCheckbox(at: charIndex) ? charIndex : charIndex - 1

        // Toggle directly on textStorage — does NOT reset scroll position.
        let ts = tv.textStorage
        let safeLoc = max(0, min(checkboxIndex, ts.length - 1))
        let lineRange = (ts.string as NSString).lineRange(for: NSRange(location: safeLoc, length: 0))

        ts.beginEditing()
        ts.enumerateAttribute(.attachment, in: lineRange, options: []) { value, range, stop in
            guard let cb = value as? CheckboxAttachment else { return }
            cb.toggle()
            // Re-set the attachment to force redraw
            ts.removeAttribute(.attachment, range: range)
            ts.addAttribute(.attachment, value: cb, range: range)

            // Strikethrough + dim on checked, clear on unchecked
            let textStart = range.upperBound
            let textEnd   = lineRange.upperBound
            if textStart < textEnd {
                let textRange = NSRange(location: textStart, length: textEnd - textStart)
                if cb.isChecked {
                    ts.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: textRange)
                    ts.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: textRange)
                } else {
                    ts.removeAttribute(.strikethroughStyle, range: textRange)
                    ts.addAttribute(.foregroundColor, value: UIColor.label, range: textRange)
                }
            }
            stop.pointee = true
        }
        ts.endEditing()

        // Hide cursor — checkbox tap is a toggle, not a text editing action.
        // Resign FIRST (hides cursor), then restore scroll position.
        // Do NOT set selectedRange before resigning — that causes a brief
        // cursor flash visible to the user.
        let savedOffset = tv.contentOffset
        tv.resignFirstResponder()
        tv.setContentOffset(savedOffset, animated: false)

        // Publish snapshot so TaskDetailView can sync the binding
        lastToggledText = NSAttributedString(attributedString: ts)
        toggleVersion += 1
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }

    // Don't fire checkbox toggle when the editing menu (Select All, Copy, etc.) is showing.
    // Otherwise tapping "Select All" can land on a checkbox and toggle it instead.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        return false
    }
}

#endif
