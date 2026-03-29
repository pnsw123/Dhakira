import SwiftUI

// MARK: - WidgetPreviewLayout
// Fake home-screen showing widget size previews. No WidgetKit import — just sized rectangles.
// Issue #74 — https://github.com/pnsw123/prod-note/issues/74

struct WidgetPreviewLayout: View {
    let theme: AppTheme

    var body: some View {
        VStack(spacing: 8) {
            // systemMedium — 329×155 pt
            FakeWidgetView(theme: theme)
                .frame(width: 329, height: 155)
                .clipShape(RoundedRectangle(cornerRadius: 22))

            HStack(spacing: 8) {
                // systemSmall — 155×155 pt
                FakeWidgetView(theme: theme)
                    .frame(width: 155, height: 155)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                FakeWidgetView(theme: theme)
                    .frame(width: 155, height: 155)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
            }
        }
        // NOTE: PhoneMockupView already scales by 0.35 — no additional scaleEffect here
    }
}

// MARK: - FakeWidgetView

struct FakeWidgetView: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            Color(theme.screenBackground)
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "checklist")
                    .font(.title2)
                    .foregroundStyle(Color(theme.accentColor))
                Text("ProdNote")
                    .font(.caption.bold())
                    .foregroundStyle(Color(theme.primaryText))
                Text("3 tasks today")
                    .font(.caption2)
                    .foregroundStyle(Color(theme.secondaryText))
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
