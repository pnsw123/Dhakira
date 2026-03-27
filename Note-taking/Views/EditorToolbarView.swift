import SwiftUI

struct EditorToolbarButton: Identifiable {
    let id: String
    let icon: String
    let label: String
}

struct EditorToolbarView: View {
    var onTextFormat: () -> Void = {}
    var onChecklist: () -> Void = {}
    var onTable: () -> Void = {}
    var onAttachment: () -> Void = {}
    var onMarkup: () -> Void = {}
    var onParagraph: () -> Void = {}

    @State private var buttonOrder: [String] = [
        "textformat", "checklist", "tablecells", "paperclip", "pencil.tip.crop.circle", "list.bullet"
    ]

    private var buttons: [(id: String, icon: String, action: () -> Void)] {
        [
            ("textformat", "textformat", onTextFormat),
            ("checklist", "checklist", onChecklist),
            ("tablecells", "tablecells", onTable),
            ("paperclip", "paperclip", onAttachment),
            ("pencil.tip.crop.circle", "pencil.tip.crop.circle", onMarkup),
            ("list.bullet", "list.bullet", onParagraph)
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(buttonOrder, id: \.self) { buttonId in
                if let button = buttons.first(where: { $0.id == buttonId }) {
                    Button {
                        moveToFront(buttonId)
                        button.action()
                    } label: {
                        Image(systemName: button.icon)
                            .font(.body)
                            .foregroundStyle(Color.primary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.1))
    }

    private func moveToFront(_ id: String) {
        guard let index = buttonOrder.firstIndex(of: id), index != 0 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            buttonOrder.remove(at: index)
            buttonOrder.insert(id, at: 0)
        }
    }
}
