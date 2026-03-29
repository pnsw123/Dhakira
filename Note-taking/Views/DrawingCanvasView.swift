#if canImport(UIKit)
import SwiftUI
import PencilKit
import OSLog

private let log = Logger(subsystem: "notes.Note-taking", category: "DrawingCanvas")

#Preview("Drawing Canvas") {
    @Previewable @State var drawingData: Data? = nil
    @Previewable @State var isActive: Bool = true
    DrawingCanvasView(drawingData: $drawingData, isActive: $isActive)
        .background(Color(.systemGray6))
}

// MARK: - DrawingCanvasView
// PKCanvasView + PKToolPicker are created once in the Coordinator.
// The parent (TaskDetailView) controls tool picker visibility via
// onCanvasReady — same pattern as NativeEditorView.onEditorReady.

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data?
    @Binding var isActive: Bool
    /// Fires once when the PKCanvasView is in a window. Parent stores
    /// the reference and manages PKToolPicker from onChange(of: isDrawingMode).
    var onCanvasReady: ((PKCanvasView, PKToolPicker) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData)
    }

    func makeUIView(context: Context) -> CanvasHostView {
        let canvas = context.coordinator.canvasView
        log.info("DrawingCanvasView.makeUIView: hasExistingData=\(drawingData != nil)")

        if let data = drawingData,
           let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
            log.debug("DrawingCanvasView.makeUIView: restored \(drawing.strokes.count) stroke(s)")
        }

        // Wrap in a host view that detects when it moves to a window.
        let host = CanvasHostView(canvasView: canvas)
        host.onMovedToWindow = { [weak canvas] in
            guard let canvas else { return }
            let picker = context.coordinator.toolPicker
            log.debug("DrawingCanvasView: canvas moved to window — firing onCanvasReady")
            DispatchQueue.main.async {
                self.onCanvasReady?(canvas, picker)
            }
        }
        return host
    }

    func updateUIView(_ uiView: CanvasHostView, context: Context) {
        let canvas = context.coordinator.canvasView
        canvas.isUserInteractionEnabled = isActive
    }

    // MARK: - CanvasHostView
    // Thin UIView wrapper that detects didMoveToWindow — the moment
    // PKToolPicker can safely be shown.

    class CanvasHostView: UIView {
        let canvasView: PKCanvasView
        var onMovedToWindow: (() -> Void)?
        private var didNotify = false

        init(canvasView: PKCanvasView) {
            self.canvasView = canvasView
            super.init(frame: .zero)
            addSubview(canvasView)
            canvasView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                canvasView.topAnchor.constraint(equalTo: topAnchor),
                canvasView.bottomAnchor.constraint(equalTo: bottomAnchor),
                canvasView.leadingAnchor.constraint(equalTo: leadingAnchor),
                canvasView.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        }

        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil && !didNotify {
                didNotify = true
                onMovedToWindow?()
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate {
        let canvasView: PKCanvasView
        let toolPicker: PKToolPicker
        private var drawingData: Binding<Data?>

        init(drawingData: Binding<Data?>) {
            self.drawingData = drawingData
            self.canvasView = PKCanvasView()
            self.toolPicker = PKToolPicker()
            super.init()

            canvasView.drawingPolicy = .anyInput
            canvasView.backgroundColor = .systemBackground
            canvasView.isScrollEnabled = false
            canvasView.delegate = self

            log.debug("Coordinator.init: PKCanvasView + PKToolPicker created")
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let data = canvasView.drawing.dataRepresentation()
            log.debug("canvasViewDrawingDidChange: \(canvasView.drawing.strokes.count) stroke(s)")
            drawingData.wrappedValue = data
        }
    }
}

#else
import SwiftUI

struct DrawingCanvasView: View {
    @Binding var drawingData: Data?
    @Binding var isActive: Bool
    var onCanvasReady: ((Any, Any) -> Void)?

    var body: some View {
        Text("Drawing is only available on iOS/iPadOS")
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
