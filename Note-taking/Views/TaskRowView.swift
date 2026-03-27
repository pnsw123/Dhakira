import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var onToggleComplete: () -> Void = {}
    var onTapDetail: () -> Void = {}

    @State private var showPriorityPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Bookmark tab — sits ABOVE the row, right-aligned
            HStack {
                Spacer()
                Button { showPriorityPicker.toggle() } label: {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 3,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 3
                    )
                    .fill(Color.forPriority(task.priority))
                    .frame(width: 14, height: 10)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPriorityPicker) {
                    HStack(spacing: 8) {
                        colorDot("high", Color.priorityHigh)
                        colorDot("medium", Color.priorityMedium)
                        colorDot("default", Color.priorityDefault)
                    }
                    .padding(10)
                    .presentationCompactAdaptation(.popover)
                }
                .padding(.trailing, 16)
            }

            // Task row
            HStack(spacing: 10) {
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

                TextField("New Task", text: $task.title)
                    .font(.system(size: 16))
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(task.isCompleted)

                Button(action: onTapDetail) {
                    Text("···")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .opacity(task.isCompleted ? 0.35 : 1.0)
        .sensoryFeedback(.success, trigger: task.isCompleted)
    }

    private func colorDot(_ key: String, _ color: Color) -> some View {
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
