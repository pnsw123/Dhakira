import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "HomeView")

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// Called by the > button — more reliable than dismiss() with NavigationStack bindings.
    var onClose: (() -> Void)? = nil

    @Query(filter: #Predicate<Folder> { $0.parentFolder == nil }, sort: \Folder.createdAt)
    private var topLevelFolders: [Folder]

    @Query(sort: \TaskList.createdAt)
    private var allTaskLists: [TaskList]

    @State private var selectedTaskList: TaskList?
    @State private var showRecentlyCompleted: Bool = false
    @State private var showRecentlyDeleted: Bool = false
    @State private var autoRenameFolderId: UUID? = nil

    var body: some View {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    // Folders section
                    foldersSection
                        .id("folders-section")

                    // Recently Completed card
                    Button(action: { showRecentlyCompleted = true }) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.primary)
                            Text("Recently Completed")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
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
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.primary)
                            Text("Recently Deleted")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
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
            .onAppear {
                log.info("HomeView: appeared — topLevelFolders=\(topLevelFolders.count), allTaskLists=\(allTaskLists.count)")
            }
            .onDisappear {
                log.info("HomeView: disappeared")
            }
            .onChange(of: selectedTaskList) { old, new in
                log.info("HomeView: selectedTaskList changed \(old?.name ?? "nil") → \(new?.name ?? "nil")")
            }
            .onChange(of: autoRenameFolderId) { _, newId in
                if newId != nil {
                    withAnimation { proxy.scrollTo("folders-section", anchor: .top) }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                HStack(spacing: 0) {
                    Spacer()

                    // > goes back to Tasks (the default page)
                    Button(action: {
                        log.info("HomeView: > button tapped → calling onClose()")
                        onClose?()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.primary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                    .accessibilityIdentifier("btn-go-to-tasks")
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
            .navigationDestination(item: $selectedTaskList) { list in
                TaskListView(taskList: list)
            }
            .navigationDestination(isPresented: $showRecentlyCompleted) {
                RecentlyCompletedView()
            }
            .navigationDestination(isPresented: $showRecentlyDeleted) {
                RecentlyDeletedView()
            }
            } // ScrollViewReader
    }

    // MARK: - Folders Section

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Folders")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.primary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                if !topLevelFolders.isEmpty {
                    FolderSectionView(
                        folders: topLevelFolders,
                        allTaskLists: allTaskLists,
                        onSelectTaskList: { list in
                        log.info("HomeView: onSelectTaskList called for '\(list.name)' — setting selectedTaskList")
                        selectedTaskList = list
                    },
                        autoRenameId: autoRenameFolderId
                    )
                    Divider().padding(.leading, 16)
                }

                // "Add Folder" lives inside the section card — neutral color, no blue
                Button(action: createNewFolder) {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.primary)
                            .frame(width: 22)
                        Text("Add Folder")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Actions

    private func createNewFolder() {
        log.info("createNewFolder: creating new top-level folder")
        let folder = Folder(name: "")
        modelContext.insert(folder)
        autoRenameFolderId = folder.id
    }
}
