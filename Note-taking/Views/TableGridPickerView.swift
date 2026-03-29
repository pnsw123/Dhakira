import SwiftUI

// MARK: - TableGridPickerView (Issue #56)
// A 6×6 drag-to-select grid that lets the user choose the size of a table to insert.
// Drag or tap across cells to highlight the selection. Lift finger or tap Insert to confirm.
// Styled to match iOS 26 liquid glass design used throughout the app.

struct TableGridPickerView: View {

    static let maxRows = 6
    static let maxCols = 6

    let onInsert: (Int, Int) -> Void
    let onDismiss: () -> Void

    @State private var hoveredRow: Int = 1
    @State private var hoveredCol: Int = 1
    private let cellSize: CGFloat = 28
    private let cellSpacing: CGFloat = 5

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Text("Insert Table")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
            }

            // Size label
            Text("\(hoveredRow) × \(hoveredCol)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            // Grid
            grid

            // Insert button
            Button {
                onInsert(hoveredRow, hoveredCol)
            } label: {
                Text("Insert")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .padding(.horizontal, 28)
    }

    // MARK: - Grid

    private var grid: some View {
        VStack(spacing: cellSpacing) {
            ForEach(1...TableGridPickerView.maxRows, id: \.self) { row in
                HStack(spacing: cellSpacing) {
                    ForEach(1...TableGridPickerView.maxCols, id: \.self) { col in
                        cell(row: row, col: col)
                    }
                }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in updateHovered(from: value.location) }
                .onEnded { value in
                    updateHovered(from: value.location)
                    onInsert(hoveredRow, hoveredCol)
                }
        )
    }

    private func cell(row: Int, col: Int) -> some View {
        let isSelected = row <= hoveredRow && col <= hoveredCol
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.85) : Color.primary.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.accentColor : Color.primary.opacity(0.18),
                        lineWidth: 1
                    )
            )
            .frame(width: cellSize, height: cellSize)
            .animation(.easeOut(duration: 0.07), value: isSelected)
    }

    // MARK: - Helpers

    private func updateHovered(from location: CGPoint) {
        let step = cellSize + cellSpacing
        // Approximate grid origin inside the VStack (header + size label + spacings + padding)
        let gridOriginY: CGFloat = 20 + 28 + 14 + 18 + 14
        let col = max(1, min(TableGridPickerView.maxCols, Int((location.x - 20) / step) + 1))
        let row = max(1, min(TableGridPickerView.maxRows, Int((location.y - gridOriginY) / step) + 1))
        if row != hoveredRow || col != hoveredCol {
            hoveredRow = row
            hoveredCol = col
        }
    }
}

#Preview("Table Grid Picker") {
    TableGridPickerView(
        onInsert: { rows, cols in print("Insert \(rows)×\(cols)") },
        onDismiss: { print("Dismissed") }
    )
    .padding()
    .background(Color(.systemBackground))
}
