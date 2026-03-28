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

    // Slash command coordinator — replaces 3 @State vars + double evaluate() (Issue #48)
    @StateObject private var slashCoordinator = SlashCommandCoordinator()

    // Color palette state — shown automatically when text is selected
    /// Persisted across palette appearances so the last-used mode (text color / highlight) is remembered.
    @State private var paletteMode: ColorPaletteView.ColorMode = .fontColor
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
        .init(id: "paperclip",       icon: "paperclip"),      // ← 5th position
        .init(id: "pencil",          icon: "pencil.tip.crop.circle"), // ← 6th position
        .init(id: "text.alignleft",  icon: "text.alignleft"),
        .init(id: "text.aligncenter",icon: "text.aligncenter"),
        .init(id: "text.alignright", icon: "text.alignright"),
        .init(id: "list.bullet",     icon: "list.bullet"),
        .init(id: "tablecells",      icon: "tablecells"),
    ]

    struct EditorTool: Identifiable { let id: String; let icon: String }

    // Attachment service — single enum replaces 6 Bool flags (Issue #49)
    @State private var attachmentService = AttachmentService()
    @State private var showAttachmentSheet = false

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
                    // Use coordinator — handles suppression internally (Issue #48)
                    slashCoordinator.textDidChange(
                        text: newText,
                        cursorLocation: richTextContext.selectedRange.location
                    )
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
                                mode: $paletteMode,
                                onApplyHighlight: { color in
                                    applyColorAttribute(key: .backgroundColor,
                                                        value: color,
                                                        range: savedColorSelection)
                                },
                                onApplyFontColor: { color in
                                    applyColorAttribute(key: .foregroundColor,
                                                        value: color,
                                                        range: savedColorSelection)
                                },
                                onRemoveFontColor: {
                                    applyColorAttribute(key: .foregroundColor,
                                                        value: nil,
                                                        range: savedColorSelection)
                                },
                                onRemoveHighlight: {
                                    applyColorAttribute(key: .backgroundColor,
                                                        value: nil,
                                                        range: savedColorSelection)
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

            if showToolbar && !isDrawingMode {
                ZStack(alignment: .bottom) {
                    editorToolbar

                    // Slash command menu — floats above toolbar (Issue #46 / #48)
                    if slashCoordinator.isMenuVisible && !slashCoordinator.filteredCommands.isEmpty {
                        HStack(alignment: .bottom) {
                            SlashCommandMenuView(
                                commands: slashCoordinator.filteredCommands,
                                onSelect: { cmd in applySlashCommand(cmd) },
                                onDismiss: { slashCoordinator.dismiss() }
                            )
                            .padding(.leading, 16)
                            Spacer()
                        }
                        .offset(y: -60)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .animation(.easeInOut(duration: 0.15), value: slashCoordinator.isMenuVisible)
                    }

                    // Table grid picker — floats above toolbar (Issue #43)
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
                        .offset(y: -60)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(10)
                    }
                }
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
                        // Re-focus the text editor so the keyboard area is tappable again.
                        // Delay must be longer than the animation to avoid stealing first
                        // responder from PKCanvasView if user re-enters drawing quickly.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            if !isDrawingMode {
                                richTextView?.becomeFirstResponder()
                            }
                        }
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
        // AttachmentService drives all picker sheets via a single enum (Issue #49)
        .background(attachmentService.presentationHooks(attributedText: $attributedText))
        .overlay {
            if showAttachmentSheet {
                // Dimming background — tap to dismiss
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.2)) { showAttachmentSheet = false } }

                // Inline glass menu — no separate window/sheet
                VStack(spacing: 0) {
                    ForEach(Array(attachmentMenuItems.enumerated()), id: \.element.id) { index, item in
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) { showAttachmentSheet = false }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                triggerAttachment(item.id)
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(Color.primary)
                                    .frame(width: 28)
                                Text(item.label)
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)

                        if index < attachmentMenuItems.count - 1 {
                            Divider().padding(.leading, 62)
                        }
                    }
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                .padding(.horizontal, 24)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showAttachmentSheet)
        .onAppear { loadBody() }
        .onDisappear { saveBody() }
    }

    // MARK: - Toolbar (Issues #39–#43)

    private var editorToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
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
            .padding(.horizontal, 6)
        }
        .frame(height: 52)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// Attachment button — same plain style as every other toolbar button.
    private var attachmentMenuButton: some View {
        toolbarButton("paperclip") {
            showAttachmentSheet = true
        }
    }

    private func handleToolbarTap(_ id: String) {
        log.info("handleToolbarTap: '\(id)'")

        // Special-case non-dispatcher actions first
        switch id {
        case "tablecells":
            log.debug("handleToolbarTap: toggling table picker")
            savedTableCursorLocation = richTextContext.selectedRange.location
            withAnimation(.spring(response: 0.3)) { showTablePicker.toggle() }
            return
        case "pencil":
            log.debug("handleToolbarTap: entering drawing mode")
            richTextView?.resignFirstResponder()
            saveBody()
            showTablePicker = false
            // No animation — canvas must be in the window immediately
            // so PKToolPicker can attach via becomeFirstResponder
            isDrawingMode = true
            return
        default:
            break
        }

        // Dispatcher path — all standard formatting commands (Issue #50)
        guard let command = ToolbarCommand(rawValue: id),
              let tv = richTextView else {
            log.warning("handleToolbarTap: unrecognised toolbar id '\(id)'")
            return
        }
        var ctx = EditorContext(textView: tv, richTextContext: richTextContext)
        if let updated = RichEditorCommandDispatcher.dispatch(command, context: &ctx, attributedText: &attributedText) {
            attributedText = updated
        }
    }

    /// Apply or remove a colour attribute directly on the UITextView, then sync the binding.
    /// Reads from UITextView — NOT from the `attributedText` binding — to avoid the
    /// stale-copy overwrite bug: RichTextKit buffers text internally, so `attributedText`
    /// can lag behind the live UITextView. Writing to both the view and the binding keeps
    /// everything in sync.
    private func applyColorAttribute(key: NSAttributedString.Key,
                                     value: Any?,
                                     range: NSRange) {
        guard range.length > 0,
              let tv = richTextView,
              let current = tv.attributedText else {
            log.debug("applyColorAttribute: skipped — empty range or missing textView")
            return
        }
        tv.becomeFirstResponder()
        let mutable = current.mutableCopy() as! NSMutableAttributedString
        let loc  = min(range.location, mutable.length)
        let len  = min(range.length,   mutable.length - loc)
        guard len > 0 else { return }
        let safe    = NSRange(location: loc, length: len)
        let nsStr   = mutable.string as NSString
        var applied = 0
        // Apply attribute character-by-character.
        // For font color: skip all whitespace (invisible on spaces anyway).
        // For highlight: only skip newlines/line-endings — spaces between words must
        // be included or the highlight appears broken with gaps.
        for i in safe.location ..< (safe.location + safe.length) {
            guard i < mutable.length else { break }
            let charRange = NSRange(location: i, length: 1)
            let scalar    = nsStr.character(at: i)
            if key == .foregroundColor {
                // Font color — skip all whitespace
                if scalar == 0x20 || scalar == 0x09 || scalar == 0x0A ||
                   scalar == 0x0D || scalar == 0xA0 { continue }
            } else {
                // Highlight (backgroundColor) — only skip line endings to avoid
                // coloured blocks on blank lines; spaces between words are included.
                if scalar == 0x0A || scalar == 0x0D { continue }
            }
            if let v = value {
                mutable.addAttribute(key, value: v, range: charRange)
            } else {
                mutable.removeAttribute(key, range: charRange)
            }
            applied += 1
        }
        tv.attributedText = mutable
        tv.selectedRange  = range       // restore selection (setting attributedText resets it)
        attributedText    = mutable     // keep the SwiftUI binding in sync
        log.debug("applyColorAttribute: \(key.rawValue) — \(applied) chars coloured (whitespace skipped)")
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

    // MARK: - Slash Command Application (Issue #46 / #48)

    private func applySlashCommand(_ cmd: SlashCommand) {
        log.info("applySlashCommand: '\(cmd.id)' (\(cmd.label))")

        let cursor = richTextContext.selectedRange.location

        // Coordinator removes '/' + filter text using frozen state (no double-evaluate)
        slashCoordinator.commandSelected(cmd, applyTo: &attributedText, cursorLocation: cursor)

        // newCursor is now where the slash was (coordinator deleted those chars)
        // We use the post-deletion cursor from the updated attributedText length as a safe fallback
        let newCursor = max(0, min(cursor, attributedText.length))
        let selRange = NSRange(location: newCursor, length: 0)

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
        case _ where cmd.id.hasPrefix("color"):
            // Dynamic lookup — no hardcoded hex strings (Issue #51)
            if let nc = NamedColor.find(id: cmd.id) {
                RichEditorCommands.applyTextColor(nc.uiColor, context: richTextContext)
            } else {
                log.warning("applySlashCommand: unknown color command '\(cmd.id)'")
            }
        default:
            log.warning("applySlashCommand: unhandled command id '\(cmd.id)'")
            break
        }

        log.debug("applySlashCommand: done — coordinator handled slash menu dismissal")
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

    // MARK: - Inline Attachment Menu

    private struct AttachmentMenuItem: Identifiable {
        let id: String
        let icon: String
        let label: String
    }

    private var attachmentMenuItems: [AttachmentMenuItem] {
        [
            .init(id: "scanText",      icon: "text.viewfinder", label: "Scan Text"),
            .init(id: "scanDocuments", icon: "doc.viewfinder",  label: "Scan Documents"),
            .init(id: "takePhoto",     icon: "camera",           label: "Take Photo or Video"),
            .init(id: "choosePhoto",   icon: "photo",            label: "Choose Photo or Video"),
            .init(id: "recordAudio",   icon: "mic",              label: "Record Audio"),
            .init(id: "attachFile",    icon: "paperclip",        label: "Attach File"),
        ]
    }

    private func triggerAttachment(_ id: String) {
        switch id {
        case "scanText":      attachmentService.scanText()
        case "scanDocuments": attachmentService.scanDocuments()
        case "takePhoto":     attachmentService.takePhotoOrVideo()
        case "choosePhoto":   attachmentService.choosePhotoOrVideo()
        case "recordAudio":   attachmentService.recordAudio()
        case "attachFile":    attachmentService.attachFile()
        default: break
        }
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

    // MARK: - Save / Load — NoteBodyBinding (Issue #53)

    @State private var loadError: NoteBodyError? = nil
    @State private var saveError: NoteBodyError? = nil

    private func loadBody() {
        NoteBodyBinding.load(from: task, into: &attributedText,
                             onLoadError: { loadError = $0 })
    }

    private func saveBody() {
        NoteBodyBinding.save(attributedText, into: task,
                             onSaveError: { saveError = $0 })
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .padding(.horizontal, 28)
    }
}

// GlassAttachmentMenuSheet removed — replaced by inline overlay in TaskDetailView

// AttachmentCoordinator and AttachmentPresenters removed — replaced by AttachmentService (Issue #49)

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
