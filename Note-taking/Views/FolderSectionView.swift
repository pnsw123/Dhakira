import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import Combine
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "FolderSection")

// MARK: - SwipeToRevealDelete

/// Coordinates which row is currently swiped open. Only one row at a time.
@MainActor
private final class SwipeCoordinator: ObservableObject {
    static let shared = SwipeCoordinator()
    @Published var activeRowId: UUID?

    func claim(_ id: UUID) {
        if activeRowId != id { activeRowId = id }
    }

    func release(_ id: UUID) {
        if activeRowId == id { activeRowId = nil }
    }
}

/// Custom swipe-to-delete for VStack layouts where .swipeActions doesn't work.
/// Swipe left to reveal a red delete button. Full swipe triggers the action immediately.
/// Only one row can be revealed at a time via SwipeCoordinator.
private struct SwipeToRevealDelete: ViewModifier {
    let onDelete: () -> Void
    @State private var offset: CGFloat = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var rowId = UUID()
    @ObservedObject private var coordinator = SwipeCoordinator.shared

    private let buttonWidth: CGFloat = 80
    private var isRevealed: Bool { offset < -10 }

    func body(content: Content) -> some View {
        content
            .offset(x: offset + dragOffset)
            .background(alignment: .trailing) {
                // Delete button behind the content — naturally matches row height
                if isRevealed {
                    Button {
                        dismiss()
                        onDelete()
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: buttonWidth)
                            .frame(maxHeight: .infinity)
                            .background(Color.red)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                    .offset(x: buttonWidth) // sits just off the right edge
                }
            }
            .simultaneousGesture(swipeGesture)
            .overlay {
                // Dismiss overlay: only when revealed, never eats normal taps
                if isRevealed {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { dismiss() }
                }
            }
            .clipped()
            .onChange(of: coordinator.activeRowId) { _, activeId in
                if activeId != rowId && offset < 0 {
                    withAnimation(.spring(response: 0.25)) { offset = 0 }
                }
            }
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.25)) { offset = 0 }
        coordinator.release(rowId)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 16)
            .updating($dragOffset) { value, state, _ in
                let h = value.translation.width
                let v = value.translation.height
                guard abs(h) > abs(v) * 1.5, h < 0 else { return }
                if offset == 0 {
                    state = max(h, -buttonWidth * 1.5)
                } else {
                    state = min(max(h, -buttonWidth * 0.5), buttonWidth)
                }
            }
            .onEnded { value in
                let h = value.translation.width
                let v = value.translation.height
                guard abs(h) > abs(v) * 1.5 else {
                    dismiss()
                    return
                }
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    if h < -buttonWidth * 1.2 {
                        offset = 0
                        coordinator.release(rowId)
                        onDelete()
                    } else if h < -buttonWidth * 0.4 && offset == 0 {
                        offset = -buttonWidth
                        coordinator.claim(rowId)
                    } else if h > buttonWidth * 0.3 && offset < 0 {
                        offset = 0
                        coordinator.release(rowId)
                    } else if offset < 0 {
                        offset = -buttonWidth
                    } else {
                        offset = 0
                    }
                }
            }
    }
}

