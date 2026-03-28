import Foundation
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
        let range = NSRange(location: 0, length: text.length)
        guard let rtf = try? text.data(
            from: range,
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) else {
            log.error("NoteBodyCodec.encode: RTF serialisation failed (\(text.length) chars)")
            return .failure(.encodeFailed("RTF serialisation returned nil"))
        }
        var payload = Data([NoteBodyVersion.v1.rawValue])
        payload.append(rtf)
        log.debug("NoteBodyCodec.encode: \(text.length) chars → \(payload.count) bytes (v1)")
        return .success(payload)
    }

    // MARK: Decode

    static func decode(_ blob: Data) -> Result<NSAttributedString, NoteBodyError> {
        guard !blob.isEmpty else {
            log.warning("NoteBodyCodec.decode: received empty Data")
            return .failure(.emptyData)
        }

        let versionByte = blob[blob.startIndex]

        switch NoteBodyVersion(rawValue: versionByte) {
        case .v1:
            // Strip the 1-byte version prefix, parse the RTF payload
            let rtfPayload = blob.dropFirst()
            return decodeRTF(rtfPayload)

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
            return result
        }
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
}
