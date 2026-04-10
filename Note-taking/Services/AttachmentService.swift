import PhotosUI
import SwiftUI
import UIKit
import OSLog
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
    var errorDescription: String? {
        switch self {
        case .imageDecodeFailed(let bytes):
            return "Could not decode image (\(bytes) bytes). The file may be corrupted or unsupported."
        case .mutableCopyFailed:
            return "An internal error occurred while preparing the editor content."
        case .unsupportedSource(let name):
            return "'\(name)' is not supported yet."
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
    case dataScanner

    var id: String {
        switch self {
        case .photoLibrary:    return "photoLibrary"
        case .camera:          return "camera"
        case .documentPicker:  return "documentPicker"
        case .documentScanner: return "documentScanner"
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
        // Resize to max 1440px before storing in memory or on disk.
        // Full-resolution camera photos (48MP+) cause OOM crashes when held in NSTextAttachment.
        let resized = AttachmentService.resized(image, maxDimension: 1440)
        let storageData = resized.jpegData(compressionQuality: 0.85) ?? data
        log.debug("AttachmentService.appendImage: resized \(Int(image.size.width))×\(Int(image.size.height)) → \(Int(resized.size.width))×\(Int(resized.size.height))")

        let attachment = NSTextAttachment()
        attachment.image = resized
        // Default display width ~50% of typical editor area so images are not
        // oversized on insertion. Users can resize via ➖/➕ pill (Issue #99).
        let maxWidth: CGFloat = 180
        let displayWidth = min(resized.size.width, maxWidth)
        let scale = displayWidth / max(1, resized.size.width)
        attachment.bounds = CGRect(x: 0, y: 0, width: displayWidth, height: resized.size.height * scale)
        log.debug("AttachmentService.appendImage: display-scaled \(resized.size.width)pt → \(displayWidth)pt")
        // Persist resized image to disk and tag with UUID via custom attribute
        let attachmentId = AttachmentStore.shared.save(imageData: storageData, taskId: taskId)
        let attachStr = NSMutableAttributedString(string: "\n", attributes: [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 15)
        ])
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

    func appendFile(url: URL, to attributedText: inout NSAttributedString, at cursorPosition: Int? = nil) {
        // File icon — pick an SF Symbol based on extension, same as Apple Files app style
        let ext = url.pathExtension.lowercased()
        let symbolName: String
        switch ext {
        case "pdf":               symbolName = "doc.richtext"
        case "doc", "docx":       symbolName = "doc.text"
        case "xls", "xlsx":       symbolName = "tablecells"
        case "ppt", "pptx":       symbolName = "rectangle.on.rectangle"
        case "zip", "rar", "gz":  symbolName = "archivebox"
        case "mp3", "m4a", "wav": symbolName = "music.note"
        case "mp4", "mov":        symbolName = "video"
        case "jpg", "jpeg", "png", "heic": symbolName = "photo"
        default:                  symbolName = "doc"
        }
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let iconImage  = UIImage(systemName: symbolName, withConfiguration: iconConfig)?
            .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
        let iconAttachment = NSTextAttachment()
        iconAttachment.image = iconImage
        iconAttachment.bounds = CGRect(x: 0, y: -3, width: 18, height: 20)

        let result = NSMutableAttributedString(string: "\n", attributes: [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 15)
        ])
        result.append(NSAttributedString(attachment: iconAttachment))
        result.append(NSAttributedString(string: "\u{00A0}" + url.lastPathComponent, attributes: [
            .link: url,
            .font: UIFont.systemFont(ofSize: 15)
        ]))

        let mutable  = NSMutableAttributedString(attributedString: attributedText)
        let insertAt = min(cursorPosition ?? mutable.length, mutable.length)
        mutable.insert(result, at: insertAt)
        attributedText = mutable
        log.info("AttachmentService.appendFile: '\(url.lastPathComponent)' at \(insertAt)")
        NotificationCenter.default.post(name: .attachmentAppended, object: mutable,
                                        userInfo: ["cursorPosition": insertAt + result.length])
    }

    func appendScannedText(_ text: String, to attributedText: inout NSAttributedString) {
        let mutable = NSMutableAttributedString(attributedString: attributedText)
        mutable.append(NSAttributedString(string: "\n" + text))
        attributedText = mutable
        log.info("AttachmentService.appendScannedText: \(text.count) chars")
    }

    // MARK: - Image resize helper

    /// Downscale image so its longest side does not exceed maxDimension.
    /// Uses UIGraphicsImageRenderer — Apple's recommended API, handles orientation correctly.
    /// Returns the original image unchanged if it already fits within the limit.
    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
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

    /// SwiftUI PhotosPicker selection — replaces UIKit PHPickerViewController.
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            // PhotosPicker presented as sheet when .photoLibrary is active
            .photosPicker(
                isPresented: Binding(
                    get: { service.activeSheet == .photoLibrary },
                    set: { if !$0 { service.activeSheet = nil } }
                ),
                selection: $selectedPhotos,
                maxSelectionCount: 10,
                matching: .images
            )
            .onChange(of: selectedPhotos) { _, newItems in
                guard !newItems.isEmpty else { return }
                let cursorPos = service.savedCursorPosition
                Task {
                    for (index, item) in newItems.enumerated() {
                        print("PhotoPicker: loading photo \(index + 1)/\(newItems.count)")
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            print("PhotoPicker: photo \(index + 1) loaded (\(data.count) bytes)")
                            await MainActor.run {
                                service.appendImage(data, to: &attributedText, taskId: taskId, at: cursorPos)
                            }
                        } else {
                            print("PhotoPicker: photo \(index + 1) FAILED to load")
                        }
                    }
                    print("PhotoPicker: all \(newItems.count) photo(s) delivered")
                    await MainActor.run { selectedPhotos = [] }
                }
            }
            // Other sheets (camera, document picker, scanner, etc.)
            .sheet(item: Binding(
                get: { service.activeSheet == .photoLibrary ? nil : service.activeSheet },
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
            EmptyView() // Handled by .photosPicker above
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
                // Guard: dismiss sheet FIRST to prevent SwiftUI re-evaluation
                // from firing the callback again (triple-insert bug).
                guard service.activeSheet == .documentPicker else { return }
                service.activeSheet = nil
                service.appendFile(url: url, to: &attributedText, at: service.savedCursorPosition)
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
        case .dataScanner:
            #if os(iOS) && !targetEnvironment(macCatalyst)
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
