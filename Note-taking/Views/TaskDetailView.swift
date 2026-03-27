import SwiftUI
import SwiftData
import WebKit

#if canImport(UIKit)
import UIKit
import PhotosUI
import VisionKit
import AVFoundation
import UniformTypeIdentifiers

// MARK: - TaskDetailView

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @State private var html: String = ""
    @State private var showToolbar = true
    @State private var isDrawingMode = false
    @State private var showAttachmentMenu = false
    @State private var showFormattingBar = false
    @State private var showTablePicker = false
    @State private var showExportMenu = false

    // Attachment coordinator (holds UIKit delegates)
    @State private var attachmentCoordinator = AttachmentCoordinator()

    // Reference to WKWebView for export
    @State private var editorWebView: WKWebView?

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy 'at' h:mma"
        return formatter.string(from: task.createdAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date — caption above title
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // Title — always the largest text element on the page
            TextField("Untitled", text: $task.title, axis: .vertical)
                .font(.system(size: 28, weight: .bold))
                .lineLimit(1...4)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)

            Divider().padding(.horizontal, 20)

            // Content area — either rich text editor or drawing canvas
            if isDrawingMode {
                DrawingCanvasViewWithDoneButton(
                    drawingData: $task.drawingData,
                    onDone: { drawingImageData in
                        exitDrawingMode(imageData: drawingImageData)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TipTapEditorView(html: $html, onWebViewReady: { wv in
                    editorWebView = wv
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)
            }

            // Inline formatting bar (shown when Aa is active)
            if showFormattingBar {
                formattingBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Table grid picker overlay
            if showTablePicker {
                TableGridPickerView { rows, cols in
                    insertTable(rows: rows, cols: cols)
                    showTablePicker = false
                } onDismiss: {
                    showTablePicker = false
                }
                .transition(.scale.combined(with: .opacity))
                .zIndex(10)
            }

            // Bottom toolbar — single swipeable row
            if showToolbar && !isDrawingMode {
                editorToolbar
            }
        }
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    saveBody()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(minWidth: 44, minHeight: 44)
                }
            }

            ToolbarItemGroup(placement: .confirmationAction) {
                // Share / Export menu
                Menu {
                    Button {
                        shareTask()
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        exportAsPDF()
                    } label: {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }
                    Button {
                        exportAsWord()
                    } label: {
                        Label("Export as Word", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }

                Button { showToolbar.toggle() } label: {
                    Image(systemName: showToolbar ? "keyboard.chevron.compact.down" : "keyboard")
                }

                Button { toggleComplete() } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundStyle(task.isCompleted ? Color.accentColor : Color.primary)
                }
            }
        }
        .sheet(isPresented: $showAttachmentMenu) {
            attachmentSheet
        }
        .background(attachmentCoordinator.presentationHooks(html: $html))
        .onAppear { loadBody() }
        .onDisappear { saveBody() }
    }

    // MARK: - Swipeable toolbar (single row)

    private var editorToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                toolbarButton("textformat") {
                    withAnimation(.spring(response: 0.3)) {
                        showFormattingBar.toggle()
                    }
                }
                toolbarButton("checklist") {
                    sendEditorCommand("toggleTaskList")
                }
                toolbarButton("tablecells") {
                    withAnimation(.spring(response: 0.3)) {
                        showTablePicker.toggle()
                    }
                }
                toolbarButton("paperclip") {
                    showAttachmentMenu = true
                }
                toolbarButton("pencil.tip.crop.circle") {
                    saveBody()
                    withAnimation { isDrawingMode = true }
                }
                toolbarButton("list.bullet") {
                    sendEditorCommand("toggleBulletList")
                }
                toolbarButton("bold") {
                    sendEditorCommand("toggleBold")
                }
                toolbarButton("italic") {
                    sendEditorCommand("toggleItalic")
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func toolbarButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Inline formatting bar (Aa popover)

    private var formattingBar: some View {
        HStack(spacing: 0) {
            formatButton("bold") { sendEditorCommand("toggleBold") }
            formatButton("italic") { sendEditorCommand("toggleItalic") }
            formatButton("underline") { sendEditorCommand("toggleUnderline") }
            formatButton("strikethrough") { sendEditorCommand("toggleStrike") }
        }
        .frame(height: 44)
        .background(
            Capsule().fill(.regularMaterial)
                .shadow(color: Color.primary.opacity(0.1), radius: 6, y: 2)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
    }

    private func formatButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Attachment sheet (ultraThinMaterial)

    private var attachmentSheet: some View {
        ZStack {
            Color.clear.background(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Pull handle
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 16)

                Text("Add to Note")
                    .font(.headline)
                    .padding(.bottom, 16)

                VStack(spacing: 0) {
                    attachmentOptionRow(icon: "text.viewfinder", title: "Scan Text", color: .orange) {
                        showAttachmentMenu = false
                        attachmentCoordinator.scanText()
                    }
                    Divider().padding(.leading, 58)
                    attachmentOptionRow(icon: "doc.viewfinder", title: "Scan Documents", color: .blue) {
                        showAttachmentMenu = false
                        attachmentCoordinator.scanDocuments()
                    }
                    Divider().padding(.leading, 58)
                    attachmentOptionRow(icon: "camera", title: "Take Photo or Video", color: .green) {
                        showAttachmentMenu = false
                        attachmentCoordinator.takePhotoOrVideo()
                    }
                    Divider().padding(.leading, 58)
                    attachmentOptionRow(icon: "photo.on.rectangle", title: "Choose Photo or Video", color: .purple) {
                        showAttachmentMenu = false
                        attachmentCoordinator.choosePhotoOrVideo()
                    }
                    Divider().padding(.leading, 58)
                    attachmentOptionRow(icon: "waveform", title: "Record Audio", color: .red) {
                        showAttachmentMenu = false
                        attachmentCoordinator.recordAudio()
                    }
                    Divider().padding(.leading, 58)
                    attachmentOptionRow(icon: "doc", title: "Attach File", color: .gray) {
                        showAttachmentMenu = false
                        attachmentCoordinator.attachFile()
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.regularMaterial)
                )
                .padding(.horizontal, 16)

                Button("Cancel") { showAttachmentMenu = false }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.regularMaterial))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
            }
        }
        .presentationDetents([.height(520)])
        .presentationBackground(.clear)
    }

    private func attachmentOptionRow(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(color)
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.white)
                }
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Drawing mode exit

    private func exitDrawingMode(imageData: Data?) {
        withAnimation { isDrawingMode = false }
        guard let data = imageData,
              let image = UIImage(data: data),
              let pngData = image.pngData() else { return }
        let base64 = pngData.base64EncodedString()
        let js = "insertImage('data:image/png;base64,\(base64)')"
        editorWebView?.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Table insert

    private func insertTable(rows: Int, cols: Int) {
        let js = "insertTable(\(rows), \(cols))"
        editorWebView?.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - JS bridge helper

    private func sendEditorCommand(_ command: String) {
        editorWebView?.evaluateJavaScript("editorCommand('\(command)')", completionHandler: nil)
    }

    // MARK: - Export

    private func exportAsPDF() {
        guard let webView = editorWebView else { return }
        let config = WKPDFConfiguration()
        webView.createPDF(configuration: config) { result in
            switch result {
            case .success(let data):
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("\(task.title.isEmpty ? "Note" : task.title).pdf")
                try? data.write(to: tempURL)
                DispatchQueue.main.async { presentShareSheet(items: [tempURL]) }
            case .failure:
                break
            }
        }
    }

    private func exportAsWord() {
        editorWebView?.evaluateJavaScript("exportAsDocx()") { result, _ in
            guard let base64 = result as? String,
                  let data = Data(base64Encoded: base64) else { return }
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(task.title.isEmpty ? "Note" : task.title).docx")
            try? data.write(to: tempURL)
            DispatchQueue.main.async { self.presentShareSheet(items: [tempURL]) }
        }
    }

    private func shareTask() {
        let text = "\(task.title)\n\n\(html)"
        presentShareSheet(items: [text])
    }

    private func presentShareSheet(items: [Any]) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        root.present(vc, animated: true)
    }

    // MARK: - Actions

    private func loadBody() {
        if let data = task.body, let s = String(data: data, encoding: .utf8) {
            html = s
        }
    }

    private func saveBody() {
        let stripped = html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&[a-zA-Z0-9#]+;", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        task.body = stripped.isEmpty ? nil : html.data(using: .utf8)
    }

    private func toggleComplete() {
        withAnimation {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
        }
    }
}

// MARK: - TableGridPickerView

struct TableGridPickerView: View {
    let onInsert: (Int, Int) -> Void
    let onDismiss: () -> Void

    @State private var hoveredRow = 1
    @State private var hoveredCol = 1
    private let maxRows = 6
    private let maxCols = 6

    var body: some View {
        VStack(spacing: 12) {
            Text("Select table size")
                .font(.subheadline.weight(.semibold))

            VStack(spacing: 4) {
                ForEach(1...maxRows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(1...maxCols, id: \.self) { col in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(row <= hoveredRow && col <= hoveredCol
                                      ? Color.accentColor
                                      : Color.secondary.opacity(0.2))
                                .frame(width: 28, height: 28)
                                .onHover { inside in
                                    if inside { hoveredRow = row; hoveredCol = col }
                                }
                                .onTapGesture {
                                    onInsert(row, col)
                                }
                        }
                    }
                }
            }

            Text("\(hoveredRow) × \(hoveredCol)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Color.secondary)

            Button("Cancel", action: onDismiss)
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: Color.primary.opacity(0.15), radius: 16)
        )
        .padding(32)
    }
}

