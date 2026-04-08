#if canImport(UIKit)
import UIKit
import Combine

// MARK: - CheckboxTapCoordinator
// Handles taps on CheckboxAttachment characters inside the UITextView.
// Edits textStorage directly to avoid scroll position reset.

final class CheckboxTapCoordinator: NSObject, ObservableObject, UIGestureRecognizerDelegate {
    @Published private(set) var toggleVersion: Int = 0
    private(set) var lastToggledText: NSAttributedString? = nil
    /// Captured in gestureRecognizerShouldBegin — tells us whether the keyboard
    /// was already visible before the tap so we can suppress unwanted keyboard show.
    private var wasFirstResponder = false

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
        // Only treat this as a checkbox tap if the tap landed directly ON the checkbox
        // attachment character. Do NOT check charIndex - 1 — that broadens the hit area
        // to include the space right after the checkbox and triggers unintended toggles
        // when the user taps to place the cursor for text editing.
        guard isCheckbox(at: charIndex) else { return }
        let checkboxIndex = charIndex

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

        // Bug 1 fix: do NOT unconditionally resign first responder.
        // Previously this always dismissed the keyboard, causing the user to lose
        // edit mode after every checkbox toggle.
        // If the text view already has keyboard focus, keep it — just restore scroll.
        // If it did NOT have focus (keyboard was already hidden), keep it hidden.
        let savedOffset = tv.contentOffset
        // If the keyboard was NOT visible before this tap, dismiss it.
        // UITextView's own tap gesture fires simultaneously and makes it
        // first responder — undo that so checkbox taps don't pop the keyboard.
        if !wasFirstResponder {
            tv.resignFirstResponder()
        }
        tv.setContentOffset(savedOffset, animated: false)

        // Publish snapshot so TaskDetailView can sync the binding
        lastToggledText = NSAttributedString(attributedString: ts)
        toggleVersion += 1
    }

    // Capture keyboard state BEFORE the tap is recognized — at this point
    // UITextView hasn't become first responder yet from this touch.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let tv = gestureRecognizer.view as? UITextView {
            wasFirstResponder = tv.isFirstResponder
        }
        return true
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

// MARK: - ScrollDismissHandler
// Attached to the UITextView's built-in panGestureRecognizer.
// Dismisses the keyboard when the user scrolls DOWN (content moves up).
// Only fires on real finger-driven scrolls — not on programmatic offset
// changes (keyboard appearing, auto-scroll to cursor, etc.).

final class ScrollDismissHandler: NSObject, ObservableObject {
    @objc func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let tv = pan.view as? UITextView,
              tv.isFirstResponder,
              tv.selectedRange.length == 0 else { return }
        let velocity = pan.velocity(in: tv)
        // velocity.y < 0 means finger moving UP → content scrolling DOWN
        if velocity.y < -200 {
            tv.resignFirstResponder()
        }
    }
}

#endif
