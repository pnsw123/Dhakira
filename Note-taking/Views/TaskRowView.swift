import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var onToggleComplete: () -> Void = {}
    var onTapDetail: () -> Void = {}

    @State private var showPriorityPicker = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Checkbox — flush left, aligned with text baseline
            Button(action: onToggleComplete) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .foregroundStyle(
                        task.isCompleted
                        ? Color.forPriority(task.priority)
                        : Color.secondary.opacity(0.3)
                    )
            }
            .buttonStyle(.plain)

            // Title — takes remaining space
            TextField("New Task", text: $task.title)
                .font(.system(size: 16))
                .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                .strikethrough(task.isCompleted)

            // "..." — subtle, tappable to open detail
            Button(action: onTapDetail) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.secondary.opacity(0.3))
            }
            .buttonStyle(.plain)

            // Color bookmark — right edge, prominent
            Button { showPriorityPicker.toggle() } label: {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.forPriority(task.priority))
                    .frame(width: 8, height: 32)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showPriorityPicker) {
                priorityPicker
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .opacity(task.isCompleted ? 0.35 : 1.0)
        .sensoryFeedback(.success, trigger: task.isCompleted)
    }

    private var priorityPicker: some View {
        HStack(spacing: 8) {
            dot("high", Color.priorityHigh)
            dot("medium", Color.priorityMedium)
            dot("default", Color.priorityDefault)
        }
        .padding(10)
        .presentationCompactAdaptation(.popover)
    }

    private func dot(_ key: String, _ color: Color) -> some View {
        Button {
            task.priority = key
            showPriorityPicker = false
        } label: {
            Circle().fill(color).frame(width: 18, height: 18)
                .overlay {
                    if task.priority == key {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
