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

    @Environment(ThemeManager.self) private var themeManager
    @State private var autoRenameFolderId: UUID? = nil

    var body: some View {
            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    // Folders section
                    foldersSection
                        .id("folders-section")

                    // Recently Completed + Recently Deleted — one grouped card
                    VStack(spacing: 0) {
                        Button(action: { onShowRecentlyCompleted?() }) {
                            HStack(spacing: 10) {
                                Spacer().frame(width: 0)
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.primary)
                                    .frame(width: 22)
                                Text("Recently Completed")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
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
                                    .foregroundStyle(Color.primary)
                                    .frame(width: 22)
                                Text("Recently Deleted")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    .padding(.horizontal, 16)
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(themeManager.current.screenBackground)
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
                .padding(.top, 4)
                .padding(.bottom, 8)
                .background(Color.screenBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.separatorColor)
                        .frame(height: 0.5)
                }
            }
            } // ScrollViewReader
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
                            .foregroundStyle(Color.primary)
                            .frame(width: 22)
                        Text("Add Folder")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
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
