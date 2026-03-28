import Foundation
import UIKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "SlashCommandEngine")

// MARK: - SlashCommand model

struct SlashCommand: Identifiable, Equatable {
    let id: String
    let section: String
    let label: String
    let iconText: String
    let iconColor: UIColor

    static let all: [SlashCommand] = {
        var commands: [SlashCommand] = [
            // Basic Blocks
            SlashCommand(id: "text",       section: "Basic Blocks", label: "Text",         iconText: "T",   iconColor: .label),
            SlashCommand(id: "bulletList", section: "Basic Blocks", label: "Bulleted List", iconText: "•",  iconColor: .label),
            SlashCommand(id: "todoList",   section: "Basic Blocks", label: "To-do List",   iconText: "✓",   iconColor: .label),
            SlashCommand(id: "quote",      section: "Basic Blocks", label: "Quote",        iconText: "\"",  iconColor: .label),
            // Headings
            SlashCommand(id: "heading1",   section: "Headings",     label: "Heading 1",    iconText: "H1",  iconColor: .label),
            SlashCommand(id: "heading2",   section: "Headings",     label: "Heading 2",    iconText: "H2",  iconColor: .label),
            SlashCommand(id: "heading3",   section: "Headings",     label: "Heading 3",    iconText: "H3",  iconColor: .label),
            // Media
            SlashCommand(id: "table",      section: "Media",        label: "Table",        iconText: "Tbl", iconColor: .label),
        ]
        // Colors — generated from NamedColor.forEditor (single source of truth)
        let colorCommands = NamedColor.forEditor.map { nc in
            SlashCommand(id: nc.id, section: "Colors", label: nc.label, iconText: "A", iconColor: nc.uiColor)
        }
        commands.append(contentsOf: colorCommands)
        return commands
    }()
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
        // Search backward from cursor for a '/' on the same line.
        // Use direct unichar (UInt16) literals to avoid any UnicodeScalar conversion issues.
        var slashLoc = -1
        var idx = cursorLocation - 1
        let slashChar: unichar = 0x2F   // '/'
        let newlineChar: unichar = 0x0A // '\n'
        while idx >= 0 {
            let char = nsText.character(at: idx)
            if char == slashChar {
                slashLoc = idx
                break
            }
            // Stop at newline — slash must be on the same line
            if char == newlineChar {
                break
            }
            idx -= 1
        }

        guard slashLoc >= 0 else {
            log.debug("evaluate: no slash found on current line — inactive")
            return State(isActive: false, filterText: "", filteredCommands: [], slashLocation: -1)
        }

        let filterRange = NSRange(location: slashLoc + 1, length: cursorLocation - slashLoc - 1)
        guard filterRange.length >= 0, filterRange.location + filterRange.length <= nsText.length else {
            log.error("evaluate: invalid filterRange \(filterRange.location)+\(filterRange.length) for text length \(nsText.length)")
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

        log.debug("evaluate: slashLoc=\(slashLoc), filter='\(filter)', \(filtered.count)/\(SlashCommand.all.count) command(s) matched")

        return State(
            isActive: !filtered.isEmpty,
            filterText: filter,
            filteredCommands: filtered,
            slashLocation: slashLoc
        )
    }
}

// UIColor(hex:) is defined in Color+App.swift (single shared definition)
