import SwiftUI

// MARK: - PhoneMockupView
// Renders a phone-frame with 3 swipeable pages for App scope, widget layout for Widget scope.
// Uses theme tokens exclusively — never system adaptive colors — so previews look correct
// regardless of device dark/light mode.
// Issue #74 — https://github.com/pnsw123/prod-note/issues/74

struct PhoneMockupView: View {
    let theme: AppTheme
    let scope: ThemeScope
    @Binding var currentPage: Int   // owned by ThemeDetailView; arrows live outside this frame

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
                } else {
                    AppScopePreview(theme: theme, currentPage: $currentPage)
                }
            }
            .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 44))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
    }
}

// MARK: - App scope: 3 swipeable pages with themed dots

private struct AppScopePreview: View {
    let theme: AppTheme
    @Binding var currentPage: Int

    var body: some View {
        TabView(selection: $currentPage) {
            MockTasksPage(theme: theme).tag(0)
            MockDetailPage(theme: theme).tag(1)
            MockFolderPage(theme: theme).tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        // Force correct color scheme so adaptive colors (text, separators) match the background
        .environment(\.colorScheme, theme.backgroundIsDark ? .dark : .light)
    }
}

// MARK: - Page 1: Tasks

private struct MockTasksPage: View {
    let theme: AppTheme

    private struct Row: Identifiable {
        let id = UUID()
        let title: String
        let done: Bool
        let priority: String
    }

    private let rows: [Row] = [
        Row(title: "Morning standup",      done: true,  priority: "high"),
        Row(title: "Review pull requests", done: true,  priority: "medium"),
        Row(title: "Update documentation", done: false, priority: "none"),
        Row(title: "Team lunch 12pm",      done: false, priority: "none"),
        Row(title: "Write weekly report",  done: false, priority: "none"),
        Row(title: "Check emails",         done: false, priority: "none"),
        Row(title: "Plan next sprint",     done: false, priority: "none"),
    ]

    private static let defaultGrid: [SIMD2<Float>] = [
        [0,0],[0.5,0],[1,0],[0,0.5],[0.5,0.5],[1,0.5],[0,1],[0.5,1],[1,1]
    ]

    @ViewBuilder
    private var background: some View {
        if theme.backgroundStyle == .gradient {
            if #available(iOS 18, *) {
                MeshGradient(
                    width: 3, height: 3,
                    points: theme.meshPoints ?? Self.defaultGrid,
                    colors: theme.meshColors
                )
            } else {
                ZStack {
                    theme.meshColors[4]
                    RadialGradient(colors: [theme.meshColors[0].opacity(0.85), .clear],
                                   center: .topLeading, startRadius: 0, endRadius: 220)
                    RadialGradient(colors: [theme.meshColors[8].opacity(0.80), .clear],
                                   center: .bottomTrailing, startRadius: 0, endRadius: 200)
                }
            }
        } else {
            theme.screenBackground
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Color.clear.frame(height: 18) // status bar spacer

                // Nav bar — .background{} so ultraThinMaterial blurs gradient backdrop
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
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.separatorColor)
                        .frame(height: 0.5)
                }

                // Task rows — transparent, float directly on gradient (matches real app)
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                        HStack(spacing: 8) {
                            ZStack {
                                if row.done {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 16))
                                        .foregroundStyle(
                                            row.priority == "high"   ? Color.priorityHighColor :
                                            row.priority == "medium" ? Color.priorityMediumColor :
                                            theme.secondaryText
                                        )
                                } else {
                                    Circle()
                                        .strokeBorder(theme.checkboxInactive, lineWidth: 1)
                                        .frame(width: 16, height: 16)
                                }
                            }

                            Text(row.title)
                                .font(.system(size: 11))
                                .foregroundStyle(theme.primaryText)
                                .strikethrough(row.done, color:
                                    row.done ? (
                                        row.priority == "high"   ? theme.priorityHigh :
                                        row.priority == "medium" ? theme.priorityMedium :
                                        theme.secondaryText
                                    ) : theme.secondaryText
                                )
                                .lineLimit(1)

                            Spacer()

                            if row.priority == "high" {
                                MockPennant()
                                    .fill(Color.priorityHighColor)
                                    .frame(width: 8, height: 12)
                            } else if row.priority == "medium" {
                                MockPennant()
                                    .fill(Color.priorityMediumColor)
                                    .frame(width: 8, height: 12)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .opacity(row.done ? 0.35 : 1.0)

                        Rectangle()
                            .fill(theme.separatorColor)
                            .frame(height: 0.5)
                            .padding(.leading, 38)
                    }
                    Spacer()
                }
                .padding(.top, 8)
            }

            // FAB
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
                .padding(.bottom, 12)
        }
        .background { background }
    }
}

