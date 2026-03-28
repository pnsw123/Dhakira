import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "HomeView")

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Folder> { $0.parentFolder == nil }, sort: \Folder.createdAt)
    private var topLevelFolders: [Folder]

    @Query(sort: \TaskList.createdAt)
    private var allTaskLists: [TaskList]

    /// The Default Folder's "Tasks" list for the > shortcut.
    private var defaultTaskList: TaskList? {
        topLevelFolders
            .first(where: { $0.name == "Default" })
            .flatMap { folder in
                allTaskLists.first(where: { $0.folder?.id == folder.id })
            }
    }

    @State private var navigateToDefaultList: Bool = false
    @State private var selectedTaskList: TaskList?
    @State private var showRecentlyCompleted: Bool = false
    @State private var showRecentlyDeleted: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Folders section
                    foldersSection

                    // Recently Completed card
                    Button(action: { showRecentlyCompleted = true }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.primary)
                            Text("Recently Completed")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    // Recently Deleted card
                    Button(action: { showRecentlyDeleted = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.primary)
                            Text("Recently Deleted")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color.screenBackground)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 0) {
                    Text("Home")
                        .font(.system(size: 34, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)

                    // New Folder button
                    Button(action: createNewFolder) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(Color.primary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)

                    // > shortcut to default Tasks list
                    if defaultTaskList != nil {
                        Button(action: { navigateToDefaultList = true }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color.screenBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.black.opacity(0.06))
                        .frame(height: 0.5)
                }
            }
            .navigationDestination(isPresented: $navigateToDefaultList) {
                if let list = defaultTaskList {
                    TaskListView(taskList: list)
                }
            }
            .navigationDestination(item: $selectedTaskList) { list in
                TaskListView(taskList: list)
            }
            .navigationDestination(isPresented: $showRecentlyCompleted) {
                RecentlyCompletedView()
            }
            .navigationDestination(isPresented: $showRecentlyDeleted) {
                RecentlyDeletedView()
            }
        }
    }

    // MARK: - Folders Section

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "folder")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                Text("Folders")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)

            if topLevelFolders.isEmpty {
                // Empty state — card still visible, no collapse control
                HStack {
                    Image(systemName: "folder")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                    Text("No folders yet")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    FolderSectionView(
                        folders: topLevelFolders,
                        allTaskLists: allTaskLists,
                        onSelectTaskList: { list in selectedTaskList = list }
                    )
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Actions

    private func createNewFolder() {
        log.info("createNewFolder: creating new top-level folder")
        let folder = Folder(name: "New Folder")
        modelContext.insert(folder)
    }
}
