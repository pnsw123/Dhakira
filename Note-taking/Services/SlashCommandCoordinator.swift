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

    /// Frozen snapshot taken the moment the slash menu appears.
    /// Used in commandSelected() — we never call evaluate() a second time.
    private var frozenState: SlashCommandEngine.State?

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
        let slashLoc: Int
        if let frozen = frozenState, frozen.slashLocation >= 0 {
            slashLoc = frozen.slashLocation
        } else {
            slashLoc = -1
        }

        // Remove the '/' + filter text that was typed
        if slashLoc >= 0 {
            let deleteLen = cursorLocation - slashLoc
            if deleteLen > 0 {
                let deleteRange = NSRange(location: slashLoc, length: deleteLen)
                let mutable = NSMutableAttributedString(attributedString: attributedText)
                mutable.deleteCharacters(in: deleteRange)
                attributedText = mutable
                log.debug("SlashCommandCoordinator.commandSelected: deleted \(deleteLen) char(s) at offset \(slashLoc)")
            }
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
