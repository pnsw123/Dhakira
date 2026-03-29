import WidgetKit
import SwiftUI

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
                .font(.title2)
                .foregroundStyle(Color(theme.accentColor))
                .widgetAccentable()   // tinted in iOS 16+ accented rendering mode

            Spacer()

            Text("\(entry.taskCount)")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Color(theme.primaryText))

            Text("tasks today")
                .font(.caption)
                .foregroundStyle(Color(theme.secondaryText))
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            smallView
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("ProdNote")
                    .font(.headline)
                    .foregroundStyle(Color(theme.primaryText))
                    .widgetAccentable()
                Text("Tap to open")
                    .font(.caption)
                    .foregroundStyle(Color(theme.secondaryText))
            }
        }
        .padding(14)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ProdNote")
                .font(.title2.bold())
                .foregroundStyle(Color(theme.primaryText))
                .widgetAccentable()
            Text("\(entry.taskCount) tasks remaining")
                .font(.body)
                .foregroundStyle(Color(theme.secondaryText))
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
