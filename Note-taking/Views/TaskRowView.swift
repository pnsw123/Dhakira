import SwiftUI
import SwiftData

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

    /// Three-dots: blue if task has real content (excluding title/date), black otherwise
    private var dotsColor: Color {
        let hasRealContent: Bool = {
            if let bodyData = task.body,
               let bodyText = String(data: bodyData, encoding: .utf8) {
                let stripped = bodyText
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !stripped.isEmpty { return true }
            }
            if task.drawingData != nil { return true }
            if let attachments = task.attachments, !attachments.isEmpty { return true }
            return false
        }()
        return hasRealContent ? .accentColor : .primary
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
                                : Color.secondary.opacity(0.3)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())

                    TextField("New Task", text: $task.title)
                        .font(.system(size: 15))
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        .strikethrough(task.isCompleted)
                }

                // Line 2: Three-dots
                HStack {
                    Spacer().frame(width: 40)
                    Button(action: onTapDetail) {
                        Text("···")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(dotsColor.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .frame(height: 16)
                    .contentShape(Rectangle())
                }
            }
            .padding(.leading, 4)
            .padding(.trailing, 12)
            .padding(.vertical, 8)

            // Pennant flag — visible for non-default, invisible tap target always
            Button { cyclePriority() } label: {
                ZStack(alignment: .top) {
                    Color.clear.frame(width: 44, height: 44)
                    PennantShape()
                        .fill(Color.forPriority(task.priority))
                        .frame(width: 22, height: 36)
                        .opacity(task.priority == "default" ? 0 : 1)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .sensoryFeedback(.selection, trigger: task.priority)
            .offset(x: -4, y: 0)
        }
        .opacity(task.isCompleted ? 0.35 : 1.0)
        .sensoryFeedback(.success, trigger: task.isCompleted)
    }

    private func cyclePriority() {
        guard let currentIndex = priorityCycle.firstIndex(of: task.priority) else {
            task.priority = "medium"
            return
        }
        let nextIndex = (currentIndex + 1) % priorityCycle.count
        task.priority = priorityCycle[nextIndex]
    }
}
