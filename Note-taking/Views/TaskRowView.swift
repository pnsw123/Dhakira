import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "TaskRow")

/// Pennant shape — rectangle with a V-notch at the bottom
struct PennantShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: rect.width / 2, y: rect.height * 0.8))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }
}

struct TaskRowView: View {
    @Bindable var task: TaskItem
    /// True when this row is the newly created task being typed into inline.
    var isFocused: Bool = false
    var onToggleComplete: () -> Void = {}
    var onTapDetail: () -> Void = {}

    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isRegular: Bool { hSizeClass == .regular }

    /// Local focus state for the inline TextField — driven by the `isFocused` prop.
    @FocusState private var isEditing: Bool
    /// Cached — recomputed only when task.body / drawingData / attachments change.
    @State private var hasRealContent: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {

                // ── Tap zone 1: Checkbox ─────────────────────────────────────
                Button(action: onToggleComplete) {
                    ZStack {
                        if task.isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.forPriority(task.priority))
                        } else {
                            Circle()
                                .stroke(Color.checkboxInactive, lineWidth: 1.5)
                                .frame(width: 22, height: 22)
                        }
                    }
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .contentShape(Circle().size(CGSize(width: 36, height: 36)))
                .padding(.top, 1)

                if isFocused {
                    // ── Inline editing (new task just created via +) ──────────
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("New Task", text: $task.title, axis: .vertical)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(1...3)
                            .focused($isEditing)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("*")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.secondaryText.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    // ── Tap zone 2: Entire row content → detail ───────────────
                    Button(action: onTapDetail) {
                        VStack(alignment: .leading, spacing: 6) {

                            // Title + flag (flag stays top-right even for multi-line titles)
                            HStack(alignment: .top, spacing: 8) {
                                Text(task.title.isEmpty ? "New Task" : task.title)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(Color.primaryText)
                                    .strikethrough(task.isCompleted)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                PennantShape()
                                    .fill(Color.forPriority(task.priority))
                                    .frame(width: 11, height: 17)
                                    .opacity(task.priority == "default" ? 0 : 1)
                                    .padding(.top, 2)
                            }

                            // * — visual signal only (gray = empty, blue = has content)
                            Text("*")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(
                                    hasRealContent
                                        ? Color.themeAccent
                                        : Color.secondaryText.opacity(0.4)
                                )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, isRegular ? 36 : 20)
            .padding(.vertical, isRegular ? 14 : 10)

        }
        .opacity(task.isCompleted ? 0.35 : 1.0)
        .sensoryFeedback(.success, trigger: task.isCompleted)
        .onChange(of: isFocused) { _, focused in
            if focused { isEditing = true }
        }
        .task(id: task.body) {
            let bodyData    = task.body
            let drawingData = task.drawingData
            let attachments = task.attachments
            let result: Bool
            if let bodyData, case .success(let attr) = NoteBodyCodec.decode(bodyData) {
                result = !attr.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            } else if let drawingData, !drawingData.isEmpty {
                result = true
            } else if let attachments, !attachments.isEmpty {
                result = true
            } else {
                result = false
            }
            hasRealContent = result
        }
    }
}
