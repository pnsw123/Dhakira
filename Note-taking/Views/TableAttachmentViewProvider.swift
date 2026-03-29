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

        // After RTF round-trip the attachment is a generic NSTextAttachment (RTF doesn't
        // preserve custom subclasses). Read tableData from contents directly so tables
        // render correctly both immediately after insertion AND after save/reload.
        let tableData: TableData
        if let ta = textAttachment as? TableAttachment {
            tableData = ta.tableData
        } else if let data = textAttachment?.contents,
                  case .success(let decoded) = TableAttachmentCodec.decode(data) {
            tableData = decoded
        } else {
            log.warning("TableAttachmentViewProvider.loadView: could not read table data from attachment")
            view = UIView()
            return
        }

        let state = TableViewState(tableData: tableData)
        self.tableState = state

        // Wire cell changes: write back into the underlying NSTextAttachment.contents
        // directly so saves work whether the attachment is a TableAttachment subclass
        // (new insert) or a generic NSTextAttachment restored from RTF.
        state.onCellChange = { [weak self] _, _ in
            if let updatedData = try? JSONEncoder().encode(state.tableData) {
                self?.textAttachment?.contents = updatedData
            }
            self?.triggerSave()
        }

        let tableView = makeTableView(state: state)
        let hosting = UIHostingController(rootView: tableView)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false

        // Embed in parent VC so SwiftUI's update cycle has an owner.
        // NSTextContainer has no .textView on iOS — walk the layout manager's
        // delegate chain via the view we are about to set, using the responder chain.
        if let parentVC = view?.parentViewController ?? UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController {
            parentVC.addChild(hosting)
            hosting.didMove(toParent: parentVC)
        }

        let size = hosting.sizeThatFits(in: CGSize(width: 280, height: UIView.layoutFittingCompressedSize.height))
        hosting.view.frame = CGRect(origin: .zero, size: size)

        self.host = hosting
        self.view = hosting.view
        log.debug("TableAttachmentViewProvider.loadView: rendered \(tableData.rows)×\(tableData.cols) table, size=\(size.debugDescription)")
    }

    /// Preferred attachment bounds — used by TextKit 2 to reserve space in the text container.
    override func attachmentBounds(
        for attributes: [NSAttributedString.Key: Any],
        location: (any NSTextLocation),
        textContainer: NSTextContainer?,
        proposedLineFragment: CGRect,
        position: CGPoint
    ) -> CGRect {
        let rows: Int
        if let ta = textAttachment as? TableAttachment {
            rows = ta.tableData.rows
        } else if let data = textAttachment?.contents,
                  case .success(let decoded) = TableAttachmentCodec.decode(data) {
            rows = decoded.rows
        } else {
            return .zero
        }
        let width = min(proposedLineFragment.width > 0 ? proposedLineFragment.width : 280, 320)
        let rowHeight: CGFloat = 36
        let height = CGFloat(rows) * rowHeight + 2
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

// MARK: - UIView parent VC helper

private extension UIView {
    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
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
