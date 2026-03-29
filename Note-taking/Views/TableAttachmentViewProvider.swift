import UIKit
import SwiftUI
import Combine
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "TableAttachmentViewProvider")

// MARK: - TableAttachmentViewProvider (Issues #57 + #58)
//
// NSTextAttachmentViewProvider subclass that renders a TableAttachment
// as a live SwiftUI Grid inside the UITextView using TextKit 2.
//
// Registration:
//   textView.registerTextAttachmentViewProviderClass(
//       TableAttachmentViewProvider.self,
//       forFileType: TableAttachment.utType.identifier
//   )

final class TableAttachmentViewProvider: NSTextAttachmentViewProvider {

    /// Host controller for the SwiftUI table view.
    private var host: UIHostingController<AnyView>?

    /// Observable state shared between provider and the SwiftUI view.
    private var tableState: TableViewState?

    /// Called by TextKit 2 to produce the inline view for this attachment.
    override func loadView() {
        super.loadView()

        guard let tableAttachment = textAttachment as? TableAttachment else {
            log.warning("TableAttachmentViewProvider.loadView: attachment is not a TableAttachment")
            view = UIView()
            return
        }

        let state = TableViewState(tableData: tableAttachment.tableData)
        self.tableState = state

        // Wire cell changes: update the attachment data and trigger save
        state.onCellChange = { [weak tableAttachment, weak self] coord, value in
            guard let attachment = tableAttachment else { return }
            attachment.updateCell(row: coord.row, col: coord.col, value: value)
            // Notify the text view that the attachment changed so the document is re-saved
            self?.triggerSave()
        }

        let tableView = makeTableView(state: state)
        let hosting = UIHostingController(rootView: tableView)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        let size = hosting.sizeThatFits(in: CGSize(width: 280, height: UIView.layoutFittingCompressedSize.height))
        hosting.view.frame = CGRect(origin: .zero, size: size)

        self.host = hosting
        self.view = hosting.view
        log.debug("TableAttachmentViewProvider.loadView: rendered \(tableAttachment.tableData.rows)×\(tableAttachment.tableData.cols) table, size=\(size.debugDescription)")
    }

    /// Preferred attachment bounds — used by TextKit 2 to reserve space in the text container.
    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: (any NSTextLocation),
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        guard let tableAttachment = textAttachment as? TableAttachment else {
            return .zero
        }
        let width = min(proposedLineFragment.width > 0 ? proposedLineFragment.width : 280, 320)
        let rowHeight: CGFloat = 36
        let height = CGFloat(tableAttachment.tableData.rows) * rowHeight + 2 // +2 for border
        return CGRect(origin: .zero, size: CGSize(width: width, height: height))
    }

    // MARK: - Save trigger

    /// Post a notification so TaskDetailView can save the body after a cell edit.
    private func triggerSave() {
        NotificationCenter.default.post(
            name: TableAttachmentViewProvider.cellDidChangeNotification,
            object: textAttachment
        )
        log.debug("TableAttachmentViewProvider.triggerSave: posted cellDidChangeNotification")
    }

    static let cellDidChangeNotification = Notification.Name("TableAttachmentCellDidChange")

    // MARK: - Helpers

    private func makeTableView(state: TableViewState) -> AnyView {
        AnyView(
            TableGridViewEditable(state: state)
                .frame(maxWidth: 320)
        )
    }
}

// MARK: - TableViewState

/// Observable object bridging the SwiftUI table view and the UIKit attachment provider.
@MainActor
final class TableViewState: ObservableObject {
    @Published var tableData: TableData
    @Published var focusedCell: TableCellCoordinate?
    var onCellChange: ((TableCellCoordinate, String) -> Void)?

    init(tableData: TableData) {
        self.tableData = tableData
    }
}

// MARK: - TableGridViewEditable (Issue #58)

/// Editable table view driven by TableViewState.
struct TableGridViewEditable: View {
    @ObservedObject var state: TableViewState

    var body: some View {
        TableGridView(
            tableData: state.tableData,
            focusedCell: state.focusedCell,
            onCellTap: { coord in
                state.focusedCell = coord
            },
            onCellChange: { coord, value in
                state.tableData.cells[coord.row * state.tableData.cols + coord.col] = value
                state.onCellChange?(coord, value)
            },
            onDismiss: {
                state.focusedCell = nil
            }
        )
    }
}
