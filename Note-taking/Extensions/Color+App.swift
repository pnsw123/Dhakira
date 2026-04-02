import SwiftUI
import UIKit

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
        NamedColor(id: "colorGray",     label: "Gray",   uiColor: UIColor(hex: "#8E8E93"), role: .shared),
        NamedColor(id: "colorOrange",   label: "Orange", uiColor: UIColor(hex: "#FF6A00"), role: .shared),
        NamedColor(id: "colorBlue",     label: "Blue",   uiColor: UIColor(hex: "#0A84FF"), role: .shared),
        NamedColor(id: "colorPurple",   label: "Purple", uiColor: UIColor(hex: "#BF5AF2"), role: .shared),
        NamedColor(id: "colorPink",     label: "Pink",   uiColor: UIColor(hex: "#FF375F"), role: .shared),
        NamedColor(id: "colorBrown",    label: "Brown",  uiColor: UIColor(hex: "#AC8E68"), role: .shared),
        NamedColor(id: "paletteYellow", label: "Yellow", uiColor: UIColor(hex: "#FFCC02"), role: .shared),
        NamedColor(id: "paletteRed",    label: "Red",    uiColor: UIColor(hex: "#FF3B30"), role: .shared),
        NamedColor(id: "paletteTeal",   label: "Teal",   uiColor: UIColor(hex: "#5AC8FA"), role: .shared),
        NamedColor(id: "paletteBlack",  label: "Black",  uiColor: UIColor(hex: "#1C1C1E"), role: .shared),
        NamedColor(id: "paletteWhite",  label: "White",  uiColor: UIColor(hex: "#FFFFFF"), role: .shared),
    ]

    /// Colors for the slash-command editor menu
    static var forEditor: [NamedColor] { all.filter { $0.role != .paletteOnly } }

    /// Main 4 preset swatches for the color palette pill.
    /// Chosen based on accent color frequency across all 16 themes:
    /// Yellow (universal highlight), Teal (9/16 themes), Pink (3/16 themes), Orange (priorityMedium on all themes).
    /// Black + White moved to extra — invisible on dark/light themes respectively.
    static var paletteMain: [NamedColor] {
        [
            NamedColor(id: "paletteBlack",  label: "Black",  uiColor: UIColor(hex: "#1C1C1E"), role: .paletteOnly),
            NamedColor(id: "paletteTeal",   label: "Teal",   uiColor: UIColor(hex: "#5AC8FA"), role: .paletteOnly),
            NamedColor(id: "colorPink",     label: "Pink",   uiColor: UIColor(hex: "#FF375F"), role: .shared),
            NamedColor(id: "paletteYellow", label: "Yellow", uiColor: UIColor(hex: "#FFCC02"), role: .paletteOnly),
        ]
    }

    /// Extra colors behind the rainbow button
    static var paletteExtra: [NamedColor] {
        [
            NamedColor(id: "colorOrange",   label: "Orange", uiColor: UIColor(hex: "#FF6A00"), role: .shared),
            NamedColor(id: "paletteWhite",  label: "White",  uiColor: UIColor(hex: "#FFFFFF"), role: .paletteOnly),
            NamedColor(id: "colorBlue",     label: "Blue",   uiColor: UIColor(hex: "#0A84FF"), role: .shared),
            NamedColor(id: "colorPurple",   label: "Purple", uiColor: UIColor(hex: "#BF5AF2"), role: .shared),
            NamedColor(id: "paletteRed",    label: "Red",    uiColor: UIColor(hex: "#FF3B30"), role: .paletteOnly),
            NamedColor(id: "colorBrown",    label: "Brown",  uiColor: UIColor(hex: "#AC8E68"), role: .shared),
            NamedColor(id: "colorGray",     label: "Gray",   uiColor: UIColor(hex: "#8E8E93"), role: .shared),
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
    // MARK: - Priority colors (adaptive: brighter in dark mode for contrast)
    static let priorityHighColor = Color(
        light: Color(red: 1.000, green: 0.231, blue: 0.188),   // #FF3B30 — iOS system red (matches Delete)
        dark:  Color(red: 1.000, green: 0.271, blue: 0.227)    // #FF4538 — iOS system red dark variant
    )
    static let priorityMediumColor = Color(
        light: Color(red: 0.878, green: 0.439, blue: 0.125),   // #E07020 — deep orange on white
        dark:  Color(red: 1.000, green: 0.604, blue: 0.290)    // #FF9A4A — lighter orange on dark
    )

    static func forPriority(_ priority: String) -> Color {
        switch priority {
        case "high": return .priorityHighColor
        case "medium": return .priorityMediumColor
        default: return .gray
        }
    }

    // MARK: - Theme tokens — forwarded from active ThemeManager
    // Computed vars so every Color.screenBackground call picks up theme changes instantly.
    // Issue #70 — https://github.com/pnsw123/prod-note/issues/70

    /// Main screen background — comes from the active theme
    static var screenBackground: Color  { ThemeManager.shared.current.screenBackground }
    /// Row/card background — comes from the active theme
    static var rowBackground: Color     { ThemeManager.shared.current.surfaceBackground }
    /// Editor/note body background — comes from the active theme
    static var editorBackground: Color  { ThemeManager.shared.current.editorBackground }
    /// Primary text — comes from the active theme
    static var primaryText: Color       { ThemeManager.shared.current.primaryText }
    /// Secondary / subdued text — comes from the active theme
    static var secondaryText: Color     { ThemeManager.shared.current.secondaryText }
    /// Hairline divider — comes from the active theme
    static var separatorColor: Color    { ThemeManager.shared.current.separatorColor }
    /// Unchecked checkbox ring — comes from the active theme
    static var checkboxInactive: Color  { ThemeManager.shared.current.checkboxInactive }
    /// FAB button background — comes from the active theme
    static var fabColor: Color          { ThemeManager.shared.current.fabBackground }
    /// FAB icon color — comes from the active theme
    static var fabIcon: Color           { ThemeManager.shared.current.fabIcon }
    /// Accent / tint color — comes from the active theme
    static var themeAccent: Color       { ThemeManager.shared.current.accentColor }
}

// Color(light:dark:) is now provided by ProdNoteShared package.
