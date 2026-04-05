import EventKit
import SwiftUI
import SwiftData
import WidgetKit
import OSLog

@main
struct Note_takingApp: App {
    let container: ModelContainer

    private let log = Logger(subsystem: "notes.Note-taking", category: "App")

    /// Task UUID received via deep link (dhakira://task/{uuid}).
    /// Passed into ContentView so it can navigate to the correct task detail page.
    @State private var pendingDeepLinkTaskId: UUID? = nil

    // Use the singleton so Color+App.swift and the environment share the same instance.
    // Issue #70 — https://github.com/pnsw123/prod-note/issues/70
    @State private var themeManager = ThemeManager.shared

    // StoreKit manager — injected alongside ThemeManager.
    // Issue #76 — https://github.com/pnsw123/prod-note/issues/76
    @State private var storeKitManager = StoreKitManager.shared

    @Environment(\.scenePhase) private var scenePhase


    init() {
        log.info("App init — building ModelContainer via AppSchemaBuilder")
        do {
            container = try AppSchemaBuilder.makeContainer()
            log.info("ModelContainer ready ✓")
        } catch {
            log.critical("ModelContainer FAILED to init: \(error.localizedDescription)")
            fatalError("Failed to create ModelContainer: \(error)")
        }

    }

    var body: some Scene {
        WindowGroup {
            ContentView(pendingDeepLinkTaskId: $pendingDeepLinkTaskId)
                .environment(themeManager)
                .environment(storeKitManager)
                .preferredColorScheme(themeManager.current.preferredScheme)
                .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
                    // Issue #86: when Apple Calendar events change, reconcile body events.
                    log.info("EKEventStoreChanged: reconciling body events")
                    BodyEventSyncService.shared.reconcileAllAppleEvents(context: container.mainContext)
                    CalendarSyncService.shared.reconcileAllParentEvents(context: container.mainContext)
                }
                .task {
                    // Issue #88: configure notification delegate for foreground display.
                    NotificationService.shared.configure()
                    // Request calendar permission once on first launch (Issue #60).
                    await CalendarPermissionService.shared.requestIfNeeded()
                    // Validate Google OAuth tokens — clears stale Keychain data after reinstall.
                    await GoogleAuthService.shared.validateOnLaunch()
                    // Clean up calendar events for completed/trashed tasks (handles CloudKit sync,
                    // reinstalls, and tasks completed on other devices).
                    await CalendarSyncService.shared.cleanupStaleEvents(in: container.mainContext)
                    // Issue #86: reconcile body events — mark struck if deleted from Apple Calendar.
                    BodyEventSyncService.shared.reconcileAllAppleEvents(context: container.mainContext)
                    // Reconcile parent task events — clear calendarEventId if deleted externally.
                    CalendarSyncService.shared.reconcileAllParentEvents(context: container.mainContext)
                    // Issue #87: reconcile body events against Google Calendar on app open.
                    await BodyEventSyncService.shared.reconcileGoogleEvents(context: container.mainContext)
                    // Run all startup work on a background actor so the UI renders immediately.
                    let worker = StartupWorker(modelContainer: container)
                    await worker.run()
                }
                // Warm launch: app already running, user taps a calendar event deep link.
                .onOpenURL { url in
                    log.info("onOpenURL: \(url.absoluteString)")
                    if let taskId = DeepLinkHandler.handleIncomingURL(url) {
                        pendingDeepLinkTaskId = taskId
                    }
                }
        }
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                // Re-read iOS Settings toggles every time the app comes to foreground.
                CalendarSelectionService.shared.refreshFromUserDefaults()
                // Issue #86: reconcile on foreground return.
                BodyEventSyncService.shared.reconcileAllAppleEvents(context: container.mainContext)
                // Reconcile parent task events on foreground return.
                CalendarSyncService.shared.reconcileAllParentEvents(context: container.mainContext)
                // Issue #87: also reconcile Google Calendar on foreground return.
                Task {
                    await BodyEventSyncService.shared.reconcileGoogleEvents(context: container.mainContext)
                }
            } else if newPhase == .inactive {
                // iOS can kill apps from inactive without going through background —
                // flush changes here too so nothing is lost.
                do {
                    try container.mainContext.save()
                } catch {
                    log.error("scenePhase → inactive: save failed — \(error.localizedDescription)")
                }
            } else if newPhase == .background {
                // Force-flush pending changes (e.g. soft-deletes) before iOS may kill the process.
                // Prevents deleted tasks from reappearing if the app was killed before autosave ran.
                do {
                    try container.mainContext.save()
                    container.mainContext.processPendingChanges()
                    log.info("scenePhase → background: mainContext.save() succeeded")
                } catch {
                    log.error("scenePhase → background: mainContext.save() FAILED — \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - StartupWorker

/// Runs one-time and recurring startup maintenance on a background actor,
/// keeping the main thread (and the UI) completely unblocked.
@ModelActor
private actor StartupWorker {

    private let log = Logger(subsystem: "notes.Note-taking", category: "StartupWorker")

    func run() {
        cleanupEmptyTasks()
        cleanup30DayDeletedTasks()
        syncWidgetData()
    }

    // MARK: Cleanup empty tasks

    private func cleanupEmptyTasks() {
        log.debug("cleanupEmptyTasks: scanning for empty-title tasks")
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.title == "" }
        )
        guard let emptyTasks = try? modelContext.fetch(descriptor), !emptyTasks.isEmpty else {
            log.debug("cleanupEmptyTasks: nothing to clean")
            return
        }
        log.info("cleanupEmptyTasks: deleting \(emptyTasks.count) empty task(s)")
        emptyTasks.forEach { modelContext.delete($0) }
        try? modelContext.save()
        log.info("cleanupEmptyTasks: done ✓")
    }

    // MARK: Sync widget data on launch

    private func syncWidgetData() {
        log.debug("syncWidgetData: syncing ALL active tasks to widget")
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.isTrashed == false && $0.isCompleted == false }
        )
        guard let tasks = try? modelContext.fetch(descriptor) else {
            log.debug("syncWidgetData: no tasks found")
            return
        }
        let widgetTasks = tasks.prefix(8).map { t in
            let hasContent = (t.body != nil && !t.body!.isEmpty) ||
                             (t.drawingData != nil && !t.drawingData!.isEmpty) ||
                             (t.attachments != nil && !t.attachments!.isEmpty)
            return WidgetTask(id: t.id, title: t.title, priority: t.priority, hasContent: hasContent)
        }
        let taskCount = tasks.count
        let encoded = try? JSONEncoder().encode(Array(widgetTasks))
        // Jump to main actor to access ThemeManager and WidgetCenter (both UI-bound)
        Task { @MainActor in
            let themeId = ThemeManager.shared.current.id
            let defaults = UserDefaults(suiteName: "group.com.prodnote.notetaking")
            defaults?.set(taskCount, forKey: "activeTaskCount")
            if let encoded { defaults?.set(encoded, forKey: "activeTasks") }
            defaults?.set(themeId, forKey: "themeId")
            defaults?.synchronize()
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: Purge 30-day deleted tasks

    private func cleanup30DayDeletedTasks() {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate<TaskItem> { $0.isTrashed == true }
        )
        guard let deletedTasks = try? modelContext.fetch(descriptor), !deletedTasks.isEmpty else { return }

        // Stamp any orphaned deleted tasks that are missing a deletedAt timestamp
        var needsSave = false
        for task in deletedTasks where task.deletedAt == nil {
            task.deletedAt = Date()
            needsSave = true
        }
        if needsSave {
            log.info("cleanup30DayDeletedTasks: stamped \(deletedTasks.filter { $0.deletedAt != nil }.count) orphaned task(s) with deletedAt")
        }

        let toRemove = deletedTasks.filter { ($0.deletedAt ?? Date()) < cutoff }
        guard !toRemove.isEmpty else {
            if needsSave { try? modelContext.save() }
            return
        }
        log.info("cleanup30DayDeletedTasks: permanently removing \(toRemove.count) expired task(s)")
        for task in toRemove {
            if let eventId = task.calendarEventId {
                let idToDelete = eventId
                Task.detached { await CalendarSyncService.shared.deleteEvent(withId: idToDelete) }
            }
            if let googleEventId = task.googleCalendarEventId {
                let idToDelete = googleEventId
                Task.detached { await CalendarSyncService.shared.deleteGoogleEvent(idToDelete) }
            }
            // Clean up attachment files from disk
            let taskIdToClean = task.id
            DispatchQueue.global(qos: .background).async {
                AttachmentStore.shared.deleteAll(taskId: taskIdToClean)
            }
            modelContext.delete(task)
        }
        try? modelContext.save()
    }
}
