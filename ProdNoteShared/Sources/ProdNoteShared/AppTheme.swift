import SwiftUI

// MARK: - AppTheme
// Central theme struct. Every color, font, and spacing token lives here.
// Add a new theme = add one static let. All views update automatically.

public struct AppTheme: Equatable, Hashable, Identifiable {

    public let id: String
    public let name: String
    public let subtitle: String
    public let tag: String
    public let isPaid: Bool

    // MARK: — Background
    public let meshColors: [Color]
    public let backgroundStyle: BackgroundStyle

    // MARK: — Surface colors
    public let screenBackground: Color
    public let surfaceBackground: Color
    public let editorBackground: Color

    // MARK: — Text colors
    public let primaryText: Color
    public let secondaryText: Color
    public let placeholderText: Color

    // MARK: — Accent
    public let accentColor: Color
    public let linkColor: Color
    public let quoteBarColor: Color

    // MARK: — Priority
    public let priorityHigh: Color
    public let priorityMedium: Color

    // MARK: — Components
    public let fabBackground: Color
    public let fabIcon: Color
    public let separatorColor: Color
    public let checkboxActive: Color
    public let checkboxInactive: Color

    // MARK: — Preferred color scheme
    public let preferredScheme: ColorScheme?

    // MARK: — Custom mesh point positions (optional)
    public let meshPoints: [SIMD2<Float>]?

    public init(
        id: String, name: String, subtitle: String, tag: String, isPaid: Bool,
        meshColors: [Color], backgroundStyle: BackgroundStyle,
        screenBackground: Color, surfaceBackground: Color, editorBackground: Color,
        primaryText: Color, secondaryText: Color, placeholderText: Color,
        accentColor: Color, linkColor: Color, quoteBarColor: Color,
        priorityHigh: Color, priorityMedium: Color,
        fabBackground: Color, fabIcon: Color,
        separatorColor: Color, checkboxActive: Color, checkboxInactive: Color,
        preferredScheme: ColorScheme?,
        meshPoints: [SIMD2<Float>]? = nil
    ) {
        self.id = id; self.name = name; self.subtitle = subtitle
        self.tag = tag; self.isPaid = isPaid
        self.meshColors = meshColors; self.backgroundStyle = backgroundStyle
        self.screenBackground = screenBackground; self.surfaceBackground = surfaceBackground
        self.editorBackground = editorBackground
        self.primaryText = primaryText; self.secondaryText = secondaryText
        self.placeholderText = placeholderText
        self.accentColor = accentColor; self.linkColor = linkColor
        self.quoteBarColor = quoteBarColor
        self.priorityHigh = priorityHigh; self.priorityMedium = priorityMedium
        self.fabBackground = fabBackground; self.fabIcon = fabIcon
        self.separatorColor = separatorColor
        self.checkboxActive = checkboxActive; self.checkboxInactive = checkboxInactive
        self.preferredScheme = preferredScheme
        self.meshPoints = meshPoints
    }

    public var backgroundIsDark: Bool { preferredScheme != .light }

    /// Returns the StoreKit product ID for paid themes.
    /// Free themes return nil. MeshingKit themes map to com.prodnote.theme.<name>.
    public var productId: String? {
        guard isPaid else { return nil }
        return "com.prodnote.theme.\(id.replacingOccurrences(of: "mk-", with: ""))"
    }

    public enum BackgroundStyle: String, Equatable, Hashable {
        case gradient, color, photo, blur
    }
}

// MARK: - Preset Themes

extension AppTheme {

