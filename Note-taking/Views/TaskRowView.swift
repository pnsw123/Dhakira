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
    var onToggleComplete: () -> Void = {}
    var onTapDetail: () -> Void = {}

    private let priorityCycle = ["default", "medium", "high"]

    /// True if task has real content beyond title and creation date (Issue #53 — uses NoteBodyCodec)
    private var hasRealContent: Bool {
        if let bodyData = task.body,
           case .success(let bodyAttr) = NoteBodyCodec.decode(bodyData) {
            let stripped = bodyAttr.string.trimmingCharacters(in: .whitespacesAndNewlines)
            if !stripped.isEmpty { return true }
        }
        if let drawingData = task.drawingData, !drawingData.isEmpty { return true }
        if let attachments = task.attachments, !attachments.isEmpty { return true }
        return false
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Row content
            VStack(alignment: .leading, spacing: 2) {
                // Line 1: Checkbox + Title
                HStack(spacing: 10) {
                    Button(action: onToggleComplete) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                task.isCompleted
                                ? Color.forPriority(task.priority)
                                : Color.secondary.opacity(0.45)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())

                    TextField("New Task", text: $task.title, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        .strikethrough(task.isCompleted)
                        .lineLimit(1...2)
                }

                // Line 2: Asterisk — blue if has content, dim if empty
                HStack {
                    Spacer().frame(width: 40)
                    Button(action: onTapDetail) {
                        Image(systemName: "asterisk")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(
                                hasRealContent
                                ? Color.accentColor
                                : Color.secondary.opacity(0.25)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(height: 20)
                    .contentShape(Rectangle().size(CGSize(width: 44, height: 20)))
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 32)
            .padding(.vertical, 8)

            // Pennant flag
            Button { cyclePriority() } label: {
                ZStack(alignment: .top) {
                    Color.clear.frame(width: 44, height: 44)
                    PennantShape()
                        .fill(Color.forPriority(task.priority))
                        .frame(width: 14, height: 22)
                        .opacity(task.priority == "default" ? 0 : 1)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .sensoryFeedback(.selection, trigger: task.priority)
        }
        .opacity(task.isCompleted ? 0.35 : 1.0)
        .sensoryFeedback(.success, trigger: task.isCompleted)
    }

    private func cyclePriority() {
        guard let currentIndex = priorityCycle.firstIndex(of: task.priority) else {
            log.warning("cyclePriority: unknown priority '\(task.priority)' for '\(task.title)' — resetting to medium")
            task.priority = "medium"
            return
        }
        let nextIndex = (currentIndex + 1) % priorityCycle.count
        let newPriority = priorityCycle[nextIndex]
        log.info("cyclePriority: '\(task.title)' \(task.priority) → \(newPriority)")
        task.priority = newPriority
    }
}
