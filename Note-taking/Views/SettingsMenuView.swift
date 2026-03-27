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
            Section("Sort By") {
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
            }

            Section {
                Toggle(isOn: $showCompleted) {
                    Label("Show Completed", systemImage: "checkmark.circle")
                }
            }

            Section {
                Button(action: onThemeTapped) {
                    Label("Theme", systemImage: "paintbrush")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 20))
        }
    }
}
