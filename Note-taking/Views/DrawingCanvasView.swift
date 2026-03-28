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

struct DrawingCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data?
    /// When true, the PKToolPicker is shown. When false, it is hidden (drawing stays).
    @Binding var isActive: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        log.info("DrawingCanvasView.makeUIView: creating canvas, hasExistingData=\(drawingData != nil)")
        let canvasView = PKCanvasView()
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isScrollEnabled = false
        canvasView.delegate = context.coordinator
        context.coordinator.canvasView = canvasView

        if let data = drawingData {
            if let drawing = try? PKDrawing(data: data) {
                canvasView.drawing = drawing
                log.debug("DrawingCanvasView.makeUIView: restored drawing with \(drawing.strokes.count) stroke(s)")
            } else {
                log.error("DrawingCanvasView.makeUIView: failed to deserialize PKDrawing from \(data.count) bytes")
            }
        }

        // Create the tool picker and store in coordinator (survives SwiftUI re-renders)
        let toolPicker = PKToolPicker()
        context.coordinator.toolPicker = toolPicker
        log.debug("DrawingCanvasView.makeUIView: PKToolPicker created")

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = isActive
        log.debug("DrawingCanvasView.updateUIView: isActive=\(isActive)")

        // PKToolPicker requires a real window — skip in Xcode previews
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else { return }
        let picker = context.coordinator.toolPicker

        if isActive {
            // Must re-add observer every time — SwiftUI can recreate the view
            picker?.addObserver(uiView)

            // Defer until canvas is in the window hierarchy
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard uiView.window != nil else {
                    log.warning("DrawingCanvasView: canvas not in window yet — retrying")
                    // Retry once more after a longer delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        guard uiView.window != nil else { return }
                        picker?.setVisible(true, forFirstResponder: uiView)
                        picker?.addObserver(uiView)
                        uiView.becomeFirstResponder()
                    }
                    return
                }
                picker?.setVisible(true, forFirstResponder: uiView)
                uiView.becomeFirstResponder()
                log.debug("DrawingCanvasView: tool picker shown, canvas is first responder")
            }
        } else {
            picker?.setVisible(false, forFirstResponder: uiView)
            uiView.resignFirstResponder()
            log.debug("DrawingCanvasView.updateUIView: tool picker hidden")
        }
    }

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
            let data = canvasView.drawing.dataRepresentation()
            log.debug("canvasViewDrawingDidChange: \(canvasView.drawing.strokes.count) stroke(s), \(data.count) bytes")
            parent.drawingData = data
        }
    }
}

#else
import SwiftUI

struct DrawingCanvasView: View {
    @Binding var drawingData: Data?
    @Binding var isActive: Bool

    var body: some View {
        Text("Drawing is only available on iOS/iPadOS")
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
