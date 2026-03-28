import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "FolderSection")

/// Recursive folder tree, Finder list-view style, with inline expand/collapse.
struct FolderSectionView: View {
    let folders: [Folder]
    let allTaskLists: [TaskList]
    var onSelectTaskList: (TaskList) -> Void
    var indentLevel: Int = 0

    /// Shared expand state so all levels share the same expanded set.
    @State private var expandedFolderIds: Set<UUID> = []

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                FolderRowView(
                    folder: folder,
                    allTaskLists: allTaskLists,
                    isExpanded: expandedFolderIds.contains(folder.id),
                    onToggle: { toggleFolder(folder) },
                    onSelectTaskList: onSelectTaskList,
                    indentLevel: indentLevel
                )

                if index < folders.count - 1 {
                    Divider()
                        .padding(.leading, CGFloat(16 + indentLevel * 20))
                }
            }
        }
        .onAppear {
            // Pre-expand Default Folder if it has contents
            for folder in folders where folder.name == "Default" {
                let hasContents = !(folder.subfolders?.isEmpty ?? true) ||
                    !allTaskLists.filter({ $0.folder?.id == folder.id }).isEmpty
                if hasContents {
                    expandedFolderIds.insert(folder.id)
                }
            }
        }
    }

    private func toggleFolder(_ folder: Folder) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedFolderIds.contains(folder.id) {
                expandedFolderIds.remove(folder.id)
            } else {
                expandedFolderIds.insert(folder.id)
            }
        }
        log.debug("toggleFolder: '\(folder.name)' → \(expandedFolderIds.contains(folder.id) ? "expanded" : "collapsed")")
    }
}

// MARK: - FolderRowView

struct FolderRowView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var folder: Folder
    let allTaskLists: [TaskList]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onSelectTaskList: (TaskList) -> Void
    var indentLevel: Int = 0

    @State private var isRenaming: Bool = false
    @State private var renameText: String = ""
    @State private var showDeleteConfirm: Bool = false

    private var taskListsForFolder: [TaskList] {
        allTaskLists.filter { $0.folder?.id == folder.id }
    }

    private var subfolders: [Folder] {
        (folder.subfolders ?? []).sorted(by: { $0.createdAt < $1.createdAt })
    }

    private var hasContents: Bool {
        !subfolders.isEmpty || !taskListsForFolder.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Folder header row
            HStack(spacing: 10) {
                Spacer().frame(width: CGFloat(indentLevel * 20))

                Image(systemName: isExpanded ? "folder.fill" : "folder")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22)

                if isRenaming {
                    TextField("Folder name", text: $renameText, onCommit: commitRename)
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(folder.name)
                        .font(.system(size: 16))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Expand chevron — only shown when folder has contents
                if hasContents {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                if hasContents { onToggle() }
            }
            .contextMenu {
                Button(action: startRename) {
                    Label("Rename", systemImage: "pencil")
                }
                Button(action: addTaskList) {
                    Label("Add List", systemImage: "plus.circle")
                }
                Button(action: addSubfolder) {
                    Label("New Subfolder", systemImage: "folder.badge.plus")
                }
                Divider()
                Button(role: .destructive, action: { showDeleteConfirm = true }) {
                    Label("Delete", systemImage: "trash")
                }
            }
            .confirmationDialog("Delete \"\(folder.name)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Folder", role: .destructive, action: deleteFolder)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("All task lists and tasks inside this folder will be permanently removed.")
            }

            // Expanded content: subfolders + task lists
            if isExpanded {
                // Subfolders (recursive)
                if !subfolders.isEmpty {
                    Divider().padding(.leading, CGFloat(16 + (indentLevel + 1) * 20))
                    FolderSectionView(
                        folders: subfolders,
                        allTaskLists: allTaskLists,
                        onSelectTaskList: onSelectTaskList,
                        indentLevel: indentLevel + 1
                    )
                }

                // Task list rows
                ForEach(taskListsForFolder) { taskList in
                    Divider().padding(.leading, CGFloat(16 + (indentLevel + 1) * 20))
                    TaskListRowView(
                        taskList: taskList,
                        indentLevel: indentLevel + 1,
                        onTap: { onSelectTaskList(taskList) }
                    )
                }

                // "Add List" inline button
                Divider().padding(.leading, CGFloat(16 + (indentLevel + 1) * 20))
                Button(action: addTaskList) {
                    HStack(spacing: 10) {
                        Spacer().frame(width: CGFloat((indentLevel + 1) * 20))
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 22)
                        Text("Add List")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.accentColor)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func startRename() {
        renameText = folder.name
        isRenaming = true
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            folder.name = trimmed
            log.info("commitRename: folder renamed to '\(trimmed)'")
        }
        isRenaming = false
    }

    private func deleteFolder() {
        log.info("deleteFolder: '\(folder.name)'")
        // Delete all task lists and their tasks
        for list in taskListsForFolder {
            for task in (list.tasks ?? []) {
                modelContext.delete(task)
            }
            modelContext.delete(list)
        }
        // Delete subfolders recursively handled by cascade relationship
        modelContext.delete(folder)
    }

    private func addTaskList() {
        log.info("addTaskList: adding to folder '\(folder.name)'")
        let newList = TaskList(name: "New List", folder: folder)
        modelContext.insert(newList)
    }

    private func addSubfolder() {
        log.info("addSubfolder: inside '\(folder.name)'")
        let sub = Folder(name: "New Folder", parentFolder: folder)
        modelContext.insert(sub)
    }
}

// MARK: - TaskListRowView

struct TaskListRowView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var taskList: TaskList
    var indentLevel: Int = 0
    let onTap: () -> Void

    @State private var isRenaming: Bool = false
    @State private var renameText: String = ""

    var body: some View {
        HStack(spacing: 10) {
            Spacer().frame(width: CGFloat(indentLevel * 20))

            Image(systemName: "list.bullet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.secondary)
                .frame(width: 22)

            if isRenaming {
                TextField("List name", text: $renameText, onCommit: commitRename)
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(taskList.name)
                    .font(.system(size: 15))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .contextMenu {
            Button(action: startRename) {
                Label("Rename", systemImage: "pencil")
            }
        }
    }

    private func startRename() {
        renameText = taskList.name
        isRenaming = true
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            taskList.name = trimmed
        }
        isRenaming = false
    }
}
