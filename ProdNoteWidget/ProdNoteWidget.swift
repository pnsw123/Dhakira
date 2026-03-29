import WidgetKit
import SwiftUI

// MARK: - ProdNoteEntry

struct ProdNoteEntry: TimelineEntry {
    let date: Date
    let themeId: String
    let backgroundImageData: Data?
    let taskCount: Int
}

// MARK: - ProdNoteProvider

struct ProdNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProdNoteEntry {
        ProdNoteEntry(date: .now, themeId: "defaultLight", backgroundImageData: nil, taskCount: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProdNoteEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProdNoteEntry>) -> Void) {
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry()], policy: .after(nextUpdate)))
    }

    private func entry() -> ProdNoteEntry {
        let defaults = UserDefaults(suiteName: "group.com.prodnote.shared")
        let themeId = defaults?.string(forKey: "themeId") ?? "defaultLight"

        // Read shared background image from App Group container
        let imageData: Data? = {
            guard let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.prodnote.shared")?
                .appendingPathComponent("theme_background.jpg") else { return nil }
            return try? Data(contentsOf: url)
        }()

        // Task count cached by the main app into shared UserDefaults
        let taskCount = defaults?.integer(forKey: "activeTaskCount") ?? 0

        return ProdNoteEntry(date: .now, themeId: themeId, backgroundImageData: imageData, taskCount: taskCount)
    }
}

// MARK: - ProdNoteWidget (home screen sizes)

struct ProdNoteWidget: Widget {
    let kind = "ProdNoteWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProdNoteProvider()) { entry in
            ProdNoteWidgetView(entry: entry)
                // containerBackground required on iOS 17+ (NOT .background())
                .containerBackground(for: .widget) {
                    widgetBackground(for: entry)
                }
                .widgetURL(URL(string: "prodnote://openNote"))
        }
        .configurationDisplayName("ProdNote")
        .description("Your tasks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }

    @ViewBuilder
    private func widgetBackground(for entry: ProdNoteEntry) -> some View {
        let theme = AppTheme.all.first { $0.id == entry.themeId } ?? .defaultLight
        if let data = entry.backgroundImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else {
            Color(theme.screenBackground)
        }
    }
}

// MARK: - ProdNoteWidgetAccessory (lock screen / complication sizes)

struct ProdNoteWidgetAccessory: Widget {
    let kind = "ProdNoteWidgetAccessory"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProdNoteProvider()) { entry in
            ProdNoteWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
                .widgetURL(URL(string: "prodnote://openNote"))
        }
        .configurationDisplayName("ProdNote")
        .description("Tasks at a glance on your lock screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
