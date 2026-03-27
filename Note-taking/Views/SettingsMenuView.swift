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
            // Sort By — single row with submenu (like Apple Reminders)
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        sortBy = option
                    } label: {
                        if sortBy == option {
                            Label(option.rawValue, systemImage: "checkmark")
                        } else {
                            Text(option.rawValue)
                        }
                    }
                }
            } label: {
                Label {
                    VStack(alignment: .leading) {
                        Text("Sort By")
                        Text(sortBy.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }

            // Show Completed — single row
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
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 22))
        }
    }
}
