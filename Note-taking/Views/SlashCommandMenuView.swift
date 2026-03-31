import SwiftUI
import UIKit

// MARK: - SlashCommandMenuView
// Pixel-faithful floating slash command panel per the spec in issue #46 / PRD #37 comment.
// Sections: Basic Blocks | Headings | Media | Colors
// Visual: ultraThinMaterial background, 14pt radius, shadow, max height 320pt, scrollable.

struct SlashCommandMenuView: View {
    let commands: [SlashCommand]
    /// Index of the keyboard-highlighted row (0 = top). Passed from the coordinator.
    var selectedIndex: Int = 0
    let onSelect: (SlashCommand) -> Void
    let onDismiss: () -> Void

    private var sections: [(String, [SlashCommand])] {
        var result: [(String, [SlashCommand])] = []
        var seen: [String] = []
        for cmd in commands {
            if !seen.contains(cmd.section) {
                seen.append(cmd.section)
            }
        }
        for section in seen {
            let items = commands.filter { $0.section == section }
            result.append((section, items))
        }
        return result
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Flatten all commands to get a global flat index for keyboard highlight.
                    let flat = commands
                    ForEach(sections, id: \.0) { section, items in
                        // Section header
                        Text(section.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.secondaryText)
                            .tracking(0.8)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, 4)

                        ForEach(items, id: \.id) { cmd in
                            let idx = flat.firstIndex(where: { $0.id == cmd.id }) ?? 0
                            Button {
                                onSelect(cmd)
                            } label: {
                                commandRow(cmd, isSelected: idx == selectedIndex)
                            }
                            .buttonStyle(.plain)
                            .id(cmd.id)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 320)
            // Scroll to keep the highlighted row visible when navigating with arrow keys.
            .onChange(of: selectedIndex) { _, _ in
                if selectedIndex < commands.count {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        proxy.scrollTo(commands[selectedIndex].id, anchor: .center)
                    }
                }
            }
        }
        .background(Color.rowBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        .frame(maxWidth: 260)
    }

    @ViewBuilder
    private func commandRow(_ cmd: SlashCommand, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            // Icon badge: 30×30 rounded square
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.separatorColor.opacity(0.5))
                    .frame(width: 30, height: 30)

                if cmd.section == "Colors" {
                    Text(cmd.iconText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(cmd.iconColor))
                } else if let symbol = cmd.sfSymbol {
                    Image(systemName: symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primaryText)
                } else {
                    Text(cmd.iconText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primaryText)
                }
            }

            Text(cmd.label)
                .font(.system(size: 15))
                .foregroundStyle(Color.primaryText)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isSelected
                ? Color.themeAccent.opacity(0.13)
                : Color.clear
        )
        .contentShape(Rectangle())
    }
}