fileprivate extension View {
    func swipeToRevealDelete(onDelete: @escaping () -> Void) -> some View {
        modifier(SwipeToRevealDelete(onDelete: onDelete))
    }
}

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
    @State private var isRootDropTargeted: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Drop zone before the first folder
            FolderReorderDropZone(indentLevel: indentLevel, showDividerWhenIdle: false) { rawID in
                reorder(rawID, toIndex: 0)
            }

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

                // Drop zone after each row — also acts as the divider between rows
                FolderReorderDropZone(
                    indentLevel: indentLevel,
                    showDividerWhenIdle: index < folders.count - 1
                ) { rawID in
                    reorder(rawID, toIndex: index + 1)
                }
            }
        }
        // Root-level drop zone — drag any subfolder here to unnest it back to a root folder.
        // Does NOT conflict with FolderReorderDropZone: this handler only accepts folders
        // that have a parentFolder (i.e. nested subfolders), while reorder zones handle
        // same-level sibling reordering. The parentFolder != nil guard ensures mutual exclusion.
        .dropDestination(for: FolderTransferID.self) { items, _ in
            guard indentLevel == 0,
                  let transfer = items.first,
                  let draggedFolder = modelContext.model(for: transfer.rawID) as? Folder,
                  draggedFolder.parentFolder != nil else { return false }
            let previousParent = draggedFolder.parentFolder
            draggedFolder.parentFolder = nil
            undoManager?.registerUndo(withTarget: draggedFolder) { f in
                f.parentFolder = previousParent
            }
            undoManager?.setActionName("Move Folder to Root")
            log.info("Drag-drop: '\(draggedFolder.name)' moved to root")
            return true
        } isTargeted: { targeted in
            if indentLevel == 0 {
                withAnimation(.easeInOut(duration: 0.2)) { isRootDropTargeted = targeted }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isRootDropTargeted ? Color.accentColor : .clear, lineWidth: 2)
        )
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

    @MainActor
    private func reorder(_ rawID: PersistentIdentifier, toIndex: Int) {
        guard let dragged = modelContext.model(for: rawID) as? Folder else { return }
        var sorted = folders
        guard let fromIndex = sorted.firstIndex(where: { $0.id == dragged.id }) else { return }
        // Already in the target position — nothing to do
        if fromIndex == toIndex || fromIndex == toIndex - 1 { return }
        sorted.remove(at: fromIndex)
        let insertAt = toIndex > fromIndex ? toIndex - 1 : toIndex
        sorted.insert(dragged, at: min(insertAt, sorted.count))
        for (i, folder) in sorted.enumerated() {
            folder.sortOrder = i * 10
        }
        do {
            try modelContext.save()
            log.info("Reorder: '\(dragged.name)' moved to index \(insertAt)")
        } catch {
            log.error("Reorder: save failed — \(error.localizedDescription)")
        }
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

// MARK: - FolderReorderDropZone

/// Drop target between folder rows for vertical reordering.
/// Expands when a drag hovers over it with a prominent accent line.
private struct FolderReorderDropZone: View {
    let indentLevel: Int
    let showDividerWhenIdle: Bool
    let onDrop: (PersistentIdentifier) -> Void
    @State private var isTargeted = false

    var body: some View {
        ZStack {
            // Hit area expands when a drag hovers — stays compact otherwise
            Color.clear.frame(height: isTargeted ? 28 : 12)
            if isTargeted {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(height: 4)
                    .padding(.leading, CGFloat(16 + indentLevel * 20))
                    .padding(.trailing, 16)
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 4, y: 0)
                    .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .center)))
            } else if showDividerWhenIdle {
                Divider()
                    .padding(.leading, CGFloat(16 + indentLevel * 20))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isTargeted)
        .dropDestination(for: FolderTransferID.self) { items, _ in
            guard let first = items.first else { return false }
            onDrop(first.rawID)
            return true
        } isTargeted: { isTargeted = $0 }
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
    @State private var showDeleteConfirm: Bool = false
    @State private var autoRenameListId: UUID? = nil
    @State private var autoRenameSubfolderId: UUID? = nil
    @State private var isAddingNewList: Bool = false
    @State private var newListName: String = ""
    @FocusState private var isNewListFocused: Bool
    @State private var isDropTargeted: Bool = false

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
            .draggable(FolderTransferID(rawID: folder.persistentModelID))
            .dropDestination(for: FolderTransferID.self) { items, _ in
                guard let transfer = items.first,
                      let draggedFolder = modelContext.model(for: transfer.rawID) as? Folder,
                      draggedFolder.id != folder.id,
                      !Self.isAncestor(draggedFolder, of: folder) else { return false }
                let targetDepth = Self.depth(of: folder) + 1
                guard targetDepth <= 10 else { return false }
                let previousParent = draggedFolder.parentFolder
                draggedFolder.parentFolder = folder
                // Register undo so the user can reverse drag-nest
                undoManager?.registerUndo(withTarget: draggedFolder) { f in
                    f.parentFolder = previousParent
                }
                undoManager?.setActionName("Move Folder")
                log.info("Drag-drop: '\(draggedFolder.name)' moved into '\(folder.name)'")
                return true
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isDropTargeted ? Color.accentColor : .clear, lineWidth: 2)
            )
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
            .swipeToRevealDelete { showDeleteConfirm = true }

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
        // Soft-delete all tasks so they appear in Recently Deleted
        for list in taskListsForFolder {
            for task in (list.tasks ?? []) where !task.isTrashed {
                task.isTrashed = true
                task.deletedAt = now
            }
            modelContext.delete(list)
        }
        // Subfolders cascade via SwiftData relationship
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
        .swipeToRevealDelete(onDelete: deleteTaskList)
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
        let taskCount = taskList.tasks?.count ?? 0
        log.info("TaskListRowView.deleteTaskList: '\(taskList.name)' with \(taskCount) task(s)")
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

