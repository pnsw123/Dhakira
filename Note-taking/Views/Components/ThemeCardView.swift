import SwiftUI

// MARK: - ThemeCardView
// Thumbnail card used in the 2-column theme gallery grid.
// Shows a mini live preview of the app UI so users see exactly
// what tasks look like in that theme before tapping through.

struct ThemeCardView: View {
    let theme: AppTheme
    let isSelected: Bool
    var namespace: Namespace.ID

    @Environment(ThemeManager.self) private var themeManager
    @Environment(StoreKitManager.self) private var store

    var body: some View {
        ZStack(alignment: .bottom) {

            // Layer 1 — full gradient background
            cardBackground

            // Layer 2 — bottom fade so label is readable over any gradient
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: UnitPoint(x: 0.5, y: 0.30),
                endPoint: .bottom
            )

            // Layer 4 — theme name + mood tag
            HStack(alignment: .bottom, spacing: 4) {
                Text(theme.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                tagBadge
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 11)

            // Layer 5 — selection ring in the theme's own accent colour
            if isSelected {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(theme.accentColor, lineWidth: 2.5)
            }

            // Layer 6 — lock icon overlay for unowned paid themes
            if theme.isPaid && !store.isOwned(theme) {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.45), in: Circle())
                            .padding(10)
                    }
                    Spacer()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .aspectRatio(1.0, contentMode: .fit)
        .matchedTransitionSource(id: theme.id, in: namespace)
        .shadow(color: .black.opacity(0.28), radius: 16, x: 0, y: 8)
    }

    // MARK: — Mini UI Preview

    @ViewBuilder
    private var miniUIPreview: some View {
        VStack(spacing: 3) {

            // Task list card with FAB overlay
            ZStack(alignment: .bottomTrailing) {

                // Task rows
                VStack(spacing: 0) {
                    ForEach(Array(previewRows.enumerated()), id: \.offset) { i, row in
                        miniRow(row)
                        if i < previewRows.count - 1 {
                            Rectangle()
                                .fill(theme.separatorColor.opacity(0.45))
                                .frame(height: 0.5)
                                .padding(.leading, 22)
                        }
                    }
                }
                .background(theme.surfaceBackground.opacity(0.60), in: RoundedRectangle(cornerRadius: 8))

                // Mini FAB
                Circle()
                    .fill(theme.fabBackground)
                    .frame(width: 17, height: 17)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(theme.fabIcon)
                    )
                    .shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 1.5)
                    .offset(x: 2, y: 8)
            }
        }
    }

    // MARK: — Row data

    private struct PreviewRow {
        let done: Bool
        let textWidth: CGFloat
        let hasFlag: Bool
    }

    private let previewRows: [PreviewRow] = [
        PreviewRow(done: true,  textWidth: 0.80, hasFlag: true),
        PreviewRow(done: true,  textWidth: 0.58, hasFlag: false),
        PreviewRow(done: false, textWidth: 0.92, hasFlag: false),
        PreviewRow(done: false, textWidth: 0.70, hasFlag: false),
        PreviewRow(done: false, textWidth: 0.50, hasFlag: false),
    ]

    @ViewBuilder
    private func miniRow(_ row: PreviewRow) -> some View {
        HStack(spacing: 5) {

            // Checkbox
            Group {
                if row.done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.priorityHigh)
                } else {
                    Circle()
                        .strokeBorder(theme.checkboxInactive, lineWidth: 1)
                        .frame(width: 9, height: 9)
                }
            }
            .frame(width: 11)

            // Abstracted text line (represents the task title)
            RoundedRectangle(cornerRadius: 1.5)
                .fill((row.done ? theme.secondaryText : theme.primaryText)
                    .opacity(row.done ? 0.40 : 0.82))
                .frame(height: 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(x: row.textWidth, y: 1, anchor: .leading)

            // Priority flag
            if row.hasFlag {
                CardPennant()
                    .fill(theme.priorityHigh)
                    .frame(width: 5, height: 8)
            } else {
                Color.clear.frame(width: 5, height: 8)
            }
        }
        .frame(height: 20)
        .padding(.horizontal, 6)
    }

    // MARK: — Tag badge

    @ViewBuilder
    private var tagBadge: some View {
        let label = isSelected ? "Active" : theme.tag
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                isSelected ? theme.accentColor.opacity(0.85) : .white.opacity(0.20),
                in: Capsule()
            )
    }

    // MARK: — Card background

    @ViewBuilder
    private var cardBackground: some View {
        ZStack {
            // Base: focal/mid color
            theme.meshColors[4]
            // Top-left bloom
            RadialGradient(
                colors: [theme.meshColors[0].opacity(0.85), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 180
            )
            // Bottom-right bloom
            RadialGradient(
                colors: [theme.meshColors[8].opacity(0.80), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 160
            )
        }
    }
}

// MARK: - Pennant flag shape (mini version for card thumbnail)

private struct CardPennant: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.68))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Preview

#Preview {
    LazyVGrid(
        columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)],
        spacing: 16
    ) {
        ThemeCardView(theme: .nebula, isSelected: false, namespace: Namespace().wrappedValue)
        ThemeCardView(theme: .cosmos,       isSelected: false, namespace: Namespace().wrappedValue)
        ThemeCardView(theme: .nebula,       isSelected: false, namespace: Namespace().wrappedValue)
        ThemeCardView(theme: .galaxy,       isSelected: true,  namespace: Namespace().wrappedValue)
        ThemeCardView(theme: .crystal,       isSelected: false, namespace: Namespace().wrappedValue)
        ThemeCardView(theme: .ember,      isSelected: false, namespace: Namespace().wrappedValue)
    }
    .padding(16)
    .background(Color(red: 0.11, green: 0.11, blue: 0.12))
    .environment(ThemeManager.shared)
    .environment(StoreKitManager.shared)
}
