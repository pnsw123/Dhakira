import Foundation
import UIKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "NoteBodyCodec")

// Custom attribute key for tagging image attachments with their disk UUID.
// Stored on the NSAttributedString character, NOT on NSTextAttachment.fileType
// (which is a UTI — setting it to a UUID breaks image rendering).
extension NSAttributedString.Key {
    static let imageAttachmentId   = NSAttributedString.Key("com.prodnote.imageAttachmentId")

}

// MARK: - NoteBodyError (Issue #53)

enum NoteBodyError: Error, LocalizedError {
    case encodeFailed(String)
    case decodeFailed(String)
    case emptyData
    case unknownVersion(UInt8)

    var errorDescription: String? {
        switch self {
        case .encodeFailed(let detail): return "Could not save note: \(detail)"
        case .decodeFailed(let detail): return "Could not load note: \(detail)"
        case .emptyData:                return "Note body is empty"
        case .unknownVersion(let v):    return "Unsupported note format (version \(v))"
        }
    }
}

// MARK: - NoteBodyVersion

private enum NoteBodyVersion: UInt8 {
    case legacy = 0   // bare RTF, no prefix (all existing notes before this codec)
    case v1     = 1   // 1-byte version prefix + RTF payload
}

// MARK: - NoteBodyCodec

/// Low-level codec with a 1-byte version prefix.
/// - Encode: writes [version byte][RTF bytes]
/// - Decode: reads the version byte, falls back gracefully for legacy bare-RTF blobs
enum NoteBodyCodec {

    // MARK: Encode

    static func encode(_ text: NSAttributedString) -> Result<Data, NoteBodyError> {
        // Strip ghost .link attributes pointing to non-existent files before encoding.
        // When a user deletes a file attachment by backspacing, invisible .link attributes
        // can persist on surrounding characters (ghost links). Cleaning them here prevents
        // the ghost links from being saved and resurrected on next decode.
        let cleaned = stripGhostFileLinks(from: text)
        // Strip CheckboxAttachment objects and replace with [cb:0]/[cb:1] placeholders
        // BEFORE RTF encoding. RTF cannot preserve custom NSTextAttachment subclasses —
        // they are silently destroyed on round-trip. We handle them just like images.
        let withoutCheckboxes = stripCheckboxes(from: cleaned)
        // Strip image attachments so the RTF blob contains only text + placeholder markers.
        // Actual image content lives on disk.
        let stripped = stripImages(from: withoutCheckboxes)
        let range = NSRange(location: 0, length: stripped.length)
        guard let rtf = try? stripped.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else {
            log.error("NoteBodyCodec.encode: RTF serialisation failed (\(stripped.length) chars)")
            return .failure(.encodeFailed("RTF serialisation returned nil"))
        }
        var payload = Data([NoteBodyVersion.v1.rawValue])
        payload.append(rtf)
        log.debug("NoteBodyCodec.encode: \(stripped.length) chars → \(payload.count) bytes (v1)")
        return .success(payload)
    }

    // MARK: Decode

    static func decode(_ blob: Data, taskId: UUID) -> Result<NSAttributedString, NoteBodyError> {
        guard !blob.isEmpty else {
            log.warning("NoteBodyCodec.decode: received empty Data")
            return .failure(.emptyData)
        }

        let versionByte = blob[blob.startIndex]

        let rtfResult: Result<NSAttributedString, NoteBodyError>

        switch NoteBodyVersion(rawValue: versionByte) {
        case .v1:
            // Strip the 1-byte version prefix, parse the RTF payload
            let rtfPayload = blob.dropFirst()
            rtfResult = decodeRTF(rtfPayload)

        case .legacy, .none:
            // Either version 0 (legacy) or an unrecognised byte.
            // Attempt a bare-RTF parse — this is how ALL existing notes are stored.
            // On next save they will be re-encoded with the v1 prefix automatically.
            log.debug("NoteBodyCodec.decode: version byte=\(versionByte) — attempting legacy RTF fallback")
            let result = decodeRTF(blob)
            if case .failure = result {
                // If even the legacy path fails and the byte looks like a known-bad version,
                // surface a proper error rather than an unknown-version one.
                if NoteBodyVersion(rawValue: versionByte) == nil && versionByte > 1 {
                    log.error("NoteBodyCodec.decode: unknown version byte \(versionByte)")
                    return .failure(.unknownVersion(versionByte))
                }
            }
            rtfResult = result
        }

        // Restore image placeholders from disk, then restore checkbox placeholders.
        return rtfResult.map { restoreCheckboxes(in: restoreImages(in: $0, taskId: taskId)) }
    }

