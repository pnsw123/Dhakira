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
    @Environment(\.colorScheme) var colorScheme

    /// All themes the widget might need — includes .defaultLight and .midnight
    /// which are NOT in AppTheme.all (they were removed from the theme picker
    /// because dark mode is now automatic, not a manual theme selection).
    private static let widgetThemes: [AppTheme] = [.defaultLight, .midnight] + AppTheme.all

    private var theme: AppTheme {
        // "default" = auto-theme → follow system dark/light mode
        if entry.themeId == "default" {
            return colorScheme == .dark ? .midnight : .defaultLight
        }
        // "midnight" or any other theme → look up in the full list
        return Self.widgetThemes.first { $0.id == entry.themeId }
            ?? (colorScheme == .dark ? .midnight : .defaultLight)
    }

    /// Resolves a Color that might use `Color(light:dark:)` to the correct variant
    /// for the current color scheme. Widget extensions don't always inherit trait
    /// collections properly, so dynamic UIColors can resolve to the wrong mode.
    private func resolved(_ color: Color) -> Color {
        #if canImport(UIKit)
        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        let uiColor = UIColor(color).resolvedColor(with: traits)
        return Color(uiColor: uiColor)
        #else
        return color
        #endif
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
    // Design matches WidgetPreviewLayout exactly — same fonts, sizes, spacing, colors.

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "checklist")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(theme.accentColor))
                .widgetAccentable()

            Spacer()

            Text("\(entry.taskCount)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(resolved(theme.primaryText))

            Text("tasks today")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(resolved(theme.secondaryText))
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .modifier(WidgetGlassModifier())
    }

    private var mediumView: some View {
        let maxRows = 4
        let visible = Array(entry.tasks.prefix(maxRows))
        let overflow = entry.taskCount - visible.count

        return VStack(alignment: .leading, spacing: 0) {
            // Header — "Today" + count, no app name
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(resolved(theme.primaryText))
                Spacer()
                Text("\(entry.taskCount) tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(resolved(theme.secondaryText))
            }
            .padding(.bottom, 8)

            if visible.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(theme.accentColor))
                    Text("All caught up!")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(resolved(theme.secondaryText))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(visible) { task in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 7) {
                                Circle()
                                    .strokeBorder(resolved(theme.checkboxInactive), lineWidth: 1.2)
                                    .frame(width: 12, height: 12)
                                Text(task.title)
                                    .font(.system(size: 12))
                                    .foregroundStyle(resolved(theme.primaryText))
                                    .lineLimit(1)
                                Spacer()
                                if task.priority == "high" {
                                    WidgetPennant()
                                        .fill(Color(theme.priorityHigh))
                                        .frame(width: 7, height: 10)
                                } else if task.priority == "medium" {
                                    WidgetPennant()
                                        .fill(Color(theme.priorityMedium))
                                        .frame(width: 7, height: 10)
                                }
                            }
                            Text("*")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(
                                    task.hasContent
                                        ? Color(theme.accentColor)
                                        : resolved(theme.secondaryText).opacity(0.35)
                                )
                                .padding(.leading, 19)
                        }
                    }

                    if overflow > 0 {
                        Text("+\(overflow) more")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(resolved(theme.secondaryText))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(WidgetGlassModifier())
    }

    private var largeView: some View {
        let maxRows = 8
        let visible = Array(entry.tasks.prefix(maxRows))
        let overflow = entry.taskCount - visible.count

        return VStack(alignment: .leading, spacing: 0) {
            // Header — "Today" + count, no app name
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(resolved(theme.primaryText))
                Spacer()
                Text("\(entry.taskCount) tasks")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(resolved(theme.secondaryText))
            }

            // Thin separator
            Rectangle()
                .fill(resolved(Color(theme.separatorColor)).opacity(0.5))
                .frame(height: 0.5)
                .padding(.vertical, 9)

            if visible.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(theme.accentColor))
                    Text("All caught up!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(resolved(theme.secondaryText))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(visible) { task in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Circle()
                                    .strokeBorder(resolved(theme.checkboxInactive), lineWidth: 1.2)
                                    .frame(width: 11, height: 11)
                                Text(task.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(resolved(theme.primaryText))
                                    .lineLimit(1)
                                Spacer()
                                if task.priority == "high" {
                                    WidgetPennant()
                                        .fill(Color(theme.priorityHigh))
                                        .frame(width: 7, height: 11)
                                } else if task.priority == "medium" {
                                    WidgetPennant()
                                        .fill(Color(theme.priorityMedium))
                                        .frame(width: 7, height: 11)
                                }
                            }
                            Text("*")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(
                                    task.hasContent
                                        ? Color(theme.accentColor)
                                        : resolved(theme.secondaryText).opacity(0.35)
                                )
                                .padding(.leading, 19)
                        }
                    }

                    if overflow > 0 {
                        Text("+\(overflow) more")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(resolved(theme.secondaryText))
                            .padding(.top, 2)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(WidgetGlassModifier())
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
        Text("Dhakira: \(entry.taskCount) tasks")
    }
}

// MARK: - Glass modifier
// Note: glassEffect is a UIKit/SwiftUI app surface API — it does NOT work inside
// WidgetKit. Applying it in a widget renders opaque glass that hides all content.
// Widgets get their background from containerBackground; no overlay is needed here.

private struct WidgetGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}
