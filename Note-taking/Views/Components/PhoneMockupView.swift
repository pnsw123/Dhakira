import SwiftUI

// MARK: - PhoneMockupView
// Renders a phone-frame with 3 swipeable pages for App scope, widget layout for Widget scope.
// Uses theme tokens exclusively — never system adaptive colors — so previews look correct
// regardless of device dark/light mode.
// Issue #74 — https://github.com/pnsw123/prod-note/issues/74

struct PhoneMockupView: View {
    let theme: AppTheme
    let scope: ThemeScope

    var body: some View {
        ZStack(alignment: .top) {
            // Phone bezel
            RoundedRectangle(cornerRadius: 44)
                .stroke(.white.opacity(0.35), lineWidth: 1.5)
                .background(
                    RoundedRectangle(cornerRadius: 44)
                        .fill(.black.opacity(0.15))
                )

            // Content — non-interactive
            Group {
                if scope == .widgets {
                    WidgetPreviewLayout(theme: theme)
                        .scaleEffect(0.65)
                        .padding(.top, 20)
                } else {
                    AppScopePreview(theme: theme)
                }
            }
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 44))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
}

// MARK: - App scope: 3 swipeable pages

private struct AppScopePreview: View {
    let theme: AppTheme
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            MockFolderPage(theme: theme).tag(0)
            MockTasksPage(theme: theme).tag(1)
            MockDetailPage(theme: theme).tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .indexViewStyle(.page(backgroundDisplayMode: .interactive))
    }
}

// MARK: - Page 1: Folders/Home

private struct MockFolderPage: View {
    let theme: AppTheme

    private struct FolderRow: Identifiable {
        let id = UUID()
        let icon: String
        let iconColor: Color
        let name: String
        let count: Int?
    }

    private let mainFolders: [FolderRow] = [
        FolderRow(icon: "folder.fill",      iconColor: Color(red: 0.0, green: 0.48, blue: 1.0), name: "Default",   count: 5),
        FolderRow(icon: "folder.fill",      iconColor: Color(red: 0.2, green: 0.78, blue: 0.35), name: "Work",     count: 3),
        FolderRow(icon: "folder.fill",      iconColor: Color(red: 0.69, green: 0.32, blue: 0.87), name: "Personal", count: 8),
    ]

    private let systemFolders: [FolderRow] = [
        FolderRow(icon: "checkmark.circle", iconColor: Color(red: 0.56, green: 0.56, blue: 0.58), name: "Recently Completed", count: nil),
        FolderRow(icon: "trash",            iconColor: Color(red: 0.56, green: 0.56, blue: 0.58), name: "Recently Deleted",   count: nil),
    ]

