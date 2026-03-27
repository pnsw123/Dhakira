import SwiftUI
import SwiftData
import MarkupEditor

struct TaskDetailView: View {
    @Bindable var task: TaskItem
    @Environment(\.dismiss) private var dismiss
    @State private var html: String = ""
    @State private var showToolbar = true
    @State private var showDrawing = false
    @State private var showAttachmentMenu = false

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM yyyy 'at' h:mma"
        return formatter.string(from: task.createdAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date header
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 20)

            // Task title
            TextField("Task Title", text: $task.title)
                .font(.title2.bold())
                .padding(.horizontal, 20)

            // Rich text editor
            MarkupEditorView(html: $html)
                .padding(.horizontal, 8)

            Spacer(minLength: 0)

            // Editor toolbar
            if showToolbar {
                EditorToolbarView(
                    onAttachment: {
                        showAttachmentMenu.toggle()
                    },
                    onMarkup: {
                        showDrawing.toggle()
                    }
                )
            }
        }
        .padding(.top, 8)
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
                Button {
                    shareTask()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .frame(minWidth: 44, minHeight: 44)
                }

                Button {
                    showToolbar.toggle()
                } label: {
                    Image(systemName: showToolbar ? "keyboard.chevron.compact.down" : "keyboard")
                        .frame(minWidth: 44, minHeight: 44)
                }

                Button {
                    toggleComplete()
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
        }
        .onAppear {
            loadBody()
        }
        .onDisappear {
            saveBody()
        }
        .sheet(isPresented: $showAttachmentMenu) {
            NavigationStack {
                AttachmentMenuView()
                    .navigationTitle("Attachments")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showAttachmentMenu = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showDrawing) {
            NavigationStack {
                DrawingCanvasView(drawingData: $task.drawingData)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showDrawing = false
                            }
                        }
                    }
            }
        }
    }

    private func loadBody() {
        if let data = task.body, let bodyHtml = String(data: data, encoding: .utf8) {
            html = bodyHtml
        }
    }

    private func saveBody() {
        task.body = html.data(using: .utf8)
    }

    private func shareTask() {
        // Share functionality placeholder
    }

    private func toggleComplete() {
        withAnimation {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
        }
    }
}