// MARK: - AttachmentCoordinator

@Observable
final class AttachmentCoordinator: NSObject {
    // Used to inject the html binding for image insertion
    private var insertImageCallback: ((String) -> Void)?

    // State flags drive UIKit presenters
    var presentPhotoPickerCamera = false
    var presentPhotoPickerLibrary = false
    var presentDocumentPicker = false
    var presentDocumentScanner = false
    var presentDataScanner = false
    var presentAudioRecorder = false

    func presentationHooks(html: Binding<String>) -> some View {
        AttachmentPresenters(coordinator: self, html: html)
    }

    func scanText() { presentDataScanner = true }
    func scanDocuments() { presentDocumentScanner = true }
    func takePhotoOrVideo() { presentPhotoPickerCamera = true }
    func choosePhotoOrVideo() { presentPhotoPickerLibrary = true }
    func recordAudio() { presentAudioRecorder = true }
    func attachFile() { presentDocumentPicker = true }
}

// MARK: - AttachmentPresenters (hidden presenter bridge)

struct AttachmentPresenters: View {
    @Bindable var coordinator: AttachmentCoordinator
    @Binding var html: String

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .sheet(isPresented: $coordinator.presentPhotoPickerLibrary) {
                PhotoPickerView { imageData in
                    appendImageToHTML(imageData: imageData)
                }
            }
            .fullScreenCover(isPresented: $coordinator.presentPhotoPickerCamera) {
                CameraPickerView { imageData in
                    appendImageToHTML(imageData: imageData)
                }
            }
            .sheet(isPresented: $coordinator.presentDocumentPicker) {
                DocumentFilePickerView { url in
                    // Attach file as a link
                    let name = url.lastPathComponent
                    html += "<p><a href=\"\(url.absoluteString)\">\(name)</a></p>"
                }
            }
            .sheet(isPresented: $coordinator.presentDocumentScanner) {
                DocumentScannerView { images in
                    for img in images {
                        if let data = img.pngData() {
                            appendImageToHTML(imageData: data)
                        }
                    }
                }
            }
            .sheet(isPresented: $coordinator.presentAudioRecorder) {
                AudioRecorderView { audioURL in
                    let name = audioURL.lastPathComponent
                    html += "<p>[Audio: \(name)]</p>"
                }
            }
    }

    private func appendImageToHTML(imageData: Data) {
        let base64 = imageData.base64EncodedString()
        html += "<img src=\"data:image/png;base64,\(base64)\" style=\"max-width:100%;border-radius:8px;margin-top:8px;\" />"
    }
}

