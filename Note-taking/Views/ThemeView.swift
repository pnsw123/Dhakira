import SwiftUI

struct ThemeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "paintbrush")
                .font(.system(size: 56))
                .foregroundStyle(Color.secondary)

            Text("Themes coming soon")
                .font(.title2.bold())
                .foregroundStyle(Color.primary)

            Text("Custom themes and color schemes will be available in a future update.")
                .font(.body)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Theme")
    }
}
