import UIKit
import OSLog
import UniformTypeIdentifiers

private let log = Logger(subsystem: "notes.Note-taking", category: "TableAttachment")

// MARK: - TableData

/// Pure-value data model for a table's contents.
/// Stored as a flat array of cell strings indexed by [row * cols + col].
struct TableData: Codable, Equatable {
    let rows: Int
    let cols: Int
    var cells: [String]

    init(rows: Int, cols: Int, cells: [String]? = nil) {
        self.rows = rows
        self.cols = cols
        if let cells = cells {
            self.cells = cells
        } else {
            self.cells = Array(repeating: "", count: rows * cols)
        }
    }

    subscript(row: Int, col: Int) -> String {
        get { cells[row * cols + col] }
        set { cells[row * cols + col] = newValue }
    }
}

// MARK: - TableAttachment

/// A custom NSTextAttachment subclass that stores a table data model as JSON in `contents`.
/// The UTType `app.note-taking.table` identifies this attachment type for the view provider.
final class TableAttachment: NSTextAttachment {

    /// UTType identifier used to register the view provider on the UITextView.
    static let utType = UTType(exportedAs: "app.note-taking.table")

    private(set) var tableData: TableData

    // MARK: Init

    init(rows: Int, cols: Int) {
        self.tableData = TableData(rows: rows, cols: cols)
        super.init(data: nil, ofType: TableAttachment.utType.identifier)
        syncContents()
    }

    required init?(coder: NSCoder) {
        // Decode tableData from `contents` if available
        if let data = coder.decodeObject(forKey: "NSAttachmentContents") as? Data,
           let decoded = try? JSONDecoder().decode(TableData.self, from: data) {
            self.tableData = decoded
        } else {
            self.tableData = TableData(rows: 2, cols: 2)
        }
        super.init(coder: coder)
        syncContents()
    }

    // MARK: Data mutations

    /// Update a single cell value and re-encode contents.
    func updateCell(row: Int, col: Int, value: String) {
        tableData.cells[row * tableData.cols + col] = value
        syncContents()
        log.debug("TableAttachment.updateCell: [\(row),\(col)] = \"\(value)\"")
    }

    // MARK: Codec

    /// Encode the current tableData into `self.contents` as JSON.
    private func syncContents() {
        switch TableAttachmentCodec.encode(tableData) {
        case .success(let data):
            self.contents = data
            self.fileType = TableAttachment.utType.identifier
        case .failure(let error):
            log.error("TableAttachment.syncContents: encode failed — \(error.localizedDescription)")
        }
    }

    /// Decode a TableAttachment from raw contents Data.
    /// Returns nil if the data is missing or malformed.
    static func from(contents: Data?) -> TableAttachment? {
        guard let data = contents else { return nil }
        switch TableAttachmentCodec.decode(data) {
        case .success(let tableData):
            let attachment = TableAttachment(rows: tableData.rows, cols: tableData.cols)
            attachment.tableData = tableData
            attachment.syncContents()
            return attachment
        case .failure(let error):
            log.error("TableAttachment.from(contents:): decode failed — \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - TableAttachmentCodec

/// JSON codec for TableData — separated from the attachment for testability.
enum TableAttachmentCodec {

    enum CodecError: Error, LocalizedError {
        case encodeFailed(String)
        case decodeFailed(String)
        case emptyData

        var errorDescription: String? {
            switch self {
            case .encodeFailed(let d): return "Table encode failed: \(d)"
            case .decodeFailed(let d): return "Table decode failed: \(d)"
            case .emptyData: return "Table contents data is empty"
            }
        }
    }

    static func encode(_ data: TableData) -> Result<Data, CodecError> {
        do {
            let json = try JSONEncoder().encode(data)
            log.debug("TableAttachmentCodec.encode: \(data.rows)×\(data.cols), \(json.count) bytes")
            return .success(json)
        } catch {
            log.error("TableAttachmentCodec.encode: \(error.localizedDescription)")
            return .failure(.encodeFailed(error.localizedDescription))
        }
    }

    static func decode(_ data: Data) -> Result<TableData, CodecError> {
        guard !data.isEmpty else {
            return .failure(.emptyData)
        }
        do {
            let tableData = try JSONDecoder().decode(TableData.self, from: data)
            log.debug("TableAttachmentCodec.decode: \(tableData.rows)×\(tableData.cols)")
            return .success(tableData)
        } catch {
            log.error("TableAttachmentCodec.decode: \(error.localizedDescription)")
            return .failure(.decodeFailed(error.localizedDescription))
        }
    }
}
