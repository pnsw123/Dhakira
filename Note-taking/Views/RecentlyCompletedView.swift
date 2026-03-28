import SwiftUI
import SwiftData

struct RecentlyCompletedView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<TaskItem> { $0.isCompleted == true && $0.isDeleted == false },
        sort: \TaskItem.completedAt,
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
        NavigationStack {
            Group {
                if completedTasks.isEmpty {
                    emptyState
                } else {
                    List(completedTasks) { task in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title.isEmpty ? "Untitled" : task.title)
                                .font(.system(size: 15))
                                .strikethrough(true)
                                .foregroundStyle(Color.secondary)

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
                                if let completedAt = task.completedAt {
                                    Text(Self.dateFormatter.string(from: completedAt))
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.secondary.opacity(0.6))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Color.screenBackground)
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

                    Text("Recently Completed")
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
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(Color.secondary.opacity(0.4))
            Text("No completed tasks yet")
                .font(.system(size: 17))
                .foregroundStyle(Color.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
