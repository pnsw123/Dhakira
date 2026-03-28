import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

#Preview {
    let schema = Schema([TaskItem.self, Attachment.self, Folder.self, TaskList.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])

    let ctx = container.mainContext

    // Seed a Default Folder + Tasks list
    let defaultFolder = Folder(name: "Default")
    ctx.insert(defaultFolder)
    let defaultList = TaskList(name: "Tasks", folder: defaultFolder)
    ctx.insert(defaultList)

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
        let t = TaskItem(title: title, priority: priority, taskList: defaultList)
        t.sortOrder = i
        ctx.insert(t)
    }

    return ContentView()
        .modelContainer(container)
}
