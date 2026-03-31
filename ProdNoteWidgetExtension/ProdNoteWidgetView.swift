import WidgetKit
import SwiftUI
import ProdNoteShared

// MARK: - ProdNoteWidgetView
// Renders all widget sizes. Reads theme tokens directly from AppTheme (shared file).
// Issue #78 — https://github.com/pnsw123/prod-note/issues/78

struct ProdNoteWidgetView: View {
    var entry: ProdNoteEntry
    @Environment(\.widgetFamily) var family
    @Environment(\.widgetRenderingMode) var renderingMode  // iOS 18 tinting

    private var theme: AppTheme {
        AppTheme.all.first { $0.id == entry.themeId } ?? .defaultLight
    }

    var body: some View {
        switch family {
        case .systemSmall:              smallView
        case .systemMedium:             mediumView
        case .systemLarge:              largeView
        case .accessoryCircular:        accessoryCircularView
        case .accessoryRectangular:     accessoryRectangularView
        case .accessoryInline:          accessoryInlineView
        default:                        smallView
        }
    }

    // MARK: — Home screen sizes

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "checklist")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color(theme.accentColor))
                .widgetAccentable()

            Spacer()

            Text("\(entry.taskCount)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(Color(theme.primaryText))

            Text("tasks today")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(theme.secondaryText))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(WidgetGlassModifier())
        .overlay(
            ContainerRelativeShape()
                .strokeBorder(Color(theme.accentColor).opacity(0.28), lineWidth: 1)
        )
    }

    // Medium widget — same structure as large, compressed to ~4 visible rows.
    // Widgets are static snapshots (WidgetKit cannot scroll), so overflow is
    // shown as a "+N more" footer rather than a scrollable list.
    private var mediumView: some View {
        let maxRows = 4
        let visible = Array(entry.tasks.prefix(maxRows))
        let overflow = entry.taskCount - visible.count

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("ProdNote")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(theme.primaryText))
                    .widgetAccentable()
                Spacer()
                Text("\(entry.taskCount) tasks")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(theme.secondaryText))
            }
            .padding(.bottom, 10)

            if visible.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(theme.accentColor))
                    Text("All caught up!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(theme.secondaryText))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(visible) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .strokeBorder(Color(theme.checkboxInactive), lineWidth: 1.5)
                                .frame(width: 14, height: 14)
                            Text(task.title)
                                .font(.system(size: 13))
                                .foregroundStyle(Color(theme.primaryText))
                                .lineLimit(1)
                            Spacer()
                            if task.priority == "high" {
                                WidgetPennant()
                                    .fill(Color(theme.priorityHigh))
                                    .frame(width: 8, height: 12)
                            } else if task.priority == "medium" {
                                WidgetPennant()
                                    .fill(Color(theme.priorityMedium))
                                    .frame(width: 8, height: 12)
                            }
                        }
                    }

                    if overflow > 0 {
                        Text("+\(overflow) more")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color(theme.secondaryText))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(WidgetGlassModifier())
        .overlay(
            ContainerRelativeShape()
                .strokeBorder(Color(theme.accentColor).opacity(0.28), lineWidth: 1)
        )
    }

    // Large widget — fills the extra height with more rows + a completion stat line.
    // Max 8 visible rows; overflow shown as "+N more". Spacing is tighter (9pt) so
    // rows fill the widget without awkward empty space at the bottom.
    private var largeView: some View {
        let maxRows = 8
        let visible = Array(entry.tasks.prefix(maxRows))
        let overflow = entry.taskCount - visible.count


        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline) {
                Text("ProdNote")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color(theme.primaryText))
                    .widgetAccentable()
                Spacer()
                Text("\(entry.taskCount) tasks")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(theme.secondaryText))
            }

            // Thin separator under header
            Rectangle()
                .fill(Color(theme.separatorColor).opacity(0.5))
                .frame(height: 0.5)
                .padding(.vertical, 10)

            if visible.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(theme.accentColor))
                    Text("All caught up!")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(theme.secondaryText))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(visible) { task in
                        HStack(spacing: 10) {
                            Circle()
                                .strokeBorder(Color(theme.checkboxInactive), lineWidth: 1.5)
                                .frame(width: 16, height: 16)
                            Text(task.title)
                                .font(.system(size: 15))
                                .foregroundStyle(Color(theme.primaryText))
                                .lineLimit(1)
                            Spacer()
                            if task.priority == "high" {
                                WidgetPennant()
                                    .fill(Color(theme.priorityHigh))
                                    .frame(width: 9, height: 14)
                            } else if task.priority == "medium" {
                                WidgetPennant()
                                    .fill(Color(theme.priorityMedium))
                                    .frame(width: 9, height: 14)
                            }
                        }
                    }

                    if overflow > 0 {
                        Text("+\(overflow) more")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(theme.secondaryText))
                            .padding(.top, 2)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(WidgetGlassModifier())
        .overlay(
            ContainerRelativeShape()
                .strokeBorder(Color(theme.accentColor).opacity(0.28), lineWidth: 1)
        )
    }

    // MARK: — Pennant shape (matches PennantShape in main app)

    private struct WidgetPennant: Shape {
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

    // MARK: — Lock screen / complication sizes (accessory)

    private var accessoryCircularView: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack {
                Image(systemName: "checklist")
                    .widgetAccentable()
                Text("\(entry.taskCount)")
                    .font(.caption.bold())
            }
        }
    }

    private var accessoryRectangularView: some View {
        HStack {
            Image(systemName: "checklist")
                .widgetAccentable()
            Text("\(entry.taskCount) tasks")
                .font(.subheadline.bold())
        }
    }

    private var accessoryInlineView: some View {
        Text("ProdNote: \(entry.taskCount) tasks")
    }
}

// MARK: - Glass modifier
// iOS 26+: native liquid glass. iOS 17–25: frosted material fallback.

private struct WidgetGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(false), in: RoundedRectangle(cornerRadius: 0))
        } else {
            content
                .background(.ultraThinMaterial)
        }
    }
}
