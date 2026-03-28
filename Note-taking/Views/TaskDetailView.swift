import SwiftUI
import SwiftData
import RichTextKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "TaskDetail")

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

    // RichTextKit bindings — attributed string is the source of truth for RTF content
    @State private var attributedText: NSAttributedString = NSAttributedString()
    @StateObject private var richTextContext = RichTextContext()

    @State private var showToolbar = true
    @State private var isDrawingMode = false
    @State private var showAttachmentMenu = false
    @State private var showTablePicker = false

    // Slash command menu state
    @State private var showSlashMenu = false
    @State private var slashCommands: [SlashCommand] = []

    // Color palette state
    @State private var showColorPalette = false

    // MRU toolbar
    @State private var toolbarItems: [EditorTool] = [
        .init(id: "tablecells",    icon: "tablecells"),
        .init(id: "paperclip",     icon: "paperclip"),
        .init(id: "pencil",        icon: "pencil.tip.crop.circle"),
        .init(id: "list.bullet",   icon: "list.bullet"),
        .init(id: "bold",          icon: "bold"),
        .init(id: "italic",        icon: "italic"),
        .init(id: "underline",     icon: "underline"),
        .init(id: "strikethrough", icon: "strikethrough"),
    ]

    struct EditorTool: Identifiable { let id: String; let icon: String }

    @State private var attachmentCoordinator = AttachmentCoordinator()

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy 'at' h:mma"
        return formatter.string(from: task.createdAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            TextField("Untitled", text: $task.title, axis: .vertical)
                .font(.system(size: 28, weight: .bold))
                .lineLimit(1...4)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)

            Divider().padding(.horizontal, 20)

            ZStack(alignment: .topLeading) {
                // Native RichTextKit editor (Issue #38)
                NativeEditorView(
                    attributedText: $attributedText,
                    context: richTextContext
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)
                .onChange(of: attributedText) { _, newText in
                    detectSlashCommand(in: newText)
                }

                if isDrawingMode || task.drawingData != nil {
                    DrawingCanvasView(drawingData: $task.drawingData, isActive: $isDrawingMode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(isDrawingMode)
                }

                // Slash command menu — floats above keyboard (Issue #46)
                if showSlashMenu && !slashCommands.isEmpty {
                    VStack {
                        Spacer()
                        HStack(alignment: .bottom) {
                            SlashCommandMenuView(
                                commands: slashCommands,
                                onSelect: { cmd in
                                    applySlashCommand(cmd)
                                },
                                onDismiss: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showSlashMenu = false
                                    }
                                }
                            )
                            .padding(.leading, 16)
                            .padding(.bottom, 8)
                            Spacer()
                        }
                    }
                    .zIndex(20)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.15), value: showSlashMenu)
                }

                // Color palette — Issue #44
                if showColorPalette {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ColorPaletteView(
                                onApplyHighlight: { color in
                                    RichEditorCommands.applyHighlightColor(color, context: richTextContext)
                                    withAnimation { showColorPalette = false }
                                },
                                onApplyFontColor: { color in
                                    RichEditorCommands.applyTextColor(color, context: richTextContext)
                                    withAnimation { showColorPalette = false }
                                },
                                onDismiss: { showColorPalette = false }
                            )
                            .padding(.trailing, 16)
                            .padding(.bottom, 8)
                        }
                    }
                    .zIndex(20)
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Table grid picker (Issue #43)
            if showTablePicker {
                TableGridPickerView(
                    onInsert: { rows, cols in
                        let cursor = richTextContext.selectedRange.location
                        RichEditorCommands.insertTable(
                            rows: rows, cols: cols,
                            attributedText: &attributedText,
                            cursorLocation: cursor
                        )
                        showTablePicker = false
                    },
                    onDismiss: { showTablePicker = false }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(10)
            }

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
                if isDrawingMode {
                    Button {
                        withAnimation(.spring(response: 0.3)) { isDrawingMode = false }
                    } label: {
                        Text("Done").fontWeight(.semibold)
                    }
                } else {
                    // Export menu (Issue #45 — native PDF + RTF)
                    Menu {
                        Button { shareTask() } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Button { exportAsPDF() } label: {
                            Label("Export as PDF", systemImage: "doc.richtext")
                        }
                        Button { exportAsWord() } label: {
                            Label("Export as Word", systemImage: "doc.text")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Button { showToolbar.toggle() } label: {
                        Image(systemName: showToolbar ? "keyboard.chevron.compact.down" : "keyboard")
                    }
                }
            }
        }
        .confirmationDialog("Add to Note", isPresented: $showAttachmentMenu, titleVisibility: .hidden) {
            Button("Scan Text")             { attachmentCoordinator.scanText() }
            Button("Scan Documents")        { attachmentCoordinator.scanDocuments() }
            Button("Take Photo or Video")   { attachmentCoordinator.takePhotoOrVideo() }
            Button("Choose Photo or Video") { attachmentCoordinator.choosePhotoOrVideo() }
            Button("Record Audio")          { attachmentCoordinator.recordAudio() }
            Button("Attach File")           { attachmentCoordinator.attachFile() }
            Button("Cancel", role: .cancel) { }
        }
        .background(attachmentCoordinator.presentationHooks(attributedText: $attributedText))
        .onAppear { loadBody() }
        .onDisappear { saveBody() }
    }

    // MARK: - Toolbar (Issues #39–#43)

    private var editorToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(toolbarItems) { item in
                    toolbarButton(item.icon) {
                        handleToolbarTap(item.id)
                    }
                }
            }
            .padding(.horizontal, 8)
            .animation(.spring(response: 0.3), value: toolbarItems.map(\.id))
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

    private func handleToolbarTap(_ id: String) {
        switch id {
        case "tablecells":
            withAnimation(.spring(response: 0.3)) { showTablePicker.toggle() }
        case "paperclip":
            showAttachmentMenu = true
        case "pencil":
            saveBody()
            showTablePicker = false
            withAnimation(.spring(response: 0.35)) { isDrawingMode = true }
        case "list.bullet":
            RichEditorCommands.toggleBulletList(
                attributedText: &attributedText,
                selectedRange: richTextContext.selectedRange
            )
        case "bold":
            RichEditorCommands.toggleBold(context: richTextContext)
        case "italic":
            RichEditorCommands.toggleItalic(context: richTextContext)
        case "underline":
            RichEditorCommands.toggleUnderline(context: richTextContext)
        case "strikethrough":
            RichEditorCommands.toggleStrikethrough(context: richTextContext)
        default:
            break
        }
        // Bubble used item to front (MRU)
        withAnimation(.spring(response: 0.35)) {
            if let idx = toolbarItems.firstIndex(where: { $0.id == id }), idx != 0 {
                let tool = toolbarItems.remove(at: idx)
                toolbarItems.insert(tool, at: 0)
            }
        }
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

    // MARK: - Slash Command Detection + Application (Issue #46)

    private func detectSlashCommand(in text: NSAttributedString) {
        let cursor = richTextContext.selectedRange.location
        let state = SlashCommandEngine.evaluate(text: text.string, cursorLocation: cursor)
        withAnimation(.easeInOut(duration: 0.15)) {
            showSlashMenu = state.isActive
            slashCommands = state.filteredCommands
        }
    }

    private func applySlashCommand(_ cmd: SlashCommand) {
        let cursor = richTextContext.selectedRange.location
        let state = SlashCommandEngine.evaluate(text: attributedText.string, cursorLocation: cursor)

        // Remove the '/' + filter text
        if state.slashLocation >= 0 {
            let deleteLen = cursor - state.slashLocation
            if deleteLen > 0 {
                let deleteRange = NSRange(location: state.slashLocation, length: deleteLen)
                let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
                mutable.deleteCharacters(in: deleteRange)
                attributedText = mutable
            }
        }

        let newCursor = state.slashLocation >= 0 ? state.slashLocation : cursor
        let selRange = NSRange(location: max(0, newCursor), length: 0)

        // Apply the selected command
        switch cmd.id {
        case "text":
            RichEditorCommands.applyBodyText(attributedText: &attributedText, selectedRange: selRange)
        case "bulletList":
            RichEditorCommands.toggleBulletList(attributedText: &attributedText, selectedRange: selRange)
        case "todoList":
            RichEditorCommands.insertChecklist(attributedText: &attributedText, cursorLocation: newCursor)
        case "quote":
            RichEditorCommands.applyBlockquote(attributedText: &attributedText, selectedRange: selRange)
        case "heading1":
            RichEditorCommands.applyHeading(.h1, attributedText: &attributedText, selectedRange: selRange)
        case "heading2":
            RichEditorCommands.applyHeading(.h2, attributedText: &attributedText, selectedRange: selRange)
        case "heading3":
            RichEditorCommands.applyHeading(.h3, attributedText: &attributedText, selectedRange: selRange)
        case "table":
            withAnimation(.spring(response: 0.3)) { showTablePicker = true }
        case "colorGray":   RichEditorCommands.applyTextColor(UIColor(hex: "#8e8e93"), context: richTextContext)
        case "colorOrange": RichEditorCommands.applyTextColor(UIColor(hex: "#ff6a00"), context: richTextContext)
        case "colorBlue":   RichEditorCommands.applyTextColor(UIColor(hex: "#0a84ff"), context: richTextContext)
        case "colorPurple": RichEditorCommands.applyTextColor(UIColor(hex: "#bf5af2"), context: richTextContext)
        case "colorPink":   RichEditorCommands.applyTextColor(UIColor(hex: "#ff375f"), context: richTextContext)
        case "colorBrown":  RichEditorCommands.applyTextColor(UIColor(hex: "#ac8e68"), context: richTextContext)
        default: break
        }

        withAnimation(.easeInOut(duration: 0.15)) { showSlashMenu = false }
    }

    // MARK: - Export (Issue #45 — native, no WKWebView)

    private func exportAsPDF() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        NativeExportService.exportAsPDF(title: task.title, content: attributedText, from: root)
    }

    private func exportAsWord() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        NativeExportService.exportAsRTF(title: task.title, content: attributedText, from: root)
    }

    private func shareTask() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        NativeExportService.shareText(title: task.title, content: attributedText, from: root)
    }

    // MARK: - Save / Load (RTF Data — Issue #38)

    private func loadBody() {
        if let data = task.body, let loaded = data.attributedStringFromRTF() {
            log.info("loadBody: loaded \(loaded.length) chars for task '\(task.title)'")
            attributedText = loaded
        } else {
            log.info("loadBody: no body stored for task '\(task.title)'")
        }
    }

    private func saveBody() {
        if attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            log.info("saveBody: empty — clearing body for task '\(task.title)'")
            task.body = nil
        } else if let data = attributedText.rtfData() {
            log.info("saveBody: saved \(data.count) bytes for task '\(task.title)'")
            task.body = data
        } else {
            log.error("saveBody: RTF conversion failed for task '\(task.title)'")
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
    var presentPhotoPickerCamera = false
    var presentPhotoPickerLibrary = false
    var presentDocumentPicker = false
    var presentDocumentScanner = false
    var presentDataScanner = false
    var presentAudioRecorder = false

    func presentationHooks(attributedText: Binding<NSAttributedString>) -> some View {
        AttachmentPresenters(coordinator: self, attributedText: attributedText)
    }

    func scanText()             { presentDataScanner = true }
    func scanDocuments()        { presentDocumentScanner = true }
    func takePhotoOrVideo()     { presentPhotoPickerCamera = true }
    func choosePhotoOrVideo()   { presentPhotoPickerLibrary = true }
    func recordAudio()          { presentAudioRecorder = true }
    func attachFile()           { presentDocumentPicker = true }
}

