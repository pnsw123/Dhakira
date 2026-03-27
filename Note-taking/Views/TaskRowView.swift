import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var isFocused: Bool = false
    var onToggleComplete: () -> Void = {}
    var onTapDetail: () -> Void = {}

    @State private var showPriorityPicker = false

    var body: some View {
        HStack(spacing: 0) {
            // Color marker bookmark tab on the left — tappable for priority
            Button {
                showPriorityPicker.toggle()
            } label: {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.forPriority(task.priority))
                    .frame(width: 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .popover(isPresented: $showPriorityPicker) {
                PriorityPickerView(selectedPriority: $task.priority)
                    .presentationCompactAdaptation(.popover)
            }

            HStack(spacing: 12) {
                // Checkbox
                Button(action: onToggleComplete) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(task.isCompleted ? Color.forPriority(task.priority) : Color.secondary)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)

                // Title
                TextField("New Task", text: $task.title)
                    .font(.body)
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .strikethrough(task.isCompleted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Detail button
                Button(action: onTapDetail) {
                    Image(systemName: "ellipsis")
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.trailing, 12)
            .padding(.vertical, 8)
        }
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sensoryFeedback(.success, trigger: task.isCompleted)
    }
}
