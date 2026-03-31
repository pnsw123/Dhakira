import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "RecentlyCompleted")

struct RecentlyCompletedView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<TaskItem> { $0.isCompleted == true && $0.isDeleted == false },
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
                List(completedTasks) { task in
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
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) {
            HStack(spacing: 0) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.themeAccent)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Text("Recently Completed")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
            }
            .contentShape(Rectangle())
            .padding(.trailing, 16)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.separatorColor)
                    .frame(height: 0.5)
            }
        }
        .background(Color.clear)
        .navigationBarBackButtonHidden(true)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.secondaryText.opacity(0.4))
            Text("No completed tasks yet")
                .font(.system(size: 17))
                .foregroundStyle(Color.secondaryText)
            Spacer()
        }
        .frame(maxWidth: .infinity)
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
#Preview("Recently Completed — Nord") { previewCompleted(theme: .nord) }
