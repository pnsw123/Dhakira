import Foundation
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "AudioStorage")

// MARK: - AudioStorageError

enum AudioStorageError: Error, LocalizedError {
    case directoryCreationFailed(String)
    case copyFailed(String)

    var errorDescription: String? {
        switch self {
        case .directoryCreationFailed(let msg): return "Could not create audio directory: \(msg)"
        case .copyFailed(let msg):              return "Could not save audio recording: \(msg)"
        }
    }
}

// MARK: - AudioStorageService
// Manages permanent storage of M4A recordings in Application Support/audio/.
// Audio files recorded by AVAudioRecorder land in the system temp directory;
// this service copies them to a permanent location so iOS never cleans them up.

enum AudioStorageService {

    /// <Application Support>/audio/
    static var audioDirectory: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("audio", isDirectory: true)
    }

    /// Returns the permanent URL for a given UUID: <audioDirectory>/{uuid}.m4a
    static func permanentURL(for uuid: UUID) -> URL {
        audioDirectory.appendingPathComponent(uuid.uuidString.lowercased() + ".m4a")
    }

    /// Copy a recording from the temp directory to permanent storage.
    /// - Parameters:
    ///   - tempURL: The URL returned by AVAudioRecorder (typically in tmp/).
    ///   - uuid: UUID to use as the filename stem — caller is responsible for generating it.
    /// - Returns: The new permanent URL.
    @discardableResult
    static func persistRecording(from tempURL: URL, uuid: UUID) throws -> URL {
        let dir = audioDirectory
        let fm  = FileManager.default

        // Create the audio directory if it does not exist yet.
        if !fm.fileExists(atPath: dir.path) {
            do {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                log.debug("AudioStorageService: created directory \(dir.path)")
            } catch {
                throw AudioStorageError.directoryCreationFailed(error.localizedDescription)
            }
        }

        let destination = permanentURL(for: uuid)

        // Remove any pre-existing file at the destination (shouldn't happen with UUIDs).
        if fm.fileExists(atPath: destination.path) {
            try? fm.removeItem(at: destination)
        }

        // Copy (not move) — the recorder may still hold a file descriptor on the temp file.
        do {
            try fm.copyItem(at: tempURL, to: destination)
            log.info("AudioStorageService: saved \(uuid.uuidString).m4a (\(destination.path))")
        } catch {
            throw AudioStorageError.copyFailed(error.localizedDescription)
        }

        return destination
    }

    /// Delete a permanent audio file. Silent if the file does not exist.
    static func deleteRecording(uuid: UUID) {
        let url = permanentURL(for: uuid)
        try? FileManager.default.removeItem(at: url)
        log.info("AudioStorageService: deleted \(uuid.uuidString).m4a")
    }
}
