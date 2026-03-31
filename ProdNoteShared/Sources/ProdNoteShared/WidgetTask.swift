import Foundation

// MARK: - WidgetTask
// Lightweight Codable snapshot shared between the main app and the widget extension.
// The main app encodes and writes this to the shared App Group; the widget decodes it.

public struct WidgetTask: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let priority: String   // "high" | "medium" | "default"
    public let hasContent: Bool   // true = task has notes/drawing/attachments → colored *

    public init(id: UUID, title: String, priority: String, hasContent: Bool = false) {
        self.id = id
        self.title = title
        self.priority = priority
        self.hasContent = hasContent
    }
}
