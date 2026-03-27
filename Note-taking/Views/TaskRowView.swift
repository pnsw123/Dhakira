import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var onToggleComplete: () -> Void = {}
    var onTapDetail: () -> Void = {}

    @State private var showPriorityPicker = false

    var body: some View {
        HStack(spacing: 0) {
            // Card content — single compact row
            HStack(spacing: 10) {
                // Checkbox
                Button(action: onToggleComplete) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(
                            task.isCompleted
                            ? Color.forPriority(task.priority)
                            : Color.secondary.opacity(0.35)
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)

                // Title
                TextField("New Task", text: $task.title)
                    .font(.system(size: 16))
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(task.isCompleted)

                // "..." detail button (right side, not a separate row)
                Button(action: onTapDetail) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
            }
            .padding(.leading, 4)
            .padding(.trailing, 2)

            // Bookmark tab on the right edge — small, attached to the card
            Button {
                showPriorityPicker.toggle()
            } label: {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.forPriority(task.priority))
                    .frame(width: 6, height: 28)
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 44)
            .popover(isPresented: $showPriorityPicker) {
                priorityPicker
            }
        }
        .frame(height: 48)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.04))
        }
        .opacity(task.isCompleted ? 0.4 : 1.0)
        .sensoryFeedback(.success, trigger: task.isCompleted)
    }

    // Tiny color picker — just 3 small dots
    private var priorityPicker: some View {
        HStack(spacing: 10) {
            priorityDot("high", Color.priorityHigh)
            priorityDot("medium", Color.priorityMedium)
            priorityDot("default", Color.priorityDefault)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .presentationCompactAdaptation(.popover)
    }

    private func priorityDot(_ priority: String, _ color: Color) -> some View {
        Button {
            task.priority = priority
            showPriorityPicker = false
        } label: {
            Circle()
                .fill(color)
                .frame(width: 20, height: 20)
                .overlay {
                    if task.priority == priority {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
