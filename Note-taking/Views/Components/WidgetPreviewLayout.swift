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
                        .frame(height: 240)
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

// MARK: - Widget Gradient Background
// Creates a subtle diagonal gradient using theme mesh colors for a premium feel.

private func widgetGradient(theme: AppTheme) -> some View {
    LinearGradient(
        colors: [
            theme.meshColors.count > 3 ? theme.meshColors[3] : theme.screenBackground,
            theme.screenBackground,
            theme.meshColors.count > 5 ? theme.meshColors[5] : theme.screenBackground
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Small Widget (2×2)

private struct SmallWidgetPreview: View {
    let theme: AppTheme
    let taskCount: Int

    var body: some View {
        ZStack {
            widgetGradient(theme: theme)
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
// Mirrors ProdNoteWidgetView.mediumView exactly

private struct MediumWidgetPreview: View {
    let theme: AppTheme
    let taskCount: Int

    var body: some View {
        ZStack {
            widgetGradient(theme: theme)
            HStack(spacing: 0) {
                // Left — count stat
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
                .frame(maxHeight: .infinity, alignment: .leading)

                // Divider
                Rectangle()
                    .fill(theme.separatorColor.opacity(0.5))
                    .frame(width: 0.5)
                    .padding(.vertical, 16)

                // Right — app name + open prompt
                VStack(alignment: .leading, spacing: 6) {
                    Text("ProdNote")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    Text("Tap to open")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.trailing, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - Large Widget (4×4)
// Mirrors ProdNoteWidgetView.largeView exactly — includes sample task rows with flags

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
    ]

    var body: some View {
        ZStack {
            widgetGradient(theme: theme)
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    Text("ProdNote")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    Text("\(taskCount) tasks")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.bottom, 14)

                // Task rows
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(samples) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .strokeBorder(theme.checkboxInactive, lineWidth: 1.5)
                                .frame(width: 14, height: 14)
                            Text(task.title)
                                .font(.system(size: 14))
                                .foregroundStyle(theme.primaryText)
                                .lineLimit(1)
                            Spacer()
                            if task.priority == "high" {
                                LargePreviewPennant()
                                    .fill(theme.priorityHigh)
                                    .frame(width: 8, height: 12)
                            } else if task.priority == "medium" {
                                LargePreviewPennant()
                                    .fill(theme.priorityMedium)
                                    .frame(width: 8, height: 12)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(18)
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
