import SwiftUI

// MARK: - TableGridPickerView (Issue #56)
// A 6×6 drag-to-select grid that lets the user choose the size of a table to insert.
// Drag or tap across cells to highlight the selection. Lift finger or tap Insert to confirm.
// Tap outside the picker to dismiss without inserting.

struct TableGridPickerView: View {

    /// Maximum rows/cols available in the picker.
    static let maxRows = 6
    static let maxCols = 6

    /// Called when the user confirms a table size. Rows and cols are 1-based.
    let onInsert: (Int, Int) -> Void
    /// Called when the user dismisses the picker without inserting.
    let onDismiss: () -> Void

    @State private var hoveredRow: Int = 1
    @State private var hoveredCol: Int = 1
    @State private var cellSize: CGFloat = 28

    private let cellSpacing: CGFloat = 4

    var body: some View {
        VStack(spacing: 12) {
            // Size label
            Text("\(hoveredRow) × \(hoveredCol)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .frame(minWidth: 60)
                .animation(.none, value: hoveredRow)
                .animation(.none, value: hoveredCol)

            // Grid
            grid

            // Insert button
            Button {
                onInsert(hoveredRow, hoveredCol)
            } label: {
                Text("Insert")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.indigo, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
        .frame(width: CGFloat(TableGridPickerView.maxCols) * (cellSize + cellSpacing) + 28)
    }

    // MARK: - Grid

    private var grid: some View {
        let totalRows = TableGridPickerView.maxRows
        let totalCols = TableGridPickerView.maxCols

        return VStack(spacing: cellSpacing) {
            ForEach(1...totalRows, id: \.self) { row in
                HStack(spacing: cellSpacing) {
                    ForEach(1...totalCols, id: \.self) { col in
                        cell(row: row, col: col)
                    }
                }
            }
        }
        // Drag gesture to update selection as the user moves across cells
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    updateHovered(from: value.location)
                }
                .onEnded { value in
                    updateHovered(from: value.location)
                    onInsert(hoveredRow, hoveredCol)
                }
        )
    }

    private func cell(row: Int, col: Int) -> some View {
        let isSelected = row <= hoveredRow && col <= hoveredCol
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(isSelected ? Color.indigo.opacity(0.85) : Color.primary.opacity(0.08))
            .frame(width: cellSize, height: cellSize)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(isSelected ? Color.indigo : Color.primary.opacity(0.12), lineWidth: 0.5)
            )
            .animation(.easeOut(duration: 0.07), value: isSelected)
    }

    // MARK: - Helpers

    /// Translate a drag location (local to the VStack) into a row/col position.
    private func updateHovered(from location: CGPoint) {
        let totalCols = TableGridPickerView.maxCols
        let totalRows = TableGridPickerView.maxRows
        let step = cellSize + cellSpacing

        // The grid's origin inside the VStack is offset by the label + spacing above it.
        // We rely on the DragGesture local coordinate space which starts at the VStack top.
        // Approx top-of-grid offset: label height (~22) + spacing (12) + padding top (14)
        let gridOriginY: CGFloat = 22 + 12 + 14
        let col = max(1, min(totalCols, Int((location.x - 14) / step) + 1))
        let row = max(1, min(totalRows, Int((location.y - gridOriginY) / step) + 1))
        if row != hoveredRow || col != hoveredCol {
            hoveredRow = row
            hoveredCol = col
        }
    }
}

// MARK: - Preview

#Preview("Table Grid Picker") {
    TableGridPickerView(
        onInsert: { rows, cols in
            print("Insert \(rows)×\(cols)")
        },
        onDismiss: {
            print("Dismissed")
        }
    )
    .padding()
    .background(Color(.systemBackground))
}
