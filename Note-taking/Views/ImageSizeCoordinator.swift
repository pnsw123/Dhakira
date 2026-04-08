#if canImport(UIKit)
import UIKit
import Combine
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "ImageSize")

// MARK: - ImageSizeCoordinator
//
// Detects taps on inline NSTextAttachment images and shows a ➖/➕ pill
// to the RIGHT of the tapped image for resizing.
//
// Resize pattern from RichTextKit's autosizeImageAttachments:
//   https://github.com/danielsaidi/RichTextKit/blob/main/Sources/RichTextKit/Images/RichTextImageAttachmentManager.swift
//   → attachment.bounds = newBounds (direct set, same reference type)
//   → textStorage.edited(.editedAttributes, range:, changeInLength: 0)
//     https://developer.apple.com/documentation/uikit/nstextstorage/edited(_:range:changeinlength:)
//
// NSTextAttachment.bounds:
//   https://developer.apple.com/documentation/uikit/nstextattachment/bounds

final class ImageSizeCoordinator: NSObject, ObservableObject, UIGestureRecognizerDelegate {

    @Published private(set) var didResize: Int = 0

    private weak var textView: UITextView?
    private var buttonsView: UIView?
    private var selectedAttachment: NSTextAttachment?
    private var selectedCharIndex: Int = NSNotFound
    private var scrollObservation: NSKeyValueObservation?
    /// True while applyResize is running — prevents the contentOffset KVO
    /// (which fires when TextKit reflows content after a bounds change) from
    /// calling dismissButtons() and wiping the selection mid-resize.
    private var isResizing = false
    /// True briefly after handleTap selects an image — prevents the layout-reflow scroll
    /// from triggering dismissButtons() before the pill has a chance to appear.
    private var isTapping = false

    private let minWidth: CGFloat = 60
    private let maxWidth: CGFloat = 340
    private let step:     CGFloat = 0.25  // ±25 % per tap

    // MARK: - Setup

