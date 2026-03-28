import SwiftUI
import UIKit

// MARK: - SlashCommandMenuView
// Pixel-faithful floating slash command panel per the spec in issue #46 / PRD #37 comment.
// Sections: Basic Blocks | Headings | Media | Colors
// Visual: ultraThinMaterial background, 14pt radius, shadow, max height 320pt, scrollable.

struct SlashCommandMenuView: View {
    let commands: [SlashCommand]
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sections, id: \.0) { section, items in
                    // Section header
                    Text(section.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.secondary)
                        .tracking(0.8)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                    ForEach(items, id: \.id) { cmd in
                        Button {
                            onSelect(cmd)
                        } label: {
                            commandRow(cmd, isSelected: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxHeight: 320)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .shadow(color: Color.primary.opacity(0.15), radius: 12, y: 4)
        .frame(maxWidth: 260)
    }

    @ViewBuilder
    private func commandRow(_ cmd: SlashCommand, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            // Icon badge: 30×30 rounded square
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(width: 30, height: 30)

                if cmd.section == "Colors" {
                    Text(cmd.iconText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(cmd.iconColor))
                } else {
                    Text(cmd.iconText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
            }

            Text(cmd.label)
                .font(.system(size: 15))
                .foregroundStyle(Color.primary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            isSelected
                ? Color(uiColor: NamedColor.find(id: "colorBlue")?.uiColor ?? UIColor(hex: "#0A84FF")).opacity(0.13)
                : Color.clear
        )
        .contentShape(Rectangle())
    }
}
