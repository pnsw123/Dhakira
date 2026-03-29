import Foundation
import SwiftUI
import UIKit
import Combine
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "SlashCommandCoordinator")

// MARK: - SlashCommandCoordinator (Issue #48)
// Collapses detectSlashCommand + applySlashCommand + 3 @State slash vars into one @StateObject.
//
// KEY FIX: State is FROZEN at detect-time in `frozenState`.
// `commandSelected()` reads `frozenState.slashLocation` — never re-evaluates.
// This eliminates the cursor-drift window that existed in the old double-evaluate() pattern.

@MainActor
final class SlashCommandCoordinator: ObservableObject {
    @Published private(set) var isMenuVisible: Bool = false
    @Published private(set) var filteredCommands: [SlashCommand] = []
    /// Highlighted row index for keyboard (arrow key) navigation.
    @Published private(set) var selectedIndex: Int = 0

    /// Frozen snapshot taken the moment the slash menu appears.
    /// Used in commandSelected() — we never call evaluate() a second time.
    private var frozenState: SlashCommandEngine.State?

    /// The position of the '/' that triggered the menu, or -1 if not active.
    /// Read this BEFORE calling commandSelected (which clears frozenState).
    var currentSlashLocation: Int { frozenState?.slashLocation ?? -1 }

    /// The currently highlighted command (by selectedIndex), falls back to first.
    var selectedCommand: SlashCommand? {
        guard !filteredCommands.isEmpty else { return nil }
        let idx = min(selectedIndex, filteredCommands.count - 1)
        return filteredCommands[idx]
    }

    /// Single-tick suppression flag — prevents the attributedText mutation
    /// inside commandSelected() from retriggering evaluation.
    private var suppressNextEvaluation = false

    // MARK: - Public API (2 entry points)

    /// Call this every time the text changes (from onChange of attributedText).
    /// Uses the cursor location from the text view at call time.
    func textDidChange(text: NSAttributedString, cursorLocation: Int) {
        guard !suppressNextEvaluation else {
            suppressNextEvaluation = false
            log.debug("SlashCommandCoordinator.textDidChange: suppressed")
            return
        }

        let state = SlashCommandEngine.evaluate(text: text.string, cursorLocation: cursorLocation)
        log.debug("SlashCommandCoordinator.textDidChange: cursor=\(cursorLocation), active=\(state.isActive), filter='\(state.filterText)', \(state.filteredCommands.count) result(s)")

        if state.isActive {
            frozenState = state      // freeze ONCE when menu appears
        } else {
            frozenState = nil
        }

        // Set immediately (no withAnimation) so callers can read isMenuVisible
        // in the same frame. The overlay applies its own .animation() modifier.
        isMenuVisible = state.isActive
        filteredCommands = state.filteredCommands
        // Reset highlight to top item whenever the filtered list changes.
        selectedIndex = 0
    }

    /// Move keyboard highlight down one row (wraps at bottom).
    func moveSelectionDown() {
        guard !filteredCommands.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, filteredCommands.count - 1)
    }

    /// Move keyboard highlight up one row (stops at top).
    func moveSelectionUp() {
        guard !filteredCommands.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }

    /// Call this when the user selects a command from the menu.
    /// Returns a closure that modifies the attributedText binding in place.
    ///
    /// Usage:
    ///   coordinator.commandSelected(cmd) { attributedText in ... }
    func commandSelected(
        _ cmd: SlashCommand,
        applyTo attributedText: inout NSAttributedString,
        cursorLocation: Int
    ) {
        log.info("SlashCommandCoordinator.commandSelected: '\(cmd.id)' (\(cmd.label))")

        // Suppress the next evaluation cycle — the text mutation we're about to do
        // must not re-trigger the menu.
        suppressNextEvaluation = true
        // Ensure flag resets after one run-loop tick even if textDidChange never fires.
        DispatchQueue.main.async { [weak self] in
            self?.suppressNextEvaluation = false
        }

        // Use FROZEN state — never re-evaluate here (cursor-drift fix).
        // Compute effective cursor from frozen filter text so we never rely on
        // richTextContext.selectedRange (which resets to 0 when the menu steals focus).
        let slashLoc: Int
        if let frozen = frozenState, frozen.slashLocation >= 0 {
            slashLoc = frozen.slashLocation
            // frozenCursor = '/' position + 1 (for '/') + length of filter text typed after '/'
            let frozenCursor = frozen.slashLocation + 1 + frozen.filterText.count
            let deleteLen = frozenCursor - slashLoc
            if deleteLen > 0 {
                let deleteRange = NSRange(location: slashLoc, length: deleteLen)
                let mutable = NSMutableAttributedString(attributedString: attributedText)
                if deleteRange.location + deleteRange.length <= mutable.length {
                    mutable.deleteCharacters(in: deleteRange)
                    attributedText = mutable
                    log.debug("SlashCommandCoordinator.commandSelected: deleted \(deleteLen) char(s) at offset \(slashLoc)")
                }
            }
        } else {
            slashLoc = -1
        }

        frozenState = nil

        withAnimation(.easeInOut(duration: 0.15)) {
            isMenuVisible = false
            filteredCommands = []
        }
    }

    /// Dismiss the menu without applying any command.
    func dismiss() {
        log.debug("SlashCommandCoordinator.dismiss")
        frozenState = nil
        withAnimation(.easeInOut(duration: 0.15)) {
            isMenuVisible = false
            filteredCommands = []
        }
    }
}
