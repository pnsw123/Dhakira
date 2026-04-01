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

    @Query(filter: #Predicate<Folder> { $0.parentFolder == nil }, sort: \Folder.createdAt)
    private var topLevelFolders: [Folder]

    @Query(sort: \TaskList.createdAt)
    private var allTaskLists: [TaskList]

    @State private var autoRenameFolderId: UUID? = nil
    @State private var showSettings = false
    @State private var calendarExpanded = false

    @State private var calendarService = CalendarSelectionService.shared
    @State private var authService     = GoogleAuthService.shared

    var body: some View {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
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
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.primaryText)
                                    .frame(width: 22)
                                Text("Recently Completed")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 16)

                        Button(action: { onShowRecentlyDeleted?() }) {
                            HStack(spacing: 10) {
                                Spacer().frame(width: 0)
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.primaryText)
                                    .frame(width: 22)
                                Text("Recently Deleted")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.secondaryText)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(Color.clear)
            .onAppear {
                log.info("HomeView: appeared — topLevelFolders=\(topLevelFolders.count), allTaskLists=\(allTaskLists.count)")
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
            .safeAreaInset(edge: .top) {
                HStack(spacing: 0) {
                    // Invisible spacer — mirrors the < button on Tasks so "Folders" sits at the same x position
                    Color.clear
                        .frame(width: 36, height: 36)
                        .padding(.leading, 8)

                    Text("Folders")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)

                    // > goes back to Tasks (the default page)
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
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                    .accessibilityIdentifier("btn-go-to-tasks")
                }
                .contentShape(Rectangle())
                .padding(.top, 4)
                .padding(.bottom, 8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.separatorColor)
                        .frame(height: 0.5)
                }
            }
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
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.themeAccent)
                        .frame(width: 22)
                    Text("Choose your Calendar")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.secondaryText)
                        .rotationEffect(.degrees(calendarExpanded ? 90 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: calendarExpanded)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
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
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, 16)

                // Local Google Calendar row
                Button(action: { calendarService.toggleGoogleSync() }) {
                    HStack(spacing: 10) {
                        Spacer().frame(width: 0)
                        Image(systemName: "g.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(calendarService.hasGoogleCalendar ? Color.themeAccent : Color.secondaryText)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Local Google Calendar")
                                .font(.system(size: 16))
                                .foregroundStyle(calendarService.hasGoogleCalendar ? Color.primaryText : Color.secondaryText)
                            if !calendarService.hasGoogleCalendar {
                                Text("Add Google account in iOS Settings")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.secondaryText)
                            }
                        }
                        Spacer()
                        if calendarService.googleCalendarSyncEnabled && calendarService.hasGoogleCalendar {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.themeAccent)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(!calendarService.hasGoogleCalendar)

                Divider().padding(.leading, 16)

                // Web Google Calendar row
                Button(action: {
                    if authService.isConnected {
                        authService.disconnect()
                        if calendarService.googleWebCalendarEnabled { calendarService.toggleWebSync() }
                    } else {
                        if !calendarService.googleWebCalendarEnabled { calendarService.toggleWebSync() }
                        Task { await authService.connect() }
                    }
                }) {
                    HStack(spacing: 10) {
                        Spacer().frame(width: 0)
                        Image(systemName: "globe")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.themeAccent)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Web Google Calendar")
                                .font(.system(size: 16))
                                .foregroundStyle(Color.primaryText)
                            Text(authService.isConnected ? "Connected" : "Sign in with Google")
                                .font(.system(size: 12))
                                .foregroundStyle(authService.isConnected ? Color.themeAccent : Color.secondaryText)
                        }
                        Spacer()
                        if authService.isConnected {
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
                }
                .buttonStyle(.plain)
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

                // "Add Folder" lives inside the section card — neutral color, no blue
                Button(action: createNewFolder) {
                    HStack(spacing: 10) {
                        Spacer().frame(width: 0)
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.primaryText)
                            .frame(width: 22)
                        Text("Add Folder")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.primaryText)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
        let folder = Folder(name: "")
        modelContext.insert(folder)
        autoRenameFolderId = folder.id
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
#Preview("Folders — Coral") { previewHomeView(theme: .coral) }
#Preview("Folders — Forest") { previewHomeView(theme: .forest) }