// MARK: - PhotoPickerView (PHPickerViewController)

struct PhotoPickerView: UIViewControllerRepresentable {
    let onPick: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (Data) -> Void
        init(onPick: @escaping (Data) -> Void) { self.onPick = onPick }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                if let image = object as? UIImage, let data = image.pngData() {
                    DispatchQueue.main.async { self.onPick(data) }
                }
            }
        }
    }
}

// MARK: - CameraPickerView (UIImagePickerController)

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (Data) -> Void
        init(onCapture: @escaping (Data) -> Void) { self.onCapture = onCapture }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage, let data = image.pngData() {
                DispatchQueue.main.async { self.onCapture(data) }
            }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - DocumentFilePickerView (UIDocumentPickerViewController)

struct DocumentFilePickerView: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            DispatchQueue.main.async { self.onPick(url) }
        }
    }
}

// MARK: - DocumentScannerView (VNDocumentCameraViewController)

struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        init(onScan: @escaping ([UIImage]) -> Void) { self.onScan = onScan }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFinishWith scan: VNDocumentCameraScan) {
            controller.dismiss(animated: true)
            var images: [UIImage] = []
            for i in 0..<scan.pageCount { images.append(scan.imageOfPage(at: i)) }
            DispatchQueue.main.async { self.onScan(images) }
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                          didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - AudioRecorderView

struct AudioRecorderView: View {
    let onSave: (URL) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isRecording = false
    @State private var recorder: AVAudioRecorder?
    @State private var audioURL: URL?

    var body: some View {
        ZStack {
            Color.clear.background(.ultraThinMaterial).ignoresSafeArea()
            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)

                Text("Record Audio")
                    .font(.headline)

                Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle")
                    .font(.system(size: 72))
                    .foregroundStyle(isRecording ? Color.red : Color.accentColor)
                    .symbolEffect(.pulse, isActive: isRecording)

                Text(isRecording ? "Recording…" : "Tap to start")
                    .foregroundStyle(Color.secondary)

                Button(isRecording ? "Stop" : "Record") {
                    isRecording ? stopRecording() : startRecording()
                }
                .buttonStyle(.borderedProminent)

                if let url = audioURL {
                    Button("Insert Audio") {
                        onSave(url)
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }

                Button("Cancel") { dismiss() }
                    .foregroundStyle(Color.secondary)
            }
            .padding(32)
        }
        .presentationDetents([.medium])
        .presentationBackground(.clear)
    }

    private func startRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(Date().timeIntervalSince1970).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        try? AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        recorder = try? AVAudioRecorder(url: url, settings: settings)
        recorder?.record()
        audioURL = url
        isRecording = true
    }

    private func stopRecording() {
        recorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
        isRecording = false
    }
}
#endif
