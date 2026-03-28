import AppIntents
import SwiftData
import UIKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "CreateTaskIntent")

struct CreateTaskIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Task"
    static var description: IntentDescription = "Creates a new task in the app"

    @Parameter(title: "Title")
    var title: String

    @Parameter(title: "Details", default: nil)
    var details: String?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        log.info("CreateTaskIntent.perform: title='\(title)', hasDetails=\(details != nil)")
        let container: ModelContainer
        do {
            // Use AppSchemaBuilder — stays in sync with the app's schema automatically (Issue #52)
            container = try AppSchemaBuilder.makeContainer()
        } catch {
            log.error("CreateTaskIntent.perform: failed to create ModelContainer — \(error.localizedDescription)")
            throw error
        }
        let context = container.mainContext

        let task = TaskItem(title: title)
        if let details = details {
            // Use NoteBodyCodec — versioned, surfaces encode failures (Issue #53)
            if case .success(let data) = NoteBodyCodec.encode(NSAttributedString(string: details)) {
                task.body = data
                log.debug("CreateTaskIntent.perform: attached details body (\(details.count) chars)")
            } else {
                log.error("CreateTaskIntent.perform: NoteBodyCodec.encode failed for details")
            }
        }
        context.insert(task)
        do {
            try context.save()
            log.info("CreateTaskIntent.perform: task '\(title)' saved successfully")
        } catch {
            log.error("CreateTaskIntent.perform: context.save() failed — \(error.localizedDescription)")
            throw error
        }

        return .result(dialog: "Created task: \(title)")
    }
}