// MARK: - AttachmentPresenters

struct AttachmentPresenters: View {
    @Bindable var coordinator: AttachmentCoordinator
    @Binding var attributedText: NSAttributedString

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .sheet(isPresented: $coordinator.presentPhotoPickerLibrary) {
                PhotoPickerView { data in appendImage(data) }
            }
            .fullScreenCover(isPresented: $coordinator.presentPhotoPickerCamera) {
                CameraPickerView { data in appendImage(data) }
            }
            .sheet(isPresented: $coordinator.presentDocumentPicker) {
                DocumentFilePickerView { url in
                    let link = NSAttributedString(
                        string: url.lastPathComponent,
                        attributes: [.link: url, .font: UIFont.preferredFont(forTextStyle: .body)]
                    )
                    let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
                    mutable.append(NSAttributedString(string: "\n"))
                    mutable.append(link)
                    attributedText = mutable
                }
            }
            .sheet(isPresented: $coordinator.presentDocumentScanner) {
                DocumentScannerView { images in
                    for img in images { if let d = img.pngData() { appendImage(d) } }
                }
            }
            .sheet(isPresented: $coordinator.presentAudioRecorder) {
                AudioRecorderView { url in
                    let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
                    mutable.append(NSAttributedString(string: "\n[Audio: \(url.lastPathComponent)]"))
                    attributedText = mutable
                }
            }
            .sheet(isPresented: $coordinator.presentDataScanner) {
                DataScannerWrapperView { text in
                    let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
                    mutable.append(NSAttributedString(string: "\n" + text))
                    attributedText = mutable
                }
            }
    }

    private func appendImage(_ data: Data) {
        guard let image = UIImage(data: data) else { return }
        let attachment = NSTextAttachment()
        attachment.image = image
        let maxWidth: CGFloat = 280
        if image.size.width > maxWidth {
            let scale = maxWidth / image.size.width
            attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: image.size.height * scale)
        }
        let mutable = attributedText.mutableCopy() as! NSMutableAttributedString
        mutable.append(NSAttributedString(string: "\n"))
        mutable.append(NSAttributedString(attachment: attachment))
        attributedText = mutable
    }
}

