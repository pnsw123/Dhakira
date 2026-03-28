import SwiftUI
import UIKit

// MARK: - ColorPaletteView
// Compact floating pill — matches iOS Cut/Copy/Paste callout height (44pt).
// 4 presets + rainbow button in main pill. Expanded pill is a single row of 8,
// trailing-aligned so its right edge lines up with the main pill.

struct ColorPaletteView: View {
    enum ColorMode { case highlight, fontColor }

    let onApplyHighlight:  (UIColor) -> Void
    let onApplyFontColor:  (UIColor) -> Void
    let onRemoveFontColor: () -> Void
    let onRemoveHighlight: () -> Void
    let onDismiss:         () -> Void

    @State private var mode: ColorMode = .fontColor
    @State private var activeFontColorName: String? = nil
    @State private var activeHighlightName: String? = nil
    @State private var showMoreColors = false

    private let mainColors: [(String, UIColor)] = [
        ("Yellow", UIColor(hex: "#FFCC02")),
        ("Red",    UIColor(hex: "#FF3B30")),
        ("Blue",   UIColor(hex: "#007AFF")),
        ("Green",  UIColor(hex: "#34C759")),
    ]

    private let extraColors: [(String, UIColor)] = [
        ("Orange", UIColor(hex: "#FF9500")),
        ("Pink",   UIColor(hex: "#FF375F")),
        ("Purple", UIColor(hex: "#BF5AF2")),
        ("Teal",   UIColor(hex: "#5AC8FA")),
        ("Brown",  UIColor(hex: "#AC8E68")),
        ("Gray",   UIColor(hex: "#8E8E93")),
        ("Black",  UIColor(hex: "#1C1C1E")),
        ("White",  UIColor(hex: "#FFFFFF")),
    ]

    private let dot: CGFloat       = 26
    private let pillH: CGFloat     = 44
    private let swatchPad: CGFloat = 4   // horizontal padding each side of a swatch

    var body: some View {
        // trailing alignment → expanded panel's right edge lines up with main pill
        VStack(alignment: .trailing, spacing: 6) {

            // ── Main pill ────────────────────────────────────────────────────
            HStack(spacing: 0) {

                // Mode selector — segmented control style, clearly shows active mode
                modeSegmentControl
                    .padding(.horizontal, 4)

                // Separator
                Rectangle()
                    .fill(Color.primary.opacity(0.15))
                    .frame(width: 0.5, height: 22)
                    .padding(.horizontal, 6)

                // 4 preset swatches
                ForEach(mainColors, id: \.0) { name, uiColor in
                    swatchButton(name, uiColor)
                        .padding(.horizontal, swatchPad)
                }

                // Rainbow "more" button
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showMoreColors.toggle()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(AngularGradient(
                                colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                                center: .center
                            ))
                            .frame(width: dot, height: dot)
                        Image(systemName: showMoreColors ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                    .padding(.horizontal, swatchPad)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More colors")
            }
            .padding(.horizontal, 8)
            .frame(height: pillH)
            .background(pillBackground)

            // ── Expanded pill — single row, same height, trailing-aligned ────
            if showMoreColors {
                HStack(spacing: 0) {
                    ForEach(extraColors, id: \.0) { name, uiColor in
                        swatchButton(name, uiColor)
                            .padding(.horizontal, swatchPad - 1)  // slightly tighter to match width
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: pillH)
                .background(pillBackground)
                .transition(.scale(scale: 0.92, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: showMoreColors)
    }

    // MARK: - Mode segment control

    /// Mini segmented control — white-card background on the active segment makes it
    /// unambiguous which mode is selected. Action is always just `mode = target`
    /// so tapping either button always produces a visible state change.
    private var modeSegmentControl: some View {
        HStack(spacing: 2) {
            modeSegmentButton(target: .fontColor) {
                VStack(spacing: 2) {
                    Text("A")
                        .font(.system(size: 17, weight: .bold))
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(mode == .fontColor ? Color.accentColor : Color.secondary.opacity(0.4))
                        .frame(width: 14, height: 2.5)
                }
            }
            modeSegmentButton(target: .highlight) {
                Image(systemName: "highlighter")
                    .font(.system(size: 14, weight: .medium))
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.07))
        )
    }

    @ViewBuilder
    private func modeSegmentButton<Label: View>(
        target: ColorMode,
        @ViewBuilder label: () -> Label
    ) -> some View {
        let isActive = mode == target
        Button {
            mode = target   // always switch — always produces a visible change
        } label: {
            label()
                .foregroundStyle(isActive ? Color.primary : Color.secondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isActive
                              ? Color(uiColor: .systemBackground)
                              : Color.clear)
                        .shadow(color: .black.opacity(isActive ? 0.08 : 0),
                                radius: 2, y: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isActive)
    }

    // MARK: - Swatch button

    @ViewBuilder
    private func swatchButton(_ name: String, _ uiColor: UIColor) -> some View {
        let isActive = (mode == .fontColor && activeFontColorName == name)
                    || (mode == .highlight && activeHighlightName  == name)
        Button {
            applyOrRemove(name: name, color: uiColor)
        } label: {
            ZStack {
                Circle()
                    .fill(Color(uiColor))
                    .frame(width: dot, height: dot)
                if uiColor.isLight {
                    Circle()
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 0.5)
                        .frame(width: dot, height: dot)
                }
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(uiColor.isLight ? Color.black.opacity(0.6) : .white)
                }
            }
            .overlay(
                Circle().strokeBorder(
                    isActive ? Color.primary.opacity(0.5) : Color.clear,
                    lineWidth: 2
                )
            )
            .scaleEffect(isActive ? 1.1 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }

    // MARK: - Shared background

    private var pillBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.13), radius: 12, x: 0, y: 4)
    }

    // MARK: - Logic

    private func applyOrRemove(name: String, color: UIColor) {
        if mode == .highlight {
            if activeHighlightName == name {
                onRemoveHighlight(); activeHighlightName = nil
            } else {
                onApplyHighlight(color); activeHighlightName = name
            }
        } else {
            if activeFontColorName == name {
                onRemoveFontColor(); activeFontColorName = nil
            } else {
                onApplyFontColor(color); activeFontColorName = name
            }
        }
    }
}

// MARK: - UIColor helpers

private extension UIColor {
    var isLight: Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.2126 * r + 0.7152 * g + 0.0722 * b > 0.6
    }
}
