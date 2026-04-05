import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "TaskList")

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The TaskList this view is scoped to. Nil means show all (legacy / default fallback).
    var taskList: TaskList?
    /// Called when the root view's < button is tapped. Owned by ContentView so
    /// HomeView is only registered once in the NavigationStack (avoids crashes).
    var onShowHome: (() -> Void)? = nil
    /// Task UUID delivered by a deep link (dhakira://task/{uuid}).
    /// When non-nil this view locates the matching task and navigates to its detail page.
    /// Only the root ContentView passes a real binding; secondary appearances use a constant.
    @Binding var pendingDeepLinkTaskId: UUID?

    // Convenience initialiser for callers that do not need deep-link support.
    init(taskList: TaskList? = nil, onShowHome: (() -> Void)? = nil) {
        self.taskList = taskList
        self.onShowHome = onShowHome
        self._pendingDeepLinkTaskId = .constant(nil)
    }

    // Full initialiser used by ContentView.
    init(taskList: TaskList? = nil, onShowHome: (() -> Void)? = nil, pendingDeepLinkTaskId: Binding<UUID?>) {
        self.taskList = taskList
        self.onShowHome = onShowHome
        self._pendingDeepLinkTaskId = pendingDeepLinkTaskId
    }

    @Query(filter: #Predicate<TaskItem> { $0.isTrashed == false }, sort: \TaskItem.sortOrder, order: .forward)
    private var allTasks: [TaskItem]

    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.horizontalSizeClass) private var hSizeClass
    private var isRegular: Bool { hSizeClass == .regular }
    @AppStorage("taskListSortBy") private var sortBy: SortOption = .manual
    @State private var selectedTask: TaskItem?
    @State private var showTheme = false
    @State private var recentlyCompletedIds: Set<UUID> = []
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""

    @Environment(\.undoManager) private var undoManager
    /// Bumped after each undo registration so SwiftUI re-evaluates canUndo/canRedo.
    @State private var undoVersion: Int = 0

    // Inline "add task" — no task is created until the user types a name
    @State private var isAddingTask: Bool = false
    @State private var newTaskTitle: String = ""
    @FocusState private var newTaskFieldFocused: Bool