// MARK: - DataScannerWrapperView (VisionKit live text capture)

struct DataScannerWrapperView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard DataScannerViewController.isSupported && DataScannerViewController.isAvailable else {
            return UIViewController()
        }
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        context.coordinator.scanner = scanner
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        weak var scanner: DataScannerViewController?

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let text) = item {
                DispatchQueue.main.async {
                    self.onScan(text.transcript)
                    dataScanner.dismiss(animated: true)
                }
            }
        }
    }
}

// MARK: - PhotoPickerView

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

// MARK: - CameraPickerView

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

// MARK: - DocumentFilePickerView

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

// MARK: - DocumentScannerView

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

                Text("Record Audio").font(.headline)

                Image(systemName: isRecording ? "waveform.circle.fill" : "mic.circle")
                    .font(.system(size: 72))
                    .foregroundStyle(isRecording ? Color.red : Color.accentColor)
                    .symbolEffect(.pulse, isActive: isRecording)

                Text(isRecording ? "Recording…" : "Tap to start").foregroundStyle(Color.secondary)

                Button(isRecording ? "Stop" : "Record") {
                    isRecording ? stopRecording() : startRecording()
                }
                .buttonStyle(.borderedProminent)

                if let url = audioURL {
                    Button("Insert Audio") { onSave(url); dismiss() }
                        .buttonStyle(.bordered)
                }

                Button("Cancel") { dismiss() }.foregroundStyle(Color.secondary)
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