    func attach(to tv: UITextView) {
        textView = tv
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        tv.addGestureRecognizer(tap)
        // Hide pill when user scrolls — but ignore offset changes triggered by
        // TextKit reflowing content during a resize (isResizing guards that).
        scrollObservation = tv.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in
            guard let self, !self.isResizing, !self.isTapping else { return }
            self.dismissButtons()
        }
    }

    // Full cleanup — called on scroll and on taps away from an image.
    func dismissButtons() {
        buttonsView?.removeFromSuperview()
        buttonsView = nil
        selectedAttachment = nil
        selectedCharIndex = NSNotFound
    }

    // MARK: - Tap detection

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let tv = gesture.view as? UITextView else { dismissButtons(); return }
        log.debug("ImageSizeCoordinator.handleTap: ENTER")

        let tapPoint = gesture.location(in: tv)
        let tcPoint  = CGPoint(x: tapPoint.x - tv.textContainerInset.left,
                               y: tapPoint.y - tv.textContainerInset.top)

        let charIndex = tv.layoutManager.characterIndex(
            for: tcPoint, in: tv.textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard charIndex < tv.textStorage.length else { dismissButtons(); return }

        // Read from textStorage (live, mutable) — NOT tv.attributedText which is a copy.
        // This guarantees the attachment reference we keep is the same object TextKit owns,
        // so setting attachment.bounds later actually changes the rendered glyph.
        let attrs = tv.textStorage.attributes(at: charIndex, effectiveRange: nil)
        guard let attachment = attrs[.attachment] as? NSTextAttachment,
              attachment.image != nil,
              !(attachment is CheckboxAttachment) else {
            dismissButtons(); return
        }

        // Guard: tap must land INSIDE the image rect, not just near it.
        guard let imgRect = attachmentRect(at: charIndex, in: tv),
              imgRect.contains(tapPoint) else {
            dismissButtons(); return
        }

        log.info("ImageSizeCoordinator: tapped image at char \(charIndex)")

        // Store selection BEFORE touching buttonsView.
        selectedAttachment = attachment
        selectedCharIndex  = charIndex

        // Remove only the old pill — do NOT call dismissButtons() here,
        // that would clear selectedAttachment/selectedCharIndex we just set.
        buttonsView?.removeFromSuperview()
        buttonsView = nil

        // Suppress scroll-dismissal briefly while the layout pass triggered by
        // image selection (or insertion reflow) runs — otherwise the contentOffset
        // KVO fires immediately and removes the pill before it appears.
        isTapping = true
        DispatchQueue.main.async { [weak self] in self?.isTapping = false }

        // Defer showButtons by one layout pass so attachmentRect reads stable layout.
        // This fixes the "pill appears at random position" bug on first tap after insertion.
        DispatchQueue.main.async { [weak self] in
            guard let self, let tv = self.textView else { return }
            // Re-read the rect after layout has settled.
            guard let settledRect = self.attachmentRect(at: charIndex, in: tv),
                  settledRect.width > 0 else {
                log.warning("ImageSizeCoordinator: attachmentRect still stale after layout — skip pill")
                return
            }
            // Guard: if the user tapped somewhere else before this deferred block ran,
            // selectedCharIndex will have been cleared — don't show a stale pill.
            guard self.selectedCharIndex == charIndex,
                  self.selectedAttachment != nil else { return }
            self.showButtons(rightOf: settledRect, in: tv)
        }
    }

    // MARK: - Pill (right side of image)

    private func showButtons(rightOf imageRect: CGRect, in tv: UITextView) {
        guard let window = tv.window else { return }

        // Convert image rect from UITextView coords → window coords.
        let rectInWindow = tv.convert(imageRect, to: window)

        let pillH: CGFloat = 38
        let pillW: CGFloat = 88

        let pill = UIView()
        pill.backgroundColor    = UIColor.systemBackground
        pill.layer.cornerRadius  = pillH / 2
        pill.layer.shadowColor   = UIColor.black.cgColor
        pill.layer.shadowOpacity = 0.18
        pill.layer.shadowRadius  = 6
        pill.layer.shadowOffset  = CGSize(width: 0, height: 2)
        pill.layer.borderColor   = UIColor.separator.cgColor
        pill.layer.borderWidth   = 0.5

        // Vertical divider in the centre
        let divider = UIView()
        divider.backgroundColor = UIColor.separator
        pill.addSubview(divider)

        let shrink = makeButton(systemName: "minus", tag: 0)
        let grow   = makeButton(systemName: "plus",  tag: 1)
        pill.addSubview(shrink)
        pill.addSubview(grow)

        // Layout manually (no autolayout needed for a fixed-size pill)
        pill.frame  = CGRect(x: 0, y: 0, width: pillW, height: pillH)
        divider.frame = CGRect(x: pillW / 2 - 0.25, y: 8, width: 0.5, height: pillH - 16)
        shrink.frame  = CGRect(x: 0,         y: 0, width: pillW / 2, height: pillH)
        grow.frame    = CGRect(x: pillW / 2, y: 0, width: pillW / 2, height: pillH)

        // Position pill to the RIGHT of the image, vertically centred.
        // Clamp both axes so the pill never escapes the visible window.
        var pillX = rectInWindow.maxX + 10
        var pillY = rectInWindow.midY - pillH / 2

        // If no room on the right, flip to the left side.
        if pillX + pillW > window.bounds.width - 8 {
            pillX = rectInWindow.minX - pillW - 10
        }
        // Final safety clamp — keep inside the window's safe area
        // so the pill never hides behind the notch / Dynamic Island / home indicator.
        let safe = window.safeAreaInsets
        pillX = max(safe.left + 8, min(pillX, window.bounds.width  - pillW - safe.right  - 8))
        pillY = max(safe.top  + 8, min(pillY, window.bounds.height - pillH - safe.bottom - 8))

        pill.frame.origin = CGPoint(x: pillX, y: pillY)

        window.addSubview(pill)
        buttonsView = pill
    }

    private func makeButton(systemName: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        btn.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        btn.tintColor = .label
        btn.tag = tag
        btn.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        applyResize(factor: sender.tag == 0 ? (1 - step) : (1 + step))
    }

    // MARK: - Resize
    //
    // Mirrors RichTextKit autosizeImageAttachments (same two steps):
    //   1. attachment.bounds = newBounds
    //   2. textStorage.edited(.editedAttributes, range:, changeInLength: 0)
    //
    // Because selectedAttachment was obtained from tv.textStorage (not a copy),
    // mutating .bounds here directly updates the live attributed string TextKit renders.

    private func applyResize(factor: CGFloat) {
        log.debug("ImageSizeCoordinator.applyResize: ENTER factor=\(factor)")
        guard let attachment = selectedAttachment,
              let tv          = textView,
              selectedCharIndex != NSNotFound else {
            log.warning("ImageSizeCoordinator.applyResize: no selection — tap image first")
            return
        }

        let current: CGRect = {
            let b = attachment.bounds
            if b.width > 0 { return b }
            let sz = attachment.image?.size ?? CGSize(width: 100, height: 100)
            return CGRect(origin: .zero, size: sz)
        }()

        let aspect = current.height / max(1, current.width)
        let newW   = (current.width * factor).clamped(to: minWidth...maxWidth)
        let newH   = newW * aspect

        isResizing = true
        // Save typing attributes BEFORE the edit — textStorage.edited() can
        // cause UITextView to re-derive typingAttributes from the attachment
        // character, shrinking the cursor and font size (Issue #100).
        let savedTypingAttrs = tv.typingAttributes
        let savedSelection   = tv.selectedRange

        attachment.bounds = CGRect(x: 0, y: 0, width: newW, height: newH)

        tv.textStorage.edited(
            .editedAttributes,
            range: NSRange(location: selectedCharIndex, length: 1),
            changeInLength: 0
        )

        // Restore typing attributes so the cursor/font size stays unchanged.
        tv.typingAttributes = savedTypingAttrs
        tv.selectedRange    = savedSelection

        // Clear the flag after the current run loop so any KVO callbacks
        // triggered by the layout pass above are ignored.
        DispatchQueue.main.async { [weak self] in self?.isResizing = false }

        didResize += 1
        log.debug("ImageSizeCoordinator: \(Int(current.width))→\(Int(newW))pt (×\(factor))")

        // Slide pill to follow the image's new right edge.
        if let newRect = attachmentRect(at: selectedCharIndex, in: tv),
           let window  = tv.window {
            let rectInWindow = tv.convert(newRect, to: window)
            let pillW = buttonsView?.bounds.width ?? 88
            let pillH = buttonsView?.bounds.height ?? 38
            var pillX = rectInWindow.maxX + 10
            if pillX + pillW > window.bounds.width - 8 {
                pillX = rectInWindow.minX - pillW - 10
            }
            let safe = window.safeAreaInsets
            pillX = max(safe.left + 8, min(pillX, window.bounds.width  - pillW - safe.right  - 8))
            let pillY = max(safe.top  + 8, min(rectInWindow.midY - pillH / 2, window.bounds.height - pillH - safe.bottom - 8))
            buttonsView?.frame.origin = CGPoint(x: pillX, y: pillY)
        }
    }

    // MARK: - NSLayoutManager helper (TextKit 1)

    private func attachmentRect(at charIndex: Int, in tv: UITextView) -> CGRect? {
        let lm    = tv.layoutManager
        let inset = tv.textContainerInset
        let glyphRange = lm.glyphRange(
            forCharacterRange: NSRange(location: charIndex, length: 1),
            actualCharacterRange: nil
        )
        let gi = glyphRange.location
        guard gi != NSNotFound, gi < lm.numberOfGlyphs else { return nil }
        let attachSize = lm.attachmentSize(forGlyphAt: gi)
        guard attachSize.width > 0 else { return nil }
        var effectiveRange = NSRange()
        let lineRect = lm.lineFragmentRect(forGlyphAt: gi, effectiveRange: &effectiveRange)
        let glyphLoc = lm.location(forGlyphAt: gi)
        return CGRect(
            x:      lineRect.minX + glyphLoc.x + inset.left,
            y:      lineRect.minY + glyphLoc.y - attachSize.height + inset.top,
            width:  attachSize.width,
            height: attachSize.height
        )
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

#endif
