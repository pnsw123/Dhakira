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
    /// Reference to the underlying UITextView — obtained once via onEditorReady.
    /// Used to restore focus + selection before issuing formatting commands.
    @State private var richTextView: UITextView?

    @State private var showToolbar = true
    @State private var isDrawingMode = false
    @State private var showTablePicker = false
    /// Cursor position captured when the table picker opens — preserved because
    /// tapping the picker dismisses the keyboard and resets richTextContext.selectedRange.
    @State private var savedTableCursorLocation: Int = 0

    // Slash command menu state
    @State private var showSlashMenu = false
    @State private var slashCommands: [SlashCommand] = []
    /// Suppress the slash menu re-evaluation immediately after a command is applied
    /// (the attributedText mutation from deleting "/" would otherwise re-trigger evaluation)
    @State private var suppressSlashDetection = false

    // Color palette state — shown automatically when text is selected
    @State private var showColorPalette = false
    /// The selected text's rect in global (window) coordinates — used to position
    /// the color palette right below the system "Copy / Paste" callout.
    @State private var selectionGlobalRect: CGRect = .zero
    /// Selected range saved the moment the palette appears — preserved because
    /// tapping a swatch dismisses the keyboard and clears UITextView.selectedRange.
    @State private var savedColorSelection: NSRange = NSRange(location: 0, length: 0)

    // Fixed toolbar — order matches familiar mobile editor conventions (Bold first).
    // MRU promotion removed: position never changes.
    @State private var toolbarItems: [EditorTool] = [
        .init(id: "bold",            icon: "bold"),
        .init(id: "italic",          icon: "italic"),
        .init(id: "underline",       icon: "underline"),
        .init(id: "strikethrough",   icon: "strikethrough"),
        .init(id: "text.alignleft",  icon: "text.alignleft"),
        .init(id: "text.aligncenter",icon: "text.aligncenter"),
        .init(id: "text.alignright", icon: "text.alignright"),
        .init(id: "list.bullet",     icon: "list.bullet"),
        .init(id: "tablecells",      icon: "tablecells"),
        .init(id: "paperclip",       icon: "paperclip"),
        .init(id: "pencil",          icon: "pencil.tip.crop.circle"),
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
                    context: richTextContext,
                    onEditorReady: { tv in
                        richTextView = tv
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 4)
                .onChange(of: attributedText) { _, newText in
                    guard !suppressSlashDetection else { return }
                    detectSlashCommand(in: newText)
                }
                .onChange(of: richTextContext.selectedRange) { _, range in
                    let hasSelection = range.length > 0
                    // Capture the selection's screen rect BEFORE animating so the
                    // palette can be positioned correctly from the first frame.
                    if hasSelection, let tv = richTextView {
                        let nsLen = (tv.text as NSString).length
                        let loc = min(range.location, max(0, nsLen))
                        let len = min(range.length, nsLen - loc)
                        if len > 0,
                           let start = tv.position(from: tv.beginningOfDocument, offset: loc),
                           let end   = tv.position(from: start, offset: len),
                           let tRange = tv.textRange(from: start, to: end) {
                            let r = tv.firstRect(for: tRange)
                            // firstRect returns CGRect.null / infinite on empty ranges
                            if !r.isNull, !r.isInfinite, r.width < 5000 {
                                selectionGlobalRect = tv.convert(r, to: nil)
                                log.debug("selectionGlobalRect updated: \(selectionGlobalRect.debugDescription)")
                            } else {
                                selectionGlobalRect = .zero
                            }
                        } else {
                            selectionGlobalRect = .zero
                        }
                    } else {
                        selectionGlobalRect = .zero
                    }
                    if hasSelection {
                        // Snapshot the range NOW, before the keyboard/focus changes
                        savedColorSelection = range
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showColorPalette = hasSelection
                    }
                }

                if isDrawingMode || task.drawingData != nil {
                    DrawingCanvasView(drawingData: $task.drawingData, isActive: $isDrawingMode)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(isDrawingMode)
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Color palette — floats below the system "Copy / Paste" callout,
            // anchored to the selected text rect (Issue #44).
            .overlay(alignment: .topLeading) {
                if showColorPalette && !isDrawingMode && !selectionGlobalRect.isEmpty {
                    GeometryReader { geo in
                        let gf = geo.frame(in: .global)
                        // Position the palette just below the selection rect.
                        // selectionGlobalRect is in window coords; subtract the ZStack's
                        // global origin to get local coordinates.
                        // +8 gap below selection + ~44pt system Cut/Copy/Paste bar height + 8pt padding
                        let localY = selectionGlobalRect.maxY - gf.minY + 60
                        if localY > 0 && localY < geo.size.height {
                            ColorPaletteView(
                                onApplyHighlight: { color in
                                    // Restore focus + selection before mutating
                                    richTextView?.becomeFirstResponder()
                                    richTextView?.selectedRange = savedColorSelection
                                    RichEditorCommands.applyHighlightColor(
                                        color,
                                        attributedText: &attributedText,
                                        selectedRange: savedColorSelection
                                    )
                                },
                                onApplyFontColor: { color in
                                    richTextView?.becomeFirstResponder()
                                    richTextView?.selectedRange = savedColorSelection
                                    RichEditorCommands.applyTextColor(
                                        color,
                                        attributedText: &attributedText,
                                        selectedRange: savedColorSelection
                                    )
                                },
                                onRemoveFontColor: {
                                    RichEditorCommands.applyTextColor(
                                        .label,
                                        attributedText: &attributedText,
                                        selectedRange: savedColorSelection
                                    )
                                },
                                onRemoveHighlight: {
                                    RichEditorCommands.applyHighlightColor(
                                        .clear,
                                        attributedText: &attributedText,
                                        selectedRange: savedColorSelection
                                    )
                                },
                                onDismiss: { showColorPalette = false }
                            )
                            .fixedSize()
                            // Center horizontally around the selection midpoint,
                            // clamped so it doesn't clip off screen edges.
                            .frame(maxWidth: geo.size.width, alignment: .center)
                            .offset(y: localY)
                        }
                    }
                    .transition(.opacity)
                }
            }

            // Slash command menu — anchored above toolbar, keyboard-aware (Issue #46)
            if showSlashMenu && !slashCommands.isEmpty {
                HStack(alignment: .bottom) {
                    SlashCommandMenuView(
                        commands: slashCommands,
                        onSelect: { cmd in applySlashCommand(cmd) },
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                showSlashMenu = false
                            }
                        }
                    )
                    .padding(.leading, 16)
                    .padding(.bottom, 4)
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeInOut(duration: 0.15), value: showSlashMenu)
            }

            // Table grid picker (Issue #43)
            if showTablePicker {
                TableGridPickerView(
                    onInsert: { rows, cols in
                        RichEditorCommands.insertTable(
                            rows: rows, cols: cols,
                            attributedText: &attributedText,
                            cursorLocation: savedTableCursorLocation
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
        .background(attachmentCoordinator.presentationHooks(attributedText: $attributedText))
        .onAppear { loadBody() }
        .onDisappear { saveBody() }
    }

    // MARK: - Toolbar (Issues #39–#43)

    private var editorToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(toolbarItems) { item in
                    if item.id == "paperclip" {
                        attachmentMenuButton
                    } else {
                        toolbarButton(item.icon) {
                            handleToolbarTap(item.id)
                        }
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

    /// Native iOS 26 Menu for attachments — pops up right above the paperclip icon.
    private var attachmentMenuButton: some View {
        Menu {
            Button { attachmentCoordinator.scanText() } label: {
                Label("Scan Text", systemImage: "text.viewfinder")
            }
            Button { attachmentCoordinator.scanDocuments() } label: {
                Label("Scan Documents", systemImage: "doc.viewfinder")
            }
            Button { attachmentCoordinator.takePhotoOrVideo() } label: {
                Label("Take Photo or Video", systemImage: "camera")
            }
            Button { attachmentCoordinator.choosePhotoOrVideo() } label: {
                Label("Choose Photo or Video", systemImage: "photo")
            }
            Button { attachmentCoordinator.recordAudio() } label: {
                Label("Record Audio", systemImage: "mic")
            }
            Button { attachmentCoordinator.attachFile() } label: {
                Label("Attach File", systemImage: "paperclip")
            }
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 18))
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    private func handleToolbarTap(_ id: String) {
        log.info("handleToolbarTap: '\(id)'")
        switch id {
        case "tablecells":
            log.debug("handleToolbarTap: toggling table picker")
            savedTableCursorLocation = richTextContext.selectedRange.location
            withAnimation(.spring(response: 0.3)) { showTablePicker.toggle() }
        case "pencil":
            log.debug("handleToolbarTap: entering drawing mode")
            // Resign text view first responder so PKCanvasView can take it and show PKToolPicker
            richTextView?.resignFirstResponder()
            saveBody()
            showTablePicker = false
            withAnimation(.spring(response: 0.35)) { isDrawingMode = true }
        case "list.bullet":
            log.debug("handleToolbarTap: toggling bullet list")
            refocusAndApply {
                RichEditorCommands.toggleBulletList(
                    attributedText: &attributedText,
                    selectedRange: richTextContext.selectedRange
                )
            }
        case "bold":
            log.debug("handleToolbarTap: toggling bold")
            refocusAndApply { RichEditorCommands.toggleBold(context: richTextContext) }
        case "italic":
            log.debug("handleToolbarTap: toggling italic")
            refocusAndApply { RichEditorCommands.toggleItalic(context: richTextContext) }
        case "underline":
            log.debug("handleToolbarTap: toggling underline")
            refocusAndApply { RichEditorCommands.toggleUnderline(context: richTextContext) }
        case "strikethrough":
            log.debug("handleToolbarTap: toggling strikethrough")
            refocusAndApply { RichEditorCommands.toggleStrikethrough(context: richTextContext) }
        case "text.alignleft":
            log.debug("handleToolbarTap: align left")
            refocusAndApply { RichEditorCommands.setAlignment(.left, context: richTextContext) }
        case "text.aligncenter":
            log.debug("handleToolbarTap: align center")
            refocusAndApply { RichEditorCommands.setAlignment(.center, context: richTextContext) }
        case "text.alignright":
            log.debug("handleToolbarTap: align right")
            refocusAndApply { RichEditorCommands.setAlignment(.right, context: richTextContext) }
        default:
            log.warning("handleToolbarTap: unrecognised toolbar id '\(id)'")
            break
        }
    }

    /// Restore focus + selection on the text view before applying a formatting command.
    /// Without this, tapping a toolbar button causes the text view to lose focus,
    /// resetting the selection to {0,0}, and the command applies to nothing.
    private func refocusAndApply(_ command: () -> Void) {
        let range = richTextContext.selectedRange
        richTextView?.becomeFirstResponder()
        if range.length > 0 {
            richTextView?.selectedRange = range
        }
        command()
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
        log.debug("detectSlashCommand: cursor=\(cursor), active=\(state.isActive), filter='\(state.filterText)', \(state.filteredCommands.count) result(s)")
        withAnimation(.easeInOut(duration: 0.15)) {
            showSlashMenu = state.isActive
            slashCommands = state.filteredCommands
        }
    }

    private func applySlashCommand(_ cmd: SlashCommand) {
        log.info("applySlashCommand: '\(cmd.id)' (\(cmd.label))")
        // Suppress slash detection while we mutate attributedText to remove the "/"
        suppressSlashDetection = true
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                suppressSlashDetection = false
            }
        }

        let cursor = richTextContext.selectedRange.location
        let state = SlashCommandEngine.evaluate(text: attributedText.string, cursorLocation: cursor)

        // Remove the '/' + filter text
        if state.slashLocation >= 0 {
            let deleteLen = cursor - state.slashLocation
            if deleteLen > 0 {
                let deleteRange = NSRange(location: state.slashLocation, length: deleteLen)
                log.debug("applySlashCommand: deleting \(deleteLen) char(s) at offset \(state.slashLocation)")
                guard let mutable = attributedText.mutableCopy() as? NSMutableAttributedString else {
                    log.error("applySlashCommand: failed to get mutable copy of attributedText")
                    return
                }
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
            log.debug("applySlashCommand: showing table grid picker")
            withAnimation(.spring(response: 0.3)) { showTablePicker = true }
        case "colorGray":   RichEditorCommands.applyTextColor(UIColor(hex: "#8e8e93"), context: richTextContext)
        case "colorOrange": RichEditorCommands.applyTextColor(UIColor(hex: "#ff6a00"), context: richTextContext)
        case "colorBlue":   RichEditorCommands.applyTextColor(UIColor(hex: "#0a84ff"), context: richTextContext)
        case "colorPurple": RichEditorCommands.applyTextColor(UIColor(hex: "#bf5af2"), context: richTextContext)
        case "colorPink":   RichEditorCommands.applyTextColor(UIColor(hex: "#ff375f"), context: richTextContext)
        case "colorBrown":  RichEditorCommands.applyTextColor(UIColor(hex: "#ac8e68"), context: richTextContext)
        default:
            log.warning("applySlashCommand: unhandled command id '\(cmd.id)'")
            break
        }

        log.debug("applySlashCommand: done, dismissing slash menu")
        withAnimation(.easeInOut(duration: 0.15)) { showSlashMenu = false }
    }

    // MARK: - Export (Issue #45 — native, no WKWebView)

    private func exportAsPDF() {
        log.info("exportAsPDF: exporting '\(task.title)'")
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            log.error("exportAsPDF: could not find root view controller")
            return
        }
        NativeExportService.exportAsPDF(title: task.title, content: attributedText, from: root)
    }

    private func exportAsWord() {
        log.info("exportAsWord: exporting '\(task.title)' as RTF")
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            log.error("exportAsWord: could not find root view controller")
            return
        }
        NativeExportService.exportAsRTF(title: task.title, content: attributedText, from: root)
    }

    private func shareTask() {
        log.info("shareTask: sharing '\(task.title)'")
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            log.error("shareTask: could not find root view controller")
            return
        }
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

    @State private var selectedRow = 2
    @State private var selectedCol = 3

    private let maxRows = 6
    private let maxCols = 6
    private let cellSize: CGFloat = 32
    private let cellGap: CGFloat  = 5

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Insert Table")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)

            // Interactive grid — drag finger to choose size
            let gridW = CGFloat(maxCols) * cellSize + CGFloat(maxCols - 1) * cellGap
            let gridH = CGFloat(maxRows) * cellSize + CGFloat(maxRows - 1) * cellGap

            ZStack(alignment: .topLeading) {
                VStack(spacing: cellGap) {
                    ForEach(1...maxRows, id: \.self) { row in
                        HStack(spacing: cellGap) {
                            ForEach(1...maxCols, id: \.self) { col in
                                let active = row <= selectedRow && col <= selectedCol
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(active
                                          ? Color.accentColor.opacity(0.85)
                                          : Color.primary.opacity(0.07))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(
                                                active ? Color.accentColor : Color.primary.opacity(0.18),
                                                lineWidth: 1
                                            )
                                    )
                                    .frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                }
                // Invisible overlay captures drag/tap across the whole grid
                Color.clear
                    .frame(width: gridW, height: gridH)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let col = min(maxCols, max(1, Int(value.location.x / (cellSize + cellGap)) + 1))
                                let row = min(maxRows, max(1, Int(value.location.y / (cellSize + cellGap)) + 1))
                                if row != selectedRow || col != selectedCol {
                                    selectedRow = row
                                    selectedCol = col
                                }
                            }
                            .onEnded { _ in
                                onInsert(selectedRow, selectedCol)
                            }
                    )
            }
            .frame(width: gridW, height: gridH)
            .padding(.bottom, 14)

            // Size label
            Text("\(selectedRow) × \(selectedCol)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)

            // Insert button — tap alternative to lifting the finger off the grid
            Button {
                onInsert(selectedRow, selectedCol)
            } label: {
                Text("Insert")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.14), radius: 24, y: 10)
        )
        .padding(.horizontal, 28)
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

    func scanText()             { log.info("AttachmentCoordinator: scanText"); presentDataScanner = true }
    func scanDocuments()        { log.info("AttachmentCoordinator: scanDocuments"); presentDocumentScanner = true }
    func takePhotoOrVideo()     { log.info("AttachmentCoordinator: takePhotoOrVideo"); presentPhotoPickerCamera = true }
    func choosePhotoOrVideo()   { log.info("AttachmentCoordinator: choosePhotoOrVideo"); presentPhotoPickerLibrary = true }
    func recordAudio()          { log.info("AttachmentCoordinator: recordAudio"); presentAudioRecorder = true }
    func attachFile()           { log.info("AttachmentCoordinator: attachFile"); presentDocumentPicker = true }
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
                    guard let mutable = attributedText.mutableCopy() as? NSMutableAttributedString else { return }
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
                    guard let mutable = attributedText.mutableCopy() as? NSMutableAttributedString else { return }
                    mutable.append(NSAttributedString(string: "\n[Audio: \(url.lastPathComponent)]"))
                    attributedText = mutable
                }
            }
            .sheet(isPresented: $coordinator.presentDataScanner) {
                DataScannerWrapperView { text in
                    guard let mutable = attributedText.mutableCopy() as? NSMutableAttributedString else { return }
                    mutable.append(NSAttributedString(string: "\n" + text))
                    attributedText = mutable
                }
            }
    }

    private func appendImage(_ data: Data) {
        log.info("appendImage: received \(data.count) bytes")
        guard let image = UIImage(data: data) else {
            log.error("appendImage: failed to decode UIImage from \(data.count) bytes")
            return
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        let maxWidth: CGFloat = 280
        if image.size.width > maxWidth {
            let scale = maxWidth / image.size.width
            attachment.bounds = CGRect(x: 0, y: 0, width: maxWidth, height: image.size.height * scale)
            log.debug("appendImage: scaled image from \(image.size.width)pt to \(maxWidth)pt")
        }
        guard let mutable = attributedText.mutableCopy() as? NSMutableAttributedString else {
            log.error("appendImage: failed to get mutable copy of attributedText")
            return
        }
        mutable.append(NSAttributedString(string: "\n"))
        mutable.append(NSAttributedString(attachment: attachment))
        attributedText = mutable
        log.info("appendImage: image appended successfully (\(Int(image.size.width))×\(Int(image.size.height)))")
    }
}

