import SwiftUI
import ProdNoteShared

// MARK: - WidgetPreviewLayout
// Widget picker shown when "Widgets" scope is selected in ThemeDetailView.
// Three size sections matching ProdNoteWidgetView exactly — same layout, same fonts,
// same spacing. Uses theme tokens so every color follows the selected preset.
// Sizes chosen so all three widgets fit on screen without scrolling.
// Issue #74 — https://github.com/pnsw123/prod-note/issues/74

struct WidgetPreviewLayout: View {
    let theme: AppTheme
    // When true, uses iPad widget proportions and shows the Extra Large section (iPad-exclusive).
    var isIPad: Bool = false
    private let taskCount = 5

    // iPad small/medium/large widgets are slightly larger than iPhone equivalents.
    private var smallSize: CGFloat  { isIPad ? 130 : 118 }
    private var mediumHeight: CGFloat { isIPad ? 130 : 118 }
    private var largeHeight: CGFloat  { isIPad ? 240 : 220 }
    private var cornerRadius: CGFloat { isIPad ? 22 : 20 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {

                // SMALL · 2×2
                VStack(alignment: .leading, spacing: 6) {
                    sectionHeader("SMALL · 2×2")
                    SmallWidgetPreview(theme: theme, taskCount: taskCount)
                        .frame(width: smallSize, height: smallSize)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // MEDIUM · 2×4
                VStack(alignment: .leading, spacing: 6) {
                    sectionHeader("MEDIUM · 2×4")
                    MediumWidgetPreview(theme: theme, taskCount: taskCount)
                        .frame(maxWidth: .infinity)
                        .frame(height: mediumHeight)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }

                // LARGE · 4×4
                VStack(alignment: .leading, spacing: 6) {
                    sectionHeader("LARGE · 4×4")
                    LargeWidgetPreview(theme: theme, taskCount: taskCount)
                        .frame(maxWidth: .infinity)
                        .frame(height: largeHeight)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }

                // EXTRA LARGE · 4×8 — iPad-exclusive widget size
                if isIPad {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            sectionHeader("EXTRA LARGE · 4×8")
                            Text("iPad only")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(theme.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.accentColor.opacity(0.15), in: Capsule())
                        }
                        ExtraLargeWidgetPreview(theme: theme, taskCount: taskCount)
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
    }

    private func sectionHeader(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.secondaryText)
            .tracking(0.5)
    }
}

// MARK: - Widget Background
// Diagonal gradient using the theme's mesh corner → focal → corner colors,
// matching the thumbnail cards and ThemeDetailView animated background.

@ViewBuilder
private func widgetBackground(theme: AppTheme) -> some View {
    if #available(iOS 18, *) {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
            ],
            colors: theme.meshColors
        )
    } else {
        RadialGradient(
            colors: [theme.meshColors[4], theme.meshColors[0]],
            center: .center,
            startRadius: 0,
            endRadius: 300
        )
    }
}

// MARK: - Small Widget (2×2)

private struct SmallWidgetPreview: View {
    let theme: AppTheme
    let taskCount: Int

    var body: some View {
        ZStack {
            widgetBackground(theme: theme)
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(theme.accentColor)

                Spacer()

                Text("\(taskCount)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)

                Text("tasks today")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .modifier(PreviewGlassModifier())
        }
    }
}

// MARK: - Medium Widget (2×4)
// Mirrors ProdNoteWidgetView.mediumView — header + task rows + flags + overflow footer.

private struct MediumWidgetPreview: View {
    let theme: AppTheme
    let taskCount: Int

    private struct Sample: Identifiable {
        let id = UUID()
        let title: String
        let priority: String
    }
    private let samples: [Sample] = [
        Sample(title: "Submit tax documents",   priority: "high"),
        Sample(title: "Reply to Sarah's email", priority: "medium"),
        Sample(title: "Book flight tickets",    priority: "default"),
        Sample(title: "Water the plants",       priority: "default"),
        Sample(title: "Call the dentist",       priority: "default"),
    ]

    var body: some View {
        let maxRows = 4
        let visible = Array(samples.prefix(maxRows))
        let overflow = taskCount - visible.count

        return ZStack {
            widgetBackground(theme: theme)
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    Text("Today")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    Text("\(taskCount) tasks")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.bottom, 8)

                // Task rows
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(visible) { task in
                        HStack(spacing: 7) {
                            Circle()
                                .strokeBorder(theme.checkboxInactive, lineWidth: 1.2)
                                .frame(width: 12, height: 12)
                            Text(task.title)
                                .font(.system(size: 12))
                                .foregroundStyle(theme.primaryText)
                                .lineLimit(1)
                            Spacer()
                            if task.priority == "high" {
                                LargePreviewPennant()
                                    .fill(theme.priorityHigh)
                                    .frame(width: 7, height: 10)
                            } else if task.priority == "medium" {
                                LargePreviewPennant()
                                    .fill(theme.priorityMedium)
                                    .frame(width: 7, height: 10)
                            }
                        }
                    }
                    if overflow > 0 {
                        Text("+\(overflow) more")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .modifier(PreviewGlassModifier())
        }
    }
}

// MARK: - Large Widget (4×4)
// Mirrors ProdNoteWidgetView.largeView — header + separator + 8 task rows + flags + overflow

private struct LargeWidgetPreview: View {
    let theme: AppTheme
    let taskCount: Int

