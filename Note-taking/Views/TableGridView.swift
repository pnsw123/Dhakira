import SwiftUI

// MARK: - TableGridView (Issue #57)
// Renders a table attachment inline in the editor.
// Uses iOS 26 glass design to match the rest of the app.

struct TableGridView: View {

    let tableData: TableData
    var focusedCell: TableCellCoordinate?
    var onCellTap: ((TableCellCoordinate) -> Void)?
    var onCellChange: ((TableCellCoordinate, String) -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<tableData.rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<tableData.cols, id: \.self) { col in
                        cellView(row: row, col: col)
                    }
                }
                if row < tableData.rows - 1 {
                    Divider().overlay(Color.primary.opacity(0.1))
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .padding(.vertical, 4)
    }

    // MARK: - Cell

    @ViewBuilder
    private func cellView(row: Int, col: Int) -> some View {
        let coord = TableCellCoordinate(row: row, col: col)
        let isFocused = focusedCell == coord
        let value = tableData[row, col]

        Group {
            if onCellChange != nil {
                EditableCellView(
                    value: value,
                    isFocused: isFocused,
                    isHeader: row == 0,
                    onTap: { onCellTap?(coord) },
                    onCommit: { newValue in onCellChange?(coord, newValue) }
                )
            } else {
                Text(value.isEmpty ? " " : value)
                    .font(row == 0 ? .footnote.weight(.semibold) : .footnote)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
            }
        }
        .background(
            isFocused
                ? Color.accentColor.opacity(0.1)
                : (row == 0 ? Color.primary.opacity(0.04) : Color.clear)
        )
        .overlay(alignment: .trailing) {
            if col < tableData.cols - 1 {
                Rectangle()
                    .fill(Color.primary.opacity(0.1))
                    .frame(width: 0.5)
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
    let isHeader: Bool
    let onTap: () -> Void
    let onCommit: (String) -> Void

    @State private var draft: String = ""

    var body: some View {
        TextField("", text: $draft, axis: .vertical)
            .font(isHeader ? .footnote.weight(.semibold) : .footnote)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .onTapGesture { onTap() }
            .onChange(of: draft) { _, newValue in onCommit(newValue) }
            .onAppear { draft = value }
            .onChange(of: value) { _, newValue in
                if newValue != draft { draft = newValue }
            }
    }
}

// MARK: - Preview

#Preview("Table Grid View") {
    TableGridView(tableData: TableData(rows: 3, cols: 4))
        .padding()
}
