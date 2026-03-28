import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "RecentlyDeleted")

struct RecentlyDeletedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(
        filter: #Predicate<TaskItem> { $0.isDeleted == true },
        sort: \TaskItem.deletedAt,
        order: .reverse
    )
    private var deletedTasks: [TaskItem]

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    var body: some View {
        NavigationStack {
            Group {
                if deletedTasks.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(deletedTasks) { task in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title.isEmpty ? "Untitled" : task.title)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.primary)

                                HStack(spacing: 4) {
                                    if let listName = task.taskList?.name {
                                        Text(listName)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.secondary.opacity(0.7))
                                        Text("·")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.secondary.opacity(0.5))
                                    }
                                    if let folder = task.taskList?.folder {
                                        Text(folder.name)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.secondary.opacity(0.7))
                                        Text("·")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.secondary.opacity(0.5))
                                    }
                                    if let deletedAt = task.deletedAt {
                                        Text("Deleted \(Self.dateFormatter.string(from: deletedAt))")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.secondary.opacity(0.6))
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(Color.screenBackground)
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button(action: { restoreTask(task) }) {
                                    Label("Restore", systemImage: "arrow.uturn.backward")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive, action: { permanentlyDelete(task) }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.screenBackground)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 0) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)

                    Text("Recently Deleted")
                        .font(.system(size: 28, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 4)
                }
                .padding(.trailing, 16)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color.screenBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 0.5)
                }
            }
            .background(Color.screenBackground)
        }
        .navigationBarBackButtonHidden(true)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "trash")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.secondary.opacity(0.4))
            Text("No recently deleted tasks")
                .font(.system(size: 17))
                .foregroundStyle(Color.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func restoreTask(_ task: TaskItem) {
        log.info("restoreTask: '\(task.title)'")
        withAnimation(.smooth(duration: 0.3)) {
            task.isDeleted = false
            task.deletedAt = nil
        }
    }

    private func permanentlyDelete(_ task: TaskItem) {
        log.info("permanentlyDelete: '\(task.title)'")
        withAnimation(.smooth(duration: 0.3)) {
            modelContext.delete(task)
        }
    }
}
