import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "RecentlyCompleted")

struct RecentlyCompletedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<TaskItem> { $0.isCompleted == true && $0.isTrashed == false },
        sort: \TaskItem.createdAt,
        order: .reverse
    )
    private var completedTasks: [TaskItem]

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        Group {
            if completedTasks.isEmpty {
                emptyState
                    .onAppear { log.info("RecentlyCompletedView: empty state shown") }
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

                        Text("Recently Completed")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)

                    ForEach(completedTasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title.isEmpty ? "Untitled" : task.title)
                                .font(.system(size: 15))
                                .strikethrough(true)
                                .foregroundStyle(Color.secondaryText)

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
                                if let completedAt = task.completedAt {
                                    Text(Self.dateFormatter.string(from: completedAt))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondaryText.opacity(0.6))
                                } else {
                                    Text("Unknown time")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondaryText.opacity(0.4))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading) {
                            Button {
                                restoreTask(task)
                            } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                trashTask(task)
                            } label: {
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

    // MARK: - Actions

    private func restoreTask(_ task: TaskItem) {
        log.info("restoreTask: uncompleting '\(task.title)'")
        withAnimation {
            task.isCompleted = false
            task.completedAt = nil
        }
        LocalStateLedger.shared.unmarkCompleted(task.id)
        do { try modelContext.save() } catch {
            log.error("restoreTask: save failed — \(error.localizedDescription)")
        }
        // Re-create calendar events for the restored task
        let t = task
        Task { await CalendarSyncService.shared.syncTaskIfNeeded(t) }
        // Issue #85: re-scan body to recreate body-line events after un-complete.
        if let bodyData = t.body,
           case .success(let attrStr) = NoteBodyCodec.decode(bodyData, taskId: t.id) {
            let bodyText = attrStr.string
            let ctx = modelContext
            Task { await BodyEventSyncService.shared.sync(bodyText: bodyText, task: t, context: ctx) }
        }
    }

    private func trashTask(_ task: TaskItem) {
        log.info("trashTask: moving '\(task.title)' to trash")
        // Clean up calendar events before trashing
        if let eventId = task.calendarEventId {
            Task { await CalendarSyncService.shared.deleteEvent(withId: eventId) }
            task.calendarEventId = nil
        }
        if let googleId = task.googleCalendarEventId {
            Task { await CalendarSyncService.shared.deleteGoogleEvent(googleId) }
            task.googleCalendarEventId = nil
        }
        // Issue #85: delete all body-line calendar events on trash.
        let ctx = modelContext
        let t = task
        Task { await BodyEventSyncService.shared.deleteAllEvents(for: t, context: ctx) }
        withAnimation {
            task.isTrashed = true
            task.deletedAt = Date()
        }
        LocalStateLedger.shared.markDeleted(task.id)
        do { try modelContext.save() } catch {
            log.error("trashTask: save failed — \(error.localizedDescription)")
        }
    }

    private var emptyState: some View {
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
            .padding(.leading, 16)

            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 56, weight: .light))
                        .foregroundStyle(Color.secondaryText.opacity(0.4))
                    Text("No completed tasks yet")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private func previewCompleted(theme: AppTheme? = nil) -> some View {
    let tm = ThemeManager.shared
    if let theme { tm.applyApp(theme) }
    let container = try! AppSchemaBuilder.makeInMemoryContainer()
    let ctx = container.mainContext
    let folder = Folder(name: "Default")
    ctx.insert(folder)
    let list = TaskList(name: "Tasks", folder: folder)
    ctx.insert(list)
    let t = TaskItem(title: "Buy groceries", taskList: list)
    t.isCompleted = true; t.completedAt = Date()
    ctx.insert(t)
    return ZStack {
        previewGradient(tm)
        NavigationStack {
            RecentlyCompletedView()
        }
    }
    .modelContainer(container)
    .environment(tm)
    .preferredColorScheme(tm.current.preferredScheme)
}

#Preview("Recently Completed — Default") { previewCompleted() }
#Preview("Recently Completed — Nebula") { previewCompleted(theme: .nebula) }