/// Tasks belonging to this task list (not soft-deleted).
    private var filteredTasks: [TaskItem] {
        var result = allTasks.filter { task in
            let belongsHere = taskList == nil ? true : task.taskList?.id == taskList?.id
            let notCompleted = !task.isCompleted || recentlyCompletedIds.contains(task.id)
            return belongsHere && notCompleted
        }
        if sortBy == .creationDate {
            result.sort { $0.createdAt < $1.createdAt }
        }
        return result
    }

    private var displayName: String {
        taskList?.name ?? "Tasks"
    }

    var body: some View {
        List {
                // Header — scrolls with content, not sticky
                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            if onShowHome != nil {
                                Button(action: {
                                    log.info("TaskListView: < button tapped (root), calling onShowHome")
                                    onShowHome?()
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Color.themeAccent)
                                        .frame(width: 36, height: 36)
                                        .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("btn-go-to-folders")
                            } else {
                                Button(action: {
                                    log.info("TaskListView: < button tapped (pushed list=\(taskList?.name ?? "?")), calling dismiss()")
                                    dismiss()
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(Color.themeAccent)
                                        .frame(width: 36, height: 36)
                                        .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            // Undo / Redo — native UndoManager
                            // undoVersion forces SwiftUI to re-check canUndo/canRedo
                            Button {
                                undoManager?.undo()
                                undoVersion += 1
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.themeAccent)
                                    .frame(width: 36, height: 36)
                                    .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                            }
                            .buttonStyle(.plain)
                            .opacity(undoVersion >= 0 && undoManager?.canUndo == true ? 1 : 0.35)
                            .accessibilityLabel("Undo")

                            Button {
                                undoManager?.redo()
                                undoVersion += 1
                            } label: {
                                Image(systemName: "arrow.uturn.forward")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.themeAccent)
                                    .frame(width: 36, height: 36)
                                    .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 8)
                            .opacity(undoVersion >= 0 && undoManager?.canRedo == true ? 1 : 0.35)
                            .accessibilityLabel("Redo")

                            settingsButton
                                .padding(.leading, 8)
                            if isAddingTask || isEditingName {
                                doneButton
                                    .padding(.leading, 8)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.top, 4)

                        if isEditingName {
                            TextField("List name", text: $editedName, onCommit: commitNameEdit)
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(Color.primaryText)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                        } else {
                            Text(displayName)
                                .font(.system(size: 34, weight: .bold))
                                .foregroundStyle(Color.primaryText)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                                .onTapGesture {
                                    if let taskList {
                                        editedName = taskList.name
                                        isEditingName = true
                                    }
                                }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
                }

                ForEach(filteredTasks) { task in
                    TaskRowView(
                        task: task,
                        onToggleComplete: { toggleComplete(task) },
                        onTapDetail: { selectedTask = task }
                    )
                    .id(task.id)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: indentLevel(for: task), bottom: 0, trailing: 0))
                    .listRowSpacing(0)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button { setPriority(task, to: "high") } label: {
                            Label("High", systemImage: "flag.fill")
                        }
                        .tint(Color.priorityHighColor)

                        Button { setPriority(task, to: "medium") } label: {
                            Label("Medium", systemImage: "flag.fill")
                        }
                        .tint(Color.priorityMediumColor)

                        Button { setPriority(task, to: "default") } label: {
                            Label("None", systemImage: "flag.slash")
                        }
                        .tint(.gray)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            softDeleteTask(task)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
                .onMove { source, destination in
                    moveTask(from: source, to: destination)
                }

                // Inline "new task" row — appears when + is tapped, no task created yet
                if isAddingTask {
                    HStack(alignment: .top, spacing: 14) {
                        Circle()
                            .stroke(Color.checkboxInactive, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                            .frame(width: 28, height: 28)
                            .padding(.top, 1)

                        TextField("New Task", text: $newTaskTitle)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Color.primaryText)
                            .focused($newTaskFieldFocused)
                            .onSubmit { commitNewTask() }
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, isRegular ? 36 : 20)
                    .padding(.vertical, isRegular ? 14 : 10)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowSpacing(0)
                    .listRowBackground(Color.clear)
                }
            }
            .contentMargins(.bottom, 72, for: .scrollContent)
            .animation(.smooth(duration: 0.35), value: filteredTasks.count)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .overlay {
                if filteredTasks.isEmpty && !isAddingTask {
                    ContentUnavailableView {
                        Label("No Tasks", systemImage: "checklist")
                    } description: {
                        Text("Double-tap to add one.")
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .background(Color.clear)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                Button(action: addTask) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.fabIcon)
                        .frame(width: 48, height: 48)
                        .background(Color.fabColor, in: Circle())
                        .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .padding(.bottom, 8)
            }
            .navigationDestination(item: $selectedTask) { task in
                TaskDetailView(task: task)
                    .withAppBackground()
            }
            .navigationDestination(isPresented: $showTheme) {
                ThemeView()
                    .withAppBackground()
                    .environment(ThemeManager.shared)
                    .environment(StoreKitManager.shared)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    if !isAddingTask { addTask() }
                }
            )
            .onChange(of: newTaskFieldFocused) { _, focused in
                if !focused && isAddingTask {
                    // Short delay — gives addTask() time to intercept if the
                    // user tapped + again (which steals focus first).
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if !newTaskFieldFocused && isAddingTask {
                            cancelNewTask()
                        }
                    }
                }
            }
            // Deep link navigation — Issue #61
            // When Note_takingApp receives dhakira://task/{uuid}, it stores the UUID here.
            // We find the matching TaskItem and open its detail page. If the UUID is not
            // found (task deleted, or from another device), we stay on the current screen.
            .onChange(of: pendingDeepLinkTaskId) { _, taskId in
                guard let taskId else { return }
                if let match = allTasks.first(where: { $0.id == taskId }) {
                    selectedTask = match
                } else {
                    log.warning("Deep link: task \(taskId) not found in local database — ignoring")
                }
                // Always clear so the link isn't replayed on re-render.
                pendingDeepLinkTaskId = nil
            }
            // Keep widget snapshot up-to-date whenever the task list changes.
            // Watch count (add/delete), priorities (flag changes), and titles (edits).
            .onAppear { reconcileWithCloudKit(); syncWidget() }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                reconcileWithCloudKit()
            }
            .onChange(of: filteredTasks.count) { _, _ in syncWidget() }
            .onChange(of: filteredTasks.map(\.priority)) { _, _ in syncWidget() }
            .onChange(of: filteredTasks.map(\.title)) { _, _ in syncWidget() }
            // Watch body size so the widget asterisk updates immediately after content is saved.
            .onChange(of: filteredTasks.map { $0.body?.count ?? 0 }) { _, _ in syncWidget() }
    }

    private func syncWidget() {
        let activeTasks = allTasks.filter { !$0.isCompleted }
        let widgetTasks = activeTasks.prefix(8).map { t in
            let hasContent = (t.body != nil && !t.body!.isEmpty) ||
                             (t.drawingData != nil && !t.drawingData!.isEmpty) ||
                             (t.attachments != nil && !t.attachments!.isEmpty)
            return WidgetTask(id: t.id, title: t.title, priority: t.priority, hasContent: hasContent)
        }
        log.debug("syncWidget: pushing \(widgetTasks.count) task(s) (total active=\(activeTasks.count)) to widget")
        ThemeManager.shared.syncActiveTasks(Array(widgetTasks), totalCount: activeTasks.count)
    }

    private var doneButton: some View {
        Button(action: commitAll) {
            Image(systemName: "checkmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.themeAccent, in: Circle())
                .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        SettingsMenuView(
            sortBy: $sortBy,
            onThemeTapped: { showTheme = true }
        )
    }

    private func commitNameEdit() {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, let list = taskList {
            list.name = trimmed
            log.info("commitNameEdit: renamed task list to '\(trimmed)'")
        }
        isEditingName = false
    }

    private func addTask() {
        // If already adding, commit the current one first (saves if non-empty)
        if isAddingTask {
            saveNewTaskIfNeeded()
        }
        newTaskTitle = ""
        isAddingTask = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            newTaskFieldFocused = true
        }
    }

    /// Saves the current inline title as a real task if non-empty.
    private func saveNewTaskIfNeeded() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let scopedTasks = allTasks.filter { taskList == nil ? true : $0.taskList?.id == taskList?.id }
        let maxOrder = (scopedTasks.map(\.sortOrder).max() ?? 0) + 1
        let newTask = TaskItem(title: trimmed, taskList: taskList)
        newTask.sortOrder = maxOrder
        modelContext.insert(newTask)
        do {
            try modelContext.save()
            modelContext.processPendingChanges()
            log.info("commitNewTask: created '\(trimmed)' (sortOrder=\(maxOrder))")
        } catch {
            log.error("commitNewTask: modelContext.save() failed — \(error.localizedDescription)")
        }

        // Register undo — deletes the task if the user immediately undoes creation
        let ctx = modelContext
        undoManager?.registerUndo(withTarget: newTask) { t in
            if let eventId = t.calendarEventId {
                Task { await CalendarSyncService.shared.deleteEvent(withId: eventId) }
            }
            if let googleId = t.googleCalendarEventId {
                Task { await CalendarSyncService.shared.deleteGoogleEvent(googleId) }
            }
            ctx.delete(t)
            try? ctx.save()
        }
        undoManager?.setActionName("Create Task")
        undoVersion += 1

        // Detect any date/time in the title and create a calendar event immediately.
        // Fire-and-forget — never blocks the UI.
        let created = newTask
        Task { await CalendarSyncService.shared.syncTaskIfNeeded(created) }
    }

    /// Called when Return is pressed — saves if non-empty.
    private func commitNewTask() {
        saveNewTaskIfNeeded()
        withAnimation(.smooth(duration: 0.3)) {
            isAddingTask = false
        }
        newTaskTitle = ""
    }

    /// Called when the user taps elsewhere — discards without saving (like Escape).
    private func cancelNewTask() {
        withAnimation(.smooth(duration: 0.3)) {
            isAddingTask = false
        }
        newTaskTitle = ""
    }

    /// Done button — saves any pending task or name edit and dismisses the keyboard.
    private func commitAll() {
        if isAddingTask {
            saveNewTaskIfNeeded()
            withAnimation(.smooth(duration: 0.3)) { isAddingTask = false }
            newTaskTitle = ""
        }
        if isEditingName {
            commitNameEdit()
        }
        newTaskFieldFocused = false
    }

    private func toggleComplete(_ task: TaskItem) {
        let willComplete = !task.isCompleted
        log.info("toggleComplete: '\(task.title)' → \(willComplete ? "complete" : "incomplete")")

        // Register undo — reverse the completion toggle
        let wasCompleted = task.isCompleted
        let oldCompletedAt = task.completedAt
        undoManager?.registerUndo(withTarget: task) { t in
            withAnimation(.easeInOut(duration: 0.3)) {
                t.isCompleted = wasCompleted
                t.completedAt = oldCompletedAt
            }
            try? modelContext.save()
        }
        undoManager?.setActionName(willComplete ? "Complete Task" : "Uncomplete Task")
        undoVersion += 1

        withAnimation(.easeInOut(duration: 0.3)) {
            task.isCompleted = willComplete
            task.completedAt = willComplete ? Date() : nil
        }
        // Persist immediately — SwiftData auto-save is deferred and can be lost if the
        // process is killed before the run loop drains or the app goes to background.
        do {
            try modelContext.save()
            modelContext.processPendingChanges()
        } catch {
            log.error("toggleComplete: modelContext.save() failed — \(error.localizedDescription)")
        }

        if willComplete {
            LocalStateLedger.shared.markCompleted(task.id)
            recentlyCompletedIds.insert(task.id)
            let taskId = task.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                recentlyCompletedIds.remove(taskId)
            }
            // Remove calendar events — task is done, no need for reminders.
            if let eventId = task.calendarEventId {
                log.info("toggleComplete: removing Apple Calendar event '\(eventId)'")
                Task { await CalendarSyncService.shared.deleteEvent(withId: eventId) }
                task.calendarEventId = nil
            } else {
                log.debug("toggleComplete: no Apple Calendar event to remove")
            }
            if let googleEventId = task.googleCalendarEventId {
                log.info("toggleComplete: removing Google Calendar event '\(googleEventId)'")
                Task { await CalendarSyncService.shared.deleteGoogleEvent(googleEventId) }
                task.googleCalendarEventId = nil
            } else {
                log.debug("toggleComplete: no Google Calendar event to remove")
            }
            // Issue #85: delete all body-line calendar events.
            let ctx = modelContext
            let completedTask = task
            Task { await BodyEventSyncService.shared.deleteAllEvents(for: completedTask, context: ctx) }
        } else {
            LocalStateLedger.shared.unmarkCompleted(task.id)
            // Un-completing — re-sync to recreate the calendar event.
            log.info("toggleComplete: un-completed — re-syncing calendar events")
            let t = task
            Task { await CalendarSyncService.shared.syncTaskIfNeeded(t) }
            // Issue #85: re-scan body to recreate body-line events.
            let ctx = modelContext
            if let bodyData = t.body,
               case .success(let attrStr) = NoteBodyCodec.decode(bodyData, taskId: t.id) {
                let bodyText = attrStr.string
                Task { await BodyEventSyncService.shared.sync(bodyText: bodyText, task: t, context: ctx) }
            }
        }
    }

    private func setPriority(_ task: TaskItem, to priority: String) {
        let newPriority = task.priority == priority ? "default" : priority
        log.info("setPriority: '\(task.title)' → \(newPriority)")

        // Register undo — restore previous priority
        let oldPriority = task.priority
        undoManager?.registerUndo(withTarget: task) { t in
            t.priority = oldPriority
            try? modelContext.save()
        }
        undoManager?.setActionName("Set Priority")
        undoVersion += 1

        task.priority = newPriority
        do {
            try modelContext.save()
        } catch {
            log.error("setPriority: modelContext.save() failed — \(error.localizedDescription)")
        }
    }

    private func softDeleteTask(_ task: TaskItem) {
        log.info("softDeleteTask: '\(task.title)'")

        // Register undo — restore task from trash
        let savedCalendarId = task.calendarEventId
        let savedGoogleId   = task.googleCalendarEventId
        undoManager?.registerUndo(withTarget: task) { t in
            withAnimation(.smooth(duration: 0.3)) {
                t.isTrashed = false
                t.deletedAt = nil
            }
            t.calendarEventId = savedCalendarId
            t.googleCalendarEventId = savedGoogleId
            LocalStateLedger.shared.unmarkDeleted(t.id)
            try? modelContext.save()
            // Issue #85: re-scan body to recreate body-line events after untrash.
            if let bodyData = t.body,
               case .success(let attrStr) = NoteBodyCodec.decode(bodyData, taskId: t.id) {
                let bodyText = attrStr.string
                let ctx = modelContext
                Task { await BodyEventSyncService.shared.sync(bodyText: bodyText, task: t, context: ctx) }
            }
        }
        undoManager?.setActionName("Delete Task")
        undoVersion += 1

        if let eventId = task.calendarEventId {
            Task { await CalendarSyncService.shared.deleteEvent(withId: eventId) }
            task.calendarEventId = nil
        }
        if let googleEventId = task.googleCalendarEventId {
            Task { await CalendarSyncService.shared.deleteGoogleEvent(googleEventId) }
            task.googleCalendarEventId = nil
        }
        // Issue #85: delete all body-line calendar events on trash.
        let ctx = modelContext
        let trashedTask = task
        Task { await BodyEventSyncService.shared.deleteAllEvents(for: trashedTask, context: ctx) }
        withAnimation(.smooth(duration: 0.3)) {
            task.isTrashed = true
            task.deletedAt = Date()
        }
        LocalStateLedger.shared.markDeleted(task.id)
        do {
            try modelContext.save()
            modelContext.processPendingChanges()
        } catch {
            log.error("softDeleteTask: modelContext.save() failed — \(error.localizedDescription)")
        }
    }

    private func moveTask(from source: IndexSet, to destination: Int) {
        var reordered = filteredTasks
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reordered.enumerated() {
            item.sortOrder = index
        }
        do {
            try modelContext.save()
            modelContext.processPendingChanges()
            log.info("moveTask: reindexed \(reordered.count) tasks after move")
        } catch {
            log.error("moveTask: modelContext.save() failed — \(error.localizedDescription)")
        }
    }

    private func reconcileWithCloudKit() {
        let ledger = LocalStateLedger.shared
        var needsSave = false
        for task in allTasks {
            if ledger.isMarkedDeleted(task.id) && !task.isTrashed {
                log.warning("reconcile: CloudKit restored deleted task '\(task.title)' — re-deleting")
                task.isTrashed = true
                task.deletedAt = task.deletedAt ?? Date()
                // Clean up any calendar events for this restored-then-deleted task.
                if let eventId = task.calendarEventId {
                    Task { await CalendarSyncService.shared.deleteEvent(withId: eventId) }
                    task.calendarEventId = nil
                }
                if let googleId = task.googleCalendarEventId {
                    Task { await CalendarSyncService.shared.deleteGoogleEvent(googleId) }
                    task.googleCalendarEventId = nil
                }
                needsSave = true
            }
            if ledger.isMarkedCompleted(task.id) && !task.isCompleted {
                log.warning("reconcile: CloudKit restored completed task '\(task.title)' — re-completing")
                task.isCompleted = true
                task.completedAt = task.completedAt ?? Date()
                // Clean up any calendar events for this restored-then-completed task.
                if let eventId = task.calendarEventId {
                    Task { await CalendarSyncService.shared.deleteEvent(withId: eventId) }
                    task.calendarEventId = nil
                }
                if let googleId = task.googleCalendarEventId {
                    Task { await CalendarSyncService.shared.deleteGoogleEvent(googleId) }
                    task.googleCalendarEventId = nil
                }
                needsSave = true
            }
        }
        if needsSave {
            do {
                try modelContext.save()
                modelContext.processPendingChanges()
                log.info("reconcile: re-applied \(allTasks.filter { $0.isTrashed }.count) deletes, \(allTasks.filter { $0.isCompleted }.count) completions")
            } catch {
                log.error("reconcile: save failed — \(error.localizedDescription)")
            }
        }
    }

    private func indentLevel(for task: TaskItem) -> CGFloat {
        var level: CGFloat = 0
        var current = task.parentTask
        while current != nil {
            level += 1
            current = current?.parentTask
        }
        return level * 20
    }
}

