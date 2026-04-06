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
        // Always use real app data — theme, tasks, everything comes from the actual app state.
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProdNoteEntry>) -> Void) {
        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now
        completion(Timeline(entries: [entry()], policy: .after(nextUpdate)))
    }

    private func entry() -> ProdNoteEntry {
        let defaults = UserDefaults(suiteName: "group.com.prodnote.notetaking")
        let themeId = defaults?.string(forKey: "themeId") ?? "default"

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
                .containerBackground(for: .widget) {
                    WidgetBackgroundView(entry: entry)
                }
                .widgetURL(URL(string: "prodnote://openNote"))
        }
        .configurationDisplayName("Dhakira")
        .description("Your tasks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Separate View for the widget background so it can use @Environment(\.colorScheme).
/// Widget structs can't use @Environment — only View structs can.
private struct WidgetBackgroundView: View {
    var entry: ProdNoteEntry
    @Environment(\.colorScheme) private var colorScheme

    private var theme: AppTheme {
        if entry.themeId == "default" {
            return colorScheme == .dark ? .midnight : .defaultLight
        }
        let allThemes = [AppTheme.defaultLight, .midnight] + AppTheme.all
        return allThemes.first { $0.id == entry.themeId }
            ?? (colorScheme == .dark ? .midnight : .defaultLight)
    }

    var body: some View {
        if let data = entry.backgroundImageData, let img = UIImage(data: data) {
            Image(uiImage: img)
                .resizable()
                .scaledToFill()
        } else if theme.backgroundStyle == .gradient {
            if #available(iOS 18, *) {
                let defaultGrid: [SIMD2<Float>] = [
                    [0,0],[0.5,0],[1,0],
                    [0,0.5],[0.5,0.5],[1,0.5],
                    [0,1],[0.5,1],[1,1]
                ]
                MeshGradient(
                    width: 3, height: 3,
                    points: theme.meshPoints ?? defaultGrid,
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
        } else {
            theme.screenBackground
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
        .configurationDisplayName("Dhakira")
        .description("Tasks at a glance on your lock screen.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
