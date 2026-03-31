import WidgetKit
import SwiftUI
import ProdNoteShared

// MARK: - ProdNoteEntry

struct ProdNoteEntry: TimelineEntry {
    let date: Date
    let themeId: String
    let backgroundImageData: Data?
    let taskCount: Int
    let tasks: [WidgetTask]
}

// MARK: - ProdNoteProvider

struct ProdNoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProdNoteEntry {
        ProdNoteEntry(date: .now, themeId: "default", backgroundImageData: nil, taskCount: 3, tasks: [
            WidgetTask(id: UUID(), title: "Submit tax documents",   priority: "high"),
            WidgetTask(id: UUID(), title: "Reply to Sarah's email", priority: "medium"),
            WidgetTask(id: UUID(), title: "Book flight tickets",    priority: "default"),
        ])
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
        let defaults = UserDefaults(suiteName: "group.com.prodnote.notetaking")
        let themeId = defaults?.string(forKey: "themeId") ?? "defaultLight"

        // Read shared background image from App Group container
        let imageData: Data? = {
            guard let url = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: "group.com.prodnote.notetaking")?
                .appendingPathComponent("theme_background.jpg") else { return nil }
            return try? Data(contentsOf: url)
        }()

        // Task count + task list written by the main app into shared UserDefaults
        let taskCount = defaults?.integer(forKey: "activeTaskCount") ?? 0
        let tasks: [WidgetTask] = {
            guard let data = defaults?.data(forKey: "activeTasks"),
                  let decoded = try? JSONDecoder().decode([WidgetTask].self, from: data)
            else { return [] }
            return decoded
        }()

        return ProdNoteEntry(date: .now, themeId: themeId, backgroundImageData: imageData, taskCount: taskCount, tasks: tasks)
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
