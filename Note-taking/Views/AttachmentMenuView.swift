import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

struct AttachmentMenuView: View {
    var onScanText: () -> Void = {}
    var onScanDocuments: () -> Void = {}
    var onTakePhoto: () -> Void = {}
    var onChoosePhoto: () -> Void = {}
    var onRecordAudio: () -> Void = {}
    var onAttachFile: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            menuRow(icon: "text.viewfinder", title: "Scan Text", action: onScanText)
            menuRow(icon: "doc.viewfinder", title: "Scan Documents", action: onScanDocuments)
            menuRow(icon: "camera", title: "Take Photo or Video", action: onTakePhoto)
            menuRow(icon: "photo.on.rectangle", title: "Choose Photo or Video", action: onChoosePhoto)
            menuRow(icon: "mic", title: "Record Audio", action: onRecordAudio)
            menuRow(icon: "doc", title: "Attach File", action: onAttachFile)
        }
        .padding(.vertical, 8)
    }

    private func menuRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28)
                Text(title)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
    }
}
