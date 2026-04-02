import OSLog
import Combine

private let log = Logger(subsystem: "notes.Note-taking", category: "ImageResize")

#if canImport(UIKit)
import UIKit

// MARK: - ImageResizeOverlayView
//
// A transparent view placed directly over an inline NSTextAttachment image.
// Four circular corner handles are the only interactive areas — all other
// touches fall through (hitTest returns nil) so the UITextView beneath can
// still receive taps (which the coordinator uses to dismiss the overlay).

private final class ImageResizeOverlayView: UIView {

    enum Handle: Int {
        case topLeft = 0, topRight = 1, bottomLeft = 2, bottomRight = 3
    }

    var onResize: ((Handle, CGPoint) -> Void)?

    private let handleSize: CGFloat = 22
    private var handleViews: [Handle: UIView] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = true
        layer.borderColor = UIColor.systemBlue.cgColor
        layer.borderWidth = 1.5
        setupHandles()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupHandles() {
        for handle in [Handle.topLeft, .topRight, .bottomLeft, .bottomRight] {
            let v = UIView(frame: CGRect(x: 0, y: 0, width: handleSize, height: handleSize))
            v.backgroundColor = .systemBlue
            v.layer.cornerRadius = handleSize / 2
            v.layer.borderColor = UIColor.white.cgColor
            v.layer.borderWidth = 2
            v.isUserInteractionEnabled = true
            v.tag = handle.rawValue
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            v.addGestureRecognizer(pan)
            addSubview(v)
            handleViews[handle] = v
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        handleViews[.topLeft]?.center     = CGPoint(x: 0,            y: 0)
        handleViews[.topRight]?.center    = CGPoint(x: bounds.width, y: 0)
        handleViews[.bottomLeft]?.center  = CGPoint(x: 0,            y: bounds.height)
        handleViews[.bottomRight]?.center = CGPoint(x: bounds.width, y: bounds.height)
    }

    // Only handles capture touches; everything else falls through to UITextView.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for v in handleViews.values {
            if v.frame.insetBy(dx: -10, dy: -10).contains(point) { return v }
        }
        return nil
    }

    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let v = pan.view, let handle = Handle(rawValue: v.tag) else { return }
        let delta = pan.translation(in: superview)
        pan.setTranslation(.zero, in: superview)
        onResize?(handle, delta)
    }
}

// MARK: - ImageResizeCoordinator
//
// Mirrors AudioTapCoordinator / CheckboxTapCoordinator exactly in structure.
// Wire up in TaskDetailView.onEditorReady just like the other coordinators.
//
// Usage:
//   imageResizeCoordinator.attach(to: tv)       // once, inside onEditorReady
//   imageResizeCoordinator.dismissOverlay()      // call on scene background etc.
//
// Published `didResize` increments after every drag step so TaskDetailView can
// sync attributedText ← UITextView.attributedText for persistence.

final class ImageResizeCoordinator: NSObject, ObservableObject, UIGestureRecognizerDelegate {

    @Published private(set) var didResize: Int = 0

    private weak var textView: UITextView?
    private var overlayView: ImageResizeOverlayView?
    private var selectedAttachment: NSTextAttachment?
    private var selectedCharacterIndex: Int = NSNotFound

    private let minSize:  CGFloat = 44
    private let maxWidth: CGFloat = 340

    // MARK: - Setup

    func attach(to textView: UITextView) {
        self.textView = textView
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        textView.addGestureRecognizer(tap)
    }

    func dismissOverlay() {
        overlayView?.removeFromSuperview()
        overlayView = nil
        selectedAttachment = nil
        selectedCharacterIndex = NSNotFound
    }

    // MARK: - Tap detection

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let tv = gesture.view as? UITextView,
              let text = tv.attributedText else {
            dismissOverlay()
            return
        }

        let point = gesture.location(in: tv)
        let adjusted = CGPoint(
            x: point.x - tv.textContainerInset.left,
            y: point.y - tv.textContainerInset.top
        )
        let charIndex = tv.layoutManager.characterIndex(
            for: adjusted,
            in: tv.textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard charIndex < text.length else { dismissOverlay(); return }

        let attrs = text.attributes(at: charIndex, effectiveRange: nil)
        guard let attachment = attrs[.attachment] as? NSTextAttachment,
              attachment.image != nil else {
            dismissOverlay()
            return
        }

        log.info("ImageResizeCoordinator: selected image at char \(charIndex)")
        selectedAttachment    = attachment
        selectedCharacterIndex = charIndex
        showOverlay(for: attachment, at: charIndex, in: tv)
    }

    // MARK: - Overlay lifecycle

    private func showOverlay(for attachment: NSTextAttachment, at charIndex: Int, in tv: UITextView) {
        dismissOverlay()
        guard let rect = attachmentRect(at: charIndex, in: tv) else { return }

        let overlay = ImageResizeOverlayView(frame: rect)
        overlay.onResize = { [weak self] handle, delta in
            self?.resize(handle: handle, delta: delta)
        }
        tv.addSubview(overlay)
        overlayView = overlay
        log.debug("ImageResizeCoordinator: overlay at \(NSCoder.string(for: rect))")
    }

    // MARK: - Resize logic

    private func resize(handle: ImageResizeOverlayView.Handle, delta: CGPoint) {
        guard let attachment = selectedAttachment,
              let tv          = textView,
              let overlay     = overlayView else { return }

        // Current bounds — fall back to the image's natural size if not yet set.
        let current: CGRect = {
            let b = attachment.bounds
            if b.width > 0 { return b }
            let sz = attachment.image?.size ?? CGSize(width: 100, height: 100)
            return CGRect(origin: .zero, size: sz)
        }()

        let aspect = current.height / max(1, current.width)

        // Right-side handles grow right (+dx); left-side handles grow left (-dx).
        let dx: CGFloat
        switch handle {
        case .topRight, .bottomRight:  dx =  delta.x
        case .topLeft,  .bottomLeft:   dx = -delta.x
        }

        let newW = max(minSize, min(maxWidth, current.width + dx))
        let newH = newW * aspect

        attachment.bounds = CGRect(x: 0, y: 0, width: newW, height: newH)

        // Tell TextKit the glyph metrics changed so it redraws at the new size.
        tv.textStorage.edited(
            .editedAttributes,
            range: NSRange(location: selectedCharacterIndex, length: 1),
            changeInLength: 0
        )

        // Reposition overlay to follow the freshly-laid-out glyph.
        if let newRect = attachmentRect(at: selectedCharacterIndex, in: tv) {
            overlay.frame = newRect
        }

        didResize += 1
        log.debug("ImageResizeCoordinator: → \(Int(newW))×\(Int(newH))")
    }

    // MARK: - Layout helper (TextKit 1)

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
        let lineRect  = lm.lineFragmentRect(forGlyphAt: gi, effectiveRange: &effectiveRange)
        let glyphLoc  = lm.location(forGlyphAt: gi)

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
    ) -> Bool {
        return true
    }
}

#endif // canImport(UIKit)
