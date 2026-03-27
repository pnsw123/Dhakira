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
        var result = allTasks
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
            ZStack {
                if filteredTasks.isEmpty {
                    emptyState
                } else {
                    taskList
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
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(Color.secondary)
            Text("No tasks yet")
                .font(.headline)
                .foregroundStyle(Color.secondary)
        }
    }

    private var taskList: some View {
        List {
            ForEach(filteredTasks) { task in
                TaskRowView(
                    task: task,
                    isFocused: focusedTaskId == task.id,
                    onToggleComplete: {
                        toggleComplete(task)
                    },
                    onTapDetail: {
                        selectedTask = task
                    }
                )
                .focused($focusedTaskId, equals: task.id)
                .padding(.leading, indentLevel(for: task))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        deleteTask(task)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        indentTask(task)
                    } label: {
                        Label("Indent", systemImage: "increase.indent")
                    }
                    .tint(Color.accentColor)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var addButton: some View {
        Button(action: addTask) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .shadow(color: Color.primary.opacity(0.15), radius: 4, y: 2)
        }
        .frame(minWidth: 44, minHeight: 44)
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    private func addTask() {
        let newTask = TaskItem(title: "")
        modelContext.insert(newTask)
        focusedTaskId = newTask.id
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
        let parentCandidate = sorted[index - 1]
        withAnimation {
            task.parentTask = parentCandidate
        }
    }

    private func indentLevel(for task: TaskItem) -> CGFloat {
        var level: CGFloat = 0
        var current = task.parentTask
        while current != nil {
            level += 1
            current = current?.parentTask
        }
        return level * 24
    }
}
