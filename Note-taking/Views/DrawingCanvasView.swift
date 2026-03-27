#if canImport(UIKit)
import SwiftUI
import PencilKit

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data?
    /// Called when the user taps Done — passes back PNG data of the rendered drawing
    var onDone: ((Data?) -> Void)?

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.delegate = context.coordinator
        context.coordinator.canvasView = canvasView

        if let data = drawingData, let drawing = try? PKDrawing(data: data) {
            canvasView.drawing = drawing
        }

        // Show tool picker
        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        context.coordinator.toolPicker = toolPicker

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasView
        var toolPicker: PKToolPicker?
        weak var canvasView: PKCanvasView?

        init(_ parent: DrawingCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawingData = canvasView.drawing.dataRepresentation()
        }

        /// Render the current drawing to PNG and call onDone
        func finishDrawing() {
            guard let canvasView else {
                parent.onDone?(nil)
                return
            }
            let image = canvasView.drawing.image(
                from: canvasView.drawing.bounds.isEmpty
                    ? CGRect(x: 0, y: 0, width: 100, height: 100)
                    : canvasView.drawing.bounds,
                scale: UIScreen.main.scale
            )
            parent.onDone?(image.pngData())
        }
    }
}

// MARK: - Done button overlay

/// Wraps DrawingCanvasView with a visible Done (checkmark) button at the top-right
struct DrawingCanvasViewWithDoneButton: View {
    @Binding var drawingData: Data?
    var onDone: ((Data?) -> Void)?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            InternalCanvas(drawingData: $drawingData, onDone: onDone)
            Button {
                // Trigger done by calling onDone with current drawing rendered
                NotificationCenter.default.post(name: .drawingDoneTapped, object: nil)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accentColor)
                    .background(Circle().fill(Color.white).padding(4))
                    .shadow(radius: 4)
            }
            .padding(.top, 12)
            .padding(.trailing, 16)
        }
    }
}

private struct InternalCanvas: UIViewRepresentable {
    @Binding var drawingData: Data?
    var onDone: ((Data?) -> Void)?

    func makeCoordinator() -> DrawingCanvasView.Coordinator {
        let view = DrawingCanvasView(drawingData: $drawingData, onDone: onDone)
        return DrawingCanvasView.Coordinator(view)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.delegate = context.coordinator
        context.coordinator.canvasView = canvasView

        if let data = drawingData, let drawing = try? PKDrawing(data: data) {
            canvasView.drawing = drawing
        }

        let toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
        context.coordinator.toolPicker = toolPicker

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(DrawingCanvasView.Coordinator.doneTapped),
            name: .drawingDoneTapped,
            object: nil
        )

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}

extension Notification.Name {
    static let drawingDoneTapped = Notification.Name("drawingDoneTapped")
}

extension DrawingCanvasView.Coordinator {
    @objc func doneTapped() {
        finishDrawing()
    }
}

#else
import SwiftUI

struct DrawingCanvasView: View {
    @Binding var drawingData: Data?
    var onDone: ((Data?) -> Void)?

    var body: some View {
        Text("Drawing is only available on iOS/iPadOS")
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct DrawingCanvasViewWithDoneButton: View {
    @Binding var drawingData: Data?
    var onDone: ((Data?) -> Void)?

    var body: some View {
        DrawingCanvasView(drawingData: $drawingData, onDone: onDone)
    }
}
#endif
