import SwiftUI

// MARK: - WidgetPreviewLayout
// Widget picker shown when "Widgets" scope is selected in ThemeDetailView.
// Three size sections matching ProdNoteWidgetView exactly — same layout, same fonts,
// same spacing. Uses theme tokens so every color follows the selected preset.
// Sizes chosen so all three widgets fit on screen without scrolling.
// Issue #74 — https://github.com/pnsw123/prod-note/issues/74

struct WidgetPreviewLayout: View {
    let theme: AppTheme
    private let taskCount = 5

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {

                // SMALL · 2×2
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("SMALL · 2×2")
                    SmallWidgetPreview(theme: theme, taskCount: taskCount)
                        .frame(width: 170, height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // MEDIUM · 2×4
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("MEDIUM · 2×4")
                    MediumWidgetPreview(theme: theme, taskCount: taskCount)
                        .frame(maxWidth: .infinity)
                        .frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                }

                // LARGE · 4×4
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader("LARGE · 4×4")
                    LargeWidgetPreview(theme: theme, taskCount: taskCount)
                        .frame(maxWidth: .infinity)
                        .frame(height: 330)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 24)
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
// Matches the actual widget background — solid screenBackground, same as the app.

private func widgetBackground(theme: AppTheme) -> some View {
    theme.screenBackground
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
                    Text("ProdNote")
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
                    Text("ProdNote")
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
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visible) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .strokeBorder(theme.checkboxInactive, lineWidth: 1.2)
                                .frame(width: 13, height: 13)
                            Text(task.title)
                                .font(.system(size: 13))
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
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
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
