import Foundation
import UIKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "NoteBodyCodec")

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
        // Replace image attachments with [img:UUID] placeholders so the RTF blob
        // contains only text — actual images live on disk via AttachmentStore.
        let stripped = stripImages(from: text)
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

        // Restore [img:UUID] placeholders back to real image attachments from disk
        return rtfResult.map { restoreImages(in: $0, taskId: taskId) }
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
    /// Returns a copy with images replaced by [img:UUID] markers.
    private static func stripImages(from source: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        let fullRange = NSRange(location: 0, length: mutable.length)
        var ranges: [(NSRange, String)] = []
        mutable.enumerateAttribute(.attachment, in: fullRange, options: []) { value, range, _ in
            if let attachment = value as? NSTextAttachment,
               let fileType = attachment.fileType,
               UUID(uuidString: fileType) != nil {
                ranges.append((range, fileType))
            }
        }
        // Replace in reverse order so indices stay valid
        for (range, uuid) in ranges.reversed() {
            mutable.replaceCharacters(in: range, with: "[img:\(uuid)]")
        }
        return mutable
    }

    /// Restore [img:UUID] placeholders back to real image attachments.
    private static func restoreImages(in source: NSAttributedString, taskId: UUID) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: source)
        let pattern = "\\[img:([A-F0-9-]+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return mutable }
        let fullRange = NSRange(location: 0, length: mutable.length)
        let matches = regex.matches(in: mutable.string, options: [], range: fullRange)

        // Replace in reverse so indices stay valid
        for match in matches.reversed() {
            guard match.numberOfRanges == 2,
                  let uuidRange = Range(match.range(at: 1), in: mutable.string),
                  let attachmentId = UUID(uuidString: String(mutable.string[uuidRange])),
                  let image = AttachmentStore.shared.load(attachmentId: attachmentId, taskId: taskId)
            else { continue }

            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.fileType = attachmentId.uuidString
            // Scale to fit editor width (max ~280pt, matching AttachmentService)
            let maxWidth: CGFloat = 280
            if image.size.width > maxWidth {
                let scale = maxWidth / image.size.width
                attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: image.size.height * scale)
            }
            let attachStr = NSAttributedString(attachment: attachment)
            mutable.replaceCharacters(in: match.range, with: attachStr)
        }
        return mutable
    }
}
