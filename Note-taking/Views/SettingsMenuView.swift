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
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.primary)
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: Circle())
                .glassEffect(.regular.interactive(), in: .circle)
        }
    }
}
