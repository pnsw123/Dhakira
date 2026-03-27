import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .forward)
    private var allTasks: [TaskItem]

    @FocusState private var focusedTaskId: UUID?
    @State private var sortBy: SortOption = .creationDate
    @State private var showCompleted = false
    @State private var selectedTask: TaskItem?
    @State private var showTheme = false

    private var filteredTasks: [TaskItem] {
        var result = Array(allTasks)
        if !showCompleted {
            result = result.filter { !$0.isCompleted }
        }
        if sortBy == .priority {
            let order = ["high": 0, "medium": 1, "default": 2]
            result.sort { (order[$0.priority] ?? 2) < (order[$1.priority] ?? 2) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredTasks) { task in
                            TaskRowView(
                                task: task,
                                onToggleComplete: { toggleComplete(task) },
                                onTapDetail: { selectedTask = task }
                            )
                            .focused($focusedTaskId, equals: task.id)
                            .id(task.id)
                            .padding(.leading, indentLevel(for: task))
                            .contextMenu {
                                Button(role: .destructive) {
                                    deleteTask(task)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    indentTask(task)
                                } label: {
                                    Label("Make Sub-task", systemImage: "increase.indent")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 90)
                }
                .onChange(of: focusedTaskId) { _, newId in
                    if let id = newId {
                        withAnimation {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    SettingsMenuView(
                        sortBy: $sortBy,
                        showCompleted: $showCompleted,
                        onThemeTapped: { showTheme = true }
                    )
                }
            }
            .safeAreaInset(edge: .bottom, alignment: .trailing) {
                Button(action: addTask) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.secondary)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
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
        }
    }

    private func addTask() {
        let newTask = TaskItem(title: "")
        modelContext.insert(newTask)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedTaskId = newTask.id
        }
    }

    private func toggleComplete(_ task: TaskItem) {
        withAnimation(.easeInOut(duration: 0.3)) {
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
        }
    }

    private func deleteTask(_ task: TaskItem) {
        withAnimation { modelContext.delete(task) }
    }

    private func indentTask(_ task: TaskItem) {
        let sorted = filteredTasks
        guard let index = sorted.firstIndex(where: { $0.id == task.id }),
              index > 0 else { return }
        withAnimation { task.parentTask = sorted[index - 1] }
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
