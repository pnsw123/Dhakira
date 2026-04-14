import SwiftUI
import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "HomeView")

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    /// Called by the > button — more reliable than dismiss() with NavigationStack bindings.
    var onClose: (() -> Void)? = nil
    /// Navigation callbacks — owned by ContentView so navigationDestinations stay stable.
    var onSelectTaskList: ((TaskList) -> Void)? = nil
    var onShowRecentlyCompleted: (() -> Void)? = nil
    var onShowRecentlyDeleted: (() -> Void)? = nil

    @Query(filter: #Predicate<Folder> { $0.parentFolder == nil }, sort: \Folder.sortOrder)
    private var topLevelFolders: [Folder]

    @Query(sort: \TaskList.createdAt)
    private var allTaskLists: [TaskList]

    @Environment(\.undoManager) private var undoManager
    @State private var undoVersion: Int = 0
    @State private var autoRenameFolderId: UUID? = nil
    @State private var showSettings = false
    @State private var calendarExpanded = false

    @State private var calendarService = CalendarSelectionService.shared
    @State private var authService     = GoogleAuthService.shared
    @State private var googleSignInLoading = false

    var body: some View {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    // Header — scrolls with content
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: 36, height: 36)

                            Spacer()

                            // Undo / Redo — right-aligned, same layout as TaskListView
                            Button {
                                undoManager?.undo()
                                undoVersion += 1
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.themeAccent)
                                    .frame(width: 36, height: 36)
                                    .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                            }
                            .buttonStyle(.macFriendly)
                            .opacity(undoVersion >= 0 && undoManager?.canUndo == true ? 1 : 0.35)
                            .accessibilityLabel("Undo")

                            Button {
                                undoManager?.redo()
                                undoVersion += 1
                            } label: {
                                Image(systemName: "arrow.uturn.forward")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.themeAccent)
                                    .frame(width: 36, height: 36)
                                    .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                            }
                            .buttonStyle(.macFriendly)
                            .padding(.leading, 8)
                            .opacity(undoVersion >= 0 && undoManager?.canRedo == true ? 1 : 0.35)
                            .accessibilityLabel("Redo")

                            Button(action: {
                                log.info("HomeView: > button tapped → calling onClose()")
                                onClose?()
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Color.themeAccent)
                                    .frame(width: 36, height: 36)
                                    .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)).interactive(), in: .circle)
                            }
                            .buttonStyle(.macFriendly)
                            .padding(.leading, 8)
                            .accessibilityIdentifier("btn-go-to-tasks")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        Text("Folders")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(Color.primaryText)
                            .padding(.horizontal, 20)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                    }

                    // Folders section
                    foldersSection
                        .id("folders-section")

                    // Choose your Calendar section
                    calendarSection

                    // Recently Completed + Recently Deleted — one grouped card
                    VStack(spacing: 0) {
                        Button(action: { onShowRecentlyCompleted?() }) {
                            HStack(spacing: 10) {
                                Spacer().frame(width: 0)
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color.primaryText)
                                    .frame(width: 22)
                                Text("Recently Completed")
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 16)

                        Button(action: { onShowRecentlyDeleted?() }) {
                            HStack(spacing: 10) {
                                Spacer().frame(width: 0)
                                Image(systemName: "trash")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color.primaryText)
                                    .frame(width: 22)
                                Text("Recently Deleted")
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 32)
            }
            .background(Color.clear)
            .onAppear {
                log.info("HomeView: appeared — topLevelFolders=\(topLevelFolders.count), allTaskLists=\(allTaskLists.count)")
                // Connect SwiftData's ModelContext to the system UndoManager.
                // This makes ALL model changes (rename, reorder, delete) automatically undoable.
                modelContext.undoManager = undoManager
                migrateSortOrderIfNeeded()
            }
            .onDisappear {
                log.info("HomeView: disappeared")
            }
            .onChange(of: autoRenameFolderId) { _, newId in
                if newId != nil {
                    withAnimation { proxy.scrollTo("folders-section", anchor: .top) }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            } // ScrollViewReader
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(spacing: 0) {
            // Header row — tapping expands / collapses the three options
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    calendarExpanded.toggle()
                }
            }) {
                HStack(spacing: 10) {
                    Spacer().frame(width: 0)
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.themeAccent)
                        .frame(width: 22)
                    Text("Choose your Calendar")
                        .font(.system(size: 17))
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.secondaryText)
                        .rotationEffect(.degrees(calendarExpanded ? 90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: calendarExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded options
            if calendarExpanded {
                Divider().padding(.leading, 16)

                // Apple Calendar row
                Button(action: { calendarService.toggleAppleSync() }) {
                    HStack(spacing: 10) {
                        Spacer().frame(width: 0)
                        Image(systemName: "calendar")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.themeAccent)
                            .frame(width: 22)
                        Text("Apple Calendar")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.primaryText)
                        Spacer()
                        if calendarService.appleCalendarSyncEnabled {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.themeAccent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 16)

                // Google Calendar row (OAuth — syncs via Google's REST API)
                Button(action: {
                    if authService.isConnected {
                        // Delete all Google events BEFORE disconnecting — while we still
                        // have the old account's token. This cleans up the old calendar.
                        Task {
                            await CalendarSyncService.shared.deleteAllGoogleEvents(in: modelContext)
                            authService.disconnect()
                            if calendarService.googleWebCalendarEnabled { calendarService.toggleWebSync() }
                        }
                    } else {
                        googleSignInLoading = true
                        if !calendarService.googleWebCalendarEnabled { calendarService.toggleWebSync() }
                        Task {
                            await authService.connect()
                            googleSignInLoading = false
                            if authService.isConnected {
                                if authService.accountDidChange {
                                    // Different account — old event IDs are useless, wipe them
                                    await CalendarSyncService.shared.clearAllGoogleEventIds(in: modelContext)
                                    authService.acknowledgeAccountChange()
                                }
                                // Sync all tasks to the (new or same) account
                                await CalendarSyncService.shared.resyncAllTasks(in: modelContext)
                            } else if calendarService.googleWebCalendarEnabled {
                                calendarService.toggleWebSync()
                            }
                        }
                    }
                }) {
                    HStack(spacing: 10) {
                        Spacer().frame(width: 0)
                        Image(systemName: "globe")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.themeAccent)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Google Calendar")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.primaryText)
                            if googleSignInLoading {
                                Text("Connecting...")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.secondaryText)
                            } else {
                                Text(authService.isConnected ? "Connected" : "Sign in with Google")
                                    .font(.system(size: 12))
                                    .foregroundStyle(authService.isConnected ? Color.themeAccent : Color.secondaryText)
                            }
                        }
                        Spacer()
                        if googleSignInLoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        } else if authService.isConnected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.themeAccent)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.secondaryText)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(googleSignInLoading)
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 16)
    }

    // MARK: - Folders Section

    private var foldersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 0) {
                if !topLevelFolders.isEmpty {
                    FolderSectionView(
                        folders: topLevelFolders,
                        allTaskLists: allTaskLists,
                        onSelectTaskList: { list in
                        log.info("HomeView: onSelectTaskList called for '\(list.name)'")
                        onSelectTaskList?(list)
                    },
                        autoRenameId: autoRenameFolderId
                    )
                    Divider().padding(.leading, 16)
                }

                // "Add Folder" — visually lighter than content rows so it reads as an action
                Button(action: createNewFolder) {
                    HStack(spacing: 10) {
                        Spacer().frame(width: 0)
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.themeAccent.opacity(0.6))
                            .frame(width: 22)
                        Text("Add Folder")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.secondaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Actions

    private func createNewFolder() {
        log.info("createNewFolder: creating new top-level folder")
        let maxOrder = topLevelFolders.map(\.sortOrder).max() ?? -10
        let folder = Folder(name: "")
        folder.sortOrder = maxOrder + 10
        modelContext.insert(folder)
        autoRenameFolderId = folder.id
    }

    /// Migration: assign sortOrder values to any folders still at the default 0.
    /// Handles single folders, partial migrations, and subfolders recursively.
    /// Uses a UserDefaults flag so it only runs the full scan once per device.
    private func migrateSortOrderIfNeeded() {
        let migrationKey = "sortOrderMigrationDone_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        migrateFolderGroup(topLevelFolders)

        // Recursively migrate subfolders at every level
        migrateSubfoldersRecursively(topLevelFolders)

        do {
            try modelContext.save()
            UserDefaults.standard.set(true, forKey: migrationKey)
            log.info("migrateSortOrderIfNeeded: migration complete")
        } catch {
            log.error("migrateSortOrderIfNeeded: save failed — \(error.localizedDescription)")
        }
    }

    /// Assign sortOrder to a group of sibling folders that are still at default 0.
    private func migrateFolderGroup(_ folders: [Folder]) {
        let needsMigration = folders.filter { $0.sortOrder == 0 }
        guard needsMigration.count > 0 else { return }
        // Sort by creation date to preserve the original order
        let sorted = needsMigration.sorted(by: { $0.createdAt < $1.createdAt })
        // Start after the highest existing sortOrder in this group
        let maxExisting = folders.map(\.sortOrder).max() ?? 0
        for (i, folder) in sorted.enumerated() {
            folder.sortOrder = maxExisting + (i + 1) * 10
        }
    }

    /// Walk the entire folder tree and migrate every level of subfolders.
    private func migrateSubfoldersRecursively(_ folders: [Folder]) {
        for folder in folders {
            let children = (folder.subfolders ?? [])
            if !children.isEmpty {
                migrateFolderGroup(children)
                migrateSubfoldersRecursively(children)
            }
        }
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

private func previewHomeView(theme: AppTheme? = nil) -> some View {
    let tm = ThemeManager.shared
    if let theme { tm.applyApp(theme) }
    let container = try! AppSchemaBuilder.makeInMemoryContainer()
    let ctx = container.mainContext
    let folder = Folder(name: "Default")
    ctx.insert(folder)
    let list = TaskList(name: "Tasks", folder: folder)
    ctx.insert(list)
    let work = Folder(name: "Work")
    ctx.insert(work)
    let workList = TaskList(name: "Projects", folder: work)
    ctx.insert(workList)
    return ZStack {
        previewGradient(tm)
        NavigationStack {
            HomeView()
                .scrollContentBackground(.hidden)
        }
    }
    .modelContainer(container)
    .environment(tm)
    .preferredColorScheme(tm.current.preferredScheme)
}

#Preview("Folders — Default") { previewHomeView() }
#Preview("Folders — Nebula") { previewHomeView(theme: .nebula) }
#Preview("Folders — Cosmos") { previewHomeView(theme: .cosmos) }