// MARK: - DataScannerWrapperView (VisionKit live text capture)

struct DataScannerWrapperView: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScan: onScan) }

    func makeUIViewController(context: Context) -> UIViewController {
        guard DataScannerViewController.isSupported && DataScannerViewController.isAvailable else {
            let vc = UIViewController()
            let label = UILabel()
            label.text = "Text scanning is not available on this device."
            label.textAlignment = .center
            label.numberOfLines = 0
            label.textColor = .secondaryLabel
            label.translatesAutoresizingMaskIntoConstraints = false
            vc.view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor, constant: 32),
                label.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -32)
            ])
            return vc
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
    @State private var showMicPermissionAlert = false

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
        .alert("Microphone Access Required", isPresented: $showMicPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to record audio.")
        }
    }

    private func startRecording() {
        switch AVAudioApplication.shared.recordPermission {
        case .denied:
            showMicPermissionAlert = true
            return
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                if granted {
                    DispatchQueue.main.async { self.beginRecording() }
                } else {
                    DispatchQueue.main.async { self.showMicPermissionAlert = true }
                }
            }
            return
        case .granted:
            beginRecording()
        @unknown default:
            beginRecording()
        }
    }

    private func beginRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(Date().timeIntervalSince1970).m4a")
        log.info("AudioRecorder: beginning recording to \(url.lastPathComponent)")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.record()
            audioURL = url
            isRecording = true
            log.info("AudioRecorder: recording started")
        } catch {
            log.error("AudioRecorder: failed to start recording — \(error.localizedDescription)")
        }
    }

    private func stopRecording() {
        log.info("AudioRecorder: stopping recording, file=\(audioURL?.lastPathComponent ?? "nil")")
        recorder?.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            log.error("AudioRecorder: failed to deactivate audio session — \(error.localizedDescription)")
        }
        isRecording = false
        log.info("AudioRecorder: recording stopped")
    }
}
#endif
