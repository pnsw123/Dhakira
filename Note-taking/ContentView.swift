import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TaskListView()
    }
}

#Preview {
    let schema = Schema([TaskItem.self, Attachment.self, Folder.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    let ctx = container.mainContext
    let samples: [(String, String)] = [
        ("Buy groceries for dinner", "high"),
        ("Submit tax documents", "high"),
        ("Reply to Sarah's email", "medium"),
        ("Finish project proposal", "medium"),
        ("Book flight tickets", "medium"),
        ("Call the dentist", "default"),
        ("Water the plants", "default"),
    ]
    for (i, (title, priority)) in samples.enumerated() {
        let t = TaskItem(title: title, priority: priority)
        t.sortOrder = i
        ctx.insert(t)
    }

    return ContentView()
        .modelContainer(container)
}
