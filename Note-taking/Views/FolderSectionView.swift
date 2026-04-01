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
    var autoRenameId: UUID? = nil

    /// Expanded folder IDs persisted in UserDefaults so state survives data refreshes.
    @AppStorage("expandedFolderIds_v2") private var expandedFolderIdsStorage: String = ""
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
                    indentLevel: indentLevel,
                    startEditingOnAppear: folder.id == autoRenameId
                )

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
        let newValue = expandedFolderIds.map(\.uuidString).joined(separator: ",")
        guard newValue != expandedFolderIdsStorage else { return }
        expandedFolderIdsStorage = newValue
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

    @State private var isRenaming: Bool = false
    @State private var renameText: String = ""
    @FocusState private var isRenameFocused: Bool
    @State private var showDeleteConfirm: Bool = false
    @State private var autoRenameListId: UUID? = nil
    @State private var autoRenameSubfolderId: UUID? = nil

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

                Image(systemName: "folder.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.themeAccent)
                    .frame(width: 22)

                if isRenaming {
                    TextField("Folder name", text: $renameText, onCommit: commitRename)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .focused($isRenameFocused)
                } else {
                    Text(folder.name)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Expand chevron — always shown so any folder can be opened
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondaryText)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
            #if os(iOS)
            .swipeToDelete { showDeleteConfirm = true }
            #endif

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

                // "Add List" inline button — neutral color, no blue
                Divider().padding(.leading, CGFloat(16 + (indentLevel + 1) * 20))
                Button(action: addTaskList) {
                    HStack(spacing: 10) {
                        Spacer().frame(width: CGFloat((indentLevel + 1) * 20))
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primaryText)
                            .frame(width: 22)
                        Text("Add List")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.primaryText)
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
            for task in (list.tasks ?? []) where !task.isDeleted {
                task.isDeleted = true
                task.deletedAt = now
            }
            modelContext.delete(list)
        }
        // Subfolders cascade via SwiftData relationship
        modelContext.delete(folder)
    }

    private func addTaskList() {
        log.info("addTaskList: adding to folder '\(folder.name)'")
        let newList = TaskList(name: "", folder: folder)
        modelContext.insert(newList)
        autoRenameListId = newList.id
    }

    private func addSubfolder() {
        log.info("addSubfolder: inside '\(folder.name)'")
        let sub = Folder(name: "", parentFolder: folder)
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
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.secondaryText)
                .frame(width: 22)

            if isRenaming {
                TextField("List name", text: $renameText, onCommit: commitRename)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .focused($isRenameFocused)
            } else {
                Text(taskList.name)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.secondaryText.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
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
        #if os(iOS)
        .swipeToDelete(perform: deleteTaskList)
        #endif
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
        for task in (taskList.tasks ?? []) where !task.isDeleted {
            task.isDeleted = true
            task.deletedAt = now
        }
        modelContext.delete(taskList)
    }
}

// MARK: - Swipe to Delete

private struct SwipeToDeleteModifier: ViewModifier {
    let onDelete: () -> Void

    /// Live drag delta — auto-resets to 0 when gesture ends.
    @GestureState private var dragDelta: CGFloat = 0
    /// Settled offset after each gesture completes.
    @State private var settled: CGFloat = 0

    private let snapWidth: CGFloat = 80

    private var currentOffset: CGFloat {
        max(min(0, settled + dragDelta), -snapWidth * 2.5)
    }

    func body(content: Content) -> some View {
        ZStack(alignment: .trailing) {
            // Red delete button — fixed on the right, revealed as content slides left
            Color(uiColor: .systemRed)
                .frame(width: snapWidth)
                .overlay(
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .opacity(currentOffset < -10 ? 1 : 0)
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.2)) { settled = -500 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onDelete() }
                }

            // Row content — slides left on swipe
            content
                .offset(x: currentOffset)
                .gesture(
                    DragGesture(minimumDistance: 15, coordinateSpace: .local)
                        .updating($dragDelta) { value, state, _ in
                            state = value.translation.width
                        }
                        .onEnded { value in
                            let tentative = settled + value.translation.width
                            let predicted = settled + value.predictedEndTranslation.width
                            let isFullSwipe = predicted < -300 || tentative < -snapWidth * 1.3

                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                settled = isFullSwipe ? -500 :
                                          tentative < -snapWidth * 0.4 ? -snapWidth : 0
                            }
                            if isFullSwipe {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onDelete() }
                            }
                        }
                )

            // Transparent overlay on top of content when button is showing —
            // absorbs taps to reset the swipe without triggering the row action.
            if settled < -snapWidth * 0.3 {
                Color.clear
                    .contentShape(Rectangle())
                    .offset(x: currentOffset)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { settled = 0 }
                    }
            }
        }
        .clipped()
    }
}

private extension View {
    func swipeToDelete(perform action: @escaping () -> Void) -> some View {
        modifier(SwipeToDeleteModifier(onDelete: action))
    }
}
