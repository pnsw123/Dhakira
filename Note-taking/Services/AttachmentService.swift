import SwiftUI
import UIKit
import OSLog
import AVFoundation

private let log = Logger(subsystem: "notes.Note-taking", category: "AttachmentService")

extension Notification.Name {
    /// Posted by AttachmentService after an image/file is appended.
    /// `object` carries the fully updated NSAttributedString so the editor
    /// can push it directly to the UITextView (which ignores SwiftUI binding
    /// updates because RichTextKit's updateUIView is intentionally empty).
    static let attachmentAppended = Notification.Name("AttachmentService.attachmentAppended")
}

// MARK: - AttachmentError (Issue #49)

enum AttachmentError: Error, LocalizedError {
    case imageDecodeFailed(Int)       // bytes count
    case mutableCopyFailed
    case unsupportedSource(String)
    case audioSaveFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageDecodeFailed(let bytes):
            return "Could not decode image (\(bytes) bytes). The file may be corrupted or unsupported."
        case .mutableCopyFailed:
            return "An internal error occurred while preparing the editor content."
        case .unsupportedSource(let name):
            return "'\(name)' is not supported yet."
        case .audioSaveFailed(let msg):
            return "Could not save recording: \(msg)"
        }
    }
}

// MARK: - AttachmentSheet (Issue #49)
// Single enum replaces 6 Bool flags — compiler enforces one-at-a-time.

enum AttachmentSheet: Identifiable {
    case photoLibrary
    case camera
    case documentPicker
    case documentScanner
    case audioRecorder
    case dataScanner

    var id: String {
        switch self {
        case .photoLibrary:    return "photoLibrary"
        case .camera:          return "camera"
        case .documentPicker:  return "documentPicker"
        case .documentScanner: return "documentScanner"
        case .audioRecorder:   return "audioRecorder"
        case .dataScanner:     return "dataScanner"
        }
    }
}

// MARK: - AttachmentService

@Observable @MainActor
final class AttachmentService: NSObject {

    /// The currently active sheet — nil means no sheet is shown.
    /// Setting this opens the corresponding picker. Single enum = mutual exclusion enforced by compiler.
    var activeSheet: AttachmentSheet? = nil

    /// Non-nil when an error should be shown to the user as an alert.
    var alertItem: AttachmentError? = nil

    // MARK: - Actions

    func scanText()           { log.info("AttachmentService: scanText");       activeSheet = .dataScanner }
    func scanDocuments()      { log.info("AttachmentService: scanDocuments");  activeSheet = .documentScanner }
    func takePhotoOrVideo()   { log.info("AttachmentService: takePhoto");      activeSheet = .camera }
    func choosePhotoOrVideo() { log.info("AttachmentService: choosePhoto");    activeSheet = .photoLibrary }
    func recordAudio()        { log.info("AttachmentService: recordAudio");    activeSheet = .audioRecorder }
    func attachFile()         { log.info("AttachmentService: attachFile");     activeSheet = .documentPicker }

    // MARK: - Image Append (with typed errors)

    func appendImage(_ data: Data, to attributedText: inout NSAttributedString, taskId: UUID) {
        log.info("AttachmentService.appendImage: \(data.count) bytes")
        guard let image = UIImage(data: data) else {
            log.error("AttachmentService.appendImage: UIImage decode failed (\(data.count) bytes)")
            alertItem = .imageDecodeFailed(data.count)
            return
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        let maxWidth: CGFloat = 280
        if image.size.width > maxWidth {
            let scale = maxWidth / image.size.width
            attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: image.size.height * scale)
            log.debug("AttachmentService.appendImage: scaled \(image.size.width)pt → \(maxWidth)pt")
        }
        // Persist image to disk and tag the attachment with its UUID
        let attachmentId = AttachmentStore.shared.save(imageData: data, taskId: taskId)
        attachment.fileType = attachmentId.uuidString
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.append(NSAttributedString(string: "\n"))
        mutable.append(NSAttributedString(attachment: attachment))
        attributedText = mutable
        log.info("AttachmentService.appendImage: appended \(Int(image.size.width))×\(Int(image.size.height))")
        // Notify the editor to push the new text into UITextView directly.
        // RichTextKit's updateUIView is intentionally empty, so the SwiftUI
        // binding update above never reaches the live UITextView on its own.
        NotificationCenter.default.post(name: .attachmentAppended, object: mutable)
    }

    func appendFile(url: URL, to attributedText: inout NSAttributedString) {
        let link = NSAttributedString(
            string: url.lastPathComponent,
            attributes: [.link: url, .font: UIFont.preferredFont(forTextStyle: .body)]
        )
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.append(NSAttributedString(string: "\n"))
        mutable.append(link)
        attributedText = mutable
        log.info("AttachmentService.appendFile: '\(url.lastPathComponent)'")
    }

