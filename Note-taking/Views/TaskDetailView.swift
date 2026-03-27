import SwiftUI
import SwiftData

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @State private var html: String = ""
    @State private var showToolbar = true
    @State private var isDrawingMode = false
    @State private var showAttachmentMenu = false

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy 'at' h:mma"
        return formatter.string(from: task.createdAt)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // Title
            TextField("Task Title", text: $task.title)
                .font(.title2.bold())
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // Content area — either rich text or drawing
            if isDrawingMode {
                DrawingCanvasView(drawingData: $task.drawingData)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TipTapEditorView(html: $html)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
            }

            // Bottom toolbar (Apple Notes style)
            if showToolbar {
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
                Button { shareTask() } label: {
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
        .onAppear { loadBody() }
        .onDisappear { saveBody() }
    }

    // MARK: - Apple Notes style toolbar
    private var editorToolbar: some View {
        HStack(spacing: 0) {
            toolbarButton("textformat") { /* Aa formatting */ }
            toolbarButton("checklist") { /* checklist toggle */ }
            toolbarButton("tablecells") { /* table insert */ }
            toolbarButton("paperclip") { showAttachmentMenu = true }
            toolbarButton("pencil.tip.crop.circle") { isDrawingMode.toggle() }
            toolbarButton("list.bullet") { /* paragraph/list */ }
        }
        .frame(height: 44)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.primary.opacity(0.08), radius: 8, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func toolbarButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Attachment sheet (Apple Notes style)
    private var attachmentSheet: some View {
        NavigationStack {
            List {
                attachmentRow(icon: "text.viewfinder", title: "Scan Text")
                attachmentRow(icon: "doc.viewfinder", title: "Scan Documents")
                attachmentRow(icon: "camera", title: "Take Photo or Video")
                attachmentRow(icon: "photo.on.rectangle", title: "Choose Photo or Video")
                attachmentRow(icon: "waveform", title: "Record Audio")
                attachmentRow(icon: "doc", title: "Attach File")
            }
            .navigationTitle("Attachments")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showAttachmentMenu = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func attachmentRow(icon: String, title: String) -> some View {
        Button {
            showAttachmentMenu = false
        } label: {
            Label(title, systemImage: icon)
        }
    }

    // MARK: - Actions
    private func loadBody() {
        if let data = task.body, let s = String(data: data, encoding: .utf8) {
            html = s
        }
    }

    private func saveBody() {
        let meaningful = html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&[a-zA-Z0-9#]+;", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        task.body = meaningful.isEmpty ? nil : html.data(using: .utf8)
    }

    private func shareTask() {}

    private func toggleComplete() {
        withAnimation {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
        }
    }
}
