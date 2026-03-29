import SwiftUI

// MARK: - TableGridView (Issue #57)
// SwiftUI Grid that renders a table attachment inline in the editor.
// Display-only in base form; edited cells are managed by TableGridViewEditable (Issue #58).

struct TableGridView: View {

    let tableData: TableData
    /// When non-nil, that cell is currently focused for editing (Issue #58).
    var focusedCell: TableCellCoordinate?
    /// Called when a cell is tapped (Issue #58).
    var onCellTap: ((TableCellCoordinate) -> Void)?
    /// Called when a cell value changes (Issue #58).
    var onCellChange: ((TableCellCoordinate, String) -> Void)?
    /// Called when user taps outside the table to dismiss (Issue #58).
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<tableData.rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<tableData.cols, id: \.self) { col in
                        cellView(row: row, col: col)
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
    }

    // MARK: - Cell

    @ViewBuilder
    private func cellView(row: Int, col: Int) -> some View {
        let coord = TableCellCoordinate(row: row, col: col)
        let isFocused = focusedCell == coord
        let value = tableData[row, col]

        if onCellChange != nil {
            // Editable mode (Issue #58) — each cell is a TextField
            EditableCellView(
                value: value,
                isFocused: isFocused,
                onTap: { onCellTap?(coord) },
                onCommit: { newValue in onCellChange?(coord, newValue) }
            )
            .frame(minWidth: 44, minHeight: 36)
            .background(isFocused ? Color.indigo.opacity(0.08) : Color.clear)
            .overlay(cellBorder(row: row, col: col))
        } else {
            // Display-only mode (Issue #57)
            Text(value.isEmpty ? " " : value)
                .font(.footnote)
                .foregroundStyle(.primary)
                .frame(minWidth: 44, minHeight: 36, alignment: .topLeading)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .overlay(cellBorder(row: row, col: col))
        }
    }

    private func cellBorder(row: Int, col: Int) -> some View {
        let isLastCol = col == tableData.cols - 1
        let isLastRow = row == tableData.rows - 1
        return ZStack {
            if !isLastCol {
                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(width: 0.5)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if !isLastRow {
                Rectangle()
                    .fill(Color.primary.opacity(0.10))
                    .frame(height: 0.5)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

// MARK: - TableCellCoordinate

struct TableCellCoordinate: Equatable, Hashable {
    let row: Int
    let col: Int
}

// MARK: - EditableCellView (Issue #58)

struct EditableCellView: View {
    let value: String
    let isFocused: Bool
    let onTap: () -> Void
    let onCommit: (String) -> Void

    @State private var draft: String = ""

    var body: some View {
        TextField("", text: $draft, axis: .vertical)
            .font(.footnote)
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .onTapGesture { onTap() }
            .onChange(of: draft) { _, newValue in
                onCommit(newValue)
            }
            .onAppear { draft = value }
            .onChange(of: value) { _, newValue in
                // Keep draft in sync when external changes arrive (e.g. undo)
                if newValue != draft { draft = newValue }
            }
    }
}

// MARK: - Preview

#Preview("Table Grid View") {
    var data = TableData(rows: 3, cols: 4)
    data.cells[0] = "Name"
    data.cells[1] = "Age"
    data.cells[2] = "City"
    data.cells[3] = "Score"
    data.cells[4] = "Alice"
    data.cells[5] = "30"
    data.cells[6] = "New York"
    data.cells[7] = "95"

    return TableGridView(tableData: data)
        .padding()
        .background(Color(.systemGroupedBackground))
}