// MARK: - Page 2: Task Detail

private struct MockDetailPage: View {
    let theme: AppTheme

    @ViewBuilder
    private var background: some View {
        if theme.backgroundStyle == .gradient {
            if #available(iOS 18, *) {
                MeshGradient(
                    width: 3, height: 3,
                    points: theme.meshPoints ?? [
                        [0,0],[0.5,0],[1,0],
                        [0,0.5],[0.5,0.5],[1,0.5],
                        [0,1],[0.5,1],[1,1]
                    ],
                    colors: theme.meshColors
                )
            } else {
                ZStack {
                    theme.meshColors[4]
                    RadialGradient(colors: [theme.meshColors[0].opacity(0.85), .clear], center: .topLeading, startRadius: 0, endRadius: 220)
                    RadialGradient(colors: [theme.meshColors[8].opacity(0.80), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 200)
                }
            }
        } else {
            theme.editorBackground
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Color.clear.frame(height: 18) // status bar spacer

                // Nav bar — back button + share + keyboard (all themed)
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

                // Cursor
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

                // Formatting toolbar — floating pill matching real BottomCustomisationBar
                HStack(spacing: 0) {
                    ForEach(["bold", "italic", "checklist", "list.bullet", "underline", "strikethrough", "textformat.size.smaller", "textformat.size.larger"], id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(theme.accentColor)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13))
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .background { background }
    }
}

// MARK: - Page 3: Folders — matches real FolderListView exactly

private struct MockFolderPage: View {
    let theme: AppTheme

    @ViewBuilder
    private var background: some View {
        if theme.backgroundStyle == .gradient {
            if #available(iOS 18, *) {
                MeshGradient(
                    width: 3, height: 3,
                    points: theme.meshPoints ?? [
                        [0,0],[0.5,0],[1,0],
                        [0,0.5],[0.5,0.5],[1,0.5],
                        [0,1],[0.5,1],[1,1]
                    ],
                    colors: theme.meshColors
                )
            } else {
                ZStack {
                    theme.meshColors[4]
                    RadialGradient(colors: [theme.meshColors[0].opacity(0.85), .clear], center: .topLeading, startRadius: 0, endRadius: 220)
                    RadialGradient(colors: [theme.meshColors[8].opacity(0.80), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 200)
                }
            }
        } else {
            theme.screenBackground
        }
    }

    private struct FolderRow: Identifiable {
        let id = UUID()
        let icon: String
        let iconColor: Color
        let name: String
        let count: Int?
    }

    // Matches the reference screenshot exactly: Default + Add Folder
    private let mainFolders: [FolderRow] = [
        FolderRow(icon: "folder.fill",       iconColor: Color(red: 0.0, green: 0.48, blue: 1.0),  name: "Default",    count: 5),
        FolderRow(icon: "folder.badge.plus",  iconColor: Color(red: 0.56, green: 0.56, blue: 0.58), name: "Add Folder", count: nil),
    ]

    private let systemFolders: [FolderRow] = [
        FolderRow(icon: "checkmark.circle", iconColor: Color(red: 0.56, green: 0.56, blue: 0.58), name: "Recently Completed", count: nil),
        FolderRow(icon: "trash",            iconColor: Color(red: 0.56, green: 0.56, blue: 0.58), name: "Recently Deleted",   count: nil),
    ]

    var body: some View {
        ZStack {
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

                rowGroup(mainFolders)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)

                rowGroup(systemFolders)
                    .padding(.horizontal, 12)

                Spacer()
            }
        }
        .background { background }
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
                .background(.clear)

                if i < rows.count - 1 {
                    Rectangle()
                        .fill(theme.separatorColor)
                        .frame(height: 0.5)
                        .padding(.leading, 42)
                }
            }
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
    }
}

// MARK: - Pennant flag shape — matches real TaskRowView priority indicator

private struct MockPennant: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY * 0.68))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 12) {
        PhoneMockupView(theme: .rose,      scope: .app,     currentPage: .constant(0))
        PhoneMockupView(theme: .tokyoNight, scope: .app,     currentPage: .constant(1))
        PhoneMockupView(theme: .nord,      scope: .widgets, currentPage: .constant(0))
    }
    .frame(height: 490)
    .padding()
    .background(Color.gray)
}
