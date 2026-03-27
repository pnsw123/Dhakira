import SwiftUI
import SwiftData

struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.createdAt, order: .reverse)
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
        switch sortBy {
        case .creationDate:
            result.sort { $0.createdAt > $1.createdAt }
        case .priority:
            let order = ["high": 0, "medium": 1, "default": 2]
            result.sort { (order[$0.priority] ?? 2) < (order[$1.priority] ?? 2) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if filteredTasks.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredTasks) { task in
                                TaskRowView(
                                    task: task,
                                    onToggleComplete: { toggleComplete(task) },
                                    onTapDetail: { selectedTask = task }
                                )
                                .focused($focusedTaskId, equals: task.id)
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
                        .padding(.bottom, 80)
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
            .overlay(alignment: .bottomTrailing) {
                addButton
            }
            .navigationDestination(item: $selectedTask) { task in
                TaskDetailView(task: task)
            }
            .navigationDestination(isPresented: $showTheme) {
                ThemeView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundStyle(Color.secondary.opacity(0.5))
            Text("No tasks yet")
                .font(.title3)
                .foregroundStyle(Color.secondary)
            Text("Tap + to create your first task")
                .font(.subheadline)
                .foregroundStyle(Color.secondary.opacity(0.7))
        }
    }

    private var addButton: some View {
        Button(action: addTask) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
        }
        .shadow(color: Color.primary.opacity(0.1), radius: 8, y: 4)
        .frame(minWidth: 44, minHeight: 44)
        .padding(.trailing, 24)
        .padding(.bottom, 24)
    }

    private func addTask() {
        withAnimation {
            let newTask = TaskItem(title: "")
            modelContext.insert(newTask)
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
        withAnimation {
            modelContext.delete(task)
        }
    }

    private func indentTask(_ task: TaskItem) {
        let sorted = filteredTasks
        guard let index = sorted.firstIndex(where: { $0.id == task.id }),
              index > 0 else { return }
        withAnimation {
            task.parentTask = sorted[index - 1]
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
