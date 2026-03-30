import SwiftUI
import PhotosUI

// MARK: - BottomCustomisationBar
// Four tabs — Color / Gradient / Photo / Blur — letting the user override the theme's
// default background. All tabs share an identical fixed-height content area so the bar
// never resizes when switching tabs (user request: consistent size).
// Uses .glassEffect directly — GlassEffectContainer was causing size overrides on iOS 26.
// Issue #75 — https://github.com/pnsw123/prod-note/issues/75

struct BottomCustomisationBar: View {
    let theme: AppTheme
    @Environment(ThemeManager.self) private var themeManager

    @State private var selectedTab: CustomTab = .color
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var customColor: Color = .blue
    @State private var selectedGradientIndex: Int = 0

    // Fixed content area height — ALL tabs must fit within this.
    // Changing this one constant keeps every tab consistent.
    private let contentHeight: CGFloat = 56

    enum CustomTab: String, CaseIterable, Identifiable {
        case color    = "Color"
        case gradient = "Gradient"
        case photo    = "Photo"
        case blur     = "Blur"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .color:    return "circle.fill"
            case .gradient: return "slowmo"
            case .photo:    return "photo"
            case .blur:     return "drop.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // ── Content area — locked to contentHeight for all tabs ──
            tabContent
                .frame(maxWidth: .infinity, minHeight: contentHeight, maxHeight: contentHeight)
                .clipped()
                .padding(.horizontal, 16)

            // ── Tab selector ────────────────────────────────────────
            tabSelector
        }
        .padding(.vertical, 10)
        .modifier(GlassBarModifier())
    }

    // MARK: — Tab content (all cases must stay within contentHeight)

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .color:
            ColorPicker("Background color", selection: $customColor, supportsOpacity: false)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: customColor) { _, newColor in
                    themeManager.applyColorOverride(newColor)
                }

        case .gradient:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(gradientPresets.indices, id: \.self) { i in
                        gradientSwatch(at: i)
                    }
                }
                .padding(.horizontal, 4)
            }

        case .photo:
            PhotosPicker(
                selection: $pickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                Label("Choose Photo", systemImage: "photo.badge.plus")
                    .font(.subheadline.weight(.medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .onChange(of: pickerItem) { _, item in
                Task { await loadPhoto(from: item) }
            }

        case .blur:
            #if canImport(UIKit)
            if let img = themeManager.backgroundImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 10)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("No background photo selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            #else
            Text("No background photo selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            #endif
        }
    }

    // MARK: — Tab buttons

    private var tabSelector: some View {
        HStack(spacing: 0) {
            ForEach(CustomTab.allCases) { tab in
                Button {
                    withAnimation(.spring(duration: 0.25, bounce: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18))
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: — Gradient presets

    private var gradientPresets: [[Color]] {
        [
            [.blue, .purple, .pink],
            [.green, .teal, .blue],
            [.orange, .red, .pink],
            [.yellow, .orange, .red],
            [.purple, .indigo, .blue],
        ]
    }

    @ViewBuilder
    private func gradientSwatch(at index: Int) -> some View {
        let colors = gradientPresets[index]
        Button {
            selectedGradientIndex = index
            themeManager.applyGradientOverride(colors)
        } label: {
            if #available(iOS 18, *) {
                MeshGradient(
                    width: 2, height: 2,
                    points: [[0, 0], [1, 0], [0, 1], [1, 1]],
                    colors: colors
                )
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    selectedGradientIndex == index
                        ? RoundedRectangle(cornerRadius: 10).strokeBorder(.white, lineWidth: 2)
                        : nil
                )
            } else {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: — Photo loading

    private func loadPhoto(from item: PhotosPickerItem?) async {
        guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
        #if canImport(UIKit)
        themeManager.applyBackground(data: data)
        #endif
    }
}

// MARK: - Preview

#Preview {
    BottomCustomisationBar(theme: .midnight)
        .environment(ThemeManager.shared)
        .padding()
}

// MARK: — Glass bar modifier
// Uses .glassEffect() directly — avoids GlassEffectContainer which overrides the fixed frame.

private struct GlassBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.tint(Color.themeAccent.opacity(0.2)), in: RoundedRectangle(cornerRadius: 24))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}
