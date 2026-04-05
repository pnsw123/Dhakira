import EventKit
import SwiftUI
import SwiftData
import RichTextKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "TaskDetail")

#if canImport(UIKit)
import UIKit
import Combine
import PencilKit
import PhotosUI
import VisionKit
import UniformTypeIdentifiers

// MARK: - TaskDetailView

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.scenePhase) private var scenePhase
    private var isRegular: Bool { hSizeClass == .regular }

    // RichTextKit bindings — attributed string is the source of truth for RTF content
    @State private var attributedText: NSAttributedString = NSAttributedString()
    @StateObject private var richTextContext = RichTextContext()
    /// Reference to the underlying UITextView — obtained once via onEditorReady.
    /// Used to restore focus + selection before issuing formatting commands.
    @State private var richTextView: UITextView?

    @State private var showToolbar = true
    @State private var showExportOptions = false
    @State private var isKeyboardVisible = false
    @State private var isDrawingMode = false
    /// References to PencilKit objects — created once, embedded inside UITextView.
    @State private var pkCanvasView: PKCanvasView?
    @State private var pkToolPicker: PKToolPicker?
    /// KVO observer for syncing canvas size with UITextView.contentSize.
    @State private var contentSizeObserver: NSKeyValueObservation?
    // Slash command coordinator — replaces 3 @State vars + double evaluate() (Issue #48)
    @StateObject private var slashCoordinator = SlashCommandCoordinator()
    // Checkbox tap coordinator — wires a UITapGestureRecognizer to the UITextView
    // so users can tap checkbox attachments to toggle them checked/unchecked.
    @StateObject private var checkboxCoordinator = CheckboxTapCoordinator()
    // Long press coordinator — shows color palette when user holds without selecting text.
    @StateObject private var colorLongPressCoordinator = ColorLongPressCoordinator()
    // Image size coordinator — tap an image to show ➖/➕ pill for resizing.
    @StateObject private var imageSizeCoordinator = ImageSizeCoordinator()
    // Link tap coordinator — opens file/URL attachments when tapped inside the editable text view.
    @StateObject private var linkTapCoordinator = LinkTapCoordinator()
    // Key interceptor — takes first responder on iPad/Mac when slash menu is visible
    // so arrow keys navigate menu rows instead of moving the text cursor.
    @State private var keyInterceptor = SlashMenuKeyInterceptor()

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
    /// Sticky font color — set when user picks a color, persists across cursor moves
    /// until explicitly removed via the palette. Re-applied in onSelectionChanged
    /// because UIKit resets typingAttributes on every cursor movement.
    @State private var activeFontColor: UIColor? = nil

    /// Cursor rect in global (window) coordinates when "/" was typed — used to
    /// anchor the slash menu right below the cursor instead of at the bottom.
    @State private var slashCursorGlobalRect: CGRect = .zero

    /// Tracks the text length after each keystroke so we can detect a single
    /// newline insertion (Return key) for block-continuation logic.
    @State private var prevTextLength: Int = 0

    /// Issue #84: debounce timer for body-line event sync.
    /// Fires 2 seconds after the last newline insertion (Enter key).
    @State private var bodyEventDebounceTimer: Timer?
    /// Tracks whether a newline was inserted (Enter pressed) since the last sync.
    @State private var newlineDetectedSinceLastSync = false

    /// Re-entrancy guard: prevents onSelectionChanged from firing recursively
    /// when it modifies @State variables that trigger SwiftUI re-renders,
    /// which cause RichTextKit to re-report the selection range (Issue #89).
    @State private var isProcessingSelectionChange = false
    /// Guards against EKEventStoreChanged → textDidChange cascades.
    /// Set to true while we're programmatically updating tv.attributedText
    /// from a non-user-edit path (calendar reconciliation, struck styling).
    @State private var isSuppressingTextDidChange = false

    // Default toolbar order — most-used items first. User can drag-reorder; saved to UserDefaults.
    static let defaultToolbarItems: [EditorTool] = [
        .init(id: "fontSizeUp",       icon: "textformat.size.larger"),   // 1 — increase text size
        .init(id: "fontSizeDown",     icon: "textformat.size.smaller"),  // 2 — decrease text size
        .init(id: "checklist",        icon: "checklist"),                 // 3 — to-do list
        .init(id: "bold",             icon: "bold"),                      // 4 — bold
        .init(id: "pencil",           icon: "pencil.tip.crop.circle"),   // 5 — drawing
        .init(id: "italic",           icon: "italic"),                   // 6
        .init(id: "paperclip",        icon: "paperclip"),                // 7 — attach file
        .init(id: "underline",        icon: "underline"),
        .init(id: "list.bullet",      icon: "list.bullet"),
        .init(id: "strikethrough",    icon: "strikethrough"),
        .init(id: "text.alignleft",   icon: "text.alignleft"),
        .init(id: "text.aligncenter", icon: "text.aligncenter"),
        .init(id: "text.alignright",  icon: "text.alignright"),
        .init(id: "photo",            icon: "photo"),
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

    var body: some View {
        VStack(spacing: 0) {
            _TaskHeaderView(task: task)

            editorArea

            if showToolbar && !isDrawingMode && !slashCoordinator.isMenuVisible {
                editorToolbar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .tint(Color.themeAccent)
        .overlay(alignment: .topTrailing) { shareMenuOverlay }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 0) {
                // Back button — same glass circle as TaskListView
                Button {
                    saveBody()
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.themeAccent)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)

                Spacer()

                // Right actions
                if isDrawingMode {
                    HStack(spacing: 8) {
                        // Undo / Redo for drawing — native UndoManager from PKCanvasView
                        Button {
                            pkCanvasView?.undoManager?.undo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.themeAccent)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .opacity(pkCanvasView?.undoManager?.canUndo == true ? 1 : 0.35)
                        .accessibilityLabel("Undo Drawing")

                        Button {
                            pkCanvasView?.undoManager?.redo()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.themeAccent)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .opacity(pkCanvasView?.undoManager?.canRedo == true ? 1 : 0.35)
                        .accessibilityLabel("Redo Drawing")

                        Button {
                            withAnimation(.spring(response: 0.3)) { isDrawingMode = false }
                            pkToolPicker?.setVisible(false, forFirstResponder: pkCanvasView ?? UIView())
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                if !isDrawingMode { richTextView?.becomeFirstResponder() }
                            }
                        } label: {
                            Text("Done")
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.themeAccent)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.trailing, 8)
                } else {
                    HStack(spacing: 8) {
                        // Undo / Redo — native UndoManager from UITextView
                        Button {
                            richTextView?.undoManager?.undo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.themeAccent)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .opacity(richTextView?.undoManager?.canUndo == true ? 1 : 0.35)
                        .accessibilityLabel("Undo")

                        Button {
                            richTextView?.undoManager?.redo()
                        } label: {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.themeAccent)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .opacity(richTextView?.undoManager?.canRedo == true ? 1 : 0.35)
                        .accessibilityLabel("Redo")

                        Menu {
                            Button { shareTask() } label: {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            Button { exportAsPDF() } label: {
                                Label("Export as PDF", systemImage: "doc.richtext")
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.themeAccent)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)

                        if isKeyboardVisible {
                            Button {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            } label: {
                                Image(systemName: "keyboard.chevron.compact.down")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.themeAccent)
                                    .frame(width: 36, height: 36)
                                    .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                            }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                        }

                        Button {
                            showToolbar.toggle()
                            if !showToolbar {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        } label: {
                            Image(systemName: "rectangle.and.pencil.and.ellipsis")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color.themeAccent)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 4)
                    }
                    .padding(.trailing, 8)
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 8)
        }
        // AttachmentService drives all picker sheets via a single enum (Issue #49)
        .background(attachmentService.presentationHooks(attributedText: $attributedText, taskId: task.id))
        // Zero-size hidden view that becomes first responder on iPad/Mac so arrow keys
        // navigate the slash menu without disrupting the UITextView's soft keyboard.
        .background(
            KeyInterceptorRepresentable(
                interceptor: keyInterceptor,
                onMoveDown:  { slashCoordinator.moveSelectionDown() },
                onMoveUp:    { slashCoordinator.moveSelectionUp() },
                onSelect: {
                    if let cmd = slashCoordinator.selectedCommand {
                        richTextView?.becomeFirstResponder()
                        applySlashCommand(cmd)
                    }
                },
                onDismiss: {
                    slashCoordinator.dismiss()
                    richTextView?.becomeFirstResponder()
                }
            )
            .frame(width: 0, height: 0)
            .opacity(0)
        )
        .onAppear { loadToolbarOrder(); loadBody() }
        .onDisappear { saveBody() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { isKeyboardVisible = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            // Issue #86: refresh strikethrough when calendar events change.
            // Also clear parent event ID if the event was deleted from Apple Calendar.
            CalendarSyncService.shared.reconcileParentEvent(for: task)
            BodyEventSyncService.shared.reconcileAppleEvents(for: task, context: modelContext)
            applyStruckThroughStyling()
            // Push the updated attributedText into the live UITextView.
            // IMPORTANT: suppress textDidChangeNotification during this update (Issue #89).
            // Without this guard, setting tv.attributedText fires textDidChange → scheduleBodyEventSync
            // → calendar saves → EKEventStoreChanged → this handler → infinite loop that freezes the UI.
            if let tv = richTextView {
                isSuppressingTextDidChange = true
                tv.attributedText = attributedText
                isSuppressingTextDidChange = false
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .inactive || newPhase == .background {
                saveBody()
            }
        }
        // Sync checkbox toggle back to the @State binding (Bug #1 fix)
        .onChange(of: checkboxCoordinator.toggleVersion) { _, _ in
            if let toggled = checkboxCoordinator.lastToggledText {
                attributedText = toggled
                // Checkbox toggled → sync body events so checked items get their
                // calendar events deleted (subtask done = no reminder needed).
                let bodyText = toggled.string
                let checked = extractCheckedLines(from: toggled)
                let t = task
                let ctx = modelContext
                if !checked.isEmpty {
                    log.info("checkboxToggle: \(checked.count) checked line(s) — syncing body events")
                }
                Task { await CalendarSyncCoordinator.shared.syncBodyEvents(bodyText: bodyText, task: t, context: ctx, checkedLines: checked) }
            }
        }
        // Sync attributedText after image resize so the new size is saved on next write.
        .onChange(of: imageSizeCoordinator.didResize) { _, _ in
            if let tv = richTextView {
                attributedText = tv.attributedText ?? attributedText
            }
        }
        // Show color palette on long press (no text selection needed)
        .onChange(of: colorLongPressCoordinator.pressGlobalRect) { _, rect in
            log.debug("onChange(pressGlobalRect): rect=\(rect.debugDescription)")
            guard let rect else { return }
            selectionGlobalRect = rect
            showColorPalette = true
            colorLongPressCoordinator.clear()
            log.debug("onChange(pressGlobalRect): EXIT palette shown")
        }
        // Keyboard navigation: on iPad/Mac give first responder to interceptor so
        // arrow keys route to the slash menu instead of moving the text cursor.
        .onChange(of: slashCoordinator.isMenuVisible) { _, visible in
            let isHardwareKeyboardDevice =
                UIDevice.current.userInterfaceIdiom == .pad ||
                UIDevice.current.userInterfaceIdiom == .mac
            if visible && isHardwareKeyboardDevice {
                DispatchQueue.main.async { keyInterceptor.becomeFirstResponder() }
            } else if !visible && keyInterceptor.isFirstResponder {
                richTextView?.becomeFirstResponder()
            }
        }
    }

    // MARK: - Toolbar (Issues #39–#43)

    // MARK: - Editor area sub-views (extracted to keep body type-checkable)

    private var editorArea: some View {
        ZStack(alignment: .topLeading) {
            NativeEditorView(
                attributedText: $attributedText,
                context: richTextContext,
                onEditorReady: { tv in
                    richTextView = tv
                    // RichTextKit's updateUIView() is intentionally empty, so changes to
                    // attributedText after makeUIView don't reach the UITextView automatically.
                    // onAppear → loadBody() runs before onEditorReady fires (async dispatch),
                    // so attributedText is already populated here — push it into the live view.
                    if attributedText.length > 0 {
                        tv.attributedText = attributedText
                        let endLoc = attributedText.length
                        tv.selectedRange = NSRange(location: endLoc, length: 0)
                        tv.typingAttributes[.foregroundColor] = UIColor.label
                        prevTextLength = attributedText.length
                    }
                    // Strip highlight (backgroundColor) typing attribute after pressing Enter.
                    // UITextView inherits all attributes — including highlight colour — onto the
                    // next line, so without this fix every new paragraph appears highlighted.
                    NotificationCenter.default.addObserver(
                        forName: UITextView.textDidChangeNotification,
                        object: tv,
                        queue: .main
                    ) { _ in
                        let sel = tv.selectedRange
                        guard sel.length == 0, sel.location > 0 else { return }
                        let nsStr = tv.text as NSString
                        let prevChar = nsStr.substring(with: NSRange(location: sel.location - 1, length: 1))
                        if prevChar == "\n" {
                            // Clear BOTH highlight colors so they don't bleed onto new lines.
                            tv.typingAttributes.removeValue(forKey: .backgroundColor)
                            tv.typingAttributes[.foregroundColor] = UIColor.label
                            // Also strip background from the newline character itself so it
                            // doesn't render a colored bar across the empty line.
                            let nlRange = NSRange(location: sel.location - 1, length: 1)
                            if nlRange.location < tv.textStorage.length {
                                tv.textStorage.removeAttribute(.backgroundColor, range: nlRange)
                            }
                        }
                    }
                    let tap = UITapGestureRecognizer(
                        target: checkboxCoordinator,
                        action: #selector(CheckboxTapCoordinator.handleTap(_:))
                    )
                    tap.delegate = checkboxCoordinator
                    tv.addGestureRecognizer(tap)
                    let longPress = UILongPressGestureRecognizer(
                        target: colorLongPressCoordinator,
                        action: #selector(ColorLongPressCoordinator.handleLongPress(_:))
                    )
                    longPress.delegate = colorLongPressCoordinator
                    tv.addGestureRecognizer(longPress)
                    imageSizeCoordinator.attach(to: tv)
                    linkTapCoordinator.attach(to: tv)
                    DispatchQueue.main.async { refreshQuoteBorderViews(in: tv) }

                    // Sync drawing canvas scroll with text view so strokes stay in place.
                    syncCanvasScrollWithTextView(tv)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 4)
            .onReceive(NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification)) { note in
                guard let tv = note.object as? UITextView, tv === richTextView else { return }
                // Skip processing when we're programmatically setting tv.attributedText
                // from non-user-edit paths (e.g. EKEventStoreChanged handler).
                // Without this, calendar saves → EKEventStoreChanged → tv.attributedText = ...
                // → textDidChange → scheduleBodyEventSync → more calendar saves → freeze (Issue #89).
                guard !isSuppressingTextDidChange else { return }
                log.debug("textDidChange: ENTER len=\(tv.textStorage.length)")
                // Keep attributedText in sync so saveBody() fallback is accurate when richTextView is nil on disappear.
                attributedText = tv.attributedText ?? NSAttributedString()
                handleReturnKey(tv: tv)
                evaluateSlashCommand()
                evaluateMarkdownHeader(tv: tv)
                DispatchQueue.main.async { refreshQuoteBorderViews(in: tv) }

                // Issue #84: detect newline → start/reset 2s debounce for body event sync.
                let textLen = (tv.text as NSString).length
                let cursorLoc = tv.selectedRange.location
                if textLen > 0, cursorLoc > 0,
                   (tv.text as NSString).character(at: cursorLoc - 1) == 0x0A {
                    newlineDetectedSinceLastSync = true
                }
                scheduleBodyEventSync()
            }
            .onReceive(NotificationCenter.default.publisher(for: .attachmentAppended)) { note in
                guard let newText = note.object as? NSAttributedString,
                      let tv = richTextView else { return }
                log.debug("attachmentAppended: received \(newText.length) chars")
                tv.attributedText = newText
                attributedText = newText
                prevTextLength = newText.length
                // Place cursor right after the inserted attachment (not at end)
                let cursorPos = (note.userInfo?["cursorPosition"] as? Int) ?? newText.length
                let safeCursor = min(cursorPos, newText.length)
                tv.selectedRange = NSRange(location: safeCursor, length: 0)
                log.debug("attachmentAppended: cursor placed at \(safeCursor)")
                // Restore typing attributes — programmatic attributedText reset clears them
                tv.typingAttributes[.foregroundColor] = UIColor.label
                tv.typingAttributes[.font] = UIFont.preferredFont(forTextStyle: .body)
                DispatchQueue.main.async { refreshQuoteBorderViews(in: tv) }
            }
            .onChange(of: richTextContext.selectedRange) { _, range in
                log.debug("onChange(selectedRange): FIRED range=\(range.location)+\(range.length)")
                // Defer to the next run loop iteration (Issue #89).
                // RichTextKit publishes selectedRange DURING UITextView's layout pass
                // (TextKit 1 compatibility mode switch). Accessing tv.attributedText
                // synchronously inside that layout pass crashes because TextKit is
                // still mutating internal state. DispatchQueue.main.async pushes our
                // handler to AFTER the layout cycle completes.
                DispatchQueue.main.async { onSelectionChanged(range) }
            }

            DrawingCanvasView(
                drawingData: $task.drawingData,
                isActive: $isDrawingMode,
                onCanvasReady: { canvas, picker in
                    pkCanvasView = canvas
                    pkToolPicker = picker
                    // Keep scroll disabled — user draws on full screen.
                    // We sync contentOffset programmatically so drawings scroll with text.
                    canvas.isScrollEnabled = false
                    // Large contentSize so strokes at any Y position are kept
                    canvas.contentSize = CGSize(width: 4096, height: 16384)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(isDrawingMode || task.drawingData != nil ? 1 : 0)
            .allowsHitTesting(isDrawingMode)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topLeading) { colorPaletteOverlay }
        .overlay(alignment: .topLeading) { slashMenuOverlay }
    }

    @ViewBuilder private var colorPaletteOverlay: some View {
        if showColorPalette && !isDrawingMode && !selectionGlobalRect.isEmpty {
            GeometryReader { geo in
                let gf = geo.frame(in: .global)
                let selBottomLocal = selectionGlobalRect.maxY - gf.minY
                let selTopLocal    = selectionGlobalRect.minY - gf.minY
                let paletteH: CGFloat = 52  // collapsed pill height
                // Mirror Apple's system bar: flip above when not enough room below
                let belowY = selBottomLocal + 60
                let wouldClip = belowY + paletteH > geo.size.height
                let localY: CGFloat = wouldClip
                    ? selTopLocal - 60 - paletteH  // above the system bar
                    : belowY                        // below the system bar (default)
                if localY > -paletteH && localY < geo.size.height {
                    ColorPaletteView(
                        mode: $paletteMode,
                        onApplyHighlight: { color in
                            let pair = NamedColor.highlightPair(for: color)
                            applyColorAttribute(key: .backgroundColor, value: pair.backgroundColor, range: savedColorSelection)
                            applyColorAttribute(key: .foregroundColor, value: pair.textColor, range: savedColorSelection)
                            // Clear highlight colors from typing attributes so they don't
                            // bleed onto new lines when the user presses Enter.
                            if let tv = richTextView {
                                tv.typingAttributes.removeValue(forKey: .backgroundColor)
                                tv.typingAttributes[.foregroundColor] = UIColor.label
                            }
                            activeFontColor = nil
                        },
                        onApplyFontColor: { color in
                            applyColorAttribute(key: .foregroundColor, value: color, range: savedColorSelection)
                        },
                        onRemoveFontColor: {
                            applyColorAttribute(key: .foregroundColor, value: UIColor.label, range: savedColorSelection)
                        },
                        onRemoveHighlight: {
                            applyColorAttribute(key: .backgroundColor, value: nil, range: savedColorSelection)
                            applyColorAttribute(key: .foregroundColor, value: UIColor.label, range: savedColorSelection)
                        },
                        onDismiss: { showColorPalette = false },
                        initialFontColorName: detectedFontColorName(),
                        initialHighlightName: detectedHighlightName()
                    )
                    .fixedSize()
                    .frame(maxWidth: geo.size.width, alignment: .center)
                    .offset(y: localY)
                }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder private var shareMenuOverlay: some View {
        if showExportOptions {
            // Dismiss on outside tap
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showExportOptions = false
                    }
                }
                .overlay(alignment: .topTrailing) {
                    VStack(alignment: .leading, spacing: 0) {
                        Button {
                            withAnimation { showExportOptions = false }
                            shareTask()
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.horizontal, 12)

                        Button {
                            withAnimation { showExportOptions = false }
                            exportAsPDF()
                        } label: {
                            Label("Export as PDF", systemImage: "doc.richtext")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(Color.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(width: 210)
                    .glassEffect(.regular.tint(Color.themeAccent.opacity(0.25)), in: .rect(cornerRadius: 14))
                    .padding(.top, 56)
                    .padding(.trailing, 8)
                    .transition(.scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity))
                }
        }
    }

    @ViewBuilder private var slashMenuOverlay: some View {
        if slashCoordinator.isMenuVisible && !slashCoordinator.filteredCommands.isEmpty {
            GeometryReader { geo in
                let gf = geo.frame(in: .global)
                let caretMaxY: CGFloat = slashCursorGlobalRect == .zero ? gf.minY + 40 : slashCursorGlobalRect.maxY

                let localX: CGFloat = slashCursorGlobalRect == .zero
                    ? 16
                    : max(0, min(slashCursorGlobalRect.minX - gf.minX, geo.size.width - 264))
                let localY: CGFloat = caretMaxY - gf.minY + 6
                if localY < geo.size.height {
                    SlashCommandMenuView(
                        commands: slashCoordinator.filteredCommands,
                        selectedIndex: slashCoordinator.selectedIndex,
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

    private var editorToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: isRegular ? 6 : 2) {
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
            .padding(.horizontal, isRegular ? 10 : 6)
        }
        .frame(height: isRegular ? 62 : 52)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: isRegular ? 22 : 18, style: .continuous))
        .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)), in: .rect(cornerRadius: isRegular ? 22 : 18))
        .padding(.horizontal, isRegular ? 24 : 16)
        .padding(.bottom, isRegular ? 12 : 8)
        .accessibilityIdentifier("editor-toolbar")
    }

    @ViewBuilder
    private func toolbarItemView(for item: EditorTool) -> some View {
        switch item.id {
        case "paperclip":
            attachmentMenuButton
        case "fontSizeUp", "fontSizeDown":
            fontSizeHoldButton(item.icon, toolId: item.id)
        default:
            toolbarButton(item.icon) {
                handleToolbarTap(item.id)
            }
        }
    }

    /// Font-size button that fires once on tap AND continuously while held.
    private func fontSizeHoldButton(_ icon: String, toolId: String) -> some View {
        FontSizeHoldButton(icon: icon) {
            handleToolbarTap(toolId)
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
                .accessibilityIdentifier("btn-attachment-menu")
        }
        .menuStyle(.button)
    }


    private func handleToolbarTap(_ id: String) {
        log.info("handleToolbarTap: '\(id)'")

        // Special-case non-dispatcher actions first
        switch id {
        case "photo":
            attachmentService.savedCursorPosition = richTextView?.selectedRange.location
            log.debug("handleToolbarTap: photo — saved cursor at \(attachmentService.savedCursorPosition.map(String.init) ?? "nil")")
            attachmentService.choosePhotoOrVideo()
            return
        case "pencil":
            log.debug("handleToolbarTap: entering drawing mode")
            richTextView?.resignFirstResponder()
            saveBody()
            isDrawingMode = true
            // Show PKToolPicker explicitly — UIKit needs a moment after
            // the SwiftUI state change for the canvas to be interactable.
            showDrawingToolPicker()
            return
        case "fontSizeUp", "fontSizeDown":
            guard let tv = richTextView else { return }
            tv.becomeFirstResponder()
            let range = tv.selectedRange
            let increase = id == "fontSizeUp"
            let step: CGFloat = 2
            let minSize: CGFloat = 10
            // Update typing attributes so the next keystroke on an empty page
            // (or after a cursor move) uses the new size immediately.
            let currentFont = tv.typingAttributes[.font] as? UIFont
                ?? UIFont.preferredFont(forTextStyle: .body)
            let newSize = increase ? currentFont.pointSize + step : max(minSize, currentFont.pointSize - step)
            let newFont = UIFont(descriptor: currentFont.fontDescriptor, size: newSize)
            tv.typingAttributes[.font] = newFont
            // Apply to selected text only; if no selection, only the cursor changes.
            if range.length > 0 {
                RichEditorCommands.stepFontSize(
                    increase: increase,
                    attributedText: &attributedText,
                    selectedRange: range
                )
                tv.attributedText = attributedText
                tv.selectedRange = range
                saveBody()
            }
            return
        case "list.bullet":
            // toggleBulletList inserts "• " at paragraph start, shifting content right by 2.
            // The generic dispatcher restores savedRange which lands before the "•" — so we
            // own cursor placement here exactly like the slash command does (newCursor += 2).
            guard let tv = richTextView else { return }
            tv.becomeFirstResponder()
            let range = tv.selectedRange
            let nsStr = (tv.attributedText?.string ?? "") as NSString
            let parRange = nsStr.paragraphRange(for: range)
            let wasBulleted = nsStr.substring(with: parRange).hasPrefix("• ")
            RichEditorCommands.toggleBulletList(attributedText: &attributedText, selectedRange: range)
            tv.attributedText = attributedText
            // If we just added "• ": shift cursor +2 so it lands after the prefix, not before it.
            // If we just removed "• ": shift cursor -2 so it stays on the same content character.
            let shift = wasBulleted ? -2 : 2
            let maxLoc = (tv.text as NSString).length
            let newLoc = max(0, min(range.location + shift, maxLoc))
            tv.selectedRange = NSRange(location: newLoc, length: 0)
            prevTextLength = attributedText.length
            return
        case "checklist":
            // Insert a to-do item at the current cursor — same result as /todo slash command.
            guard let tv = richTextView else { return }
            tv.becomeFirstResponder()
            let cursorLoc = tv.selectedRange.location
            let newCursor = RichEditorCommands.insertChecklist(
                attributedText: &attributedText,
                cursorLocation: cursorLoc
            )
            tv.attributedText = attributedText
            tv.selectedRange = NSRange(location: newCursor, length: 0)
            prevTextLength = attributedText.length
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
        guard let tv = richTextView,
              let current = tv.attributedText else {
            log.debug("applyColorAttribute: skipped — missing textView")
            return
        }
        tv.becomeFirstResponder()

        // Apply to selected range when text is selected.
        if range.length > 0 {
            let mutable = current.mutableCopy() as! NSMutableAttributedString
            let loc  = min(range.location, mutable.length)
            let len  = min(range.length,   mutable.length - loc)
            if len > 0 {
                let safe  = NSRange(location: loc, length: len)
                let nsStr = mutable.string as NSString
                var applied = 0

                if key == .backgroundColor && value != nil {
                    // Word-like highlight: keep spaces BETWEEN words but skip
                    // trailing whitespace on each line and blank lines entirely.
                    // Uses a "pending whitespace" buffer: flush it only when real
                    // content follows (inter-word), discard it on newline (trailing).
                    var pendingWSStart = -1
                    var i = safe.location
                    let end = safe.location + safe.length
                    while i < end {
                        guard i < mutable.length else { break }
                        let scalar = nsStr.character(at: i)
                        // Covers \n, \r, Unicode line/paragraph separators
                        let isNewline = scalar == 0x0A || scalar == 0x0D ||
                                        scalar == 0x2028 || scalar == 0x2029
                        // Covers space, tab, non-breaking space
                        let isSpace   = scalar == 0x20 || scalar == 0x09 || scalar == 0xA0
                        if isNewline {
                            pendingWSStart = -1        // discard trailing whitespace
                        } else if isSpace {
                            if pendingWSStart < 0 { pendingWSStart = i }
                        } else {
                            // Real content — flush any buffered whitespace first
                            if pendingWSStart >= 0 {
                                let wsLen = i - pendingWSStart
                                let wsRange = NSRange(location: pendingWSStart, length: wsLen)
                                mutable.addAttribute(key, value: value!, range: wsRange)
                                applied += wsLen
                                pendingWSStart = -1
                            }
                            mutable.addAttribute(key, value: value!,
                                                 range: NSRange(location: i, length: 1))
                            applied += 1
                        }
                        i += 1
                    }
                } else {
                    // Font color: skip all whitespace.
                    // Highlight removal: remove from entire range (removing a missing
                    // attribute is harmless and simpler than character-walking).
                    if key == .backgroundColor {
                        mutable.removeAttribute(key, range: safe)
                        applied = safe.length
                    } else {
                        for i in safe.location ..< (safe.location + safe.length) {
                            guard i < mutable.length else { break }
                            let charRange = NSRange(location: i, length: 1)
                            let scalar    = nsStr.character(at: i)
                            if scalar == 0x20 || scalar == 0x09 || scalar == 0x0A ||
                               scalar == 0x0D || scalar == 0xA0 { continue }
                            if let v = value {
                                mutable.addAttribute(key, value: v, range: charRange)
                            } else {
                                mutable.removeAttribute(key, range: charRange)
                            }
                            applied += 1
                        }
                    }
                }
                tv.attributedText = mutable
                tv.selectedRange  = range   // restore selection (setting attributedText resets it)
                attributedText    = mutable
                log.debug("applyColorAttribute: \(key.rawValue) — \(applied) chars coloured")
            }
        }

        // Font color carries as a typing attribute — user expects to keep typing in red, etc.
        // Highlight (.backgroundColor) does NOT carry: it must only apply to the selected
        // text, never bleed onto new keystrokes (Enter, space, etc.) the user types after.
        if key == .backgroundColor {
            // Always clear highlight from typing attributes — apply was already done above.
            tv.typingAttributes.removeValue(forKey: .backgroundColor)
        } else if let v = value {
            tv.typingAttributes[key] = v
            // Track sticky font color so it survives cursor movement
            if key == .foregroundColor { activeFontColor = v as? UIColor }
        } else {
            tv.typingAttributes.removeValue(forKey: key)
            // Removing font color: restore adaptive label so text stays visible
            if key == .foregroundColor {
                tv.typingAttributes[.foregroundColor] = UIColor.label
                activeFontColor = nil   // user explicitly cleared — stop sticking
            }
        }
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
            if let pos = tv.position(from: tv.beginningOfDocument, offset: safeLoc) {
                // caretRect(for:) is the correct API for an insertion-point rect —
                // it always returns a full line-height rect, unlike firstRect(for: emptyRange)
                // which can return zero height and cause the menu to land on top of the cursor.
                let r = tv.caretRect(for: pos)
                let converted = tv.convert(r, to: nil)
                log.debug("⚠️ SLASH: caretRect=\(converted.debugDescription), isNull=\(r.isNull), isInf=\(r.isInfinite), height=\(converted.height)")
                if !r.isNull, !r.isInfinite, r.height > 0 {
                    slashCursorGlobalRect = converted
                }
            } else {
                log.warning("⚠️ SLASH: could not create text position for cursor \(safeLoc)")
            }
        } else {
            slashCursorGlobalRect = .zero
        }
    }

    // MARK: - Markdown Header Auto-Conversion
    /// Detects `# `, `## `, `### `, `#### ` typed at the start of a paragraph and converts
    /// them to h1 / h2 / h3 / h4 heading styles, removing the markdown prefix (Notion-style).
    private func evaluateMarkdownHeader(tv: UITextView) {
        guard let tvText = tv.attributedText else { return }
        let str = tvText.string as NSString
        let cursorLoc = tv.selectedRange.location
        // Only trigger when the character just before the cursor is a space
        guard cursorLoc > 0, str.character(at: cursorLoc - 1) == 0x20 else { return }

        let parRange = str.paragraphRange(for: NSRange(location: cursorLoc - 1, length: 0))
        let parText = str.substring(with: parRange)

        // Match longest prefix first so "###" doesn't match as "##"
        let match: (prefix: String, level: RichEditorCommands.HeadingLevel)?
        if parText.hasPrefix("#### ") {
            match = ("#### ", .h4)
        } else if parText.hasPrefix("### ") {
            match = ("### ", .h3)
        } else if parText.hasPrefix("## ") {
            match = ("## ", .h2)
        } else if parText.hasPrefix("# ") {
            match = ("# ", .h1)
        } else {
            return
        }
        guard let (prefix, level) = match else { return }

        let mutable = NSMutableAttributedString(attributedString: tvText)
        let prefixLen = (prefix as NSString).length
        mutable.deleteCharacters(in: NSRange(location: parRange.location, length: prefixLen))

        // Apply heading font to the now-prefix-free paragraph
        let newParRange = (mutable.string as NSString).paragraphRange(
            for: NSRange(location: parRange.location, length: 0))
        if newParRange.length > 0 {
            mutable.addAttribute(.font, value: level.font, range: newParRange)
            mutable.addAttribute(.foregroundColor, value: UIColor.label, range: newParRange)
        }

        tv.attributedText = mutable
        let safeCursor = min(parRange.location, mutable.length)
        tv.selectedRange = NSRange(location: safeCursor, length: 0)
        tv.typingAttributes[.font] = level.font
        tv.typingAttributes[.foregroundColor] = UIColor.label
        attributedText = mutable
        prevTextLength = mutable.length
        log.debug("evaluateMarkdownHeader: applied \(String(describing: level)) from prefix '\(prefix)'")
    }

    /// Sync the DrawingCanvasView's scroll offset with the UITextView so drawings
    /// stay at their drawn position when scrolling. Called once from onEditorReady.
    private func syncCanvasScrollWithTextView(_ tv: UITextView) {
        // Mirror UITextView scroll position to PKCanvasView so drawings stay in place.
        // Canvas has isScrollEnabled=false but a large contentSize — we set contentOffset
        // programmatically to scroll the drawing content in sync with the text.
        contentSizeObserver = tv.observe(\.contentOffset, options: [.new]) { _, _ in
            guard let canvas = pkCanvasView else { return }
            canvas.contentOffset = tv.contentOffset
        }
    }

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
                .font(.system(size: isRegular ? 20 : 18))
                .foregroundStyle(Color.primary)
                .frame(width: isRegular ? 50 : 44, height: isRegular ? 50 : 44)
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

        // UITextView is required for every path below — bail early if not ready.
        guard let tv = richTextView else {
            log.warning("applySlashCommand: richTextView is nil — aborting")
            return
        }

        // Read slash location BEFORE commandSelected clears frozenState.
        let slashLoc = slashCoordinator.currentSlashLocation

        // ── Ground truth is the LIVE UITextView content ──────────────────────────
        // RichTextEditor.updateUIView() is intentionally empty in RichTextKit, so
        // the SwiftUI `attributedText` binding can lag behind what the UITextView
        // actually shows. All mutations must start from tv.attributedText, matching
        // the same pattern that handleToolbarTap already uses in this file.
        var workingText: NSAttributedString = tv.attributedText ?? NSAttributedString()

        // Step 1: coordinator deletes '/' + filter text FROM workingText, dismisses menu.
        slashCoordinator.commandSelected(cmd, applyTo: &workingText, cursorLocation: 0)

        var newCursor = max(0, slashLoc >= 0 ? slashLoc : 0)
        let selRange = NSRange(location: newCursor, length: 0)

        // Step 2: apply the chosen command to workingText.
        // bulletList and quote insert a text prefix ("• " / "│ ") at the paragraph
        // start — newCursor shifts +2 to land after the prefix.
        var isColorCommand = false
        switch cmd.id {
        case "photo":
            // Delete the slash+command text, dismiss keyboard, then open photo picker.
            tv.attributedText = workingText
            tv.selectedRange  = NSRange(location: newCursor, length: 0)
            attributedText    = workingText
            prevTextLength    = workingText.length
            DispatchQueue.main.async { attachmentService.choosePhotoOrVideo() }
            return
        case "bulletList":
            RichEditorCommands.toggleBulletList(attributedText: &workingText, selectedRange: selRange)
            newCursor += 2   // past the inserted "• "
        case "todoList":
            newCursor = RichEditorCommands.insertChecklist(attributedText: &workingText,
                                                            cursorLocation: newCursor)
        case "quote":
            RichEditorCommands.applyBlockquote(attributedText: &workingText, selectedRange: selRange)
            newCursor += 2   // past the inserted "│ "
        case "heading1":
            RichEditorCommands.applyHeading(.h1, attributedText: &workingText, selectedRange: selRange)
        case "heading2":
            RichEditorCommands.applyHeading(.h2, attributedText: &workingText, selectedRange: selRange)
        case "heading3":
            RichEditorCommands.applyHeading(.h3, attributedText: &workingText, selectedRange: selRange)
        case _ where NamedColor.find(id: cmd.id) != nil:
            isColorCommand = true
        default:
            log.warning("applySlashCommand: unhandled command id '\(cmd.id)'")
        }

        // Step 3: push result to UITextView synchronously, then sync the binding.
        tv.attributedText = workingText
        tv.becomeFirstResponder()
        let safeCursor = max(0, min(newCursor, (tv.text as NSString).length))
        tv.selectedRange = NSRange(location: safeCursor, length: 0)
        attributedText = workingText
        // Keep prevTextLength in sync so handleReturnKey doesn't see a false +N delta.
        prevTextLength = workingText.length
        // Refresh quote border overlay after applying a quote block.
        if cmd.id == "quote" {
            DispatchQueue.main.async { self.refreshQuoteBorderViews(in: tv) }
        }

        // Step 4: typing attributes — next keystroke inherits the block style.
        // NOTE: No NSTextList here — we use text-prefix bullets now.
        switch cmd.id {
        case "heading1":
            tv.typingAttributes[.font] = RichEditorCommands.HeadingLevel.h1.font
            tv.typingAttributes[.foregroundColor] = UIColor.label
        case "heading2":
            tv.typingAttributes[.font] = RichEditorCommands.HeadingLevel.h2.font
            tv.typingAttributes[.foregroundColor] = UIColor.label
        case "heading3":
            tv.typingAttributes[.font] = RichEditorCommands.HeadingLevel.h3.font
            tv.typingAttributes[.foregroundColor] = UIColor.label
        case "todoList":
            tv.typingAttributes[.font]            = UIFont.preferredFont(forTextStyle: .body)
            tv.typingAttributes[.foregroundColor] = UIColor.label
        case "bulletList":
            let hangStyle = NSMutableParagraphStyle()
            hangStyle.headIndent = 14
            tv.typingAttributes[.paragraphStyle]  = hangStyle
            tv.typingAttributes[.foregroundColor] = UIColor.label
            tv.typingAttributes[.font]            = UIFont.preferredFont(forTextStyle: .body)
        case "quote":
            let quoteStyle = NSMutableParagraphStyle()
            quoteStyle.headIndent  = 16
            quoteStyle.tailIndent  = -16
            tv.typingAttributes[.paragraphStyle]  = quoteStyle
            tv.typingAttributes[.foregroundColor] = UIColor.label
        default:
            break
        }

        // Color: applied after focus so the typing attribute sticks.
        if isColorCommand {
            if let nc = NamedColor.find(id: cmd.id) {
                RichEditorCommands.applyTextColor(nc.uiColor, context: richTextContext)
            } else {
                log.warning("applySlashCommand: unknown color command '\(cmd.id)'")
            }
        }

        log.debug("applySlashCommand: done — pushed to UITextView, cursor at \(newCursor)")
    }

    // MARK: - Enter Key Block Continuation

    /// Called on every UITextView.textDidChangeNotification.
    /// Detects when the user pressed Return inside a block (bullet / todo / quote)
    /// and either continues the block or exits it (double-Enter on an empty line).
    private func handleReturnKey(tv: UITextView) {
        guard let tvText = tv.attributedText else { return }
        let cursorLoc = tv.selectedRange.location
        let str = tvText.string as NSString
        let textLen = str.length

        // Slash menu + Return key: if the menu is visible and the user pressed Return,
        // apply the keyboard-highlighted command (or first if no arrow navigation used).
        if slashCoordinator.isMenuVisible,
           let firstCmd = slashCoordinator.selectedCommand,
           textLen == prevTextLength + 1,
           cursorLoc > 0,
           str.character(at: cursorLoc - 1) == 0x0A {
            // Remove the \n that was just inserted.
            let mutable = NSMutableAttributedString(attributedString: tvText)
            mutable.deleteCharacters(in: NSRange(location: cursorLoc - 1, length: 1))
            tv.attributedText = mutable
            tv.selectedRange  = NSRange(location: cursorLoc - 1, length: 0)
            attributedText    = mutable
            prevTextLength    = mutable.length
            applySlashCommand(firstCmd)
            return
        }

        // Always sync — even on early exits — so the next call has a correct baseline.
        // Updated LAST (after any mutations), so we read the live UITextView length.
        // NOTE: do NOT use `defer` here — continueTodoLine inserts extra characters,
        // and `defer` would capture the pre-mutation `textLen`, not the post-mutation length.

        // Only trigger when exactly ONE character was inserted AND it is a newline ('\n').
        // This filters out paste, delete, and every other edit type.
        guard textLen == prevTextLength + 1,
              cursorLoc > 0,
              str.character(at: cursorLoc - 1) == 0x0A else {
            prevTextLength = textLen
            return
        }

        // We need at least one character before the newline to inspect.
        guard cursorLoc >= 2 else {
            prevTextLength = textLen
            return
        }

        // Find the paragraph BEFORE the just-inserted newline.
        // cursorLoc - 1 is the '\n'; cursorLoc - 2 is the last char of the previous line.
        let prevCharLoc  = cursorLoc - 2
        let prevParRange = str.paragraphRange(for: NSRange(location: prevCharLoc, length: 0))

        var prevLineText = str.substring(with: prevParRange)
        if prevLineText.hasSuffix("\n") { prevLineText = String(prevLineText.dropLast()) }

        // Detect block type by TEXT PREFIX — no NSTextList dependency.
        // Todo is identified by a CheckboxAttachment at the paragraph start.
        let hasBullet: Bool = prevLineText.hasPrefix("• ")
        let hasQuote:  Bool = prevLineText.hasPrefix("│ ")
        let isTodo:    Bool = {
            guard prevParRange.location < tvText.length else { return false }
            return tvText.attribute(.attachment, at: prevParRange.location,
                                    effectiveRange: nil) is CheckboxAttachment
        }()

        guard hasBullet || isTodo || hasQuote else {
            prevTextLength = textLen
            return
        }

        // Double-Enter: the "content" of the previous line is ONLY the block prefix
        // (nothing typed after it). Remove the prefix and exit the block.
        let isEmptyBullet = prevLineText == "• "
        let isEmptyQuote  = prevLineText == "│ "
        let isEmptyTodo   = isTodo && (prevLineText == "\u{FFFC} " || prevLineText == "\u{FFFC}")
        let isDoubleEnter = prevLineText.isEmpty || isEmptyBullet || isEmptyQuote || isEmptyTodo

        if isDoubleEnter {
            exitBlock(tv: tv, prevParRange: prevParRange, cursorLoc: cursorLoc,
                      blockType: hasBullet ? .bullet : (hasQuote ? .quote : .todo))
            if hasQuote {
                DispatchQueue.main.async { self.refreshQuoteBorderViews(in: tv) }
            }
        } else if hasBullet {
            continueBulletLine(tv: tv, cursorLoc: cursorLoc)
        } else if isTodo {
            continueTodoLine(tv: tv, cursorLoc: cursorLoc)
        } else if hasQuote {
            continueQuoteLine(tv: tv, cursorLoc: cursorLoc)
        }

        // Read the LIVE length AFTER any mutations so the next call has a correct baseline.
        prevTextLength = tv.attributedText?.length ?? textLen
    }

    private enum BlockType: CustomStringConvertible {
        case bullet, quote, todo
        var description: String {
            switch self { case .bullet: "bullet"; case .quote: "quote"; case .todo: "todo" }
        }
    }

    /// Double-Enter: delete the empty prefix line and return to body text.
    private func exitBlock(tv: UITextView, prevParRange: NSRange,
                           cursorLoc: Int, blockType: BlockType) {
        guard let tvText = tv.attributedText else { return }
        let mutable = NSMutableAttributedString(attributedString: tvText)

        // How many characters to delete from the start of the previous (empty) paragraph.
        // "• " → 2, "│ " → 2, CheckboxAttachment+space → 2
        let prefixLen: Int
        switch blockType {
        case .bullet: prefixLen = prevParRange.length >= 3 ? 2 : 0   // "• \n" = 3 chars
        case .quote:  prefixLen = prevParRange.length >= 3 ? 2 : 0   // "│ \n" = 3 chars
        case .todo:   prefixLen = prevParRange.length >= 3 ? 2 : 0   // <att> + space + \n
        }

        if prefixLen > 0, prevParRange.location + prefixLen <= mutable.length {
            mutable.deleteCharacters(in: NSRange(location: prevParRange.location,
                                                  length: prefixLen))
        }

        // Clear paragraph style on both paragraphs (cursor shifted back by prefixLen).
        let adjusted = max(0, cursorLoc - prefixLen)
        let safeAdjusted = min(adjusted, max(0, mutable.length - 1))
        let curParRange  = safeAdjusted < mutable.length
            ? (mutable.string as NSString).paragraphRange(
                for: NSRange(location: safeAdjusted, length: 0))
            : NSRange(location: safeAdjusted, length: 0)

        func clear(_ r: NSRange) {
            guard r.length > 0, r.location < mutable.length else { return }
            let safe = NSRange(location: r.location,
                               length: min(r.length, mutable.length - r.location))
            guard safe.length > 0 else { return }
            mutable.addAttribute(.paragraphStyle, value: NSMutableParagraphStyle(), range: safe)
            mutable.removeAttribute(.foregroundColor, range: safe)
        }
        clear(NSRange(location: prevParRange.location,
                      length: max(0, prevParRange.length - prefixLen)))
        clear(curParRange)

        tv.attributedText = mutable
        tv.selectedRange  = NSRange(location: min(adjusted, mutable.length), length: 0)
        tv.typingAttributes = [
            .font:            UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
        ]
        prevTextLength = mutable.length
        attributedText = mutable
        log.debug("handleReturnKey: exitBlock type=\(blockType), cursor=\(adjusted)")
    }

    /// Continue a bullet line: insert "• " at the start of the new empty paragraph.
    private func continueBulletLine(tv: UITextView, cursorLoc: Int) {
        guard let tvText = tv.attributedText else { return }
        let mutable    = NSMutableAttributedString(attributedString: tvText)
        let safeInsert = max(0, min(cursorLoc, mutable.length))

        let bullet = NSAttributedString(string: "• ", attributes: [
            .font:            UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
        ])
        mutable.insert(bullet, at: safeInsert)

        // Hang-indent so wrapped lines align under the text (past "• ").
        let newParRange = (mutable.string as NSString).paragraphRange(
            for: NSRange(location: safeInsert, length: 0))
        if newParRange.length > 0, newParRange.location < mutable.length {
            let safeLen = min(newParRange.length, mutable.length - newParRange.location)
            if safeLen > 0 {
                let hangStyle = NSMutableParagraphStyle()
                hangStyle.headIndent = 14
                mutable.addAttribute(.paragraphStyle, value: hangStyle,
                                     range: NSRange(location: newParRange.location, length: safeLen))
            }
        }

        let newCursor = min(safeInsert + 2, mutable.length)
        tv.attributedText = mutable
        tv.selectedRange  = NSRange(location: newCursor, length: 0)
        tv.typingAttributes[.foregroundColor] = UIColor.label
        tv.typingAttributes[.font]            = UIFont.preferredFont(forTextStyle: .body)
        prevTextLength = mutable.length
        attributedText = mutable
        log.debug("handleReturnKey: continued bullet, cursor=\(newCursor)")
    }

    /// Continue a to-do line: insert a new unchecked CheckboxAttachment on the new line.
    private func continueTodoLine(tv: UITextView, cursorLoc: Int) {
        guard let tvText = tv.attributedText else { return }
        let mutable    = NSMutableAttributedString(attributedString: tvText)
        let safeInsert = max(0, min(cursorLoc, mutable.length))

        let checkbox  = CheckboxAttachment(checked: false)
        let item      = NSMutableAttributedString(attachment: checkbox)
        item.addAttribute(.foregroundColor, value: UIColor.label,
                           range: NSRange(location: 0, length: item.length))
        item.append(NSAttributedString(string: " ", attributes: [
            .font:            UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
        ]))
        mutable.insert(item, at: safeInsert)

        let newCursor = min(safeInsert + 2, mutable.length)
        tv.attributedText = mutable
        tv.selectedRange  = NSRange(location: newCursor, length: 0)
        tv.typingAttributes[.font]            = UIFont.preferredFont(forTextStyle: .body)
        tv.typingAttributes[.foregroundColor] = UIColor.label
        prevTextLength = mutable.length
        attributedText = mutable
        log.debug("handleReturnKey: continued todo, cursor=\(newCursor)")
    }

    // MARK: - Quote Border Overlay

    /// Draws a continuous blue left-border UIView behind every contiguous block of
    /// quote paragraphs (paragraphs starting with "│ ").
    /// The "│" glyphs have typographic line-height gaps between them; the UIView spans
    /// the full block height and fills those gaps — one tall continuous bar per block.
    private func refreshQuoteBorderViews(in tv: UITextView) {
        log.debug("refreshQuoteBorderViews: ENTER")
        let quoteViewTag = 0x71756F74
        tv.subviews.filter { $0.tag == quoteViewTag }.forEach { $0.removeFromSuperview() }

        let str = tv.attributedText?.string ?? ""
        guard !str.isEmpty else { return }
        let nsStr = str as NSString
        let totalLen = nsStr.length

        // Walk paragraphs and collect contiguous ranges of quote lines.
        var quoteBlocks: [NSRange] = []
        var blockStart: Int = -1
        var blockEnd:   Int = -1
        var loc = 0

        while loc <= totalLen {
            if loc < totalLen {
                let parRange = nsStr.paragraphRange(for: NSRange(location: loc, length: 0))
                var parText = nsStr.substring(with: parRange)
                if parText.hasSuffix("\n") { parText = String(parText.dropLast()) }
                let isQuote = parText.hasPrefix("│ ") || parText == "│"

                if isQuote {
                    if blockStart < 0 { blockStart = parRange.location }
                    blockEnd = parRange.location + parRange.length
                } else {
                    if blockStart >= 0 {
                        quoteBlocks.append(NSRange(location: blockStart, length: blockEnd - blockStart))
                        blockStart = -1; blockEnd = -1
                    }
                }
                let next = parRange.location + parRange.length
                if next <= loc { break }
                loc = next
            } else {
                if blockStart >= 0 {
                    quoteBlocks.append(NSRange(location: blockStart, length: blockEnd - blockStart))
                }
                break
            }
        }

        let lm    = tv.layoutManager
        let tc    = tv.textContainer
        let inset = tv.textContainerInset

        for block in quoteBlocks {
            lm.ensureLayout(forCharacterRange: block)
            let glyphRange = lm.glyphRange(forCharacterRange: block, actualCharacterRange: nil)
            var blockRect  = lm.boundingRect(forGlyphRange: glyphRange, in: tc)
            blockRect.origin.x += inset.left
            blockRect.origin.y += inset.top

            let barX = inset.left + 4
            let borderView = UIView(frame: CGRect(x: barX, y: blockRect.minY,
                                                  width: 3, height: blockRect.height))
            borderView.backgroundColor        = .systemBlue
            borderView.layer.cornerRadius     = 1.5
            borderView.isUserInteractionEnabled = false
            borderView.tag = quoteViewTag
            tv.insertSubview(borderView, at: 0)
            log.debug("refreshQuoteBorderViews: block \(block.location)+\(block.length) → y=\(blockRect.minY) h=\(blockRect.height)")
        }
        log.debug("refreshQuoteBorderViews: EXIT (\(quoteBlocks.count) blocks)")
    }

    /// Continue a quote line: insert "│  " at the start of the new paragraph.
    private func continueQuoteLine(tv: UITextView, cursorLoc: Int) {
        guard let tvText = tv.attributedText else { return }
        let mutable    = NSMutableAttributedString(attributedString: tvText)
        let safeInsert = max(0, min(cursorLoc, mutable.length))

        let bar = NSAttributedString(string: "│ ", attributes: [
            .font:            UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.clear,
        ])
        mutable.insert(bar, at: safeInsert)

        // Hang-indent so wrapped lines align under the quoted text.
        let newParRange = (mutable.string as NSString).paragraphRange(
            for: NSRange(location: safeInsert, length: 0))
        if newParRange.length > 0, newParRange.location < mutable.length {
            let safeLen = min(newParRange.length, mutable.length - newParRange.location)
            if safeLen > 0 {
                let quoteStyle = NSMutableParagraphStyle()
                quoteStyle.headIndent = 16
                quoteStyle.tailIndent = -16
                mutable.addAttribute(.paragraphStyle, value: quoteStyle,
                                     range: NSRange(location: newParRange.location, length: safeLen))
            }
        }

        let newCursor = min(safeInsert + 2, mutable.length)
        tv.attributedText = mutable
        tv.selectedRange  = NSRange(location: newCursor, length: 0)
        tv.typingAttributes[.foregroundColor] = UIColor.label
        tv.typingAttributes[.font]            = UIFont.preferredFont(forTextStyle: .body)
        prevTextLength = mutable.length
        attributedText = mutable
        log.debug("handleReturnKey: continued quote, cursor=\(newCursor)")
        DispatchQueue.main.async { self.refreshQuoteBorderViews(in: tv) }
    }

    // MARK: - Export (Issue #45 — native, no WKWebView)

    private func exportAsPDF() {
        log.info("exportAsPDF: exporting '\(task.title)'")
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            log.error("exportAsPDF: could not find root view controller")
            return
        }
        // Pass PKDrawing for composite PDF export (text + drawings)
        let drawing = pkCanvasView?.drawing
        NativeExportService.exportAsPDF(title: task.title, content: attributedText, drawing: drawing, from: root)
    }

    // MARK: - Inline Attachment Menu

    private struct AttachmentMenuItem: Identifiable {
        let id: String
        let icon: String
        let label: String
    }

    private var attachmentMenuItems: [AttachmentMenuItem] {
        var items: [AttachmentMenuItem] = []
        #if os(iOS)
        items += [
            .init(id: "scanText",      icon: "text.viewfinder", label: "Scan Text"),
            .init(id: "scanDocuments", icon: "doc.viewfinder",  label: "Scan Documents"),
            .init(id: "takePhoto",     icon: "camera",           label: "Take Photo"),
        ]
        #endif
        items += [
            .init(id: "choosePhoto",   icon: "photo",            label: "Choose Photo"),
            .init(id: "attachFile",    icon: "paperclip",        label: "Attach File"),
        ]
        return items
    }

    private func triggerAttachment(_ id: String) {
        // Capture cursor position BEFORE opening the sheet — the sheet
        // dismisses the keyboard which moves the cursor to 0.
        attachmentService.savedCursorPosition = richTextView?.selectedRange.location
        log.debug("triggerAttachment: saved cursor at \(attachmentService.savedCursorPosition.map(String.init) ?? "nil")")
        switch id {
        case "scanText":      attachmentService.scanText()
        case "scanDocuments": attachmentService.scanDocuments()
        case "takePhoto":     attachmentService.takePhotoOrVideo()
        case "choosePhoto":   attachmentService.choosePhotoOrVideo()
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
        // Issue #86: apply strikethrough to lines whose calendar events were deleted externally.
        applyStruckThroughStyling()
        // Sync so the first Return key press is detected correctly.
        prevTextLength = attributedText.length
    }

    /// Issue #86: Applies NSAttributedString strikethrough to body lines that correspond
    /// to BodyCalendarEvent records with isStruck == true.
    private func applyStruckThroughStyling() {
        let struckRecords = (task.bodyCalendarEvents ?? []).filter { $0.isStruck }
        guard !struckRecords.isEmpty else { return }
        log.debug("applyStruckThroughStyling: \(struckRecords.count) struck record(s) to check")

        let mutable = NSMutableAttributedString(attributedString: attributedText)
        let nsText = mutable.string as NSString
        var location = 0
        var applied = 0

        // Use paragraphRange (NSString API) instead of manual +1 charIndex so that
        // CRLF, CR, Unicode line-separator, and other multi-char newlines are handled
        // correctly. Manual +1 would drift and produce out-of-bounds ranges.
        while location < nsText.length {
            let paraRange = nsText.paragraphRange(for: NSRange(location: location, length: 0))
            guard paraRange.length > 0 else { break }

            // Content range = paragraph excluding its trailing newline/separator.
            var contentEnd = paraRange.location + paraRange.length
            if contentEnd > paraRange.location {
                let last = nsText.character(at: contentEnd - 1)
                if last == 0x000A || last == 0x000D || last == 0x2028 || last == 0x2029 {
                    contentEnd -= 1
                    // Collapse \r\n into a single separator
         
                    
                    
                    if last == 0x000A && contentEnd > paraRange.location,
                       nsText.character(at: contentEnd - 1) == 0x000D {
                        contentEnd -= 1
                    }
                }
            }
            let contentRange = NSRange(location: paraRange.location,
                                       length: max(0, contentEnd - paraRange.location))

            if contentRange.length > 0 {
                let line = nsText.substring(with: contentRange)
                let cleaned = line
                    .replacingOccurrences(of: "\u{FFFC}", with: "")
                    .trimmingCharacters(in: .whitespaces)

                if !cleaned.isEmpty,
                   struckRecords.contains(where: { BodyEventSyncService.fuzzyMatch($0.lineText, cleaned) >= 0.80 }) {
                    // Defensive bounds check before mutating attributed string.
                    guard contentRange.location + contentRange.length <= mutable.length else {
                        log.warning("applyStruckThroughStyling: range \(contentRange.location)+\(contentRange.length) out of bounds (\(mutable.length)) — skipping")
                        break
                    }
                    mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                    mutable.addAttribute(.foregroundColor, value: UIColor.secondaryLabel, range: contentRange)
                    // Auto-check any □ checkbox on this line so the visual matches ☑-checked lines.
                    // Collect checkbox ranges first — safe mutation pattern (no mutation during enumeration).
                    var uncheckedRanges: [(CheckboxAttachment, NSRange)] = []
                    mutable.enumerateAttribute(.attachment, in: contentRange, options: []) { value, cbRange, _ in
                        if let cb = value as? CheckboxAttachment, !cb.isChecked {
                            uncheckedRanges.append((cb, cbRange))
                        }
                    }
                    for (cb, cbRange) in uncheckedRanges {
                        cb.toggle()
                        mutable.removeAttribute(.attachment, range: cbRange)
                        mutable.addAttribute(.attachment, value: cb, range: cbRange)
                    }
                    applied += 1
                    log.debug("applyStruckThroughStyling: struck '\(cleaned)' (auto-checked \(uncheckedRanges.count) checkbox(es))")
                }
            }

            location = paraRange.location + paraRange.length
        }

        log.debug("applyStruckThroughStyling: applied \(applied) strike(s)")
        attributedText = mutable
    }

    private func onSelectionChanged(_ range: NSRange) {
        // Re-entrancy guard: if we're already processing a selection change,
        // skip this call to prevent the infinite loop:
        // onSelectionChanged → @State update → SwiftUI re-render → selectedRange fires → onSelectionChanged
        guard !isProcessingSelectionChange else { return }
        isProcessingSelectionChange = true
        defer { isProcessingSelectionChange = false }
        log.debug("onSelectionChanged: ENTER range=\(range.location)+\(range.length)")

        let hasSelection = range.length > 0

        // Check if the selection contains an attachment (image, etc.)
        // If so: hide palette + dismiss keyboard — no text formatting applies to attachments.
        var selectionIsAttachment = false
        if hasSelection, let tv = richTextView {
            // Use tv.textStorage instead of tv.attributedText (Issue #89).
            // tv.attributedText creates a full COPY of the text — if called during
            // a TextKit layout pass or mode switch, it crashes with EXC_BAD_ACCESS.
            // textStorage is the live backing store, always safe to read.
            let nsText: NSTextStorage = tv.textStorage
            let safeLen = min(range.location + range.length, nsText.length) - range.location
            let safeRange = NSRange(location: min(range.location, nsText.length), length: max(0, safeLen))
            if safeRange.length > 0 {
                nsText.enumerateAttribute(.attachment, in: safeRange, options: []) { val, _, stop in
                    if val != nil {
                        selectionIsAttachment = true
                        stop.pointee = true
                    }
                }
            }
        }

        if selectionIsAttachment {
            log.debug("onSelectionChanged: selection contains attachment — clearing selection, hiding palette")
            withAnimation(.easeInOut(duration: 0.2)) { showColorPalette = false }
            selectionGlobalRect = .zero
            // Clear selection to remove blue handles — place cursor after the attachment instead
            if let tv = richTextView {
                let afterAttachment = min(range.location + range.length, (tv.text as NSString).length)
                tv.selectedRange = NSRange(location: afterAttachment, length: 0)
                log.debug("onSelectionChanged: cleared selection, cursor at \(afterAttachment)")
            }
            return
        }

        if hasSelection, let tv = richTextView {
            let nsLen = (tv.text as NSString).length
            let loc = min(range.location, max(0, nsLen))
            let len = min(range.length, nsLen - loc)
            if len > 0,
               let start = tv.position(from: tv.beginningOfDocument, offset: loc),
               let end   = tv.position(from: start, offset: len),
               let tRange = tv.textRange(from: start, to: end) {
                let selRects = tv.selectionRects(for: tRange)
                    .map { tv.convert($0.rect, to: nil) }
                    .filter { $0.height > 0 }
                if !selRects.isEmpty {
                    let minY = selRects.map(\.minY).min()!
                    let maxY = selRects.map(\.maxY).max()!
                    let minX = selRects.map(\.minX).min()!
                    let maxX = selRects.map(\.maxX).max()!
                    selectionGlobalRect = CGRect(x: minX, y: minY,
                                                 width: maxX - minX,
                                                 height: maxY - minY)
                } else {
                    selectionGlobalRect = .zero
                }
            } else {
                selectionGlobalRect = .zero
            }
        } else {
            selectionGlobalRect = .zero
        }
        if hasSelection { savedColorSelection = range }
        withAnimation(.easeInOut(duration: 0.2)) { showColorPalette = hasSelection }

        // UIKit resets typingAttributes to match text at new cursor position on every move.
        if let color = activeFontColor, let tv = richTextView {
            tv.typingAttributes[.foregroundColor] = color
        }
    }

    private func saveBody() {
        // Always read from the live UITextView — the @State attributedText binding lags
        // behind normal typing because RichTextKit's updateUIView() is intentionally empty.
        // Fall back to richTextContext.attributedString (kept live by RichTextKit) before
        // the stale @State copy, so saves triggered by scenePhase are still accurate.
        let tvText = richTextView?.attributedText
        let liveText = tvText ?? richTextContext.attributedString
        log.info("saveBody: richTextView=\(self.richTextView == nil ? "NIL" : "ok"), tvChars=\(tvText?.length ?? -1), ctxChars=\(self.richTextContext.attributedString.length), stateChars=\(self.attributedText.length), using=\(liveText.length) chars for '\(self.task.title)'")
        NoteBodyBinding.save(liveText, into: task,
                             onSaveError: { saveError = $0 })
        // Flush to the persistent store immediately so @Query(filter:) and CloudKit
        // never see stale data when the view disappears.
        do {
            try modelContext.save()
        } catch {
            log.error("saveBody: modelContext.save() failed — \(error.localizedDescription)")
        }
        // Issue #63: scan title + body for a date and sync to Apple Calendar.
        // Fire-and-forget — never blocks the UI.
        let bodyText = liveText.string
        let t = task
        Task { await CalendarSyncService.shared.syncTaskIfNeeded(t, bodyText: bodyText) }
        // Issue #82: sync body-line dates to individual calendar events.
        // Pass checked checkbox lines so their events get deleted (subtask done → no reminder).
        let ctx = modelContext
        let checked = extractCheckedLines(from: liveText)
        Task { await CalendarSyncCoordinator.shared.syncBodyEvents(bodyText: bodyText, task: t, context: ctx, checkedLines: checked) }
        log.debug("saveBody: EXIT (async calendar+bodyEvent sync dispatched)")
    }

    // MARK: - Calendar Sync (Issue #63)
    // Logic lives in CalendarSyncService.syncTaskIfNeeded(_:bodyText:)

    /// Extract line texts that have a checked checkbox (strikethrough).
    /// Used to tell BodyEventSyncService to delete calendar events for completed subtasks.
    private func extractCheckedLines(from attrText: NSAttributedString) -> Set<String> {
        var checked = Set<String>()
        let nsStr = attrText.string as NSString
        var loc = 0
        while loc < nsStr.length {
            let lineRange = nsStr.lineRange(for: NSRange(location: loc, length: 0))
            // Check if this line has a CheckboxAttachment that's checked
            var hasCheckedBox = false
            attrText.enumerateAttribute(.attachment, in: lineRange, options: []) { val, _, stop in
                if let cb = val as? CheckboxAttachment, cb.isChecked {
                    hasCheckedBox = true
                    stop.pointee = true
                }
            }
            if hasCheckedBox {
                let lineText = nsStr.substring(with: lineRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    // Strip the checkbox character (U+FFFC) and leading space
                    .replacingOccurrences(of: "\u{FFFC}", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if !lineText.isEmpty {
                    checked.insert(lineText)
                }
            }
            loc = NSMaxRange(lineRange)
        }
        return checked
    }

    // MARK: - Body Event Debounce (Issue #84)

    /// Resets the 2-second debounce timer. When the timer fires and a newline
    /// was detected, triggers a body-line event sync without a full saveBody().
    private func scheduleBodyEventSync() {
        log.debug("scheduleBodyEventSync: ENTER")
        bodyEventDebounceTimer?.invalidate()
        bodyEventDebounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
            Task { @MainActor in
                guard newlineDetectedSinceLastSync else { return }
                newlineDetectedSinceLastSync = false
                let tvText = richTextView?.attributedText
                let liveText = tvText ?? richTextContext.attributedString
                let bodyText = liveText.string
                let t = task
                let ctx = modelContext
                let checked = extractCheckedLines(from: liveText)
                log.info("bodyEventDebounce: firing sync for '\(t.title)' (\(checked.count) checked lines)")
                Task { await CalendarSyncCoordinator.shared.syncBodyEvents(bodyText: bodyText, task: t, context: ctx, checkedLines: checked) }
            }
        }
    }
}


// MARK: - _TaskHeaderView
// Date stamp + editable title + hairline divider.
// Private sub-view extracted from TaskDetailView (Issue #90).
private struct _TaskHeaderView: View {
    @Bindable var task: TaskItem

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy 'at' h:mma"
        return formatter.string(from: task.createdAt)
    }

    var body: some View {
        Group {
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(Color.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            TextField("Untitled", text: $task.title, axis: .vertical)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.primaryText)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .accessibilityIdentifier("task-title-field")
                .onSubmit {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            Rectangle()
                .fill(Color.primaryText.opacity(0.15))
                .frame(height: 1)
                .padding(.horizontal, 20)
        }
    }
}

// AttachmentCoordinator and AttachmentPresenters removed — replaced by AttachmentService (Issue #49)

// MARK: - DataScannerWrapperView (VisionKit live text capture)
// Camera/scanner hardware — iOS only, hidden on Mac Catalyst

#if os(iOS)
@MainActor
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
        // Apple docs: present first, THEN start scanning.
        // startScanning() is deferred to updateUIViewController
        // so the view controller is fully in the hierarchy.
        return scanner
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        // Start scanning only once the scanner is presented in the view hierarchy.
        guard let scanner = uiViewController as? DataScannerViewController,
              !scanner.isScanning else { return }
        do {
            try scanner.startScanning()
        } catch {
            Logger(subsystem: "notes.Note-taking", category: "DataScanner")
                .error("startScanning failed: \(error.localizedDescription)")
        }
    }

    /// Called when the sheet is about to dismiss — stop the camera first.
    static func dismantleUIViewController(_ uiViewController: UIViewController, coordinator: Coordinator) {
        guard let scanner = uiViewController as? DataScannerViewController else { return }
        scanner.stopScanning()
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScan: (String) -> Void
        weak var scanner: DataScannerViewController?

        init(onScan: @escaping (String) -> Void) { self.onScan = onScan }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            if case .text(let text) = item {
                dataScanner.stopScanning()
                // onScan sets activeSheet = nil → SwiftUI dismisses the sheet.
                // Do NOT also call dataScanner.dismiss() — double-dismiss crashes.
                self.onScan(text.transcript)
            }
        }
    }
}
#endif // os(iOS) — DataScannerWrapperView

// MARK: - PhotoPickerView (Images only, multi-select)

struct PhotoPickerView: UIViewControllerRepresentable {
    let onPick: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images
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
            // DO NOT dismiss here — SwiftUI will tear down the sheet binding
            // and crash when onPick tries to mutate &attributedText.
            // Instead, load images via loadObject (simpler, synchronous callback),
            // deliver each one, THEN let the onPick handler dismiss the sheet.
            guard !results.isEmpty else {
                print("PhotoPicker: no results selected")
                picker.dismiss(animated: true)
                return
            }
            print("PhotoPicker: user selected \(results.count) photo(s)")

            let total = results.count
            var remaining = total
            let onPick = self.onPick

            for (index, result) in results.enumerated() {
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    defer {
                        remaining -= 1
                        if remaining == 0 {
                            print("PhotoPicker: all \(total) photo(s) delivered — dismissing")
                            DispatchQueue.main.async { picker.dismiss(animated: true) }
                        }
                    }
                    if let error {
                        print("PhotoPicker: photo \(index + 1)/\(total) loadObject error — \(error.localizedDescription)")
                        return
                    }
                    guard let image = object as? UIImage else {
                        print("PhotoPicker: photo \(index + 1)/\(total) — not a UIImage")
                        return
                    }
                    // Downsample to 1440px max to prevent OOM with 48MP photos
                    let resized = Self.downsample(image, maxDimension: 1440)
                    guard let jpeg = resized.jpegData(compressionQuality: 0.85) else {
                        print("PhotoPicker: photo \(index + 1)/\(total) — JPEG compression failed")
                        return
                    }
                    print("PhotoPicker: photo \(index + 1)/\(total) ready (\(jpeg.count) bytes, \(Int(resized.size.width))×\(Int(resized.size.height)))")
                    DispatchQueue.main.async { onPick(jpeg) }
                }
            }
        }

        /// Downsample image so longest side ≤ maxDimension.
        private static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
            let size = image.size
            let longest = max(size.width, size.height)
            guard longest > maxDimension else { return image }
            let scale = maxDimension / longest
            let newSize = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
            return UIGraphicsImageRenderer(size: newSize).image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
        }
    }
}

