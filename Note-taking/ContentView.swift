import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "ContentView")

struct ContentView: View {
    @State private var showHome = false

    /// Task UUID to navigate to via deep link (prodnote://task/{uuid}).
    /// Set by Note_takingApp when the OS delivers an incoming URL.
    @Binding var pendingDeepLinkTaskId: UUID?

    var body: some View {
        NavigationStack {
            Group {
                if showHome {
                    HomeView(onClose: { showHome = false })
                        .transition(.opacity)
                } else {
                    TaskListView(
                        onShowHome: { showHome = true },
                        pendingDeepLinkTaskId: $pendingDeepLinkTaskId
                    )
                    .transition(.opacity)
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

    return ContentView(pendingDeepLinkTaskId: .constant(nil))
        .modelContainer(container)
}
