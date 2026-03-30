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
            VStack(alignment: .leading, spacing: 0) {

                // SMALL · 2×2
                sectionHeader("SMALL · 2×2")
                    .padding(.bottom, 8)
                SmallWidgetPreview(theme: theme, taskCount: taskCount)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.bottom, 16)

                // MEDIUM · 2×4
                sectionHeader("MEDIUM · 2×4")
                    .padding(.bottom, 8)
                MediumWidgetPreview(theme: theme, taskCount: taskCount)
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.bottom, 16)

                // LARGE · 4×4
                sectionHeader("LARGE · 4×4")
                    .padding(.bottom, 8)
                LargeWidgetPreview(theme: theme, taskCount: taskCount)
                    .frame(maxWidth: .infinity)
                    .frame(height: 175)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.bottom, 20)

                // Add Widget CTA
                HStack {
                    Spacer()
                    Text("Add Widget")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(theme.accentColor, in: Capsule())
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 16)
        }
    }

    private func sectionHeader(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.secondaryText)
            .tracking(0.5)
    }
}

// MARK: - Small Widget (2×2)
// Mirrors ProdNoteWidgetView.smallView exactly

private struct SmallWidgetPreview: View {
    let theme: AppTheme
    let taskCount: Int

    var body: some View {
        ZStack {
            theme.screenBackground
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.accentColor)

                Spacer()

                Text("\(taskCount)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)

                Text("tasks today")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.secondaryText)
            }
            .padding(12)
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
            theme.screenBackground
            HStack(spacing: 12) {
                // Left — count stat
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "checklist")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.accentColor)

                    Spacer()

                    Text("\(taskCount)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryText)

                    Text("tasks today")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(12)
                .frame(maxHeight: .infinity, alignment: .leading)

                // Divider
                Rectangle()
                    .fill(theme.separatorColor)
                    .frame(width: 0.5)
                    .padding(.vertical, 12)

                // Right — app name + open prompt
                VStack(alignment: .leading, spacing: 4) {
                    Text("ProdNote")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                    Text("Tap to open")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.trailing, 12)
                .frame(maxHeight: .infinity, alignment: .center)
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
            theme.screenBackground
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack(alignment: .firstTextBaseline) {
                    Text("ProdNote")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    Text("\(taskCount) tasks")
                        .font(.system(size: 9))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.bottom, 8)

                // Task rows
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(samples) { task in
                        HStack(spacing: 5) {
                            Circle()
                                .strokeBorder(theme.checkboxInactive, lineWidth: 1)
                                .frame(width: 9, height: 9)
                            Text(task.title)
                                .font(.system(size: 10))
                                .foregroundStyle(theme.primaryText)
                                .lineLimit(1)
                            Spacer()
                            if task.priority == "high" {
                                LargePreviewPennant()
                                    .fill(theme.priorityHigh)
                                    .frame(width: 6, height: 9)
                            } else if task.priority == "medium" {
                                LargePreviewPennant()
                                    .fill(theme.priorityMedium)
                                    .frame(width: 6, height: 9)
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding(12)
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
