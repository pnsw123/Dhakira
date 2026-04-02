import SwiftData
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "AppSchemaBuilder")

// MARK: - AppModel (Issue #52)
// Every SwiftData @Model must conform to AppModel.
// AppSchemaBuilder uses the conformance list as the single source of truth.
// Forgetting to add a new model here = CI test failure (never a silent runtime crash).

protocol AppModel: PersistentModel {}

extension TaskItem:   AppModel {}
extension Attachment: AppModel {}
extension Folder:     AppModel {}
extension TaskList:   AppModel {}

// MARK: - AppSchemaBuilder

enum AppSchemaBuilder {

    /// All registered SwiftData model types — one place to add new models.
    private static let registeredTypes: [any AppModel.Type] = [
        TaskItem.self,
        Attachment.self,
        Folder.self,
        TaskList.self,
    ]

    /// The shared Schema — derived from registeredTypes.
    static var schema: Schema {
        Schema(registeredTypes.map { $0 as any PersistentModel.Type })
    }

    /// Build a production ModelContainer (CloudKit sync enabled by default).
    /// groupContainer: .none — store the database in the app's PRIVATE container,
    /// NOT the shared App Group. The App Group has restricted write permissions that
    /// cause "Sandbox access to file-write-create denied" errors, CloudKit export
    /// failures, and data loss. The widget reads from UserDefaults (synced separately),
    /// not from the database — it does NOT need direct database access.
    static func makeContainer() throws -> ModelContainer {
        log.info("AppSchemaBuilder.makeContainer: building production container (groupContainer: .none)")
        let config = ModelConfiguration(schema: schema, groupContainer: .none, cloudKitDatabase: .automatic)
        let container = try ModelContainer(for: schema, configurations: [config])
        log.info("AppSchemaBuilder.makeContainer: done ✓")
        return container
    }

    /// Build an in-memory ModelContainer for tests and Previews.
    static func makeInMemoryContainer() throws -> ModelContainer {
        log.debug("AppSchemaBuilder.makeInMemoryContainer: building test/preview container")
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }
}