    // ─────────────────────────────────────────────
    // FREE — Bright Mode
    // ─────────────────────────────────────────────
    public static let defaultLight = AppTheme(
        id: "default",
        name: "Bright Mode",
        subtitle: "Light & clean",
        tag: "Free",
        isPaid: false,
        meshColors: [
            Color(red: 0.969, green: 0.969, blue: 0.961),
            Color(red: 0.950, green: 0.945, blue: 0.930),
            Color(red: 0.980, green: 0.975, blue: 0.965),
            Color(red: 0.940, green: 0.935, blue: 0.920),
            Color(red: 0.960, green: 0.955, blue: 0.945),
            Color(red: 0.970, green: 0.965, blue: 0.950),
            Color(red: 0.950, green: 0.945, blue: 0.930),
            Color(red: 0.975, green: 0.970, blue: 0.960),
            Color(red: 0.965, green: 0.960, blue: 0.948)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(light: Color(red: 0.969, green: 0.969, blue: 0.961),
                                  dark:  Color(red: 0.000, green: 0.000, blue: 0.000)),
        surfaceBackground:  Color(light: Color(red: 0.980, green: 0.980, blue: 0.976),
                                  dark:  Color(red: 0.110, green: 0.110, blue: 0.118)),
        editorBackground:   Color(light: Color(red: 0.980, green: 0.980, blue: 0.976),
                                  dark:  Color(red: 0.110, green: 0.110, blue: 0.118)),
        primaryText:        Color(light: Color(red: 0.110, green: 0.110, blue: 0.118),
                                  dark:  Color(red: 0.965, green: 0.965, blue: 0.973)),
        secondaryText:      Color(light: Color(red: 0.430, green: 0.430, blue: 0.448),
                                  dark:  Color(red: 0.557, green: 0.557, blue: 0.576)),
        placeholderText:    Color(light: Color(red: 0.620, green: 0.620, blue: 0.630),
                                  dark:  Color(red: 0.231, green: 0.231, blue: 0.247)),
        accentColor:        Color(red: 0.000, green: 0.478, blue: 1.000),
        linkColor:          Color(red: 0.000, green: 0.478, blue: 1.000),
        quoteBarColor:      Color(red: 0.000, green: 0.478, blue: 1.000),
        priorityHigh:       Color(red: 0.910, green: 0.251, blue: 0.251),
        priorityMedium:     Color(red: 0.878, green: 0.439, blue: 0.125),
        fabBackground:      Color(light: Color(red: 0.235, green: 0.227, blue: 0.212),
                                  dark:  Color(red: 0.965, green: 0.965, blue: 0.973)),
        fabIcon:            Color(light: .white,
                                  dark:  Color(red: 0.000, green: 0.000, blue: 0.000)),
        separatorColor:     Color(light: Color(red: 0.900, green: 0.900, blue: 0.895),
                                  dark:  Color(red: 0.329, green: 0.329, blue: 0.345)),
        checkboxActive:     Color(red: 0.000, green: 0.478, blue: 1.000),
        checkboxInactive:   Color(light: Color(red: 0.780, green: 0.780, blue: 0.800),
                                  dark:  Color(red: 0.350, green: 0.350, blue: 0.380)),
        preferredScheme:    nil
    )

    // ─────────────────────────────────────────────
    // FREE — Midnight
    // ─────────────────────────────────────────────
    public static let midnight = AppTheme(
        id: "midnight",
        name: "Midnight",
        subtitle: "Deep & focused",
        tag: "Free",
        isPaid: false,
        meshColors: [
            Color(red: 0.098, green: 0.098, blue: 0.102),
            Color(red: 0.120, green: 0.118, blue: 0.130),
            Color(red: 0.090, green: 0.090, blue: 0.098),
            Color(red: 0.130, green: 0.128, blue: 0.140),
            Color(red: 0.110, green: 0.108, blue: 0.120),
            Color(red: 0.100, green: 0.098, blue: 0.110),
            Color(red: 0.115, green: 0.112, blue: 0.125),
            Color(red: 0.095, green: 0.093, blue: 0.105),
            Color(red: 0.105, green: 0.103, blue: 0.115)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.098, green: 0.098, blue: 0.102),
        surfaceBackground:  Color(red: 0.133, green: 0.133, blue: 0.137),
        editorBackground:   Color(red: 0.133, green: 0.133, blue: 0.137),
        primaryText:        Color(red: 0.940, green: 0.940, blue: 0.960),
        secondaryText:      Color(red: 0.620, green: 0.620, blue: 0.650),
        placeholderText:    Color(red: 0.420, green: 0.420, blue: 0.450),
        accentColor:        Color(red: 0.039, green: 0.518, blue: 1.000),
        linkColor:          Color(red: 0.039, green: 0.518, blue: 1.000),
        quoteBarColor:      Color(red: 0.039, green: 0.518, blue: 1.000),
        priorityHigh:       Color(red: 1.000, green: 0.420, blue: 0.420),
        priorityMedium:     Color(red: 1.000, green: 0.604, blue: 0.290),
        fabBackground:      .white,
        fabIcon:            .black,
        separatorColor:     Color(red: 0.200, green: 0.200, blue: 0.210),
        checkboxActive:     Color(red: 0.039, green: 0.518, blue: 1.000),
        checkboxInactive:   Color(red: 0.350, green: 0.350, blue: 0.380),
        preferredScheme:    .dark
    )

    // ══════════════════════════════════════════════
    // MESHINGKIT THEMES — 8 themes
    // Palettes inspired by MeshingKit (MIT) — https://github.com/rryam/MeshingKit
    // ══════════════════════════════════════════════

    // ─────────────────────────────────────────────
    // 1. Mango — Warm amber TL → crimson center → dark maroon BR
    //    Real sunset flow: bright top-left fades into dark bottom-right.
    // ─────────────────────────────────────────────
    public static let mango = AppTheme(
        id: "mk-mango",
        name: "Mango",
        subtitle: "Golden hour glow",
        tag: "Premium",
        isPaid: true,
        meshColors: [
            Color(hex: "B67326"), Color(hex: "AD4D4D"), Color(hex: "86265F"),
            Color(hex: "993A60"), Color(hex: "731438"), Color(hex: "4C0A26"),
            Color(hex: "3A0A1F"), Color(hex: "280A13"), Color(hex: "150808"),
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(hex: "120505"),
        surfaceBackground:  Color(hex: "1E0C0A"),
        editorBackground:   Color(hex: "180808"),
        primaryText:        Color(hex: "FFF0E8"),
        secondaryText:      Color(hex: "CC9988"),
        placeholderText:    Color(hex: "7A4A42"),
        accentColor:        Color(hex: "FF8844"),
        linkColor:          Color(hex: "FF9966"),
        quoteBarColor:      Color(hex: "FF6644"),
        priorityHigh:       Color(hex: "FF4444"),
        priorityMedium:     Color(hex: "FF9944"),
        fabBackground:      Color(hex: "CC4420"),
        fabIcon:            Color(hex: "FFFFFF"),
        separatorColor:     Color(hex: "2E1210"),
        checkboxActive:     Color(hex: "FF8844"),
        checkboxInactive:   Color(hex: "441E1A"),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // 2. Nebula — Deep indigo TL → vivid violet center → fuchsia/pink BR
    //    PURPLE → PINK shift across the grid. Clearly warm-purple.
    // ─────────────────────────────────────────────
    public static let nebula = AppTheme(
        id: "mk-nebula",
        name: "Nebula",
        subtitle: "Cosmic violet",
        tag: "Premium",
        isPaid: true,
        meshColors: [
            Color(hex: "050015"), Color(hex: "1A0050"), Color(hex: "330090"),
            Color(hex: "220040"), Color(hex: "440080"), Color(hex: "7700AA"),
            Color(hex: "880066"), Color(hex: "BB0088"), Color(hex: "CC3399"),
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(hex: "04000A"),
        surfaceBackground:  Color(hex: "0E0020"),
        editorBackground:   Color(hex: "080015"),
        primaryText:        Color(hex: "F0E8FF"),
        secondaryText:      Color(hex: "AA88CC"),
        placeholderText:    Color(hex: "604488"),
        accentColor:        Color(hex: "CC55FF"),
        linkColor:          Color(hex: "AA88FF"),
        quoteBarColor:      Color(hex: "9944CC"),
        priorityHigh:       Color(hex: "FF3377"),
        priorityMedium:     Color(hex: "FF8833"),
        fabBackground:      Color(hex: "8833CC"),
        fabIcon:            Color(hex: "FFFFFF"),
        separatorColor:     Color(hex: "1A003A"),
        checkboxActive:     Color(hex: "CC55FF"),
        checkboxInactive:   Color(hex: "2E0055"),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // 3. Neon — Multi-electric on deep black
    // ─────────────────────────────────────────────
    public static let neon = AppTheme(
        id: "mk-neon",
        name: "Neon",
        subtitle: "Electric city night",
        tag: "Premium",
        isPaid: true,
        meshColors: [
            Color(hex: "FF0080"), Color(hex: "00FF80"), Color(hex: "0080FF"),
            Color(hex: "FF8000"), Color(hex: "8000FF"), Color(hex: "00FFFF"),
            Color(hex: "FF00FF"), Color(hex: "FFFF00"), Color(hex: "80FF80"),
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(hex: "080808"),
        surfaceBackground:  Color(hex: "141414"),
        editorBackground:   Color(hex: "0C0C0C"),
        primaryText:        Color(hex: "F0FFFA"),
        secondaryText:      Color(hex: "99BBAA"),
        placeholderText:    Color(hex: "445550"),
        accentColor:        Color(hex: "00DDCC"),
        linkColor:          Color(hex: "00DDCC"),
        quoteBarColor:      Color(hex: "00DDCC"),
        priorityHigh:       Color(hex: "FF2266"),
        priorityMedium:     Color(hex: "FF8800"),
        fabBackground:      Color(hex: "000000"),
        fabIcon:            Color(hex: "FFFFFF"),
        separatorColor:     Color(hex: "222222"),
        checkboxActive:     Color(hex: "00DDCC"),
        checkboxInactive:   Color(hex: "555555"),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // 4. Galaxy — Pure midnight navy blue, no purple
    //    Distinctly NAVY. Different hue family from Nebula/Twilight.
    // ─────────────────────────────────────────────
    public static let galaxy = AppTheme(
        id: "mk-galaxy",
        name: "Galaxy",
        subtitle: "Midnight navy",
        tag: "Premium",
        isPaid: true,
        meshColors: [
            Color(hex: "020814"), Color(hex: "061428"), Color(hex: "0A2040"),
            Color(hex: "082040"), Color(hex: "102C55"), Color(hex: "1A3870"),
            Color(hex: "183060"), Color(hex: "243880"), Color(hex: "2A4090"),
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(hex: "030A18"),
        surfaceBackground:  Color(hex: "091828"),
        editorBackground:   Color(hex: "060E20"),
        primaryText:        Color(hex: "E8F4FF"),
        secondaryText:      Color(hex: "88AACC"),
        placeholderText:    Color(hex: "3A5C80"),
        accentColor:        Color(hex: "4488EE"),
        linkColor:          Color(hex: "66AAFF"),
        quoteBarColor:      Color(hex: "2266CC"),
        priorityHigh:       Color(hex: "FF4455"),
        priorityMedium:     Color(hex: "FFAA33"),
        fabBackground:      Color(hex: "1A5599"),
        fabIcon:            Color(hex: "FFFFFF"),
        separatorColor:     Color(hex: "101E30"),
        checkboxActive:     Color(hex: "4488EE"),
        checkboxInactive:   Color(hex: "1A3050"),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // 5. Cosmos — Deep ocean teal → slate blue
    // ─────────────────────────────────────────────
    public static let cosmos = AppTheme(
        id: "mk-cosmos",
        name: "Cosmos",
        subtitle: "Teal meets slate",
        tag: "Premium",
        isPaid: true,
        meshColors: [
            Color(hex: "041414"), Color(hex: "082C1C"), Color(hex: "0C2828"),
            Color(hex: "062018"), Color(hex: "0C3C28"), Color(hex: "103038"),
            Color(hex: "081C30"), Color(hex: "0C2840"), Color(hex: "103850"),
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(hex: "030E0C"),
        surfaceBackground:  Color(hex: "081A16"),
        editorBackground:   Color(hex: "061510"),
        primaryText:        Color(hex: "E4FFF5"),
        secondaryText:      Color(hex: "80BBAA"),
        placeholderText:    Color(hex: "406655"),
        accentColor:        Color(hex: "44EEA8"),
        linkColor:          Color(hex: "44AADD"),
        quoteBarColor:      Color(hex: "33BBAA"),
        priorityHigh:       Color(hex: "FF5566"),
        priorityMedium:     Color(hex: "FFAA44"),
        fabBackground:      Color(hex: "229966"),
        fabIcon:            Color(hex: "FFFFFF"),
        separatorColor:     Color(hex: "0D2820"),
        checkboxActive:     Color(hex: "44EEA8"),
        checkboxInactive:   Color(hex: "1A3830"),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // 6. Twilight — Very dark TL fading to medium lavender BR
    //    The FADE is what makes it unique vs Nebula/Galaxy.
    //    TL near-black, BR a rich visible lavender — no white.
    // ─────────────────────────────────────────────
    public static let twilight = AppTheme(
        id: "mk-twilight",
        name: "Twilight",
        subtitle: "Purple into dusk",
        tag: "Premium",
        isPaid: true,
        meshColors: [
            Color(hex: "0C0020"), Color(hex: "180038"), Color(hex: "240055"),
            Color(hex: "1A0038"), Color(hex: "300068"), Color(hex: "440088"),
            Color(hex: "3A00A0"), Color(hex: "6020C0"), Color(hex: "9050D0"),
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(hex: "0A0015"),
        surfaceBackground:  Color(hex: "140025"),
        editorBackground:   Color(hex: "0E001C"),
        primaryText:        Color(hex: "F5EEFF"),
        secondaryText:      Color(hex: "BB99EE"),
        placeholderText:    Color(hex: "6644AA"),
        accentColor:        Color(hex: "BB77FF"),
        linkColor:          Color(hex: "9966EE"),
        quoteBarColor:      Color(hex: "AA55DD"),
        priorityHigh:       Color(hex: "FF3366"),
        priorityMedium:     Color(hex: "FF9944"),
        fabBackground:      Color(hex: "7733BB"),
        fabIcon:            Color(hex: "FFFFFF"),
        separatorColor:     Color(hex: "1E0038"),
        checkboxActive:     Color(hex: "BB77FF"),
        checkboxInactive:   Color(hex: "2E0050"),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // 7. Ember — Deep burnt amber → dark maroon
    // ─────────────────────────────────────────────
    public static let ember = AppTheme(
        id: "mk-ember",
        name: "Ember",
        subtitle: "Harvest warmth",
        tag: "Premium",
        isPaid: true,
        meshColors: [
            Color(hex: "260A00"), Color(hex: "4A1400"), Color(hex: "381008"),
            Color(hex: "340C00"), Color(hex: "6A2000"), Color(hex: "581808"),
            Color(hex: "460E00"), Color(hex: "681C00"), Color(hex: "260800"),
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(hex: "120600"),
        surfaceBackground:  Color(hex: "1E0E04"),
        editorBackground:   Color(hex: "180A02"),
        primaryText:        Color(hex: "FFE8CC"),
        secondaryText:      Color(hex: "CC9966"),
        placeholderText:    Color(hex: "7A5544"),
        accentColor:        Color(hex: "FF8833"),
        linkColor:          Color(hex: "FF9944"),
        quoteBarColor:      Color(hex: "FF6622"),
        priorityHigh:       Color(hex: "FF4422"),
        priorityMedium:     Color(hex: "FF8833"),
        fabBackground:      Color(hex: "CC4400"),
        fabIcon:            Color(hex: "FFFFFF"),
        separatorColor:     Color(hex: "2E1200"),
        checkboxActive:     Color(hex: "FF8833"),
        checkboxInactive:   Color(hex: "442200"),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // 8. Crystal — Deep navy ice → dark indigo (DARK theme)
    //    All dark — no light corners. White text on deep blue surface.
    //    Separator = subtle dark navy line, clearly visible against dark surface.
    // ─────────────────────────────────────────────
    public static let crystal = AppTheme(
        id: "mk-crystal",
        name: "Crystal",
        subtitle: "Arctic ice blue",
        tag: "Premium",
        isPaid: true,
        meshColors: [
            Color(hex: "06101E"), Color(hex: "0C1E38"), Color(hex: "122840"),
            Color(hex: "0A1830"), Color(hex: "163050"), Color(hex: "1E4060"),
            Color(hex: "122240"), Color(hex: "1A3058"), Color(hex: "204870"),
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(hex: "060E1A"),
        surfaceBackground:  Color(hex: "0C1828"),
        editorBackground:   Color(hex: "0A1422"),
        primaryText:        Color(hex: "EAF4FF"),
        secondaryText:      Color(hex: "7AACCC"),
        placeholderText:    Color(hex: "3A6688"),
        accentColor:        Color(hex: "44AAEE"),
        linkColor:          Color(hex: "5599DD"),
        quoteBarColor:      Color(hex: "3388CC"),
        priorityHigh:       Color(hex: "FF4455"),
        priorityMedium:     Color(hex: "FFAA33"),
        fabBackground:      Color(hex: "1A6699"),
        fabIcon:            Color(hex: "FFFFFF"),
        separatorColor:     Color(hex: "142030"),
        checkboxActive:     Color(hex: "44AAEE"),
        checkboxInactive:   Color(hex: "1E3A55"),
        preferredScheme:    .dark
    )

    // MARK: — Gallery order
    public static let all: [AppTheme] = [
        .mango,
        .nebula,
        .neon,
        .galaxy,
        .cosmos,
        .twilight,
        .ember,
        .crystal,
    ]

    public static let free: [AppTheme] = all.filter { !$0.isPaid }
    public static let paid: [AppTheme] = all.filter { $0.isPaid }
}
