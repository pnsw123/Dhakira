import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var onToggleComplete: () -> Void = {}
    var onTapDetail: () -> Void = {}

    @State private var showPriorityPicker = false

    var body: some View {
        // Extra top padding so the bookmark tab has room to stick out
        VStack(spacing: 0) {
            // Bookmark tab — sits ABOVE the card, aligned to trailing
            HStack {
                Spacer()
                Button {
                    showPriorityPicker.toggle()
                } label: {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 4
                    )
                    .fill(Color.forPriority(task.priority))
                    .frame(width: 18, height: 14)
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 14)
                .popover(isPresented: $showPriorityPicker) {
                    PriorityPickerView(selectedPriority: $task.priority)
                        .presentationCompactAdaptation(.popover)
                }
                .padding(.trailing, 12)
            }

            // Main card
            VStack(alignment: .leading, spacing: 4) {
                // Title row with checkbox
                HStack(spacing: 10) {
                    Button(action: onToggleComplete) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22))
                            .foregroundStyle(
                                task.isCompleted
                                ? Color.forPriority(task.priority)
                                : Color.secondary.opacity(0.35)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)

                    TextField("New Task", text: $task.title)
                        .font(.body)
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        .strikethrough(task.isCompleted)
                }

                // "..." to open detail
                Button(action: onTapDetail) {
                    Text("···")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
                .padding(.leading, 54)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.secondary.opacity(0.05))
            }
        }
        .opacity(task.isCompleted ? 0.4 : 1.0)
        .sensoryFeedback(.success, trigger: task.isCompleted)
    }
}