    /// Persist `url` (temp M4A from AVAudioRecorder) and insert a tappable audio chip into the note.
    /// - Parameters:
    ///   - url: The temporary file URL returned by AVAudioRecorder.
    ///   - duration: The recording length in seconds (pass `elapsedSeconds` from AudioRecorderView).
    ///   - attributedText: The note's attributed string — the chip is appended on a new line.
    func appendAudio(url: URL, duration: TimeInterval, to attributedText: inout NSAttributedString) {
        let uuid = UUID()

        // Copy from temp → permanent Application Support/audio/{uuid}.m4a
        do {
            try AudioStorageService.persistRecording(from: url, uuid: uuid)
        } catch {
            log.error("AttachmentService.appendAudio: \(error.localizedDescription)")
            alertItem = .audioSaveFailed(error.localizedDescription)
            return
        }

        // Build the prodnote-audio:// URL that encodes all metadata.
        let audioURL = AudioLinkBuilder.buildURL(
            uuid: uuid,
            name: "Recording",
            duration: duration,
            date: Date()
        )

        // Build the inline chip text. The .link attribute survives RTF serialization.
        let chipText = "🎙 Recording  •  \(formattedDuration(duration))"
        let chipAttr = NSAttributedString(
            string: chipText,
            attributes: [
                .link:            audioURL as NSURL,
                .font:            UIFont.preferredFont(forTextStyle: .callout),
                .foregroundColor: UIColor.systemBlue,
            ]
        )

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.append(NSAttributedString(string: "\n"))
        mutable.append(chipAttr)
        attributedText = mutable
        log.info("AttachmentService.appendAudio: saved \(uuid.uuidString).m4a, duration \(duration)s")
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    func appendScannedText(_ text: String, to attributedText: inout NSAttributedString) {
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.append(NSAttributedString(string: "\n" + text))
        attributedText = mutable
        log.info("AttachmentService.appendScannedText: \(text.count) chars")
    }

    // MARK: - Presentation hooks

    /// Returns a zero-size view that drives all sheet presentations for this service.
    /// Attach via .background() on the parent view.
    func presentationHooks(attributedText: Binding<NSAttributedString>, taskId: UUID) -> some View {
        AttachmentServicePresenters(service: self, attributedText: attributedText, taskId: taskId)
    }
}

// MARK: - AttachmentServicePresenters

/// Zero-size view that owns all the .sheet/.fullScreenCover modifiers.
/// Uses a single `activeSheet` enum — no race conditions between Bool flags.
struct AttachmentServicePresenters: View {
    var service: AttachmentService
    @Binding var attributedText: NSAttributedString
    var taskId: UUID

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            // Single enum-driven sheet — only one can be active at a time
            .sheet(item: Binding(
                get: { service.activeSheet },
                set: { service.activeSheet = $0 }
            )) { sheet in
                sheetContent(for: sheet)
            }
            // Alert for typed errors
            .alert("Attachment Error",
                   isPresented: Binding(
                    get: { service.alertItem != nil },
                    set: { if !$0 { service.alertItem = nil } }
                   ),
                   presenting: service.alertItem) { _ in
                Button("OK", role: .cancel) { service.alertItem = nil }
            } message: { error in
                Text(error.errorDescription ?? "An unknown error occurred.")
            }
    }

    @ViewBuilder
    private func sheetContent(for sheet: AttachmentSheet) -> some View {
        switch sheet {
        case .photoLibrary:
            PhotoPickerView { data in
                service.appendImage(data, to: &attributedText, taskId: taskId)
                service.activeSheet = nil
            }
        case .camera:
            #if os(iOS)
            CameraPickerView { data in
                service.appendImage(data, to: &attributedText, taskId: taskId)
                service.activeSheet = nil
            }
            #else
            EmptyView()
            #endif
        case .documentPicker:
            DocumentFilePickerView { url in
                service.appendFile(url: url, to: &attributedText)
                service.activeSheet = nil
            }
        case .documentScanner:
            #if os(iOS)
            DocumentScannerView { images in
                for img in images {
                    if let d = img.pngData() {
                        service.appendImage(d, to: &attributedText, taskId: taskId)
                    }
                }
                service.activeSheet = nil
            }
            #else
            EmptyView()
            #endif
        case .audioRecorder:
            AudioRecorderView { url, duration in
                service.appendAudio(url: url, duration: duration, to: &attributedText)
                service.activeSheet = nil
            }
        case .dataScanner:
            #if os(iOS)
            DataScannerWrapperView { text in
                service.appendScannedText(text, to: &attributedText)
                service.activeSheet = nil
            }
            #else
            EmptyView()
            #endif
        }
    }
}
