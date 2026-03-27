import SwiftUI
import SwiftData

@main
struct Note_takingApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([TaskItem.self, Attachment.self, Folder.self])
        let config = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
