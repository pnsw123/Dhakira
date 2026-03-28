import SwiftUI
import SwiftData
import RichTextKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "TaskDetail")

#if canImport(UIKit)
import UIKit
import PencilKit
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
    /// References to PencilKit objects — obtained via onCanvasReady, managed here.
    @State private var pkCanvasView: PKCanvasView?
    @State private var pkToolPicker: PKToolPicker?
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

    /// Cursor rect in global (window) coordinates when "/" was typed — used to
    /// anchor the slash menu right below the cursor instead of at the bottom.
    @State private var slashCursorGlobalRect: CGRect = .zero

    // Default toolbar order — user can drag-reorder, saved to UserDefaults.
    static let defaultToolbarItems: [EditorTool] = [
        .init(id: "bold",            icon: "bold"),
        .init(id: "italic",          icon: "italic"),
        .init(id: "underline",       icon: "underline"),
        .init(id: "strikethrough",   icon: "strikethrough"),
        .init(id: "fontSizeDown",    icon: "textformat.size.smaller"),
        .init(id: "fontSizeUp",      icon: "textformat.size.larger"),
        .init(id: "paperclip",       icon: "paperclip"),
        .init(id: "pencil",          icon: "pencil.tip.crop.circle"),
        .init(id: "text.alignleft",  icon: "text.alignleft"),
        .init(id: "text.aligncenter",icon: "text.aligncenter"),
        .init(id: "text.alignright", icon: "text.alignright"),
        .init(id: "list.bullet",     icon: "list.bullet"),
        .init(id: "tablecells",      icon: "tablecells"),
    ]
    @State private var toolbarItems: [EditorTool] = TaskDetailView.defaultToolbarItems
    @AppStorage("editorToolbarOrder") private var savedToolbarOrder: String = ""
    @State private var draggingToolId: String?

    struct EditorTool: Identifiable, Codable, Equatable {
        let id: String
        let icon: String
    }

    // Attachment service — single enum replaces 6 Bool flags (Issue #49)
    @State private var attachmentService = AttachmentService()

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
                // UIKit notification — fires on every keystroke, stable since iOS 2.
                // Replaces unreliable SwiftUI onChange triggers for slash detection.
                .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification)) { note in
                    guard let tv = note.object as? UITextView,
                          tv === richTextView else { return }
                    evaluateSlashCommand()
                }
                .onChange(of: richTextContext.selectedRange) { _, range in
                    let hasSelection = range.length > 0
                    if hasSelection, let tv = richTextView {
                        let nsLen = (tv.text as NSString).length
                        let loc = min(range.location, max(0, nsLen))
                        let len = min(range.length, nsLen - loc)
                        if len > 0,
                           let start = tv.position(from: tv.beginningOfDocument, offset: loc),
                           let end   = tv.position(from: start, offset: len),
                           let tRange = tv.textRange(from: start, to: end) {
                            let r = tv.firstRect(for: tRange)
                            if !r.isNull, !r.isInfinite, r.width < 5000 {
                                selectionGlobalRect = tv.convert(r, to: nil)
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
                        savedColorSelection = range
                    }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showColorPalette = hasSelection
                    }
                }

                // Always in the hierarchy so the Coordinator (and PKToolPicker)
                // are never destroyed. Hidden with opacity when not needed.
                DrawingCanvasView(
                    drawingData: $task.drawingData,
                    isActive: $isDrawingMode,
                    onCanvasReady: { canvas, picker in
                        pkCanvasView = canvas
                        pkToolPicker = picker
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(isDrawingMode || task.drawingData != nil ? 1 : 0)
                .allowsHitTesting(isDrawingMode)

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
                                    // Use UIColor.label (adaptive: black in light, white in dark)
                                    // instead of nil, which would remove the attribute and fall
                                    // back to a static black regardless of color scheme.
                                    applyColorAttribute(key: .foregroundColor,
                                                        value: UIColor.label,
                                                        range: savedColorSelection)
                                },
                                onRemoveHighlight: {
                                    applyColorAttribute(key: .backgroundColor,
                                                        value: nil,
                                                        range: savedColorSelection)
                                },
                                onDismiss: { showColorPalette = false },
                                initialFontColorName: detectedFontColorName(),
                                initialHighlightName: detectedHighlightName()
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
            // Slash command menu — uses the same global-rect approach as the color palette
            // so it always appears directly below the caret regardless of scroll or insets.
            .overlay(alignment: .topLeading) {
                if slashCoordinator.isMenuVisible && !slashCoordinator.filteredCommands.isEmpty {
                    GeometryReader { geo in
                        let gf = geo.frame(in: .global)
                        let localY: CGFloat = slashCursorGlobalRect == .zero
                            ? 40
                            : slashCursorGlobalRect.maxY - gf.minY + 4
                        let localX: CGFloat = slashCursorGlobalRect == .zero
                            ? 16
                            : max(0, min(slashCursorGlobalRect.minX - gf.minX, geo.size.width - 264))
                        if localY > 0 && localY < geo.size.height {
                            SlashCommandMenuView(
                                commands: slashCoordinator.filteredCommands,
                                onSelect: { cmd in applySlashCommand(cmd) },
                                onDismiss: { slashCoordinator.dismiss() }
                            )
                            .offset(x: localX, y: localY)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.15), value: slashCoordinator.isMenuVisible)
                        }
                    }
                }
            }

            if showToolbar && !isDrawingMode {
                ZStack(alignment: .bottom) {
                    editorToolbar

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
        .onAppear { loadToolbarOrder(); loadBody() }
        .onDisappear { saveBody() }
    }

    // MARK: - Toolbar (Issues #39–#43)

    private var editorToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(toolbarItems) { item in
                    toolbarItemView(for: item)
                        .opacity(draggingToolId == item.id ? 0.35 : 1)
                        .onDrag {
                            draggingToolId = item.id
                            return NSItemProvider(object: item.id as NSString)
                        }
                        .onDrop(of: [UTType.text], delegate: ToolbarReorderDelegate(
                            targetId: item.id,
                            items: $toolbarItems,
                            draggingId: $draggingToolId,
                            onComplete: saveToolbarOrder
                        ))
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

    @ViewBuilder
    private func toolbarItemView(for item: EditorTool) -> some View {
        switch item.id {
        case "paperclip":
            attachmentMenuButton
        default:
            toolbarButton(item.icon) {
                handleToolbarTap(item.id)
            }
        }
    }

    /// Attachment menu — native iOS 26 context menu.
    private var attachmentMenuButton: some View {
        Menu {
            ForEach(attachmentMenuItems) { item in
                Button {
                    triggerAttachment(item.id)
                } label: {
                    Label(item.label, systemImage: item.icon)
                }
            }
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: 18))
                .foregroundStyle(Color.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .menuStyle(.button)
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
            isDrawingMode = true
            // Show PKToolPicker explicitly — UIKit needs a moment after
            // the SwiftUI state change for the canvas to be interactable.
            showDrawingToolPicker()
            return
        case "fontSizeUp", "fontSizeDown":
            guard let tv = richTextView else { return }
            tv.becomeFirstResponder()
            let range = tv.selectedRange
            RichEditorCommands.stepFontSize(
                increase: id == "fontSizeUp",
                attributedText: &attributedText,
                selectedRange: range
            )
            tv.attributedText = attributedText
            tv.selectedRange = range
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
        let savedRange = tv.selectedRange
        var ctx = EditorContext(textView: tv, richTextContext: richTextContext)
        if let updated = RichEditorCommandDispatcher.dispatch(command, context: &ctx, attributedText: &attributedText) {
            // Push structural changes (font size, lists, tables) into the live UITextView
            // so the user sees the result immediately — the binding alone isn't enough.
            tv.attributedText = updated
            tv.selectedRange = savedRange
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

    /// Read the foreground color at the start of the saved selection and match it
    /// against our palette so the swatch appears pre-selected.
    private func detectedFontColorName() -> String? {
        guard savedColorSelection.length > 0, savedColorSelection.location < attributedText.length else { return nil }
        if let color = attributedText.attribute(.foregroundColor, at: savedColorSelection.location, effectiveRange: nil) as? UIColor {
            return NamedColor.matchLabel(for: color)
        }
        return nil
    }

    /// Same for background/highlight color.
    private func detectedHighlightName() -> String? {
        guard savedColorSelection.length > 0, savedColorSelection.location < attributedText.length else { return nil }
        if let color = attributedText.attribute(.backgroundColor, at: savedColorSelection.location, effectiveRange: nil) as? UIColor {
            return NamedColor.matchLabel(for: color)
        }
        return nil
    }

    /// Central slash-command evaluation — reads cursor from the UITextView
    /// directly (richTextContext.selectedRange may lag) and captures the
    /// cursor rect for the overlay position.
    private func evaluateSlashCommand() {
        guard let tv = richTextView else {
            log.warning("⚠️ SLASH: richTextView is nil — cannot evaluate")
            return
        }
        let cursorLoc = tv.selectedRange.location
        let text: NSAttributedString = tv.attributedText ?? attributedText
        let textStr = text.string
        log.debug("⚠️ SLASH: cursor=\(cursorLoc), textLen=\(textStr.count), last3chars='\(String(textStr.suffix(3)))'")

        slashCoordinator.textDidChange(text: text, cursorLocation: cursorLoc)

        log.debug("⚠️ SLASH: isMenuVisible=\(slashCoordinator.isMenuVisible), commands=\(slashCoordinator.filteredCommands.count)")

        if slashCoordinator.isMenuVisible {
            let safeLoc = min(cursorLoc, max(0, (tv.text as NSString).length))
            if let pos = tv.position(from: tv.beginningOfDocument, offset: safeLoc),
               let tRange = tv.textRange(from: pos, to: pos) {
                let r = tv.firstRect(for: tRange)
                let converted = tv.convert(r, to: nil)
                log.debug("⚠️ SLASH: cursorRect=\(converted.debugDescription), isNull=\(r.isNull), isInf=\(r.isInfinite), height=\(converted.height)")
                if !r.isNull, !r.isInfinite {
                    slashCursorGlobalRect = converted
                }
            } else {
                log.warning("⚠️ SLASH: could not create text position for cursor \(safeLoc)")
            }
        } else {
            slashCursorGlobalRect = .zero
        }
    }

    /// Calculate Y offset for the slash menu relative to the editor ZStack.
    /// Uses the UITextView's caret rect converted to the text view's own coordinate space.
    /// Show PKToolPicker — retries until the canvas successfully becomes first responder.
    /// Called from handleToolbarTap("pencil") AFTER isDrawingMode = true.
    private func showDrawingToolPicker(attempt: Int = 0) {
        guard let canvas = pkCanvasView, let picker = pkToolPicker else {
            // Canvas not ready yet — retry after SwiftUI has time to create it
            if attempt < 5 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showDrawingToolPicker(attempt: attempt + 1)
                }
            }
            return
        }
        picker.addObserver(canvas)
        picker.setVisible(true, forFirstResponder: canvas)
        let became = canvas.becomeFirstResponder()
        log.debug("showDrawingToolPicker: attempt=\(attempt), becameFirstResponder=\(became), window=\(canvas.window != nil)")
        if !became && attempt < 5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                showDrawingToolPicker(attempt: attempt + 1)
            }
        }
    }

    private func slashMenuYOffset() -> CGFloat {
        guard let tv = richTextView else { return 0 }
        let loc = tv.selectedRange.location
        let safeLoc = min(loc, max(0, (tv.text as NSString).length))
        guard let pos = tv.position(from: tv.beginningOfDocument, offset: safeLoc),
              let range = tv.textRange(from: pos, to: pos) else { return 0 }
        let r = tv.firstRect(for: range)
        guard !r.isNull, !r.isInfinite else { return 0 }
        // r is in tv's coordinate space — maxY is the bottom of the caret line
        // +8pt gap so the menu sits below the "/" text, not on top of it
        return r.maxY + 8
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

    // MARK: - Toolbar Order Persistence

    private func loadToolbarOrder() {
        guard !savedToolbarOrder.isEmpty,
              let ids = try? JSONDecoder().decode([String].self, from: Data(savedToolbarOrder.utf8))
        else { return }
        let lookup = Dictionary(uniqueKeysWithValues: Self.defaultToolbarItems.map { ($0.id, $0) })
        var reordered: [EditorTool] = []
        for id in ids {
            if let tool = lookup[id] { reordered.append(tool) }
        }
        // Append any new tools added after the user last saved
        for tool in Self.defaultToolbarItems where !ids.contains(tool.id) {
            reordered.append(tool)
        }
        toolbarItems = reordered
    }

    private func saveToolbarOrder() {
        let ids = toolbarItems.map(\.id)
        if let data = try? JSONEncoder().encode(ids) {
            savedToolbarOrder = String(data: data, encoding: .utf8) ?? ""
        }
    }

    /// Drop delegate for drag-to-reorder toolbar icons.
    struct ToolbarReorderDelegate: DropDelegate {
        let targetId: String
        @Binding var items: [EditorTool]
        @Binding var draggingId: String?
        let onComplete: () -> Void

        func performDrop(info: DropInfo) -> Bool {
            draggingId = nil
            onComplete()
            return true
        }

        func dropEntered(info: DropInfo) {
            guard let draggingId,
                  draggingId != targetId,
                  let from = items.firstIndex(where: { $0.id == draggingId }),
                  let to = items.firstIndex(where: { $0.id == targetId })
            else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                items.move(fromOffsets: IndexSet(integer: from),
                           toOffset: to > from ? to + 1 : to)
            }
        }

        func dropUpdated(info: DropInfo) -> DropProposal? {
            DropProposal(operation: .move)
        }
    }

    // MARK: - Slash Command Application (Issue #46 / #48)

    private func applySlashCommand(_ cmd: SlashCommand) {
        log.info("applySlashCommand: '\(cmd.id)' (\(cmd.label))")

        // Read slash location BEFORE commandSelected clears frozenState.
        // richTextContext.selectedRange resets to 0 when the menu steals focus,
        // so we rely on the coordinator's frozen slash position instead.
        let slashLoc = slashCoordinator.currentSlashLocation

        // Coordinator removes '/' + filter text using frozen cursor (no focus dependency)
        slashCoordinator.commandSelected(cmd, applyTo: &attributedText, cursorLocation: 0)

        // After deletion, insertion point is where the '/' was
        let newCursor = max(0, slashLoc >= 0 ? slashLoc : 0)
        let selRange = NSRange(location: newCursor, length: 0)

        // Apply the selected command to the attributedText binding
        var isColorCommand = false
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
            savedTableCursorLocation = newCursor
        case _ where cmd.id.hasPrefix("color"):
            isColorCommand = true
        default:
            log.warning("applySlashCommand: unhandled command id '\(cmd.id)'")
        }

        // Push every change (including slash deletion) directly into the live UITextView.
        // RichTextKit's SwiftUI binding does NOT propagate back synchronously — same fix
        // used by handleToolbarTap (tv.attributedText = updated).
        if let tv = richTextView {
            tv.attributedText = attributedText
            tv.becomeFirstResponder()
            tv.selectedRange = NSRange(location: newCursor, length: 0)
        }

        // Table picker: open after TV is updated so picker appears over clean text
        if cmd.id == "table" {
            withAnimation(.spring(response: 0.3)) { showTablePicker = true }
        }

        // Color: set typing attribute AFTER focus is restored so it sticks
        if isColorCommand {
            if let nc = NamedColor.find(id: cmd.id) {
                RichEditorCommands.applyTextColor(nc.uiColor, context: richTextContext)
            } else {
                log.warning("applySlashCommand: unknown color command '\(cmd.id)'")
            }
        }

        log.debug("applySlashCommand: done — pushed to UITextView, cursor at \(newCursor)")
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

