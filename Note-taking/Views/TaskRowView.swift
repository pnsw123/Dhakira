import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var onToggleComplete: () -> Void = {}
    var onTapDetail: () -> Void = {}

    @State private var showPriorityPicker = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Layer 1: Card background
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.1), lineWidth: 0.5)
                )

            // Layer 2: Task content
            HStack(spacing: 10) {
                Button(action: onToggleComplete) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            task.isCompleted
                            ? Color.forPriority(task.priority)
                            : Color.secondary.opacity(0.3)
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())

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
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)

            // Layer 3: Bookmark tab — protrudes above card
            bookmarkTab
                .offset(y: -8)
                .padding(.trailing, 16)
        }
        .padding(.top, 10)
        .opacity(task.isCompleted ? 0.35 : 1.0)
        .sensoryFeedback(.success, trigger: task.isCompleted)
    }

    private var bookmarkTab: some View {
        Button { showPriorityPicker.toggle() } label: {
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 4
            )
            .fill(Color.forPriority(task.priority))
            .frame(width: 14, height: 18)
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .popover(isPresented: $showPriorityPicker) {
            HStack(spacing: 8) {
                colorDot("high", Color.priorityHigh)
                colorDot("medium", Color.priorityMedium)
                colorDot("default", Color.priorityDefault)
            }
            .padding(10)
            .presentationCompactAdaptation(.popover)
        }
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
