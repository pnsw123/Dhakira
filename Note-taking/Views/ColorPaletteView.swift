import SwiftUI
import UIKit

// MARK: - ColorPaletteView
// Floating color palette shown on text selection (Issue #44).
// 6 swatches + highlight/font-color mode toggle.

struct ColorPaletteView: View {
    enum ColorMode {
        case highlight, fontColor
    }

    let onApplyHighlight: (UIColor) -> Void
    let onApplyFontColor: (UIColor) -> Void
    let onDismiss: () -> Void

    @State private var mode: ColorMode = .fontColor

    private let swatches: [(String, UIColor)] = [
        ("Gray",   UIColor(hex: "#8e8e93")),
        ("Orange", UIColor(hex: "#ff6a00")),
        ("Blue",   UIColor(hex: "#0a84ff")),
        ("Purple", UIColor(hex: "#bf5af2")),
        ("Pink",   UIColor(hex: "#ff375f")),
        ("Brown",  UIColor(hex: "#ac8e68")),
    ]

    var body: some View {
        HStack(spacing: 8) {
            // Mode toggles
            modeButton(icon: "highlighter", targetMode: .highlight)
            modeButton(icon: "character.cursor.ibeam", targetMode: .fontColor)

            Divider().frame(height: 24)

            // Color swatches
            ForEach(swatches, id: \.0) { name, color in
                Button {
                    if mode == .highlight {
                        onApplyHighlight(color)
                    } else {
                        onApplyFontColor(color)
                    }
                } label: {
                    Circle()
                        .fill(Color(color))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }
                .accessibilityLabel(name)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.primary.opacity(0.12), radius: 8, y: 2)
        )
    }

    @ViewBuilder
    private func modeButton(icon: String, targetMode: ColorMode) -> some View {
        Button {
            mode = targetMode
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(mode == targetMode ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}
