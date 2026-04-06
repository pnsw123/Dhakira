import SwiftData
import UniformTypeIdentifiers
import CoreTransferable

// Custom UTType for folder drag-and-drop within the app.
extension UTType {
    static let dhakiraFolderID = UTType("com.prodnote.notetaking.folderID")!
}

/// Wraps a PersistentIdentifier so it can be dragged between folder rows.
struct FolderTransferID: Codable, Transferable {
    let rawID: PersistentIdentifier

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .dhakiraFolderID)
    }
}
