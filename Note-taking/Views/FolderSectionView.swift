import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "FolderSection")


/// Recursive folder tree, Finder list-view style, with inline expand/collapse.
struct FolderSectionView: View {
    let folders: [Folder]
    let allTaskLists: [TaskList]
    var onSelectTaskList: (TaskList) -> Void
    var indentLevel: Int = 0
    var autoRenameId: UUID? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager

    /// Expanded folder IDs persisted in UserDefaults so state survives data refreshes.
    @AppStorage("expandedFolderIds_v2") private var expandedFolderIdsStorage: String = ""
    @State private var expandedFolderIds: Set<UUID> = []
    @State private var draggedFolder: Folder? = nil

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(folders.enumerated()), id: \.element.id) { index, folder in
                FolderRowView(
                    folder: folder,
                    allTaskLists: allTaskLists,
                    isExpanded: expandedFolderIds.contains(folder.id),
                    onToggle: { toggleFolder(folder) },
                    onSelectTaskList: onSelectTaskList,
                    indentLevel: indentLevel,
                    startEditingOnAppear: folder.id == autoRenameId
                )
                .onDrag {
                    draggedFolder = folder
                    return NSItemProvider(object: folder.id.uuidString as NSString)
                }
                .onDrop(of: [.text], delegate: FolderReorderDelegate(
                    folder: folder,
                    folders: folders,
                    draggedFolder: $draggedFolder,
                    modelContext: modelContext
                ))

                if index < folders.count - 1 {
                    Divider()
                        .padding(.leading, CGFloat(16 + indentLevel * 20))
                }
            }
        }
        .onAppear {
            // Restore persisted expanded state
            let persisted = Set(expandedFolderIdsStorage.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
            expandedFolderIds = persisted

            // Auto-expand newly created folder so user sees Add List immediately
            if let id = autoRenameId {
                expandedFolderIds.insert(id)
            }
            // Note: do NOT call saveExpandedState() here — onChange(of: expandedFolderIds) handles
            // persistence for any mutations above, and calling it here causes a cascade re-render
            // across all recursive FolderSectionView instances that share the same @AppStorage key.
        }
        .onChange(of: autoRenameId) { _, newId in
            if let id = newId {
                expandedFolderIds.insert(id)
                saveExpandedState()
            }
        }
        .onChange(of: expandedFolderIds) { _, _ in
            saveExpandedState()
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
        saveExpandedState()
    }

    private func saveExpandedState() {
        // Read the full persisted set. This instance only owns the IDs of its direct
        // `folders` — it should not touch IDs owned by sibling/parent instances.
        // Strategy:
        //   1. Parse the full stored set.
        //   2. Remove IDs this instance is responsible for (our folders' IDs).
        //   3. Add back only the ones that are currently expanded in this instance.
        // This way collapsed folders are removed, expanded ones are written, and IDs
        // from other recursive instances are left untouched.
        var full = Set(expandedFolderIdsStorage.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
        let myFolderIds = Set(folders.map(\.id))
        full.subtract(myFolderIds)          // remove stale entries for our scope
        full.formUnion(expandedFolderIds)   // add currently expanded ones from our scope
        let newValue = full.map(\.uuidString).joined(separator: ",")
        guard newValue != expandedFolderIdsStorage else { return }
        expandedFolderIdsStorage = newValue
    }
}

// MARK: - FolderReorderDelegate

/// Native DropDelegate for smooth drag-to-reorder. Items slide out of the way
/// as you drag over them — the standard Apple pattern for reordering.
private struct FolderReorderDelegate: DropDelegate {
    let folder: Folder
    let folders: [Folder]
    @Binding var draggedFolder: Folder?
    let modelContext: ModelContext

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedFolder,
              dragged.id != folder.id,
              let fromIndex = folders.firstIndex(where: { $0.id == dragged.id }),
              let toIndex = folders.firstIndex(where: { $0.id == folder.id })
        else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            // Swap sortOrders so the dragged item moves to the new position
            let fromOrder = dragged.sortOrder
            dragged.sortOrder = folder.sortOrder
            folder.sortOrder = fromOrder
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        // Renumber all sortOrders cleanly
        let sorted = folders.sorted(by: { $0.sortOrder < $1.sortOrder })
        for (i, f) in sorted.enumerated() {
            f.sortOrder = i * 10
        }
        try? modelContext.save()
        draggedFolder = nil
        return true
    }

    func dropExited(info: DropInfo) {
        // No-op — cleanup happens in performDrop
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
    var startEditingOnAppear: Bool = false

    @Environment(\.undoManager) private var undoManager

    @State private var isRenaming: Bool = false
    @State private var renameText: String = ""
    @FocusState private var isRenameFocused: Bool
    // showDeleteConfirm removed — delete is now instant (tasks go to Recently Deleted)
    @State private var autoRenameListId: UUID? = nil
    @State private var autoRenameSubfolderId: UUID? = nil
    @State private var isAddingNewList: Bool = false
    @State private var newListName: String = ""
    @FocusState private var isNewListFocused: Bool

    private var taskListsForFolder: [TaskList] {
        allTaskLists.filter { $0.folder?.id == folder.id }
    }

    private var subfolders: [Folder] {
        (folder.subfolders ?? []).sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    private var hasContents: Bool {
        !subfolders.isEmpty || !taskListsForFolder.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Folder header row
            HStack(spacing: 10) {
                Spacer().frame(width: CGFloat(indentLevel * 20))

                Image(systemName: "folder.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color.themeAccent)
                    .frame(width: 22)

                if isRenaming {
                    TextField("Folder name", text: $renameText, onCommit: commitRename)
                        .font(.system(size: 17))
                        .foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .focused($isRenameFocused)
                } else {
                    Text(folder.name)
                        .font(.system(size: 17))
                        .foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Expand chevron — always shown so any folder can be opened
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }
            .onAppear {
                if startEditingOnAppear {
                    renameText = folder.name
                    isRenaming = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isRenameFocused = true
                    }
                }
            }
            .onChange(of: isRenameFocused) { _, focused in
                // Commit the rename whenever the keyboard is dismissed (tap outside or Return).
                if !focused && isRenaming { commitRename() }
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
                Button(role: .destructive, action: deleteFolder) {
                    Label("Delete", systemImage: "trash")
                }
            }

            // Expanded content: subfolders + task lists
            if isExpanded {
                // Subfolders (recursive) — capped at depth 10 to prevent stack overflow
                if !subfolders.isEmpty && indentLevel < 10 {
                    Divider().padding(.leading, CGFloat(16 + (indentLevel + 1) * 20))
                    FolderSectionView(
                        folders: subfolders,
                        allTaskLists: allTaskLists,
                        onSelectTaskList: onSelectTaskList,
                        indentLevel: indentLevel + 1,
                        autoRenameId: autoRenameSubfolderId
                    )
                }

                // Task list rows
                ForEach(taskListsForFolder) { taskList in
                    Divider().padding(.leading, CGFloat(16 + (indentLevel + 1) * 20))
                    TaskListRowView(
                        taskList: taskList,
                        indentLevel: indentLevel + 1,
                        onTap: { onSelectTaskList(taskList) },
                        startEditingOnAppear: taskList.id == autoRenameListId
                    )
                }

                // Inline "new list" name input — only visible while addTaskList() is in progress
                if isAddingNewList {
                    Divider().padding(.leading, CGFloat(16 + (indentLevel + 1) * 20))
                    HStack(spacing: 10) {
                        Spacer().frame(width: CGFloat((indentLevel + 1) * 20))
                        Image(systemName: "list.bullet")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.secondaryText)
                            .frame(width: 22)
                        TextField("List name", text: $newListName)
                            .font(.system(size: 17))
                            .foregroundStyle(Color.primaryText)
                            .focused($isNewListFocused)
                            .onSubmit { commitNewList() }
                            .onChange(of: isNewListFocused) { _, focused in
                                if !focused { commitNewList() }
                            }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 15)
                }

                // "Add List" — visually lighter than content rows so it reads as an action
                Divider().padding(.leading, CGFloat(16 + (indentLevel + 1) * 20))
                Button(action: addTaskList) {
                    HStack(spacing: 10) {
                        Spacer().frame(width: CGFloat((indentLevel + 1) * 20))
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.themeAccent.opacity(0.6))
                            .frame(width: 22)
                        Text("Add List")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func startRename() {
        renameText = folder.name
        isRenaming = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isRenameFocused = true
        }
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            deleteFolder()
        } else {
            folder.name = trimmed
            log.info("commitRename: folder renamed to '\(trimmed)'")
        }
        isRenaming = false
    }

    private func deleteFolder() {
        log.info("deleteFolder: '\(folder.name)'")
        let now = Date()
        for list in taskListsForFolder {
            for task in (list.tasks ?? []) where !task.isTrashed {
                task.isTrashed = true
                task.deletedAt = now
            }
            modelContext.delete(list)
        }
        modelContext.delete(folder)
        do { try modelContext.save() } catch {
            log.error("deleteFolder: save failed — \(error.localizedDescription)")
        }
    }

    private func addTaskList() {
        log.info("addTaskList: showing inline name input for folder '\(folder.name)'")
        newListName = ""
        isAddingNewList = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isNewListFocused = true
        }
    }

    private func commitNewList() {
        let trimmed = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        isAddingNewList = false
        isNewListFocused = false
        newListName = ""
        guard !trimmed.isEmpty else {
            log.info("commitNewList: cancelled — empty name, nothing inserted")
            return
        }
        log.info("addTaskList: inserting new list '\(trimmed)' in folder '\(folder.name)'")
        let newList = TaskList(name: trimmed, folder: folder)
        modelContext.insert(newList)
        autoRenameListId = nil  // no further rename needed — already has a valid name
    }

    /// Returns true if `potentialAncestor` is an ancestor of `folder` (prevents circular nesting).
    private static func isAncestor(_ potentialAncestor: Folder, of folder: Folder) -> Bool {
        var current = folder.parentFolder
        while let parent = current {
            if parent.id == potentialAncestor.id { return true }
            current = parent.parentFolder
        }
        return false
    }

    /// Returns the nesting depth of a folder (root = 0).
    private static func depth(of folder: Folder) -> Int {
        var d = 0
        var current = folder.parentFolder
        while let parent = current {
            d += 1
            current = parent.parentFolder
        }
        return d
    }

    private func addSubfolder() {
        log.info("addSubfolder: inside '\(folder.name)'")
        let maxOrder = subfolders.map(\.sortOrder).max() ?? -10
        let sub = Folder(name: "", parentFolder: folder)
        sub.sortOrder = maxOrder + 10
        modelContext.insert(sub)
        autoRenameSubfolderId = sub.id
        // Ensure parent is expanded so the new subfolder is visible for rename
        if !isExpanded { onToggle() }
    }
}

// MARK: - TaskListRowView

struct TaskListRowView: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var taskList: TaskList
    var indentLevel: Int = 0
    let onTap: () -> Void
    var startEditingOnAppear: Bool = false

    @State private var isRenaming: Bool = false
    @State private var renameText: String = ""
    @FocusState private var isRenameFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Spacer().frame(width: CGFloat(indentLevel * 20))

            Image(systemName: "list.bullet")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.secondaryText)
                .frame(width: 22)

            if isRenaming {
                TextField("List name", text: $renameText, onCommit: commitRename)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused($isRenameFocused)
            } else {
                Text(taskList.name)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.secondaryText.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .onAppear {
            if startEditingOnAppear {
                renameText = taskList.name
                isRenaming = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isRenameFocused = true
                }
            }
        }
        .onChange(of: isRenameFocused) { _, focused in
            if !focused && isRenaming { commitRename() }
        }
        .contextMenu {
            Button(action: startRename) {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: deleteTaskList) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func startRename() {
        log.info("TaskListRowView.startRename: '\(taskList.name)'")
        renameText = taskList.name
        isRenaming = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isRenameFocused = true
        }
    }

    private func commitRename() {
        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            log.info("TaskListRowView.commitRename: empty name — deleting list '\(taskList.name)'")
            deleteTaskList()
        } else {
            log.info("TaskListRowView.commitRename: renamed '\(taskList.name)' → '\(trimmed)'")
            taskList.name = trimmed
        }
        isRenaming = false
    }

    private func deleteTaskList() {
        log.info("TaskListRowView.deleteTaskList: '\(taskList.name)'")
        let now = Date()
        for task in (taskList.tasks ?? []) where !task.isTrashed {
            task.isTrashed = true
            task.deletedAt = now
        }
        modelContext.delete(taskList)
        do { try modelContext.save() } catch {
            log.error("deleteTaskList: save failed — \(error.localizedDescription)")
        }
    }
}

