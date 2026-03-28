import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "TaskList")

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// The TaskList this view is scoped to. Nil means show all (legacy / default fallback).
    var taskList: TaskList?

    @Query(sort: \TaskItem.sortOrder, order: .forward)
    private var allTasks: [TaskItem]

    @FocusState private var focusedTaskId: UUID?
    @State private var sortBy: SortOption = .manual
    @State private var selectedTask: TaskItem?
    @State private var showTheme = false
    @State private var recentlyCompletedIds: Set<UUID> = []
    @State private var isEditingName: Bool = false
    @State private var editedName: String = ""
    @State private var showHome: Bool = false

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
                    .focused($focusedTaskId, equals: task.id)
                    .id(task.id)
                    .listRowSeparator(.visible, edges: .bottom)
                    .listRowSeparatorTint(Color.black.opacity(0.10))
                    .listRowInsets(EdgeInsets(top: 0, leading: 4 + indentLevel(for: task), bottom: 0, trailing: 0))
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
            }
            .animation(.smooth(duration: 0.35), value: filteredTasks.count)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 0) {
                    if taskList == nil {
                        // Root view — back chevron navigates to HomeView
                        Button(action: { showHome = true }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(Color.primary)
                                .frame(width: 36, height: 36)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 8)
                    } else {
                        // Pushed from HomeView — chevron goes back
                        Button(action: { dismiss() }) {
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
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 0.5)
                }
            }
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                Button(action: addTask) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.fabIcon)
                        .frame(width: 48, height: 48)
                        .background(Color.fabColor, in: Circle())
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .padding(.bottom, 8)
            }
            .navigationDestination(isPresented: $showHome) {
                HomeView(isPresented: $showHome)
            }
            .navigationDestination(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
            .navigationDestination(isPresented: $showTheme) {
                ThemeView()
            }
            .onChange(of: focusedTaskId) { oldValue, newValue in
                if let old = oldValue, old != newValue {
                    cleanupEmptyTask(id: old)
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
        let scopedTasks = allTasks.filter { taskList == nil ? true : $0.taskList?.id == taskList?.id }
        let maxOrder = (scopedTasks.map(\.sortOrder).max() ?? 0) + 1
        let newTask = TaskItem(title: "", taskList: taskList)
        newTask.sortOrder = maxOrder
        modelContext.insert(newTask)
        log.info("addTask: inserted new task (sortOrder=\(maxOrder))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            focusedTaskId = newTask.id
        }
    }

    private func cleanupEmptyTask(id: UUID) {
        guard selectedTask?.id != id else {
            log.debug("cleanupEmptyTask: skipping — task is currently open in detail view")
            return
        }
        if let task = allTasks.first(where: { $0.id == id }),
           task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           task.body == nil {
            log.info("cleanupEmptyTask: deleting empty task \(id)")
            withAnimation(.smooth(duration: 0.3)) {
                modelContext.delete(task)
            }
        }
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
        guard let sourceIndex = source.first else { return }
        let movedItem = filteredTasks[sourceIndex]
        log.info("moveTask: '\(movedItem.title)' from index \(sourceIndex) to \(destination)")
        var newItems = filteredTasks
        newItems.move(fromOffsets: source, toOffset: destination)
        let newIndex = newItems.firstIndex(where: { $0.id == movedItem.id }) ?? destination

        let prevOrder = newIndex > 0 ? newItems[newIndex - 1].sortOrder : nil
        let nextOrder = newIndex < newItems.count - 1 ? newItems[newIndex + 1].sortOrder : nil

        switch (prevOrder, nextOrder) {
        case (nil, let n?):
            movedItem.sortOrder = n - 1000
        case (let p?, nil):
            movedItem.sortOrder = p + 1000
        case (let p?, let n?) where n - p > 1:
            movedItem.sortOrder = (p + n) / 2
        default:
            for (index, item) in newItems.enumerated() {
                item.sortOrder = index * 1000
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
