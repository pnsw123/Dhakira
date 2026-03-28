import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - NamedColor (Issue #51)
// Single source of truth for all named text/highlight colors.
// Adding a new color = 1 line here. It auto-appears in the slash menu + color palette.

struct NamedColor {
    enum Role { case editorOnly, paletteOnly, shared }

    let id: String          // matches SlashCommand.id suffix (e.g. "colorBlue" → "colorBlue")
    let label: String
    let uiColor: UIColor
    let role: Role

    static let all: [NamedColor] = [
        NamedColor(id: "colorGray",   label: "Gray",   uiColor: UIColor(hex: "#8E8E93"), role: .shared),
        NamedColor(id: "colorOrange", label: "Orange", uiColor: UIColor(hex: "#FF6A00"), role: .shared),
        NamedColor(id: "colorBlue",   label: "Blue",   uiColor: UIColor(hex: "#0A84FF"), role: .shared),
        NamedColor(id: "colorPurple", label: "Purple", uiColor: UIColor(hex: "#BF5AF2"), role: .shared),
        NamedColor(id: "colorPink",   label: "Pink",   uiColor: UIColor(hex: "#FF375F"), role: .shared),
        NamedColor(id: "colorBrown",  label: "Brown",  uiColor: UIColor(hex: "#AC8E68"), role: .shared),
        // Palette-only entries
        NamedColor(id: "paletteYellow", label: "Yellow", uiColor: UIColor(hex: "#FFCC02"), role: .paletteOnly),
        NamedColor(id: "paletteRed",    label: "Red",    uiColor: UIColor(hex: "#FF3B30"), role: .paletteOnly),
        NamedColor(id: "paletteGreen",  label: "Green",  uiColor: UIColor(hex: "#34C759"), role: .paletteOnly),
        NamedColor(id: "paletteTeal",   label: "Teal",   uiColor: UIColor(hex: "#5AC8FA"), role: .paletteOnly),
        NamedColor(id: "paletteBlack",  label: "Black",  uiColor: UIColor(hex: "#1C1C1E"), role: .paletteOnly),
        NamedColor(id: "paletteWhite",  label: "White",  uiColor: UIColor(hex: "#FFFFFF"), role: .paletteOnly),
    ]

    /// Colors for the slash-command editor menu
    static var forEditor: [NamedColor] { all.filter { $0.role != .paletteOnly } }

    /// Main 4 preset swatches for the color palette pill (palette-first + shared)
    static var paletteMain: [NamedColor] {
        [
            NamedColor(id: "paletteYellow", label: "Yellow", uiColor: UIColor(hex: "#FFCC02"), role: .paletteOnly),
            NamedColor(id: "paletteRed",    label: "Red",    uiColor: UIColor(hex: "#FF3B30"), role: .paletteOnly),
            NamedColor(id: "colorBlue",     label: "Blue",   uiColor: UIColor(hex: "#0A84FF"), role: .shared),
            NamedColor(id: "paletteGreen",  label: "Green",  uiColor: UIColor(hex: "#34C759"), role: .paletteOnly),
        ]
    }

    /// Extra 8 colors for the expanded palette row
    static var paletteExtra: [NamedColor] {
        [
            NamedColor(id: "colorOrange",  label: "Orange", uiColor: UIColor(hex: "#FF6A00"), role: .shared),
            NamedColor(id: "colorPink",    label: "Pink",   uiColor: UIColor(hex: "#FF375F"), role: .shared),
            NamedColor(id: "colorPurple",  label: "Purple", uiColor: UIColor(hex: "#BF5AF2"), role: .shared),
            NamedColor(id: "paletteTeal",  label: "Teal",   uiColor: UIColor(hex: "#5AC8FA"), role: .paletteOnly),
            NamedColor(id: "colorBrown",   label: "Brown",  uiColor: UIColor(hex: "#AC8E68"), role: .shared),
            NamedColor(id: "colorGray",    label: "Gray",   uiColor: UIColor(hex: "#8E8E93"), role: .shared),
            NamedColor(id: "paletteBlack", label: "Black",  uiColor: UIColor(hex: "#1C1C1E"), role: .paletteOnly),
            NamedColor(id: "paletteWhite", label: "White",  uiColor: UIColor(hex: "#FFFFFF"), role: .paletteOnly),
        ]
    }

    static func find(id: String) -> NamedColor? { all.first { $0.id == id } }

    /// Find the palette color whose RGB is closest to the given UIColor.
    /// Returns the label (e.g. "Blue") or nil if no match within tolerance.
    static func matchLabel(for color: UIColor) -> String? {
        let allPalette = paletteMain + paletteExtra
        var cr: CGFloat = 0, cg: CGFloat = 0, cb: CGFloat = 0, ca: CGFloat = 0
        color.getRed(&cr, green: &cg, blue: &cb, alpha: &ca)
        var bestName: String?
        var bestDist: CGFloat = .greatestFiniteMagnitude
        for nc in allPalette {
            var pr: CGFloat = 0, pg: CGFloat = 0, pb: CGFloat = 0, pa: CGFloat = 0
            nc.uiColor.getRed(&pr, green: &pg, blue: &pb, alpha: &pa)
            let dist = abs(cr - pr) + abs(cg - pg) + abs(cb - pb)
            if dist < bestDist { bestDist = dist; bestName = nc.label }
        }
        // Tolerance: sum of per-channel differences < 0.08 (~5% per channel)
        return bestDist < 0.08 ? bestName : nil
    }
}

// MARK: - UIColor hex initialiser (shared, single definition)

extension UIColor {
    convenience init(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    // MARK: - Priority colors
    static let priorityHighColor = Color(red: 0.910, green: 0.251, blue: 0.251)    // #E84040
    static let priorityMediumColor = Color(red: 0.878, green: 0.439, blue: 0.125)  // #E07020

    static func forPriority(_ priority: String) -> Color {
        switch priority {
        case "high": return .priorityHighColor
        case "medium": return .priorityMediumColor
        default: return .gray
        }
    }

    // MARK: - Theme tokens (light/dark adaptive)
    /// Main screen background — warm off-white in light mode, deep charcoal in dark mode
    static let screenBackground = Color(
        light: Color(red: 0.969, green: 0.969, blue: 0.961),   // #F7F7F5
        dark:  Color(red: 0.098, green: 0.098, blue: 0.102)    // #191919
    )
    /// Row/card background — slightly lighter than screen in both modes
    static let rowBackground = Color(
        light: Color(red: 0.980, green: 0.980, blue: 0.976),   // #FAFAF9
        dark:  Color(red: 0.133, green: 0.133, blue: 0.137)    // #222223
    )

    /// FAB button background — warm charcoal (light), white (dark)
    static let fabColor = Color(light: Color(red: 0.235, green: 0.227, blue: 0.212),
                                dark: Color.white)

    /// FAB icon color — white (light), black (dark)
    static let fabIcon = Color(light: Color.white, dark: Color.black)
}

// MARK: - Light/dark adaptive color helper
extension Color {
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
        #else
        self = light
        #endif
    }
}
