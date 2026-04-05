import SwiftData
import Foundation
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "CalendarSyncCoordinator")

/// Single entry point for all calendar sync operations.
///
/// Replaces direct calls to BodyEventSyncService / CalendarSyncService scattered
/// across Note_takingApp and TaskDetailView. All existing service logic is unchanged —
/// this class is a thin routing layer.
///
/// Callers:
///   - TaskDetailView  → syncBodyEvents(...)
///   - Note_takingApp  → reconcileAll(context:) and cleanupOrphans(context:)
final class CalendarSyncCoordinator {

    static let shared = CalendarSyncCoordinator()
    private init() {}

    // MARK: - Task editor (called by TaskDetailView)

    /// Sync body-line dates to calendar events after save or Enter-key debounce.
    @MainActor
    func syncBodyEvents(
        bodyText: String,
        task: TaskItem,
        context: ModelContext,
        checkedLines: Set<String> = []
    ) async {
        await BodyEventSyncService.shared.sync(
            bodyText: bodyText,
            task: task,
            context: context,
            checkedLines: checkedLines
        )
    }

    // MARK: - App lifecycle (called by Note_takingApp)

    /// Reconcile all calendar events. Call on:
    ///   - App launch
    ///   - App enters foreground (.active)
    ///   - EKEventStoreChanged notification fires
    @MainActor
    func reconcileAll(context: ModelContext) async {
        BodyEventSyncService.shared.reconcileAllAppleEvents(context: context)
        CalendarSyncService.shared.reconcileAllParentEvents(context: context)
        await BodyEventSyncService.shared.reconcileGoogleEvents(context: context)
    }

    /// Clean up stale events from completed/trashed tasks. Call on launch only.
    func cleanupOrphans(context: ModelContext) async {
        await CalendarSyncService.shared.cleanupStaleEvents(in: context)
    }
}
