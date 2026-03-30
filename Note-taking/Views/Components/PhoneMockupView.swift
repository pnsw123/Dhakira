import SwiftUI

// MARK: - PhoneMockupView
// Renders a phone-frame outline with live theme-coloured content inside.
// App/All scope: shows a fake but realistic task-list UI using the theme's actual colours.
// Widgets scope: shows WidgetPreviewLayout (scaled down real widget sizes).
// Issue #74 — https://github.com/pnsw123/prod-note/issues/74

struct PhoneMockupView: View {
    let theme: AppTheme
    let scope: ThemeScope

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
                    // Widgets scope: scale real widget-size rects to fit the frame
                    WidgetPreviewLayout(theme: theme)
                        .scaleEffect(0.35)
                        .padding(.top, 20)
                } else {
                    // App / All scope: realistic task-list preview using theme colours
                    AppPreviewContent(theme: theme)
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

    private struct Row: Identifiable {
        let id = UUID()
        let title: String
        let done: Bool
        let priority: String   // "high" | "medium" | "none"
    }

    private let rows: [Row] = [
        Row(title: "Morning standup",     done: false, priority: "high"),
        Row(title: "Review pull requests", done: false, priority: "medium"),
        Row(title: "Update documentation", done: true,  priority: "none"),
        Row(title: "Team lunch 12pm",     done: false, priority: "none"),
        Row(title: "Write weekly report",  done: false, priority: "high"),
        Row(title: "Check emails",         done: true,  priority: "none"),
        Row(title: "Plan next sprint",     done: false, priority: "medium"),
    ]

    var body: some View {
        VStack(spacing: 0) {

            // ── Status-bar spacer ──────────────────────────────
            theme.screenBackground
                .frame(height: 18)

            // ── Navigation bar ─────────────────────────────────
            HStack {
                Text("Tasks")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                Spacer()
                // FAB placeholder
                Circle()
                    .fill(theme.fabBackground)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(theme.fabIcon)
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.screenBackground)

            // ── Separator ──────────────────────────────────────
            Rectangle()
                .fill(theme.separatorColor)
                .frame(height: 0.5)

            // ── Task list ──────────────────────────────────────
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
        .background(theme.screenBackground)
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        PhoneMockupView(theme: .defaultLight, scope: .app)
        PhoneMockupView(theme: .midnight,     scope: .app)
        PhoneMockupView(theme: .nord,         scope: .widgets)
    }
    .frame(height: 490)
    .padding()
    .background(Color.gray)
}
