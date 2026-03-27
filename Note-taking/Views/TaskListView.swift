import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder, order: .forward)
    private var allTasks: [TaskItem]

    @FocusState private var focusedTaskId: UUID?
    @State private var sortBy: SortOption = .manual
    @State private var selectedTask: TaskItem?
    @State private var showTheme = false
    @State private var recentlyCompletedIds: Set<UUID> = []

    private var filteredTasks: [TaskItem] {
        var result = Array(allTasks)
        result = result.filter { !$0.isCompleted || recentlyCompletedIds.contains($0.id) }
        if sortBy == .creationDate {
            result.sort { $0.createdAt < $1.createdAt }
        }
        return result
    }

    var body: some View {
        NavigationStack {
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
                }
                .onMove { source, destination in
                    moveTask(from: source, to: destination)
                }
                .onDelete { offsets in
                    deleteTasks(at: offsets)
                }
            }
            .animation(.smooth(duration: 0.35), value: filteredTasks.count)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                HStack {
                    Text("Tasks")
                        .font(.system(size: 34, weight: .bold))
                    Spacer()
                    settingsButton
                }
                .padding(.leading, 16)
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
            .onTapGesture(count: 2) {
                addTask()
            }
        }
    }

    private var settingsButton: some View {
        SettingsMenuView(
            sortBy: $sortBy,
            onThemeTapped: { showTheme = true }
        )
    }

    private func addTask() {
        let maxOrder = (allTasks.map(\.sortOrder).max() ?? 0) + 1
        let newTask = TaskItem(title: "")
        newTask.sortOrder = maxOrder
        modelContext.insert(newTask)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedTaskId = newTask.id
        }
    }

    private func cleanupEmptyTask(id: UUID) {
        // Never delete the task currently open in the detail view
        guard selectedTask?.id != id else { return }
        if let task = allTasks.first(where: { $0.id == id }),
           task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           task.body == nil {
            withAnimation(.smooth(duration: 0.3)) {
                modelContext.delete(task)
            }
        }
    }

    private func toggleComplete(_ task: TaskItem) {
        let willComplete = !task.isCompleted
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
        task.priority = priority
    }

    private func moveTask(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        let movedItem = filteredTasks[sourceIndex]
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
            // No gap between neighbours — re-normalise all with spacing
            for (index, item) in newItems.enumerated() {
                item.sortOrder = index * 1000
            }
        }
    }

    private func deleteTasks(at offsets: IndexSet) {
        let tasks = filteredTasks
        withAnimation(.smooth(duration: 0.3)) {
            for index in offsets {
                modelContext.delete(tasks[index])
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
