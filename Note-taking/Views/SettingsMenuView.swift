import SwiftUI

enum SortOption: String, CaseIterable {
    case creationDate = "Creation Date"
    case priority = "Priority"
}

struct SettingsMenuView: View {
    @Binding var sortBy: SortOption
    @Binding var showCompleted: Bool
    var onThemeTapped: () -> Void = {}

    var body: some View {
        Menu {
            // Sort By
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortBy = option
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if sortBy == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label("Sort By", systemImage: "arrow.up.arrow.down")
            }

            // Show Completed
            Button {
                showCompleted.toggle()
            } label: {
                Label(
                    showCompleted ? "Hide Completed" : "Show Completed",
                    systemImage: showCompleted ? "eye.slash" : "eye"
                )
            }

            Divider()

            // Theme
            Button(action: onThemeTapped) {
                Label("Theme", systemImage: "paintbrush")
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.body)
                .frame(minWidth: 44, minHeight: 44)
        }
    }
}
