#if canImport(UIKit)
import UIKit
import Combine
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "LinkTap")

// Detects taps on .link attributes inside an editable UITextView.
// UIKit only opens links automatically in non-editable text views —
// for editable editors we have to intercept the tap ourselves.
// File URLs are opened via UIDocumentInteractionController (Apple's native preview).
// http/https URLs are opened via UIApplication.open.

final class LinkTapCoordinator: NSObject, ObservableObject, UIGestureRecognizerDelegate,
                                 UIDocumentInteractionControllerDelegate {

    private weak var textView: UITextView?
    // Strong reference — UIDocumentInteractionController must be kept alive
    // until the preview is dismissed, otherwise it deallocates mid-presentation.
    private var docController: UIDocumentInteractionController?

    func attach(to tv: UITextView) {
        textView = tv
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.delegate = self
        tv.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let tv = textView else { return }
        log.debug("LinkTapCoordinator.handleTap: ENTER")

        let point   = gesture.location(in: tv)
        let tcPoint = CGPoint(x: point.x - tv.textContainerInset.left,
                              y: point.y - tv.textContainerInset.top)
        let charIndex = tv.layoutManager.characterIndex(
            for: tcPoint, in: tv.textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        guard charIndex < tv.textStorage.length else { return }

        let attrs = tv.textStorage.attributes(at: charIndex, effectiveRange: nil)

        // .link value can be URL or String depending on how it was set
        let url: URL?
        if let u = attrs[.link] as? URL {
            url = u
        } else if let s = attrs[.link] as? String {
            url = URL(string: s)
        } else {
            return  // No link at this character — let UITextView handle normally
        }
        guard let url else { return }
        log.info("LinkTapCoordinator: tapped link \(url.absoluteString)")

        if url.isFileURL {
            // Guard: file must exist on disk — deleted attachments leave ghost .link attributes
            // that would crash QLPreviewController with a sandbox / nil-view error.
            guard FileManager.default.fileExists(atPath: url.path) else {
                log.warning("LinkTapCoordinator: file does not exist at '\(url.path)' — removing ghost link and ignoring tap")
                removeGhostLink(at: charIndex, in: tv.textStorage)
                return
            }

            // Guard: prevent double-presentation if user taps rapidly or preview is already open.
            guard docController == nil else {
                log.warning("LinkTapCoordinator: preview already open — ignoring tap")
                return
            }

            // Guard: window hierarchy must be valid — presenting on a nil window or while another
            // presentation is in flight causes "zoom transition from nil view" crash.
            guard let window = tv.window,
                  let rootVC = window.rootViewController else {
                log.warning("LinkTapCoordinator: no valid window hierarchy — skipping preview")
                return
            }
            let presenter = rootVC.presentedViewController ?? rootVC
            guard presenter.view.window != nil else {
                log.warning("LinkTapCoordinator: presenter has no window — skipping preview")
                return
            }

            let controller = UIDocumentInteractionController(url: url)
            controller.delegate = self
            docController = controller  // retain until dismissed
            if !controller.presentPreview(animated: true) {
                // Preview not available — fall back to open-in menu
                let rect = CGRect(x: point.x, y: point.y, width: 1, height: 1)
                controller.presentOptionsMenu(from: rect, in: window, animated: true)
            }
        } else {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Ghost link cleanup

    /// Removes .link attributes pointing to non-existent files from the text storage.
    /// Scans the full effective range of the tapped link and strips it so the user
    /// can't tap the same ghost link again.
    private func removeGhostLink(at charIndex: Int, in textStorage: NSTextStorage) {
        var effectiveRange = NSRange(location: 0, length: 0)
        textStorage.attribute(.link, at: charIndex, effectiveRange: &effectiveRange)
        guard effectiveRange.length > 0 else { return }
        textStorage.beginEditing()
        textStorage.removeAttribute(.link, range: effectiveRange)
        textStorage.removeAttribute(.foregroundColor, range: effectiveRange)
        textStorage.removeAttribute(.underlineStyle, range: effectiveRange)
        textStorage.endEditing()
        log.info("LinkTapCoordinator: removed ghost .link attribute in range \(effectiveRange)")
    }

    // MARK: - UIDocumentInteractionControllerDelegate

    func documentInteractionControllerViewControllerForPreview(
        _ controller: UIDocumentInteractionController
    ) -> UIViewController {
        guard let window = textView?.window,
              let root = window.rootViewController else {
            log.warning("LinkTapCoordinator: no root VC for preview — returning empty VC")
            docController = nil  // release so future taps aren't blocked
            return UIViewController()
        }
        return root.presentedViewController ?? root
    }

    func documentInteractionControllerDidEndPreview(_ controller: UIDocumentInteractionController) {
        docController = nil
    }

    // MARK: - UIGestureRecognizerDelegate

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool { true }
}
#endif
