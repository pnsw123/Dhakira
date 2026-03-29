import Combine
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "AudioTap")

#if canImport(UIKit)
import UIKit

// MARK: - AudioTapCoordinator
// Mirrors CheckboxTapCoordinator exactly.
// Adds a UITapGestureRecognizer to the UITextView and fires when the user
// taps on a character whose .link attribute is a prodnote-audio:// URL.
//
// Published `pendingAudioLink` drives a sheet presentation in TaskDetailView.
// The nil→value trick (clear() + async set) ensures onChange fires every tap,
// even when the user taps the same card twice in a row.

final class AudioTapCoordinator: NSObject, ObservableObject, UIGestureRecognizerDelegate {

    @Published private(set) var pendingAudioLink: AudioLink? = nil

    /// Reset the pending link so the same card can be tapped again.
    func clear() { pendingAudioLink = nil }

    // MARK: - Tap handling

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let tv = gesture.view as? UITextView,
              let text = tv.attributedText else { return }

        let point = gesture.location(in: tv)
        // Convert UITextView coordinates → text-container coordinates.
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

        // Check the tapped character AND the one before it.
        // A tap can land just past the last character of the chip text.
        let link = audioLink(in: text, at: charIndex)
                ?? audioLink(in: text, at: charIndex - 1)
        guard let link else { return }

        log.info("AudioTapCoordinator: tapped '\(link.name)' (\(link.uuid.uuidString))")

        // Nil first, then set — guarantees SwiftUI onChange fires even for the same card.
        pendingAudioLink = nil
        DispatchQueue.main.async { [weak self] in
            self?.pendingAudioLink = link
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    /// Allow this gesture to fire simultaneously with UITextView's built-in gestures
    /// so normal cursor placement is not blocked.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return true
    }

    // MARK: - Private

    /// Returns an AudioLink if the character at `index` has a prodnote-audio .link attribute.
    /// Handles both URL and String values — RTF deserialization returns .link as String.
    private func audioLink(in text: NSAttributedString, at index: Int) -> AudioLink? {
        guard index >= 0, index < text.length else { return nil }
        let attrs = text.attributes(at: index, effectiveRange: nil)
        guard let linkVal = attrs[.link] else { return nil }

        if let url = linkVal as? URL {
            return AudioLinkBuilder.parse(url)
        } else if let str = linkVal as? String {
            return AudioLinkBuilder.parse(str)
        }
        return nil
    }
}

#endif // canImport(UIKit)