// MARK: - Previews

/// Preview-only gradient layer — renders theme mesh as a ZStack sibling
/// instead of .background{} so it paints over NavigationStack's opaque system background.
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

private func previewTaskList(theme: AppTheme? = nil) -> some View {
    let tm = ThemeManager.shared
    if let theme { tm.applyApp(theme) }
    let container = try! AppSchemaBuilder.makeInMemoryContainer()
    let ctx = container.mainContext
    let folder = Folder(name: "Default")
    ctx.insert(folder)
    let list = TaskList(name: "Tasks", folder: folder)
    ctx.insert(list)
    for (i, (title, priority)) in [
        ("Buy groceries", "high"), ("Finish project", "medium"),
        ("Call dentist", "default"), ("Water plants", "default")
    ].enumerated() {
        let t = TaskItem(title: title, priority: priority, taskList: list)
        t.sortOrder = i
        ctx.insert(t)
    }
    return ZStack {
        previewGradient(tm)
        NavigationStack {
            TaskListView(taskList: list, onShowHome: {})
        }
    }
    .modelContainer(container)
    .environment(tm)
    .preferredColorScheme(tm.current.preferredScheme)
}

#Preview("Task List — Default") { previewTaskList() }
#Preview("Task List — Nebula") { previewTaskList(theme: .nebula) }
#Preview("Task List — Galaxy") { previewTaskList(theme: .galaxy) }
