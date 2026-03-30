import SwiftUI

// MARK: - ThemeScope
// Two preview modes in ThemeDetailView — just switches what the phone mockup shows.
// The Apply button always applies the theme to BOTH app and widgets.
// Issue #74 — https://github.com/pnsw123/prod-note/issues/74

enum ThemeScope: String, CaseIterable, Identifiable {
    case app     = "App"
    case widgets = "Widgets"
    var label: String { rawValue }
    var id: String { rawValue }
}

// MARK: - ScopeSelectorView
// Animated pill selector — preview toggle only (not a scope for applying).

struct ScopeSelectorView: View {
    @Binding var selected: ThemeScope
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ThemeScope.allCases) { scope in
                Button(scope.label) { selected = scope }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        if selected == scope {
                            Capsule()
                                .fill(.primary.opacity(0.15))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .foregroundStyle(.primary)
                    .font(.subheadline.weight(.medium))
            }
        }
        .background(Capsule().fill(.ultraThinMaterial))
        .animation(.spring(duration: 0.3, bounce: 0.25), value: selected)
    }
}
