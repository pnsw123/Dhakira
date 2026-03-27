import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: TaskItem
    var onToggleComplete: () -> Void = {}
    var onTapDetail: () -> Void = {}

    @State private var showPriorityPicker = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main card
            VStack(alignment: .leading, spacing: 6) {
                // Task title
                HStack(spacing: 10) {
                    // Subtle completion tap target on the left
                    Button(action: onToggleComplete) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20, weight: .light))
                            .foregroundStyle(
                                task.isCompleted
                                ? Color.forPriority(task.priority)
                                : Color.secondary.opacity(0.4)
                            )
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)

                    TextField("New Task", text: $task.title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                        .strikethrough(task.isCompleted, color: Color.secondary)
                }

                // "..." to open detail page
                Button(action: onTapDetail) {
                    HStack(spacing: 2) {
                        Circle().fill(Color.secondary.opacity(0.5)).frame(width: 3.5, height: 3.5)
                        Circle().fill(Color.secondary.opacity(0.5)).frame(width: 3.5, height: 3.5)
                        Circle().fill(Color.secondary.opacity(0.5)).frame(width: 3.5, height: 3.5)
                    }
                    .frame(minWidth: 44, minHeight: 24, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(.leading, 42)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .padding(.trailing, 20) // space for tab
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 0.5)
                    }
            }

            // Priority color tab — small colored bookmark on TOP-RIGHT,
            // sticking slightly above the card edge like a folder tab
            Button {
                showPriorityPicker.toggle()
            } label: {
                UnevenRoundedRectangle(
                    topLeadingRadius: 3,
                    bottomLeadingRadius: 1,
                    bottomTrailingRadius: 1,
                    topTrailingRadius: 3
                )
                .fill(Color.forPriority(task.priority))
                .frame(width: 16, height: 22)
                .shadow(
                    color: Color.forPriority(task.priority).opacity(0.35),
                    radius: 3, y: 1
                )
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .offset(x: -10, y: -9)
            .popover(isPresented: $showPriorityPicker) {
                PriorityPickerView(selectedPriority: $task.priority)
                    .presentationCompactAdaptation(.popover)
            }
        }
        .opacity(task.isCompleted ? 0.45 : 1.0)
        .sensoryFeedback(.success, trigger: task.isCompleted)
    }
}