    var body: some View {
        ZStack {
            theme.screenBackground

            VStack(spacing: 0) {
                Color.clear.frame(height: 18) // status bar spacer

                // Header
                HStack {
                    Text("Folders")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                // Main folders
                rowGroup(mainFolders)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)

                // System folders
                rowGroup(systemFolders)
                    .padding(.horizontal, 12)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func rowGroup(_ rows: [FolderRow]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                HStack(spacing: 10) {
                    Image(systemName: row.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(row.iconColor)
                        .frame(width: 22, height: 22)

                    Text(row.name)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)

                    Spacer()

                    if let count = row.count {
                        Text("\(count)")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.secondaryText)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(theme.secondaryText.opacity(0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(theme.surfaceBackground)

                if i < rows.count - 1 {
                    Rectangle()
                        .fill(theme.separatorColor)
                        .frame(height: 0.5)
                        .padding(.leading, 42)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Page 2: Tasks

private struct MockTasksPage: View {
    let theme: AppTheme

    private struct Row: Identifiable {
        let id = UUID()
        let title: String
        let done: Bool
        let priority: String
    }

    private let rows: [Row] = [
        Row(title: "Morning standup",      done: false, priority: "high"),
        Row(title: "Review pull requests", done: false, priority: "medium"),
        Row(title: "Update documentation", done: true,  priority: "none"),
        Row(title: "Team lunch 12pm",      done: false, priority: "none"),
        Row(title: "Write weekly report",  done: false, priority: "high"),
        Row(title: "Check emails",         done: true,  priority: "none"),
        Row(title: "Plan next sprint",     done: false, priority: "medium"),
    ]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            theme.screenBackground

            VStack(spacing: 0) {
                Color.clear.frame(height: 18) // status bar spacer

                // Nav bar
                HStack(spacing: 0) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.accentColor)
                        .padding(.leading, 10)

                    Text("Tasks")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                        .padding(.leading, 6)

                    Spacer()

                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.accentColor)
                        .padding(.trailing, 12)
                }
                .padding(.vertical, 9)
                .background(theme.screenBackground)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.separatorColor)
                        .frame(height: 0.5)
                }

                // Task rows
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .strokeBorder(
                                        row.done ? theme.checkboxActive : theme.checkboxInactive,
                                        lineWidth: 1
                                    )
                                    .frame(width: 16, height: 16)
                                if row.done {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundStyle(theme.checkboxActive)
                                }
                            }

                            Text(row.title)
                                .font(.system(size: 11))
                                .foregroundStyle(row.done ? theme.secondaryText : theme.primaryText)
                                .strikethrough(row.done, color: theme.secondaryText)
                                .lineLimit(1)

                            Spacer()

                            if row.priority == "high" {
                                Circle().fill(theme.priorityHigh).frame(width: 5, height: 5)
                            } else if row.priority == "medium" {
                                Circle().fill(theme.priorityMedium).frame(width: 5, height: 5)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(theme.surfaceBackground)

                        if i < rows.count - 1 {
                            Rectangle()
                                .fill(theme.separatorColor)
                                .frame(height: 0.5)
                                .padding(.leading, 38)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 12)
                .padding(.top, 8)

                Spacer()
            }

            // FAB — bottom-right, mirrors real app layout
            Circle()
                .fill(theme.fabBackground)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(theme.fabIcon)
                )
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                .padding(.trailing, 12)
                .padding(.bottom, 14)
        }
    }
}

// MARK: - Page 3: Task Detail

private struct MockDetailPage: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            theme.editorBackground

            VStack(spacing: 0) {
                Color.clear.frame(height: 18) // status bar spacer

                // Nav bar
                HStack {
                    ZStack {
                        Circle()
                            .fill(theme.surfaceBackground)
                            .frame(width: 28, height: 28)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.accentColor)
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.accentColor)
                        Image(systemName: "keyboard")
                            .font(.system(size: 13))
                            .foregroundStyle(theme.accentColor)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                // Date stamp
                Text("29 Mar 2026 · 11:30PM")
                    .font(.system(size: 9))
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 2)

                // Task title
                Text("Reply to Sarah's email")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(theme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.top, 6)

                // Separator
                Rectangle()
                    .fill(theme.separatorColor)
                    .frame(height: 0.5)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                // Blinking cursor
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(theme.accentColor)
                        .frame(width: 2, height: 14)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                // Simulated note body lines
                VStack(alignment: .leading, spacing: 8) {
                    ForEach([1.0, 0.88, 0.95, 0.60], id: \.self) { widthFraction in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.placeholderText.opacity(0.35))
                            .frame(height: 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .scaleEffect(x: widthFraction, y: 1, anchor: .leading)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)

                Spacer()

                // Formatting toolbar
                HStack(spacing: 0) {
                    ForEach(["bold", "italic", "underline", "strikethrough", "textformat.size.smaller", "textformat.size.larger"], id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.accentColor)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 9)
                .background(theme.surfaceBackground)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(theme.separatorColor)
                        .frame(height: 0.5)
                }
                .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        PhoneMockupView(theme: .rose,      scope: .app)
        PhoneMockupView(theme: .academia,  scope: .app)
        PhoneMockupView(theme: .nord,      scope: .widgets)
    }
    .frame(height: 490)
    .padding()
    .background(Color.gray)
}
