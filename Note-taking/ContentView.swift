import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "ContentView")

struct ContentView: View {
    @State private var showHome = false

    var body: some View {
        NavigationStack {
            Group {
                if showHome {
                    HomeView(onClose: { showHome = false })
                } else {
                    TaskListView(onShowHome: { showHome = true })
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showHome)
        }
    }
}

#Preview {
    // Use AppSchemaBuilder — stays in sync with the app's schema automatically (Issue #52)
    let container = try! AppSchemaBuilder.makeInMemoryContainer()

    let ctx = container.mainContext

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
