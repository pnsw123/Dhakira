import SwiftUI

enum SortOption: String, CaseIterable {
    case manual = "Manual"
    case creationDate = "Creation Date"
    case priority = "Priority"
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
                .foregroundStyle(Color.themeAccent)
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: Circle())
                .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                #if targetEnvironment(macCatalyst)
                .padding(10)
                .contentShape(Rectangle())
                #endif
        }
        .tint(Color.themeAccent)
    }
}
