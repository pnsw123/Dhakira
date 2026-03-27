import SwiftUI

enum SortOption: String, CaseIterable {
    case manual = "Manual"
    case creationDate = "Creation Date"
}

struct SettingsMenuView: View {
    @Binding var sortBy: SortOption
    var onThemeTapped: () -> Void = {}

    var body: some View {
        Menu {
            Button(action: onThemeTapped) {
                Label("Theme", systemImage: "paintbrush")
            }

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
                Label("Sort By", systemImage: "arrow.up.arrow.down")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 22))
        }
    }
}