// MARK: - PhotoPickerView (Photos + Videos, multi-select — matches Apple Notes)

struct PhotoPickerView: UIViewControllerRepresentable {
    let onPick: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 0 // 0 = unlimited, like Apple Notes
        config.preferredAssetRepresentationMode = .current
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
            for result in results {
                let provider = result.itemProvider
                // Try image first
                if provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { object, _ in
                        if let image = object as? UIImage,
                           let data = image.jpegData(compressionQuality: 0.85) {
                            DispatchQueue.main.async { self.onPick(data) }
                        }
                    }
                } else if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    // Video — load file representation and read data
                    provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                        guard let url else { return }
                        // Copy to temp so it survives provider cleanup
                        let tmp = FileManager.default.temporaryDirectory
                            .appendingPathComponent(url.lastPathComponent)
                        try? FileManager.default.removeItem(at: tmp)
                        try? FileManager.default.copyItem(at: url, to: tmp)
                        // Generate thumbnail for inline display
                        Task { @MainActor in
                            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: tmp))
                            generator.appliesPreferredTrackTransform = true
                            if let cgImage = try? await generator.image(at: .zero).image {
                                let thumb = UIImage(cgImage: cgImage)
                                if let data = thumb.jpegData(compressionQuality: 0.85) {
                                    self.onPick(data)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - CameraPickerView (Photo + Video — matches Apple Notes)

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            // Allow both photo and video — same as Apple Notes
            picker.mediaTypes = [UTType.image.identifier, UTType.movie.identifier]
            picker.videoQuality = .typeHigh
            picker.cameraCaptureMode = .photo
        } else {
            picker.sourceType = .photoLibrary
        }
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

            // Photo path
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.85) {
                DispatchQueue.main.async { self.onCapture(data) }
                return
            }

            // Video path — generate thumbnail for inline display
            if let videoURL = info[.mediaURL] as? URL {
                Task { @MainActor in
                    let generator = AVAssetImageGenerator(asset: AVURLAsset(url: videoURL))
                    generator.appliesPreferredTrackTransform = true
                    if let cgImage = try? await generator.image(at: .zero).image {
                        let thumb = UIImage(cgImage: cgImage)
                        if let data = thumb.jpegData(compressionQuality: 0.85) {
                            self.onCapture(data)
                        }
                    }
                }
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

// MARK: - AudioRecorderView (Apple Notes-style with waveform + timer + playback)

struct AudioRecorderView: View {
    let onSave: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    // Recording state
    @State private var recorder: AVAudioRecorder?
    @State private var audioURL: URL?
    @State private var isRecording = false
    @State private var isPaused = false
    @State private var showMicPermissionAlert = false

    // Playback state
    @State private var player: AVAudioPlayer?
    @State private var isPlaying = false

    // Timer
    @State private var elapsedSeconds: TimeInterval = 0
    @State private var timer: Timer?

    // Waveform — live amplitude samples
    @State private var waveformSamples: [CGFloat] = []
    @State private var meteringTimer: Timer?

    // State machine: idle → recording → stopped (ready to play/save)
    private enum RecorderState { case idle, recording, paused, stopped }
    private var state: RecorderState {
        if isRecording && !isPaused { return .recording }
        if isRecording && isPaused { return .paused }
        if audioURL != nil && !isRecording { return .stopped }
        return .idle
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 20)

            // Timer display
            Text(formattedTime(elapsedSeconds))
                .font(.system(size: 54, weight: .light, design: .monospaced))
                .foregroundStyle(isRecording ? Color.red : Color.primary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.1), value: elapsedSeconds)
                .padding(.bottom, 20)

            // Waveform visualization
            waveformView
                .frame(height: 60)
                .padding(.horizontal, 24)
                .padding(.bottom, 28)

            // Controls
            controlsBar
                .padding(.horizontal, 32)
                .padding(.bottom, 20)
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.regularMaterial)
        .alert("Microphone Access Required", isPresented: $showMicPermissionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to record audio.")
        }
        .onDisappear { cleanup() }
    }

    // MARK: - Waveform

    private var waveformView: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(Array(displaySamples(width: geo.size.width).enumerated()), id: \.offset) { _, amplitude in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(isRecording ? Color.red : Color.primary.opacity(0.35))
                        .frame(width: 3, height: max(4, amplitude * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func displaySamples(width: CGFloat) -> [CGFloat] {
        let barCount = max(1, Int(width / 5.5))
        if waveformSamples.isEmpty {
            return Array(repeating: 0.05, count: barCount)
        }
        if waveformSamples.count <= barCount {
            let padding = Array(repeating: CGFloat(0.05), count: barCount - waveformSamples.count)
            return padding + waveformSamples
        }
        return Array(waveformSamples.suffix(barCount))
    }

    // MARK: - Controls bar

    private var controlsBar: some View {
        HStack {
            // Cancel / Delete
            Button {
                cleanup()
                dismiss()
            } label: {
                Text(state == .stopped ? "Delete" : "Cancel")
                    .font(.system(size: 17))
                    .foregroundStyle(state == .stopped ? Color.red : Color.primary)
            }

            Spacer()

            // Center button — Record / Pause / Play
            centerButton

            Spacer()

            // Save button (only after recording stops)
            if state == .stopped {
                Button {
                    if let url = audioURL { onSave(url) }
                    dismiss()
                } label: {
                    Text("Save")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            } else {
                // Invisible spacer for alignment
                Text("Save")
                    .font(.system(size: 17, weight: .semibold))
                    .hidden()
            }
        }
    }

    @ViewBuilder
    private var centerButton: some View {
        switch state {
        case .idle:
            // Big red record button
            Button { requestAndRecord() } label: {
                Circle()
                    .fill(Color.red)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
        case .recording:
            // Stop button (red square inside circle) — matches Apple Notes
            Button { stopRecording() } label: {
                Circle()
                    .fill(Color.red)
                    .frame(width: 64, height: 64)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.white)
                            .frame(width: 22, height: 22)
                    }
            }
        case .paused:
            // Resume recording
            Button { resumeRecording() } label: {
                Circle()
                    .fill(Color.red)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
            }
        case .stopped:
            // Play/pause playback
            Button { togglePlayback() } label: {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(x: isPlaying ? 0 : 2) // Optical center for play icon
                    }
            }
        }
    }

    // MARK: - Time formatting

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        let frac = Int((seconds.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%d:%02d.%02d", mins, secs, frac)
    }

    // MARK: - Recording logic

    private func requestAndRecord() {
        switch AVAudioApplication.shared.recordPermission {
        case .denied:
            showMicPermissionAlert = true
        case .undetermined:
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted { beginRecording() }
                    else { showMicPermissionAlert = true }
                }
            }
        case .granted:
            beginRecording()
        @unknown default:
            beginRecording()
        }
    }

    private func beginRecording() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording-\(Date().timeIntervalSince1970).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            rec.record()
            recorder = rec
            audioURL = url
            isRecording = true
            isPaused = false
            elapsedSeconds = 0
            waveformSamples = []
            startTimers()
        } catch {
            log.error("AudioRecorder: failed to start — \(error.localizedDescription)")
        }
    }

    private func resumeRecording() {
        recorder?.record()
        isPaused = false
        startTimers()
    }

    private func stopRecording() {
        recorder?.stop()
        stopTimers()
        isRecording = false
        isPaused = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            log.error("AudioRecorder: deactivate failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Playback

    private func togglePlayback() {
        if isPlaying {
            player?.pause()
            isPlaying = false
            stopTimers()
            return
        }
        guard let url = audioURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.isMeteringEnabled = true
            p.play()
            player = p
            isPlaying = true
            elapsedSeconds = 0
            // Playback timer
            timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard let p = player else { return }
                if p.isPlaying {
                    elapsedSeconds = p.currentTime
                    p.updateMeters()
                    let power = p.averagePower(forChannel: 0)
                    let normalized = CGFloat(max(0, (power + 50) / 50)) // -50dB…0dB → 0…1
                    waveformSamples.append(max(0.05, normalized))
                } else {
                    isPlaying = false
                    timer?.invalidate()
                }
            }
        } catch {
            log.error("AudioRecorder: playback failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Timers

    private func startTimers() {
        // Elapsed time timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            elapsedSeconds += 0.05
        }
        // Metering timer for waveform
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { _ in
            guard let rec = recorder, rec.isRecording else { return }
            rec.updateMeters()
            let power = rec.averagePower(forChannel: 0)
            let normalized = CGFloat(max(0, (power + 50) / 50))
            waveformSamples.append(max(0.05, normalized))
        }
    }

    private func stopTimers() {
        timer?.invalidate()
        timer = nil
        meteringTimer?.invalidate()
        meteringTimer = nil
    }

    private func cleanup() {
        stopTimers()
        recorder?.stop()
        player?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
#endif
