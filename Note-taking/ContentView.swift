import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "ContentView")

/// Identifies which Home-level screen to push onto the navigation stack.
/// Using item-based navigation (instead of isPresented) avoids a SwiftUI
/// freeze when the parent Group contains animated conditional content.
private enum HomeNav: String, Identifiable {
    case recentlyCompleted
    case recentlyDeleted
    var id: String { rawValue }
}

struct ContentView: View {
    @State private var showHome = false

    /// Task UUID to navigate to via deep link (prodnote://task/{uuid}).
    /// Set by Note_takingApp when the OS delivers an incoming URL.
    @Binding var pendingDeepLinkTaskId: UUID?

    /// Persisted ID of the task list the Tasks page is currently showing.
    /// Falls back to the first available list if the stored one no longer exists.
    @AppStorage("activeTaskListId") private var activeTaskListIdString: String = ""

    /// All task lists — used to resolve the active list and handle fallbacks.
    @Query(sort: \TaskList.createdAt) private var allTaskLists: [TaskList]

    /// The task list currently shown on the Tasks page.
    /// Resolves the stored ID, falling back to the first list if needed.
    private var activeTaskList: TaskList? {
        if !activeTaskListIdString.isEmpty,
           let id = UUID(uuidString: activeTaskListIdString),
           let found = allTaskLists.first(where: { $0.id == id }) {
            return found
        }
        // Fallback: use first available list (covers first launch and deleted-list case)
        return allTaskLists.first
    }

    @State private var homeNav: HomeNav? = nil

    var body: some View {
        NavigationStack {
            Group {
                if showHome {
                    HomeView(
                        onClose: { showHome = false },
                        onSelectTaskList: { list in
                            // Switch the active list and navigate back to the Tasks page.
                            activeTaskListIdString = list.id.uuidString
                            showHome = false
                        },
                        onShowRecentlyCompleted: { homeNav = .recentlyCompleted },
                        onShowRecentlyDeleted: { homeNav = .recentlyDeleted }
                    )
                    .transition(.opacity)
                } else {
                    TaskListView(
                        taskList: activeTaskList,
                        onShowHome: { showHome = true },
                        pendingDeepLinkTaskId: $pendingDeepLinkTaskId
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: showHome)
            .navigationDestination(item: $homeNav) { nav in
                switch nav {
                case .recentlyCompleted: RecentlyCompletedView()
                case .recentlyDeleted:   RecentlyDeletedView()
                }
            }
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
