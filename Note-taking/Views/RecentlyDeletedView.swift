import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "RecentlyDeleted")

struct RecentlyDeletedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<TaskItem> { $0.isTrashed == true },
        sort: \TaskItem.createdAt,
        order: .reverse
    )
    private var deletedTasks: [TaskItem]

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        Group {
            if deletedTasks.isEmpty {
                emptyState
            } else {
                List {
                    // Header — scrolls with content
                    VStack(alignment: .leading, spacing: 0) {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.themeAccent)
                                .frame(width: 36, height: 36)
                                .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)

                        Text("Recently Deleted")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)

                    ForEach(deletedTasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title.isEmpty ? "Untitled" : task.title)
                                .font(.system(size: 15))
                                .foregroundStyle(Color.primaryText)

                            HStack(spacing: 4) {
                                if let listName = task.taskList?.name {
                                    Text(listName)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondaryText.opacity(0.7))
                                    Text("·")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondaryText.opacity(0.5))
                                }
                                if let folder = task.taskList?.folder {
                                    Text(folder.name)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondaryText.opacity(0.7))
                                    Text("·")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondaryText.opacity(0.5))
                                }
                                if let deletedAt = task.deletedAt {
                                    Text("Deleted \(Self.dateFormatter.string(from: deletedAt))")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondaryText.opacity(0.6))
                                } else {
                                    Text("Deleted (unknown time)")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondaryText.opacity(0.4))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button(action: { restoreTask(task) }) {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive, action: { permanentlyDelete(task) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .background(Color.clear)
        .navigationBarBackButtonHidden(true)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "trash")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.secondaryText.opacity(0.4))
            Text("No recently deleted tasks")
                .font(.system(size: 17))
                .foregroundStyle(Color.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func restoreTask(_ task: TaskItem) {
        log.info("restoreTask: '\(task.title)'")
        LocalStateLedger.shared.unmarkDeleted(task.id)
        withAnimation(.smooth(duration: 0.3)) {
            task.isTrashed = false
            task.deletedAt = nil
        }
    }

    private func permanentlyDelete(_ task: TaskItem) {
        log.info("permanentlyDelete: '\(task.title)'")
        if let eventId = task.calendarEventId {
            Task { await CalendarSyncService.shared.deleteEvent(withId: eventId) }
        }
        if let googleEventId = task.googleCalendarEventId {
            Task { await CalendarSyncService.shared.deleteGoogleEvent(googleEventId) }
        }
        LocalStateLedger.shared.purge(task.id)
        AttachmentStore.shared.deleteAll(taskId: task.id)
        withAnimation(.smooth(duration: 0.3)) {
            modelContext.delete(task)
        }
    }
}

// MARK: - Previews

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

private func previewDeleted(theme: AppTheme? = nil) -> some View {
    let tm = ThemeManager.shared
    if let theme { tm.applyApp(theme) }
    let container = try! AppSchemaBuilder.makeInMemoryContainer()
    let ctx = container.mainContext
    let folder = Folder(name: "Default")
    ctx.insert(folder)
    let list = TaskList(name: "Tasks", folder: folder)
    ctx.insert(list)
    let t = TaskItem(title: "Old task", taskList: list)
    t.isTrashed = true; t.deletedAt = Date()
    ctx.insert(t)
    return ZStack {
        previewGradient(tm)
        NavigationStack {
            RecentlyDeletedView()
        }
    }
    .modelContainer(container)
    .environment(tm)
    .preferredColorScheme(tm.current.preferredScheme)
}

#Preview("Recently Deleted — Default") { previewDeleted() }
#Preview("Recently Deleted — Coral") { previewDeleted(theme: .coral) }
