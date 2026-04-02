import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "ContentView")

/// Identifies which Home-level screen to push onto the navigation stack.
private enum HomeNav: String, Identifiable {
    case recentlyCompleted
    case recentlyDeleted
    var id: String { rawValue }
}

struct ContentView: View {
    /// true = Folders page visible, false = Tasks page visible (iPhone only)
    @State private var showHome = false
    /// iPad split-view column visibility
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    @Binding var pendingDeepLinkTaskId: UUID?


    @AppStorage("activeTaskListId") private var activeTaskListIdString: String = ""
    @Query(sort: \TaskList.createdAt) private var allTaskLists: [TaskList]

    private var activeTaskList: TaskList? {
        if !activeTaskListIdString.isEmpty,
           let id = UUID(uuidString: activeTaskListIdString),
           let found = allTaskLists.first(where: { $0.id == id }) {
            return found
        }
        return allTaskLists.first
    }

    @State private var homeNav: HomeNav? = nil

    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        if hSizeClass == .compact {
            iPhoneLayout
        } else {
            iPadLayout
        }
    }

    // MARK: — iPhone: lateral slide between Folders and Tasks
    // Only one view lives in the hierarchy at a time — no touch-blocking or
    // size-measurement issues. withAnimation drives the move transition.

    @ViewBuilder
    private var iPhoneLayout: some View {
        ZStack {
            if showHome {
                NavigationStack {
                    HomeView(
                        onClose:          { slideToTasks() },
                        onSelectTaskList: { list in
                            activeTaskListIdString = list.id.uuidString
                            slideToTasks()
                        },
                        onShowRecentlyCompleted: { homeNav = .recentlyCompleted },
                        onShowRecentlyDeleted:   { homeNav = .recentlyDeleted }
                    )
                    .scrollContentBackground(.hidden)
                    .withAppBackground()
                    .navigationDestination(item: $homeNav) { nav in
                        switch nav {
                        case .recentlyCompleted: RecentlyCompletedView().withAppBackground()
                        case .recentlyDeleted:   RecentlyDeletedView().withAppBackground()
                        }
                    }
                }
                .transition(.move(edge: .leading))
            } else {
                NavigationStack {
                    TaskListView(
                        taskList: activeTaskList,
                        onShowHome: { slideToHome() },
                        pendingDeepLinkTaskId: $pendingDeepLinkTaskId
                    )
                    .withAppBackground()
                }
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.05), value: showHome)
    }

    // MARK: — iPad: native split view

    @ViewBuilder
    private var iPadLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            HomeView(
                onClose:          { columnVisibility = .detailOnly },
                onSelectTaskList: { list in
                    activeTaskListIdString = list.id.uuidString
                    columnVisibility = .detailOnly
                },
                onShowRecentlyCompleted: { homeNav = .recentlyCompleted },
                onShowRecentlyDeleted:   { homeNav = .recentlyDeleted }
            )
            .scrollContentBackground(.hidden)
            .withAppBackground()
            .navigationDestination(item: $homeNav) { nav in
                switch nav {
                case .recentlyCompleted: RecentlyCompletedView().withAppBackground()
                case .recentlyDeleted:   RecentlyDeletedView().withAppBackground()
                }
            }
        } detail: {
            NavigationStack {
                TaskListView(
                    taskList: activeTaskList,
                    onShowHome: { columnVisibility = .all },
                    pendingDeepLinkTaskId: $pendingDeepLinkTaskId
                )
                .withAppBackground()
            }
        }
    }

    // MARK: — Helpers

    private func slideToHome()  { showHome = true  }
    private func slideToTasks() { showHome = false }
}

@ViewBuilder
private func previewGradient(_ tm: ThemeManager) -> some View {
    if #available(iOS 18, *) {
        let grid: [SIMD2<Float>] = [
            [0,0],[0.5,0],[1,0],
            [0,0.5],[0.5,0.5],[1,0.5],
            [0,1],[0.5,1],[1,1]
        ]
        MeshGradient(
            width: 3, height: 3,
            points: tm.current.meshPoints ?? grid,
            colors: tm.current.meshColors
        ).ignoresSafeArea()
    } else {
        tm.current.screenBackground.ignoresSafeArea()
    }
}

#Preview {
    let tm = ThemeManager.shared
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

    return ZStack {
        previewGradient(tm)
        ContentView(pendingDeepLinkTaskId: .constant(nil))
    }
    .modelContainer(container)
    .environment(tm)
    .environment(StoreKitManager.shared)
    .preferredColorScheme(tm.current.preferredScheme)
}