    private struct Sample: Identifiable {
        let id = UUID()
        let title: String
        let priority: String
    }
    private let samples: [Sample] = [
        Sample(title: "Submit tax documents",   priority: "high"),
        Sample(title: "Reply to Sarah's email", priority: "medium"),
        Sample(title: "Book flight tickets",    priority: "default"),
        Sample(title: "Water the plants",       priority: "default"),
        Sample(title: "Call the dentist",       priority: "default"),
        Sample(title: "Prepare presentation",   priority: "high"),
        Sample(title: "Buy groceries",          priority: "default"),
        Sample(title: "Gym session at 6pm",     priority: "medium"),
    ]

    var body: some View {
        let maxRows = 8
        let visible = Array(samples.prefix(maxRows))
        let overflow = taskCount - visible.count

        return ZStack {
            widgetBackground(theme: theme)
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    Text("Today")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    Text("\(taskCount) tasks")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }

                // Separator
                Rectangle()
                    .fill(theme.separatorColor.opacity(0.5))
                    .frame(height: 0.5)
                    .padding(.vertical, 9)

                // Task rows
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visible) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .strokeBorder(theme.checkboxInactive, lineWidth: 1.2)
                                .frame(width: 11, height: 11)
                            Text(task.title)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.primaryText)
                                .lineLimit(1)
                            Spacer()
                            if task.priority == "high" {
                                LargePreviewPennant()
                                    .fill(theme.priorityHigh)
                                    .frame(width: 7, height: 11)
                            } else if task.priority == "medium" {
                                LargePreviewPennant()
                                    .fill(theme.priorityMedium)
                                    .frame(width: 7, height: 11)
                            }
                        }
                    }
                    if overflow > 0 {
                        Text("+\(overflow) more")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .modifier(PreviewGlassModifier())
        }
    }
}

// MARK: - Extra Large Widget (4×8) — iPad-exclusive
// Two-column layout matching what WidgetKit renders for .systemExtraLarge on iPadOS:
// left side shows task count summary, right side shows the full task list.

private struct ExtraLargeWidgetPreview: View {
    let theme: AppTheme
    let taskCount: Int

    private struct Sample: Identifiable {
        let id = UUID()
        let title: String
        let priority: String
    }
    private let samples: [Sample] = [
        Sample(title: "Submit tax documents",   priority: "high"),
        Sample(title: "Reply to Sarah's email", priority: "medium"),
        Sample(title: "Book flight tickets",    priority: "default"),
        Sample(title: "Water the plants",       priority: "default"),
        Sample(title: "Call the dentist",       priority: "default"),
        Sample(title: "Prepare presentation",   priority: "high"),
        Sample(title: "Buy groceries",          priority: "default"),
        Sample(title: "Gym session at 6pm",     priority: "medium"),
    ]

    var body: some View {
        ZStack {
            widgetBackground(theme: theme)
            HStack(spacing: 0) {
                // Left column — count summary (mirrors .systemSmall left half)
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(theme.accentColor)
                    Spacer()
                    Text("\(taskCount)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryText)
                    Text("tasks today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(16)
                .frame(maxHeight: .infinity, alignment: .leading)

                // Divider
                Rectangle()
                    .fill(theme.separatorColor.opacity(0.5))
                    .frame(width: 0.5)
                    .padding(.vertical, 12)

                // Right column — task list (mirrors .systemLarge right half)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Today")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.primaryText)
                        Spacer()
                        Text("\(taskCount) tasks")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                    }
                    .padding(.bottom, 8)

                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(samples) { task in
                            HStack(spacing: 8) {
                                Circle()
                                    .strokeBorder(theme.checkboxInactive, lineWidth: 1.2)
                                    .frame(width: 11, height: 11)
                                Text(task.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.primaryText)
                                    .lineLimit(1)
                                Spacer()
                                if task.priority == "high" {
                                    LargePreviewPennant()
                                        .fill(theme.priorityHigh)
                                        .frame(width: 7, height: 11)
                                } else if task.priority == "medium" {
                                    LargePreviewPennant()
                                        .fill(theme.priorityMedium)
                                        .frame(width: 7, height: 11)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}

// MARK: - Glass modifier for previews
// iOS 26: native liquid glass. iOS 17–25: frosted material fallback.

private struct PreviewGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

private struct LargePreviewPennant: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to:    CGPoint(x: 0,            y: 0))
        p.addLine(to: CGPoint(x: rect.width,   y: 0))
        p.addLine(to: CGPoint(x: rect.width,   y: rect.height))
        p.addLine(to: CGPoint(x: rect.width/2, y: rect.height * 0.8))
        p.addLine(to: CGPoint(x: 0,            y: rect.height))
        p.closeSubpath()
        return p
    }
}
