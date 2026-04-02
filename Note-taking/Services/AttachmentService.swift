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

    /// Cursor position captured when the user taps a toolbar button.
    /// Used to insert attachments at the cursor instead of at the end.
    var savedCursorPosition: Int? = nil

    // MARK: - Actions

    func scanText()           { log.info("AttachmentService: scanText");       activeSheet = .dataScanner }
    func scanDocuments()      { log.info("AttachmentService: scanDocuments");  activeSheet = .documentScanner }
    func takePhotoOrVideo()   { log.info("AttachmentService: takePhoto");      activeSheet = .camera }
    func choosePhotoOrVideo() { log.info("AttachmentService: choosePhoto");    activeSheet = .photoLibrary }
    func recordAudio()        { log.info("AttachmentService: recordAudio");    activeSheet = .audioRecorder }
    func attachFile()         { log.info("AttachmentService: attachFile");     activeSheet = .documentPicker }

    // MARK: - Image Append (with typed errors)

    /// Insert image at the given cursor position (or end if nil).
    func appendImage(_ data: Data, to attributedText: inout NSAttributedString, taskId: UUID, at cursorPosition: Int? = nil) {
        log.info("AttachmentService.appendImage: \(data.count) bytes, cursor=\(cursorPosition.map(String.init) ?? "end")")
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
        // Persist image to disk and tag with UUID via custom attribute
        let attachmentId = AttachmentStore.shared.save(imageData: data, taskId: taskId)
        let attachStr = NSMutableAttributedString(string: "\n")
        let imgStr = NSMutableAttributedString(attachment: attachment)
        imgStr.addAttribute(.imageAttachmentId, value: attachmentId.uuidString, range: NSRange(location: 0, length: imgStr.length))
        attachStr.append(imgStr)

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let insertAt = min(cursorPosition ?? mutable.length, mutable.length)
        mutable.insert(attachStr, at: insertAt)
        attributedText = mutable
        log.info("AttachmentService.appendImage: inserted \(Int(image.size.width))×\(Int(image.size.height)) at position \(insertAt)")
        NotificationCenter.default.post(name: .attachmentAppended, object: mutable,
                                        userInfo: ["cursorPosition": insertAt + attachStr.length])
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

    /// Persist `url` (temp M4A from AVAudioRecorder) and insert an Apple-Notes-style
    /// audio card into the note body.
    ///
    /// Why we use a rendered UIImage card instead of NSTextAttachmentViewProvider:
    ///   RichTextKit forces TextKit 1 (accesses NSLayoutManager on init), so
    ///   NSTextAttachmentViewProvider (TextKit 2 only) silently does nothing.
    ///   We render the card to a UIImage via AudioCardRenderer and embed it as a
    ///   standard NSTextAttachment — TextKit 1 compatible and survives RTF round-trips
    ///   via the strip/restore pattern in NoteBodyCodec.
    ///
    /// - Parameters:
    ///   - url:      Temporary M4A file returned by AVAudioRecorder.
    ///   - duration: Recording length in seconds (from AudioRecorderView.elapsedSeconds).
    ///   - attributedText: Note body — card is appended on a new line.
    /// Insert audio card at the given cursor position (or end if nil).
    func appendAudio(url: URL, duration: TimeInterval, to attributedText: inout NSAttributedString, at cursorPosition: Int? = nil) {
        log.info("AttachmentService.appendAudio: starting — duration=\(duration)s url=\(url.lastPathComponent)")
        let uuid = UUID()

        // ── Step 1: Persist M4A from temp → permanent storage ────────────────
        do {
            try AudioStorageService.persistRecording(from: url, uuid: uuid)
            log.debug("AttachmentService.appendAudio: persisted \(uuid.uuidString).m4a")
        } catch {
            log.error("AttachmentService.appendAudio: persist failed — \(error.localizedDescription)")
            alertItem = .audioSaveFailed(error.localizedDescription)
            return
        }

        // ── Step 2: Build prodnote-audio:// metadata URL ──────────────────────
        let recordingDate = Date()
        let audioURL  = AudioLinkBuilder.buildURL(uuid: uuid, name: "Recording",
                                                  duration: duration, date: recordingDate)
        let urlStr    = audioURL.absoluteString
        let link      = AudioLink(uuid: uuid, name: "Recording",
                                  duration: duration, date: recordingDate)
        log.debug("AttachmentService.appendAudio: metadata URL = \(urlStr)")

        // ── Step 3: Render Apple-Notes-style card as UIImage ──────────────────
        // Width = screen width minus the editor's horizontal insets (16 pt each side
        // in NativeEditorView + 8 pt list row inset ≈ 48 pt total).
        let cardWidth = UIScreen.main.bounds.width - 48
        let cardImage = AudioCardRenderer.render(link: link, width: cardWidth)
        log.debug("AttachmentService.appendAudio: card image = \(Int(cardImage.size.width))×\(Int(cardImage.size.height))@\(cardImage.scale)x")

        // ── Step 4: Build NSTextAttachment ────────────────────────────────────
        let attachment        = NSTextAttachment()
        attachment.image      = cardImage
        // y: -4 nudges the card baseline to align with surrounding text lines
        attachment.bounds     = CGRect(x: 0, y: -4,
                                       width:  cardImage.size.width,
                                       height: cardImage.size.height)

        // ── Step 5: Tag with custom key + .link ───────────────────────────────
        // .audioAttachmentLink → NoteBodyCodec strips/restores this on save/load
        // .link                → AudioTapCoordinator detects taps and opens AudioPlayerView
        let attachStr   = NSMutableAttributedString(attachment: attachment)
        let attachRange = NSRange(location: 0, length: attachStr.length)
        attachStr.addAttribute(.audioAttachmentLink, value: urlStr, range: attachRange)
        attachStr.addAttribute(.link,                value: urlStr, range: attachRange)
        log.debug("AttachmentService.appendAudio: tagged attachment with audioAttachmentLink + .link")

        // ── Step 6: Insert card at cursor position ─────────────────────────────
        let cardBlock = NSMutableAttributedString(string: "\n")
        cardBlock.append(attachStr)
        cardBlock.append(NSAttributedString(string: "\n"))

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let insertAt = min(cursorPosition ?? mutable.length, mutable.length)
        mutable.insert(cardBlock, at: insertAt)
        attributedText = mutable
        log.info("AttachmentService.appendAudio: inserted card for uuid=\(uuid.uuidString) at position \(insertAt)")

        // ── Step 7: Push updated text into live UITextView ───────────────────────
        NotificationCenter.default.post(name: .attachmentAppended, object: mutable,
                                        userInfo: ["cursorPosition": insertAt + cardBlock.length])
        log.debug("AttachmentService.appendAudio: posted .attachmentAppended notification")
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
                service.appendImage(data, to: &attributedText, taskId: taskId, at: service.savedCursorPosition)
                service.activeSheet = nil
            }
        case .camera:
            #if os(iOS)
            CameraPickerView { data in
                service.appendImage(data, to: &attributedText, taskId: taskId, at: service.savedCursorPosition)
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
                        service.appendImage(d, to: &attributedText, taskId: taskId, at: service.savedCursorPosition)
                    }
                }
                service.activeSheet = nil
            }
            #else
            EmptyView()
            #endif
        case .audioRecorder:
            AudioRecorderView { url, duration in
                service.appendAudio(url: url, duration: duration, to: &attributedText, at: service.savedCursorPosition)
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