    // MARK: Private

    private static func decodeRTF(_ data: Data) -> Result<NSAttributedString, NoteBodyError> {
        guard let str = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else {
            log.error("NoteBodyCodec.decodeRTF: failed on \(data.count) bytes")
            return .failure(.decodeFailed("RTF deserialisation returned nil"))
        }
        log.debug("NoteBodyCodec.decodeRTF: decoded \(str.length) chars from \(data.count) bytes")
        return .success(str)
    }

    // MARK: Image placeholder helpers

    /// Strip image attachments and replace with text placeholders.
    /// Returns a copy with images replaced by [img:UUID] or [img:UUID:WxH] markers.
    /// The WxH suffix persists the user's chosen display size so it survives
    /// navigation round-trips (Issue #101).
    private static func stripImages(from source: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: mutable.length)
        var ranges: [(NSRange, String, CGRect?)] = []
        mutable.enumerateAttribute(.imageAttachmentId, in: fullRange, options: []) { value, range, _ in
            if let uuid = value as? String, UUID(uuidString: uuid) != nil {
                // Read the attachment bounds to persist user-chosen size
                let attachment = mutable.attribute(.attachment, at: range.location, effectiveRange: nil) as? NSTextAttachment
                let bounds = (attachment?.bounds.width ?? 0) > 0 ? attachment?.bounds : nil
                ranges.append((range, uuid, bounds))
            }
        }
        // Replace in reverse order so indices stay valid
        for (range, uuid, bounds) in ranges.reversed() {
            if let b = bounds {
                mutable.replaceCharacters(in: range, with: "[img:\(uuid):\(Int(b.width))x\(Int(b.height))]")
            } else {
                mutable.replaceCharacters(in: range, with: "[img:\(uuid)]")
            }
        }
        log.debug("stripImages: replaced \(ranges.count) image(s) with placeholders")
        return mutable
    }

    /// Removes .link attributes that point to file:// URLs where the file no longer exists.
    /// Also strips orphaned U+FFFC (object replacement) characters that have no NSTextAttachment.
    /// This prevents ghost links from being persisted and crashing the app on next tap.
    private static func stripGhostFileLinks(from source: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: mutable.length)
        var ghostRanges: [NSRange] = []

        mutable.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
            let url: URL?
            if let u = value as? URL { url = u }
            else if let s = value as? String { url = URL(string: s) }
            else { return }

            guard let url, url.isFileURL else { return }
            if !FileManager.default.fileExists(atPath: url.path) {
                ghostRanges.append(range)
            }
        }

        // Strip ghost .link attributes (reverse order to keep indices valid).
        for range in ghostRanges.reversed() {
            mutable.removeAttribute(.link, range: range)
            mutable.removeAttribute(.foregroundColor, range: range)
            mutable.removeAttribute(.underlineStyle, range: range)
        }

        // Strip orphaned U+FFFC characters that have no text attachment.
        // These are invisible leftovers from deleted attachments.
        let fffcScalar = Unicode.Scalar(0xFFFC)!
        var orphanRanges: [NSRange] = []
        let str = mutable.string
        for (i, ch) in str.unicodeScalars.enumerated() {
            if ch == fffcScalar {
                let nsRange = NSRange(location: i, length: 1)
                let attachment = mutable.attribute(.attachment, at: i, effectiveRange: nil) as? NSTextAttachment
                let imageId = mutable.attribute(.imageAttachmentId, at: i, effectiveRange: nil)
                if attachment == nil && imageId == nil {
                    orphanRanges.append(nsRange)
                }
            }
        }
        for range in orphanRanges.reversed() {
            mutable.deleteCharacters(in: range)
        }

        if !ghostRanges.isEmpty || !orphanRanges.isEmpty {
            log.info("stripGhostFileLinks: removed \(ghostRanges.count) ghost link(s), \(orphanRanges.count) orphan U+FFFC char(s)")
        }
        return mutable
    }

    /// Restore [img:UUID] and [img:UUID:WxH] placeholders back to real image attachments.
    /// The optional :WxH suffix restores user-chosen display size (Issue #101).
    private static func restoreImages(in source: NSAttributedString, taskId: UUID) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        // Match both [img:UUID] and [img:UUID:123x456]
        let pattern = "\\[img:([A-F0-9-]+)(?::(\\d+)x(\\d+))?\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return mutable }
        let fullRange = NSRange(location: 0, length: mutable.length)
        let matches = regex.matches(in: mutable.string, options: [], range: fullRange)

        // Replace in reverse so indices stay valid
        for match in matches.reversed() {
            guard match.numberOfRanges >= 2,
                  let uuidRange = Range(match.range(at: 1), in: mutable.string),
                  let attachmentId = UUID(uuidString: String(mutable.string[uuidRange])),
                  let image = AttachmentStore.shared.load(attachmentId: attachmentId, taskId: taskId)
            else { continue }

            let attachment = NSTextAttachment()
            attachment.image = image

            // Restore persisted display size if present, otherwise use default
            let wRange = match.range(at: 2)
            let hRange = match.range(at: 3)
            if wRange.location != NSNotFound, hRange.location != NSNotFound,
               let wStr = Range(wRange, in: mutable.string),
               let hStr = Range(hRange, in: mutable.string),
               let w = Int(mutable.string[wStr]),
               let h = Int(mutable.string[hStr]),
               w > 0, h > 0 {
                // Use the saved user-chosen size (Issue #101)
                attachment.bounds = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
                log.debug("restoreImages: restored image \(attachmentId.uuidString) at saved size \(w)x\(h)")
            } else {
                // Fallback: scale to default display width (matching AttachmentService)
                let maxWidth: CGFloat = 180
                let displayWidth = min(image.size.width, maxWidth)
                let scale = displayWidth / max(1, image.size.width)
                attachment.bounds = CGRect(x: 0, y: 0, width: displayWidth, height: image.size.height * scale)
                log.debug("restoreImages: restored image \(attachmentId.uuidString) at default \(Int(displayWidth))pt")
            }
            let attachStr = NSMutableAttributedString(attachment: attachment)
            attachStr.addAttribute(.imageAttachmentId, value: attachmentId.uuidString, range: NSRange(location: 0, length: attachStr.length))
            mutable.replaceCharacters(in: match.range, with: attachStr as NSAttributedString)
        }
        return mutable
    }

    /// Replace CheckboxAttachment objects with text placeholders before RTF encoding.
    /// Uses [cb:1] for checked and [cb:0] for unchecked.
    /// RTF cannot preserve custom NSTextAttachment subclasses — they must be serialized
    /// as text markers just like images are serialized as [img:UUID] markers.
    private static func stripCheckboxes(from source: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: mutable.length)
        var replacements: [(NSRange, Bool)] = []
        mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if let cb = value as? CheckboxAttachment {
                replacements.append((range, cb.isChecked))
            }
        }
        // Replace in reverse order so indices stay valid
        for (range, isChecked) in replacements.reversed() {
            mutable.replaceCharacters(in: range, with: isChecked ? "[cb:1]" : "[cb:0]")
        }
        log.debug("NoteBodyCodec.stripCheckboxes: replaced \(replacements.count) checkbox(es)")
        return mutable
    }

    /// Restore [cb:0]/[cb:1] placeholders back to CheckboxAttachment objects after RTF decode.
    private static func restoreCheckboxes(in source: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        let pattern = "\\[cb:([01])\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return mutable }
        let fullRange = NSRange(location: 0, length: mutable.length)
        let matches = regex.matches(in: mutable.string, options: [], range: fullRange)
        // Replace in reverse so indices stay valid
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let flagRange = Range(match.range(at: 1), in: mutable.string) else { continue }
            let isChecked = mutable.string[flagRange] == "1"
            let checkbox = CheckboxAttachment(checked: isChecked)
            let attachStr = NSMutableAttributedString(attachment: checkbox)
            attachStr.addAttribute(.foregroundColor, value: UIColor.label,
                                   range: NSRange(location: 0, length: attachStr.length))
            mutable.replaceCharacters(in: match.range, with: attachStr as NSAttributedString)
        }
        log.debug("NoteBodyCodec.restoreCheckboxes: restored \(matches.count) checkbox(es)")
        return mutable
    }
}
