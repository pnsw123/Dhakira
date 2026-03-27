import SwiftUI

struct PriorityPickerView: View {
    @Binding var selectedPriority: String

    private let priorities: [(key: String, color: Color)] = [
        ("high", .priorityHigh),
        ("medium", .priorityMedium),
        ("default", .priorityDefault)
    ]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(priorities, id: \.key) { priority in
                Button {
                    selectedPriority = priority.key
                } label: {
                    Circle()
                        .fill(priority.color)
                        .frame(width: 28, height: 28)
                        .overlay {
                            if selectedPriority == priority.key {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
