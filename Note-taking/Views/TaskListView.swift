import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.sortOrder, order: .forward)
    private var allTasks: [TaskItem]

    @FocusState private var focusedTaskId: UUID?
    @State private var sortBy: SortOption = .manual
    @State private var showCompleted = false
    @State private var selectedTask: TaskItem?
    @State private var showTheme = false

    private var filteredTasks: [TaskItem] {
        var result = Array(allTasks)
        if !showCompleted {
            result = result.filter { !$0.isCompleted }
        }
        if sortBy == .creationDate {
            result.sort { $0.createdAt < $1.createdAt }
        }
        // Auto-group by priority color (red first, orange, then gray)
        // within the chosen sort — always
        let priorityOrder = ["high": 0, "medium": 1, "default": 2]
        let stable = result.enumerated().map { ($0.offset, $0.element) }
        result = stable.sorted { a, b in
            let pa = priorityOrder[a.1.priority] ?? 2
            let pb = priorityOrder[b.1.priority] ?? 2
            if pa != pb { return pa < pb }
            return a.0 < b.0
        }.map(\.1)
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
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 1, leading: 8 + indentLevel(for: task), bottom: 1, trailing: 8))
                    .listRowBackground(Color.clear)
                }
                .onMove { source, destination in
                    moveTask(from: source, to: destination)
                }
                .onDelete { offsets in
                    deleteTasks(at: offsets)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    settingsButton
                }
            }
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                Button(action: addTask) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.primary)
                        .frame(width: 48, height: 48)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 8)
            }
            .navigationDestination(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
            .navigationDestination(isPresented: $showTheme) {
                ThemeView()
            }
            // Auto-delete empty tasks when focus leaves
            .onChange(of: focusedTaskId) { oldId, _ in
                if let oldId = oldId {
                    cleanupEmptyTask(id: oldId)
                }
            }
        }
    }

    private var settingsButton: some View {
        SettingsMenuView(
            sortBy: $sortBy,
            showCompleted: $showCompleted,
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
        if let task = allTasks.first(where: { $0.id == id }),
           task.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           task.body == nil {
            modelContext.delete(task)
        }
    }

    private func toggleComplete(_ task: TaskItem) {
        withAnimation(.easeInOut(duration: 0.3)) {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
        }
    }

    private func moveTask(from source: IndexSet, to destination: Int) {
        var items = filteredTasks
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }
    }

    private func deleteTasks(at offsets: IndexSet) {
        let tasks = filteredTasks
        for index in offsets {
            modelContext.delete(tasks[index])
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
