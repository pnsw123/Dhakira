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

    @Query(sort: \TaskItem.sortOrder, order: .forward)
    private var allTasks: [TaskItem]

    @State private var sortBy: SortOption = .manual
    @State private var selectedTask: TaskItem?
    @State private var showTheme = false
    @State private var recentlyCompletedIds: Set<UUID> = []
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""

    // Inline "add task" — no task is created until the user types a name
    @State private var isAddingTask: Bool = false
    @State private var newTaskTitle: String = ""
    @FocusState private var newTaskFieldFocused: Bool

/// Tasks belonging to this task list (not soft-deleted).
    private var filteredTasks: [TaskItem] {
        var result = allTasks.filter { task in
            let belongsHere = taskList == nil ? true : task.taskList?.id == taskList?.id
            let notDeleted = !task.isDeleted
            let notCompleted = !task.isCompleted || recentlyCompletedIds.contains(task.id)
            return belongsHere && notDeleted && notCompleted
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
                    .listRowBackground(Color.screenBackground)
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
                            .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                            .frame(width: 28, height: 28)
                            .padding(.top, 1)

                        TextField("New Task", text: $newTaskTitle, axis: .vertical)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1...3)
                            .focused($newTaskFieldFocused)
                            .onSubmit { commitNewTask() }
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .listRowSpacing(0)
                    .listRowBackground(Color.screenBackground)
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
            .background(Color.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 0) {
                    if taskList == nil {
                        // Root view — back chevron navigates to HomeView (via ContentView)
                        Button(action: {
                            log.info("TaskListView: < button tapped (root), calling onShowHome, onShowHome=\(onShowHome != nil ? "set" : "NIL")")
                            onShowHome?()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.primary)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                        .accessibilityIdentifier("btn-go-to-folders")
                    } else {
                        // Pushed from HomeView — chevron goes back
                        Button(action: {
                            log.info("TaskListView: < button tapped (pushed list=\(taskList?.name ?? "?")), calling dismiss()")
                            dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.primary)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                    }

                    // List name — tappable to edit
                    if isEditingName {
                        TextField("List name", text: $editedName, onCommit: commitNameEdit)
                            .font(.system(size: 34, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, taskList == nil ? 16 : 4)
                    } else {
                        Text(displayName)
                            .font(.system(size: 34, weight: .bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, taskList == nil ? 16 : 4)
                            .onTapGesture {
                                if taskList != nil {
                                    editedName = displayName
                                    isEditingName = true
                                }
                            }
                    }

                    settingsButton
                }
                .padding(.trailing, 8)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color.screenBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 0.5)
                }
            }
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                Button(action: addTask) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 48, height: 48)
                        .background(.regularMaterial, in: Circle())
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .padding(.bottom, 8)
            }
            .navigationDestination(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
            .navigationDestination(isPresented: $showTheme) {
                ThemeView()
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    if !isAddingTask { addTask() }
                }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard isAddingTask else { return }
                    newTaskFieldFocused = false
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
        log.info("commitNewTask: created '\(trimmed)' (sortOrder=\(maxOrder))")
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

    private func toggleComplete(_ task: TaskItem) {
        let willComplete = !task.isCompleted
        log.info("toggleComplete: '\(task.title)' → \(willComplete ? "complete" : "incomplete")")
        withAnimation(.easeInOut(duration: 0.3)) {
            task.isCompleted = willComplete
            task.completedAt = willComplete ? Date() : nil
        }

        if willComplete {
            recentlyCompletedIds.insert(task.id)
            let taskId = task.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                recentlyCompletedIds.remove(taskId)
            }
        }
    }

    private func setPriority(_ task: TaskItem, to priority: String) {
        log.info("setPriority: '\(task.title)' → \(priority)")
        task.priority = priority
    }

    private func softDeleteTask(_ task: TaskItem) {
        log.info("softDeleteTask: '\(task.title)'")
        withAnimation(.smooth(duration: 0.3)) {
            task.isDeleted = true
            task.deletedAt = Date()
        }
    }

    private func moveTask(from source: IndexSet, to destination: Int) {
        var reordered = filteredTasks
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in reordered.enumerated() {
            item.sortOrder = index
        }
        try? modelContext.save()
        log.info("moveTask: reindexed \(reordered.count) tasks after move")
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
