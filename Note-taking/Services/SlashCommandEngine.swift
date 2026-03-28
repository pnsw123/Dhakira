import Foundation
import UIKit

// MARK: - SlashCommand model

struct SlashCommand: Identifiable, Equatable {
    let id: String
    let section: String
    let label: String
    let iconText: String
    let iconColor: UIColor

    static let all: [SlashCommand] = [
        // Basic Blocks
        SlashCommand(id: "text",         section: "Basic Blocks", label: "Text",         iconText: "T",   iconColor: .label),
        SlashCommand(id: "bulletList",   section: "Basic Blocks", label: "Bulleted List", iconText: "•",  iconColor: .label),
        SlashCommand(id: "todoList",     section: "Basic Blocks", label: "To-do List",   iconText: "✓",   iconColor: .label),
        SlashCommand(id: "quote",        section: "Basic Blocks", label: "Quote",        iconText: "\"",  iconColor: .label),
        // Headings
        SlashCommand(id: "heading1",     section: "Headings",     label: "Heading 1",    iconText: "H1",  iconColor: .label),
        SlashCommand(id: "heading2",     section: "Headings",     label: "Heading 2",    iconText: "H2",  iconColor: .label),
        SlashCommand(id: "heading3",     section: "Headings",     label: "Heading 3",    iconText: "H3",  iconColor: .label),
        // Media
        SlashCommand(id: "table",        section: "Media",        label: "Table",        iconText: "Tbl", iconColor: .label),
        // Colors
        SlashCommand(id: "colorGray",    section: "Colors",       label: "Gray",         iconText: "A",   iconColor: UIColor(hex: "#8e8e93")),
        SlashCommand(id: "colorOrange",  section: "Colors",       label: "Orange",       iconText: "A",   iconColor: UIColor(hex: "#ff6a00")),
        SlashCommand(id: "colorBlue",    section: "Colors",       label: "Blue",         iconText: "A",   iconColor: UIColor(hex: "#0a84ff")),
        SlashCommand(id: "colorPurple",  section: "Colors",       label: "Purple",       iconText: "A",   iconColor: UIColor(hex: "#bf5af2")),
        SlashCommand(id: "colorPink",    section: "Colors",       label: "Pink",         iconText: "A",   iconColor: UIColor(hex: "#ff375f")),
        SlashCommand(id: "colorBrown",   section: "Colors",       label: "Brown",        iconText: "A",   iconColor: UIColor(hex: "#ac8e68")),
    ]
}

// MARK: - SlashCommandEngine

/// Stateless engine: given a text string, determines if a slash command is active
/// and returns the filtered command list.
struct SlashCommandEngine {
    struct State {
        let isActive: Bool
        let filterText: String
        let filteredCommands: [SlashCommand]
        /// Character position of the triggering slash (for deletion on confirm)
        let slashLocation: Int
    }

    /// Parse the current text and cursor position to determine slash command state.
    static func evaluate(text: String, cursorLocation: Int) -> State {
        guard cursorLocation > 0 else {
            return State(isActive: false, filterText: "", filteredCommands: [], slashLocation: -1)
        }

        let nsText = text as NSString
        // Search backward from cursor for a '/' on the same line
        var slashLoc = -1
        var idx = cursorLocation - 1
        let slashCharVal = Character("/").asciiValue.map { UInt16($0) } ?? 47
        let newlineCharVal = Character("\n").asciiValue.map { UInt16($0) } ?? 10
        while idx >= 0 {
            let char = nsText.character(at: idx)
            if char == slashCharVal {
                slashLoc = idx
                break
            }
            // Stop at newline — slash must be on the same line
            if char == newlineCharVal {
                break
            }
            idx -= 1
        }

        guard slashLoc >= 0 else {
            return State(isActive: false, filterText: "", filteredCommands: [], slashLocation: -1)
        }

        let filterRange = NSRange(location: slashLoc + 1, length: cursorLocation - slashLoc - 1)
        guard filterRange.length >= 0, filterRange.location + filterRange.length <= nsText.length else {
            return State(isActive: false, filterText: "", filteredCommands: [], slashLocation: -1)
        }

        let filter = nsText.substring(with: filterRange).lowercased()

        let filtered: [SlashCommand]
        if filter.isEmpty {
            filtered = SlashCommand.all
        } else {
            filtered = SlashCommand.all.filter {
                $0.label.lowercased().contains(filter) || $0.section.lowercased().contains(filter)
            }
        }

        return State(
            isActive: !filtered.isEmpty,
            filterText: filter,
            filteredCommands: filtered,
            slashLocation: slashLoc
        )
    }
}

// MARK: - UIColor hex initialiser

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
