import SwiftUI

// MARK: - PhoneMockupView
// Renders a phone-frame outline with live theme-coloured content inside.
// Reads ThemeManager from environment so gradient/colour/photo overrides update in real time.
// Issue #74 — https://github.com/pnsw123/prod-note/issues/74

struct PhoneMockupView: View {
    let theme: AppTheme
    let scope: ThemeScope

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        ZStack(alignment: .top) {
            // Phone bezel
            RoundedRectangle(cornerRadius: 44)
                .stroke(.white.opacity(0.35), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 44)
                        .fill(.black.opacity(0.15))
                )

            // Content — non-interactive
            Group {
                if scope == .widgets {
                    WidgetPreviewLayout(theme: theme)
                        .scaleEffect(0.65)   // was 0.35 — widgets now fill the frame properly
                        .padding(.top, 20)
                } else {
                    AppPreviewContent(theme: theme, themeManager: themeManager)
                }
            }
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 44))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
}

// MARK: - App preview content

private struct AppPreviewContent: View {
    let theme: AppTheme
    let themeManager: ThemeManager

    private struct Row: Identifiable {
        let id = UUID()
        let title: String
        let done: Bool
        let priority: String   // "high" | "medium" | "none"
    }

    private let rows: [Row] = [
        Row(title: "Morning standup",      done: false, priority: "high"),
        Row(title: "Review pull requests", done: false, priority: "medium"),
        Row(title: "Update documentation", done: true,  priority: "none"),
        Row(title: "Team lunch 12pm",      done: false, priority: "none"),
        Row(title: "Write weekly report",  done: false, priority: "high"),
        Row(title: "Check emails",         done: true,  priority: "none"),
        Row(title: "Plan next sprint",     done: false, priority: "medium"),
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            // ── Full-screen background layer ────────────────────
            // Mirrors WithAppBackground: gradient / colour / theme default
            backgroundLayer
                .ignoresSafeArea()

            // ── App content stack ───────────────────────────────
            VStack(spacing: 0) {

                // Status-bar spacer
                Color.clear.frame(height: 18)

                // Nav bar — mirrors safeAreaInset(.top) in TaskListView
                HStack(spacing: 0) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.accentColor)
                        .padding(.leading, 10)

                    Text("Tasks")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                        .padding(.leading, 6)

                    Spacer()

                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.accentColor)
                        .padding(.trailing, 12)
                }
                .padding(.vertical, 9)
                .background(theme.screenBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.separatorColor)
                        .frame(height: 0.5)
                }

                // Task rows
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        HStack(spacing: 8) {
                            // Checkbox
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        row.done ? theme.checkboxActive : theme.checkboxInactive,
                                        lineWidth: 1
                                    )
                                    .frame(width: 16, height: 16)
                                if row.done {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(theme.checkboxActive)
                                }
                            }

                            // Title
                            Text(row.title)
                                .font(.system(size: 11))
                                .foregroundStyle(row.done ? theme.secondaryText : theme.primaryText)
                                .strikethrough(row.done, color: theme.secondaryText)
                                .lineLimit(1)

                            Spacer()

                            // Priority dot
                            if row.priority == "high" {
                                Circle().fill(theme.priorityHigh).frame(width: 5, height: 5)
                            } else if row.priority == "medium" {
                                Circle().fill(theme.priorityMedium).frame(width: 5, height: 5)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(theme.surfaceBackground)

                        if i < rows.count - 1 {
                            Rectangle()
                                .fill(theme.separatorColor)
                                .frame(height: 0.5)
                                .padding(.leading, 38)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()
            }

            // ── FAB — bottom-right, matches safeAreaInset(.bottom) in TaskListView ──
            Circle()
                .fill(theme.fabBackground)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.fabIcon)
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                .padding(.trailing, 12)
                .padding(.bottom, 14)
        }
    }

    // Mirrors WithAppBackground priority order:
    // gradient override → colour override → theme default background
    @ViewBuilder
    private var backgroundLayer: some View {
        if let gradColors = themeManager.backgroundGradientColors {
            LinearGradient(
                colors: gradColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if let color = themeManager.backgroundColorOverride {
            color
        } else {
            theme.screenBackground
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        PhoneMockupView(theme: .defaultLight, scope: .app)
        PhoneMockupView(theme: .midnight,     scope: .app)
        PhoneMockupView(theme: .nord,         scope: .widgets)
    }
    .frame(height: 490)
    .padding()
    .background(Color.gray)
    .environment(ThemeManager.shared)
    .environment(StoreKitManager.shared)
}