// MARK: - CameraPickerView (Photo only)
// Camera hardware — iOS only

#if os(iOS)
struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.mediaTypes = [UTType.image.identifier]
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
#endif // os(iOS) — CameraPickerView

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
// Document scanner camera — iOS only

#if os(iOS)
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
#endif // os(iOS) — DocumentScannerView

// MARK: - SlashMenuKeyInterceptor
// Thin UIView that intercepts ↑/↓/↵/⎋ via UIKeyCommand when it holds first responder.
// On iPad/Mac, TaskDetailView transfers first responder here while the slash menu is
// visible so arrow keys navigate menu rows instead of moving the text cursor.

final class SlashMenuKeyInterceptor: UIView {
    var onMoveDown: (() -> Void)?
    var onMoveUp:   (() -> Void)?
    var onSelect:   (() -> Void)?
    var onDismiss:  (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        let down = UIKeyCommand(input: UIKeyCommand.inputDownArrow, modifierFlags: [], action: #selector(keyDown))
        down.discoverabilityTitle = "Next item"
        let up = UIKeyCommand(input: UIKeyCommand.inputUpArrow, modifierFlags: [], action: #selector(keyUp))
        up.discoverabilityTitle = "Previous item"
        let ret = UIKeyCommand(input: "\r", modifierFlags: [], action: #selector(keyReturn))
        ret.discoverabilityTitle = "Select"
        let esc = UIKeyCommand(input: UIKeyCommand.inputEscape, modifierFlags: [], action: #selector(keyEscape))
        esc.discoverabilityTitle = "Dismiss"
        return [down, up, ret, esc]
    }

    @objc private func keyDown()   { onMoveDown?() }
    @objc private func keyUp()     { onMoveUp?() }
    @objc private func keyReturn() { onSelect?() }
    @objc private func keyEscape() { onDismiss?() }
}

/// UIViewRepresentable wrapper — keeps the interceptor in the UIKit hierarchy so it can
/// become first responder. Its callbacks are wired in TaskDetailView's .background modifier.
private struct KeyInterceptorRepresentable: UIViewRepresentable {
    let interceptor: SlashMenuKeyInterceptor
    let onMoveDown: () -> Void
    let onMoveUp:   () -> Void
    let onSelect:   () -> Void
    let onDismiss:  () -> Void

    func makeUIView(context: Context) -> SlashMenuKeyInterceptor {
        interceptor.onMoveDown = onMoveDown
        interceptor.onMoveUp   = onMoveUp
        interceptor.onSelect   = onSelect
        interceptor.onDismiss  = onDismiss
        return interceptor
    }
    func updateUIView(_ uiView: SlashMenuKeyInterceptor, context: Context) {
        uiView.onMoveDown = onMoveDown
        uiView.onMoveUp   = onMoveUp
        uiView.onSelect   = onSelect
        uiView.onDismiss  = onDismiss
    }
}

// MARK: - FontSizeHoldButton
// Fires `action` immediately on tap, and then repeatedly (~8×/sec) while held.

private struct FontSizeHoldButton: View {
    let icon: String
    let action: () -> Void

    @State private var holdTimer: Timer?
    @State private var isHolding = false

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 18))
            .foregroundStyle(Color.primary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isHolding else { return }
                        isHolding = true
                        action() // fire once immediately
                        // After 0.4s delay, start repeating at ~125ms interval
                        let fireDate = Date().addingTimeInterval(0.4)
                        holdTimer = Timer(fire: fireDate, interval: 0.125, repeats: true) { _ in
                            DispatchQueue.main.async { action() }
                        }
                        RunLoop.main.add(holdTimer!, forMode: .common)
                    }
                    .onEnded { _ in
                        stopHold()
                    }
            )
    }

    private func stopHold() {
        isHolding = false
        holdTimer?.invalidate()
        holdTimer = nil
    }
}

#endif
