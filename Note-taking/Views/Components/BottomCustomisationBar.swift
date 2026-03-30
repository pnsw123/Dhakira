import SwiftUI
import PhotosUI

// MARK: - BottomCustomisationBar
// Four tabs — Color / Gradient / Photo / Blur — letting the user override the theme's
// default background. Uses GlassEffectContainer on iOS 26, ultraThinMaterial on earlier OS.
// Issue #75 — https://github.com/pnsw123/prod-note/issues/75

struct BottomCustomisationBar: View {
    let theme: AppTheme
    @Environment(ThemeManager.self) private var themeManager

    @State private var selectedTab: CustomTab = .color
    @State private var pickerItem: PhotosPickerItem? = nil
    @State private var customColor: Color = .blue
    @State private var selectedGradientIndex: Int = 0

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
        let _ = print("🎨 [THEME-DIAG] BottomCustomisationBar.body START — reading themeManager.current.id: \(themeManager.current.id)")
        VStack(spacing: 16) {
            // Tab content
            tabContent
                .frame(height: 120)
                .padding(.horizontal, 16)

            // Tab selector buttons
            tabSelector
        }
        .padding(.vertical, 16)
        .modifier(GlassContainerModifier())
    }

    // MARK: — Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .color:
            ColorPicker("Background color", selection: $customColor, supportsOpacity: false)
                .onChange(of: customColor) { _, newColor in
                    // Bug 2 fix: wire color selection to ThemeManager
                    themeManager.applyColorOverride(newColor)
                }

        case .gradient:
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
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
                    .font(.headline)
            }
            .onChange(of: pickerItem) { _, item in
                Task { await loadPhoto(from: item) }
            }

        case .blur:
            #if canImport(UIKit)
            if let img = themeManager.backgroundImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 12)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text("No background photo selected")
                    .foregroundStyle(.secondary)
            }
            #else
            Text("No background photo selected")
                .foregroundStyle(.secondary)
            #endif
        }
    }

    // MARK: — Tab buttons

    private var tabSelector: some View {
        HStack(spacing: 24) {
            ForEach(CustomTab.allCases) { tab in
                Button {
                    withAnimation(.spring(duration: 0.25, bounce: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(tab.rawValue)
                            .font(.caption2)
                    }
                    .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: — Gradient presets (MeshGradient iOS 18 / LinearGradient fallback)

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
            // Bug 2 fix: wire gradient selection to ThemeManager
            themeManager.applyGradientOverride(colors)
        } label: {
            if #available(iOS 18, *) {
                MeshGradient(
                    width: 2, height: 2,
                    points: [[0, 0], [1, 0], [0, 1], [1, 1]],
                    colors: colors
                )
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    selectedGradientIndex == index
                        ? RoundedRectangle(cornerRadius: 12).strokeBorder(.white, lineWidth: 2)
                        : nil
                )
            } else {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: — Photo loading
    // WWDC18 #416 — downsampling happens inside ThemeManager.applyBackground(data:)
    // via CGImageSourceCreateThumbnailAtIndex (85% memory savings vs UIImage(data:))
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

// MARK: — iOS 26 glass container availability gate

private struct GlassContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 0) {
                content
            }
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 24))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
    }
}
