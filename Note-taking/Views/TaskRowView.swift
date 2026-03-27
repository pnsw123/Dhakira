import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var onToggleComplete: () -> Void = {}
    var onTapDetail: () -> Void = {}

    @State private var showPriorityPicker = false

    var body: some View {
        HStack(spacing: 0) {
            // Color bookmark tab on the left edge
            Rectangle()
                .fill(Color.forPriority(task.priority))
                .frame(width: 5)
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 12,
                        bottomLeadingRadius: 12
                    )
                )
                .onTapGesture { showPriorityPicker.toggle() }
                .popover(isPresented: $showPriorityPicker) {
                    PriorityPickerView(selectedPriority: $task.priority)
                        .presentationCompactAdaptation(.popover)
                }

            // Card content
            HStack(spacing: 12) {
                // Checkbox
                Button(action: onToggleComplete) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(
                            task.isCompleted
                            ? Color.forPriority(task.priority)
                            : Color.secondary
                        )
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)

                // Title
                TextField("New Task", text: $task.title)
                    .font(.body)
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(task.isCompleted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Detail "..." button
                Button(action: onTapDetail) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary)
                        .rotationEffect(.degrees(90))
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .padding(.vertical, 4)
        }
        .frame(minHeight: 56)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.08))
        }
        .opacity(task.isCompleted ? 0.5 : 1.0)
        .sensoryFeedback(.success, trigger: task.isCompleted)
    }
}
