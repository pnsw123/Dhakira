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
    public let meshColors: [Color]          // 9 colors for 3×3 MeshGradient card preview
    public let backgroundStyle: BackgroundStyle

    // MARK: — Surface colors
    public let screenBackground: Color
    public let surfaceBackground: Color     // cards, rows
    public let editorBackground: Color

    // MARK: — Text colors
    public let primaryText: Color
    public let secondaryText: Color
    public let placeholderText: Color

    // MARK: — Accent
    public let accentColor: Color
    public let linkColor: Color
    public let quoteBarColor: Color

    // MARK: — Priority (carried from existing Color+App.swift)
    public let priorityHigh: Color
    public let priorityMedium: Color

    // MARK: — Components
    public let fabBackground: Color
    public let fabIcon: Color
    public let separatorColor: Color
    public let checkboxActive: Color
    public let checkboxInactive: Color

    // MARK: — Preferred color scheme
    public let preferredScheme: ColorScheme?   // nil = follow system

    // MARK: — Custom mesh point positions (optional)
    // 9 SIMD2<Float> values matching the 3×3 grid: TL, TC, TR, ML, MC, MR, BL, BC, BR
    // Each value is [x, y] in normalized [0,1] space. nil = equal 3×3 grid.
    public let meshPoints: [SIMD2<Float>]?

    // MARK: — Initializer (meshPoints defaults to nil — equal grid)
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

    // MARK: — Convenience: true when background is dark (used by mockup to force colorScheme)
    public var backgroundIsDark: Bool { preferredScheme != .light }

    // MARK: — StoreKit product ID (nil for free themes)
    public var productId: String? {
        guard isPaid else { return nil }
        switch id {
        case "nord":         return "com.prodnote.theme.nord"
        case "tokyo-night":  return "com.prodnote.theme.tokyonight"
        case "forest":       return "com.prodnote.theme.forest"
        case "rose":         return "com.prodnote.theme.rose"
        case "void":         return "com.prodnote.theme.void"
        case "ocean":        return "com.prodnote.theme.ocean"
        case "lavender":     return "com.prodnote.theme.lavender"
        case "aurora":       return "com.prodnote.theme.aurora"
        case "neon":         return "com.prodnote.theme.neon"
        case "terracotta":   return "com.prodnote.theme.terracotta"
        case "amethyst":     return "com.prodnote.theme.amethyst"
        case "matrix":       return "com.prodnote.theme.matrix"
        case "midnight-blue": return "com.prodnote.theme.midnightblue"
        case "brat-green":   return "com.prodnote.theme.bratgreen"
        default:             return nil
        }
    }

    public enum BackgroundStyle: String, Equatable, Hashable {
        case gradient, color, photo, blur
    }
}

// MARK: - Preset Themes

extension AppTheme {

    // ─────────────────────────────────────────────
    // FREE — Bright Mode (warm off-white, light default)
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
        // Adaptive: light values from the original warm cream palette,
        // dark values mirror iOS system dark-mode colors for a native feel.
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
        preferredScheme:    .light   // light mesh — must force light mode or text is invisible
    )

    // ─────────────────────────────────────────────
    // FREE — Dark Mode (deep charcoal dark)
    // ─────────────────────────────────────────────
    public static let midnight = AppTheme(
        id: "midnight",
        name: "Dark Mode",
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

    // ─────────────────────────────────────────────
    // PAID — Academia (warm sepia, library warmth)
    // Target: Millennial women, students
    // Adaptive: light = cream/parchment, dark = deep amber/brown
    // ─────────────────────────────────────────────
    // PAID — Nord (arctic blue-grey, Scandinavian)
    // Target: Men, professionals
    // Palette: authentic Nord0–Nord10 polar night + frost blues — zero green
    // ─────────────────────────────────────────────
    public static let nord = AppTheme(
        id: "nord",
        name: "Nord",
        subtitle: "Arctic & minimal",
        tag: "Cool",
        isPaid: true,
        meshColors: [
            Color(red: 0.118, green: 0.137, blue: 0.173),   // Nord1 – deep polar night TL
            Color(red: 0.130, green: 0.158, blue: 0.215),   // dark steel TC (no bright highlight)
            Color(red: 0.160, green: 0.188, blue: 0.235),   // Nord2 – polar night TR
            Color(red: 0.098, green: 0.118, blue: 0.157),   // Nord0 – deepest polar ML
            Color(red: 0.368, green: 0.506, blue: 0.675),   // Nord9 – frost blue focal MC
            Color(red: 0.082, green: 0.098, blue: 0.130),   // very deep polar MR
            Color(red: 0.075, green: 0.090, blue: 0.120),   // darkest corner BL
            Color(red: 0.180, green: 0.230, blue: 0.320),   // medium polar blue BC
            Color(red: 0.070, green: 0.084, blue: 0.112)    // darkest corner BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.118, green: 0.137, blue: 0.173),
        surfaceBackground:  Color(red: 0.160, green: 0.188, blue: 0.235),
        editorBackground:   Color(red: 0.160, green: 0.188, blue: 0.235),
        primaryText:        Color(red: 0.925, green: 0.937, blue: 0.953),
        secondaryText:      Color(red: 0.698, green: 0.733, blue: 0.784),
        placeholderText:    Color(red: 0.506, green: 0.549, blue: 0.608),
        accentColor:        Color(red: 0.533, green: 0.753, blue: 0.816),
        linkColor:          Color(red: 0.404, green: 0.573, blue: 0.749),
        quoteBarColor:      Color(red: 0.533, green: 0.753, blue: 0.816),
        priorityHigh:       Color(red: 0.749, green: 0.380, blue: 0.416),
        priorityMedium:     Color(red: 0.824, green: 0.584, blue: 0.349),
        fabBackground:      Color(red: 0.533, green: 0.753, blue: 0.816),
        fabIcon:            Color(red: 0.118, green: 0.137, blue: 0.173),
        separatorColor:     Color(red: 0.200, green: 0.230, blue: 0.290),
        checkboxActive:     Color(red: 0.533, green: 0.753, blue: 0.816),
        checkboxInactive:   Color(red: 0.315, green: 0.355, blue: 0.435),   // visible arctic-blue ring
        preferredScheme:    .dark,
        meshPoints: [
            [0.00, 0.00], [0.50, 0.00], [1.00, 0.00],
            [0.00, 0.50], [0.70, 0.26], [1.00, 0.50],   // frost focal in upper-right
            [0.00, 1.00], [0.38, 1.00], [1.00, 1.00]
        ]
    )

    // ─────────────────────────────────────────────
    // PAID — Tokyo Night (deep navy, neon accents)
    // Target: Gen Z, creatives
    // ─────────────────────────────────────────────
    public static let tokyoNight = AppTheme(
        id: "tokyo-night",
        name: "Tokyo Night",
        subtitle: "City at 2am",
        tag: "Dark",
        isPaid: true,
        meshColors: [
            Color(red: 0.010, green: 0.010, blue: 0.040),   // void black
            Color(red: 0.060, green: 0.025, blue: 0.160),   // faint neon bleed
            Color(red: 0.010, green: 0.010, blue: 0.030),   // void black
            Color(red: 0.040, green: 0.060, blue: 0.220),   // dark navy-blue left
            Color(red: 0.580, green: 0.120, blue: 0.960),   // vivid electric violet — CENTER
            Color(red: 0.025, green: 0.030, blue: 0.090),   // near-black
            Color(red: 0.020, green: 0.480, blue: 0.900),   // electric cyan-blue bottom
            Color(red: 0.025, green: 0.020, blue: 0.055),   // near-black
            Color(red: 0.005, green: 0.005, blue: 0.020)    // deepest void
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.063, green: 0.075, blue: 0.141),
        surfaceBackground:  Color(red: 0.094, green: 0.110, blue: 0.196),
        editorBackground:   Color(red: 0.094, green: 0.110, blue: 0.196),
        primaryText:        Color(red: 0.784, green: 0.820, blue: 0.918),   // #C8D0EA
        secondaryText:      Color(red: 0.545, green: 0.576, blue: 0.694),
        placeholderText:    Color(red: 0.380, green: 0.408, blue: 0.518),
        accentColor:        Color(red: 0.431, green: 0.302, blue: 0.773),   // neon purple
        linkColor:          Color(red: 0.196, green: 0.376, blue: 0.780),   // electric blue
        quoteBarColor:      Color(red: 0.431, green: 0.302, blue: 0.773),
        priorityHigh:       Color(red: 0.957, green: 0.365, blue: 0.522),   // neon pink
        priorityMedium:     Color(red: 0.988, green: 0.655, blue: 0.184),   // amber
        fabBackground:      Color(red: 0.431, green: 0.302, blue: 0.773),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.125, green: 0.141, blue: 0.251),
        checkboxActive:     Color(red: 0.157, green: 0.843, blue: 0.627),   // teal glow
        checkboxInactive:   Color(red: 0.260, green: 0.280, blue: 0.400),   // visible purple-tinted ring
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Forest (muted greens, earthy)
    // Target: Creatives, nature lovers
    // ─────────────────────────────────────────────
    public static let forest = AppTheme(
        id: "forest",
        name: "Forest",
        subtitle: "Earthy & calm",
        tag: "Dark",
        isPaid: true,
        meshColors: [
            Color(red: 0.022, green: 0.042, blue: 0.018),
            Color(red: 0.048, green: 0.130, blue: 0.030),
            Color(red: 0.025, green: 0.045, blue: 0.020),
            Color(red: 0.042, green: 0.090, blue: 0.032),
            Color(red: 0.148, green: 0.440, blue: 0.082),
            Color(red: 0.280, green: 0.200, blue: 0.048),
            Color(red: 0.018, green: 0.034, blue: 0.015),
            Color(red: 0.240, green: 0.170, blue: 0.040),
            Color(red: 0.020, green: 0.036, blue: 0.018)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.028, green: 0.050, blue: 0.022),
        surfaceBackground:  Color(red: 0.055, green: 0.090, blue: 0.048),
        editorBackground:   Color(red: 0.055, green: 0.090, blue: 0.048),
        primaryText:        Color(red: 0.867, green: 0.886, blue: 0.824),
        secondaryText:      Color(red: 0.580, green: 0.620, blue: 0.510),
        placeholderText:    Color(red: 0.420, green: 0.460, blue: 0.360),
        accentColor:        Color(red: 0.480, green: 0.700, blue: 0.330),
        linkColor:          Color(red: 0.480, green: 0.700, blue: 0.330),
        quoteBarColor:      Color(red: 0.380, green: 0.580, blue: 0.260),
        priorityHigh:       Color(red: 0.820, green: 0.330, blue: 0.220),
        priorityMedium:     Color(red: 1.000, green: 0.600, blue: 0.100),   // system orange
        fabBackground:      Color(red: 0.480, green: 0.700, blue: 0.330),
        fabIcon:            Color(red: 0.100, green: 0.140, blue: 0.100),
        separatorColor:     Color(red: 0.080, green: 0.120, blue: 0.068),
        checkboxActive:     Color(red: 0.480, green: 0.700, blue: 0.330),
        checkboxInactive:   Color(red: 0.280, green: 0.370, blue: 0.255),   // visible dark-green ring
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Sakura (Japanese night sakura — dramatic two-tone)
    // Concept: Ink-black night sky split by vivid cerise blossom + warm gold petal glow
    // Two signature colors: cerise magenta (accent) + rose-gold (secondary)
    // ─────────────────────────────────────────────
    public static let rose = AppTheme(
        id: "rose",
        name: "Sakura",
        subtitle: "Night beneath the blossoms",
        tag: "Pastel",
        isPaid: true,
        meshColors: [
            Color(red: 0.160, green: 0.065, blue: 0.110),   // deep rose shadow TL
            Color(red: 0.280, green: 0.092, blue: 0.165),   // dark fuchsia TC (not bright white)
            Color(red: 0.140, green: 0.055, blue: 0.095),   // deep rose shadow TR
            Color(red: 0.320, green: 0.095, blue: 0.172),   // deep fuchsia ML
            Color(red: 0.920, green: 0.400, blue: 0.580),   // warm sakura focal MC
            Color(red: 0.240, green: 0.076, blue: 0.138),   // deep fuchsia MR
            Color(red: 0.118, green: 0.046, blue: 0.080),   // deep rose shadow BL
            Color(red: 0.720, green: 0.440, blue: 0.320),   // rose-gold glow BC
            Color(red: 0.108, green: 0.042, blue: 0.073)    // deep shadow BR
        ],
        backgroundStyle: .gradient,
        screenBackground:  Color(light: Color(red: 0.992, green: 0.955, blue: 0.970),
                                 dark:  Color(red: 0.045, green: 0.025, blue: 0.090)),  // deep indigo-plum
        surfaceBackground: Color(light: Color(red: 0.998, green: 0.972, blue: 0.982),
                                 dark:  Color(red: 0.075, green: 0.045, blue: 0.140)),  // dark plum
        editorBackground:  Color(light: Color(red: 0.998, green: 0.972, blue: 0.982),
                                 dark:  Color(red: 0.075, green: 0.045, blue: 0.140)),
        primaryText:       Color(light: Color(red: 0.180, green: 0.080, blue: 0.160),
                                 dark:  Color(red: 0.982, green: 0.950, blue: 0.992)),  // moonlight white
        secondaryText:     Color(light: Color(red: 0.520, green: 0.300, blue: 0.360),
                                 dark:  Color(red: 0.820, green: 0.580, blue: 0.480)),  // rose-gold — 2nd color
        placeholderText:   Color(light: Color(red: 0.680, green: 0.500, blue: 0.580),
                                 dark:  Color(red: 0.440, green: 0.280, blue: 0.380)),
        accentColor:       Color(light: Color(red: 0.860, green: 0.180, blue: 0.420),
                                 dark:  Color(red: 0.960, green: 0.200, blue: 0.520)),  // vivid cerise
        linkColor:         Color(light: Color(red: 0.860, green: 0.180, blue: 0.420),
                                 dark:  Color(red: 0.960, green: 0.200, blue: 0.520)),
        quoteBarColor:     Color(light: Color(red: 0.840, green: 0.200, blue: 0.440),
                                 dark:  Color(red: 0.940, green: 0.220, blue: 0.500)),
        priorityHigh:      Color(light: Color(red: 0.880, green: 0.140, blue: 0.320),
                                 dark:  Color(red: 0.980, green: 0.260, blue: 0.480)),
        priorityMedium:    Color(light: Color(red: 0.780, green: 0.400, blue: 0.180),
                                 dark:  Color(red: 0.960, green: 0.580, blue: 0.300)),  // warm gold-orange
        fabBackground:     Color(light: Color(red: 0.860, green: 0.180, blue: 0.420),
                                 dark:  Color(red: 0.960, green: 0.200, blue: 0.520)),
        fabIcon:           .white,
        separatorColor:    Color(light: Color(red: 0.920, green: 0.820, blue: 0.880),
                                 dark:  Color(red: 0.155, green: 0.068, blue: 0.220)),  // deep plum separator
        checkboxActive:    Color(light: Color(red: 0.860, green: 0.180, blue: 0.420),
                                 dark:  Color(red: 0.960, green: 0.200, blue: 0.520)),  // cerise
        checkboxInactive:  Color(light: Color(red: 0.820, green: 0.680, blue: 0.760),
                                 dark:  Color(red: 0.280, green: 0.175, blue: 0.385)),   // visible plum ring
        preferredScheme:   .dark,    // dark mesh — force dark mode for text visibility
        meshPoints: [
            [0.00, 0.00], [0.50, 0.00], [1.00, 0.00],
            [0.00, 0.38], [0.40, 0.26], [1.00, 0.42],   // sakura focal in upper-left area
            [0.00, 1.00], [0.62, 1.00], [1.00, 1.00]
        ]
    )

    // ─────────────────────────────────────────────
    // PAID — Void (pure OLED black, cosmic gold accent)
    // Target: Power users, OLED screens
    // Distinct from Dark Mode: gold star overhead vs blue
    // ─────────────────────────────────────────────
    public static let void = AppTheme(
        id: "void",
        name: "Void",
        subtitle: "Pure black, OLED",
        tag: "Minimal",
        isPaid: true,
        meshColors: [
            Color(red: 0.000, green: 0.000, blue: 0.000),   // absolute black corner
            Color(red: 0.032, green: 0.024, blue: 0.005),   // faint gold warmth top
            Color(red: 0.000, green: 0.000, blue: 0.000),   // absolute black corner
            Color(red: 0.042, green: 0.030, blue: 0.006),   // warm coal glow left
            Color(red: 0.920, green: 0.680, blue: 0.120),   // bright cosmic gold — CENTER
            Color(red: 0.038, green: 0.027, blue: 0.005),   // warm coal glow right
            Color(red: 0.000, green: 0.000, blue: 0.000),   // absolute black corner
            Color(red: 0.018, green: 0.012, blue: 0.002),   // barely warm bottom
            Color(red: 0.000, green: 0.000, blue: 0.000)    // absolute black corner
        ],
        backgroundStyle: .gradient,
        screenBackground:   .black,
        surfaceBackground:  Color(red: 0.060, green: 0.058, blue: 0.052),
        editorBackground:   Color(red: 0.060, green: 0.058, blue: 0.052),
        primaryText:        .white,
        secondaryText:      Color(red: 0.580, green: 0.560, blue: 0.480),
        placeholderText:    Color(red: 0.360, green: 0.350, blue: 0.300),
        accentColor:        Color(red: 0.880, green: 0.640, blue: 0.120),
        linkColor:          Color(red: 0.880, green: 0.640, blue: 0.120),
        quoteBarColor:      Color(red: 0.820, green: 0.580, blue: 0.100),
        priorityHigh:       Color(red: 1.000, green: 0.300, blue: 0.300),
        priorityMedium:     Color(red: 0.960, green: 0.700, blue: 0.180),
        fabBackground:      Color(red: 0.880, green: 0.640, blue: 0.120),
        fabIcon:            .black,
        separatorColor:     Color(red: 0.140, green: 0.130, blue: 0.100),
        checkboxActive:     Color(red: 0.880, green: 0.640, blue: 0.120),
        checkboxInactive:   Color(red: 0.285, green: 0.272, blue: 0.235),   // warm-tinted visible ring
        preferredScheme:    .dark,
        meshPoints: [
            [0.00, 0.00], [0.50, 0.00], [1.00, 0.00],
            [0.00, 0.42], [0.50, 0.20], [1.00, 0.42],   // gold star at upper-center
            [0.00, 1.00], [0.50, 1.00], [1.00, 1.00]
        ]
    )

    // ─────────────────────────────────────────────
    // PAID — Ocean (deep sea blues, teal accents)
    // Target: Everyone — universally calming
    // ─────────────────────────────────────────────
    public static let ocean = AppTheme(
        id: "ocean",
        name: "Ocean",
        subtitle: "Deep & tranquil",
        tag: "Cool",
        isPaid: true,
        meshColors: [
            Color(red: 0.004, green: 0.010, blue: 0.060),   // abyssal navy corner
            Color(red: 0.008, green: 0.035, blue: 0.120),   // deep ocean top
            Color(red: 0.004, green: 0.012, blue: 0.065),   // abyssal navy corner
            Color(red: 0.010, green: 0.060, blue: 0.200),   // deep water blue
            Color(red: 0.020, green: 0.520, blue: 0.760),   // ocean teal — CENTER (teal, not electric blue)
            Color(red: 0.008, green: 0.048, blue: 0.165),   // deep navy
            Color(red: 0.003, green: 0.008, blue: 0.048),   // abyss bottom
            Color(red: 0.008, green: 0.280, blue: 0.480),   // deep teal glow bottom
            Color(red: 0.003, green: 0.006, blue: 0.038)    // abyss corner
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.040, green: 0.080, blue: 0.160),
        surfaceBackground:  Color(red: 0.060, green: 0.110, blue: 0.200),
        editorBackground:   Color(red: 0.060, green: 0.110, blue: 0.200),
        primaryText:        Color(red: 0.880, green: 0.930, blue: 0.960),
        secondaryText:      Color(red: 0.420, green: 0.600, blue: 0.800),  // ocean blue — 2nd color
        placeholderText:    Color(red: 0.300, green: 0.420, blue: 0.560),
        accentColor:        Color(red: 0.180, green: 0.650, blue: 0.860),
        linkColor:          Color(red: 0.180, green: 0.650, blue: 0.860),
        quoteBarColor:      Color(red: 0.140, green: 0.580, blue: 0.800),
        priorityHigh:       Color(red: 1.000, green: 0.400, blue: 0.380),
        priorityMedium:     Color(red: 1.000, green: 0.620, blue: 0.260),
        fabBackground:      Color(red: 0.180, green: 0.650, blue: 0.860),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.060, green: 0.130, blue: 0.280),  // vivid ocean separator
        checkboxActive:     Color(red: 0.120, green: 0.560, blue: 0.960),  // electric blue — distinct from accent
        checkboxInactive:   Color(red: 0.175, green: 0.285, blue: 0.445),   // visible ocean-blue ring
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Lavender (twilight violet — dark dreamy)
    // Concept: Deep violet-black with soft lavender focal bloom — lavender fields at dusk
    // ─────────────────────────────────────────────
    public static let lavender = AppTheme(
        id: "lavender",
        name: "Lavender",
        subtitle: "Twilight & dreamy",
        tag: "Dark",
        isPaid: true,
        meshColors: [
            Color(red: 0.040, green: 0.020, blue: 0.078),   // deep violet black TL
            Color(red: 0.068, green: 0.035, blue: 0.120),   // dark violet TC
            Color(red: 0.035, green: 0.018, blue: 0.065),   // deep violet black TR
            Color(red: 0.055, green: 0.028, blue: 0.098),   // dark indigo ML
            Color(red: 0.580, green: 0.420, blue: 0.860),   // soft lavender focal MC
            Color(red: 0.048, green: 0.024, blue: 0.086),   // dark violet MR
            Color(red: 0.028, green: 0.014, blue: 0.052),   // deep black-purple BL
            Color(red: 0.280, green: 0.165, blue: 0.540),   // deep purple glow BC
            Color(red: 0.024, green: 0.012, blue: 0.048)    // deepest corner BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.048, green: 0.025, blue: 0.092),
        surfaceBackground:  Color(red: 0.075, green: 0.042, blue: 0.140),
        editorBackground:   Color(red: 0.075, green: 0.042, blue: 0.140),
        primaryText:        Color(red: 0.940, green: 0.910, blue: 0.978),
        secondaryText:      Color(red: 0.660, green: 0.500, blue: 0.860),
        placeholderText:    Color(red: 0.380, green: 0.275, blue: 0.520),
        accentColor:        Color(red: 0.680, green: 0.500, blue: 0.930),
        linkColor:          Color(red: 0.680, green: 0.500, blue: 0.930),
        quoteBarColor:      Color(red: 0.660, green: 0.480, blue: 0.900),
        priorityHigh:       Color(red: 0.960, green: 0.380, blue: 0.460),
        priorityMedium:     Color(red: 0.980, green: 0.640, blue: 0.300),
        fabBackground:      Color(red: 0.640, green: 0.460, blue: 0.900),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.120, green: 0.068, blue: 0.220),
        checkboxActive:     Color(red: 0.680, green: 0.500, blue: 0.930),
        checkboxInactive:   Color(red: 0.290, green: 0.195, blue: 0.450),   // visible lavender-purple ring
        preferredScheme:    .dark,
        meshPoints: [
            [0.00, 0.00], [0.50, 0.00], [1.00, 0.00],
            [0.00, 0.42], [0.44, 0.24], [1.00, 0.46],   // lavender focal in upper area
            [0.00, 1.00], [0.55, 1.00], [1.00, 1.00]
        ]
    )

    // ─────────────────────────────────────────────
    // PAID — Aurora (northern lights — horizontal curtain across upper sky)
    // Concept: Void black night sky, vivid green curtain left, deep violet-magenta right.
    // meshPoints push the aurora band into the upper ~30% leaving dark void below.
    // ─────────────────────────────────────────────
    public static let aurora = AppTheme(
        id: "aurora",
        name: "Aurora",
        subtitle: "Northern lights magic",
        tag: "Dark",
        isPaid: true,
        meshColors: [
            Color(red: 0.002, green: 0.004, blue: 0.018),   // void black sky TL
            Color(red: 0.004, green: 0.009, blue: 0.026),   // deep void night sky TC
            Color(red: 0.002, green: 0.004, blue: 0.018),   // void black sky TR
            Color(red: 0.005, green: 0.340, blue: 0.198),   // aurora green-teal left curtain ML
            Color(red: 0.000, green: 0.820, blue: 0.460),   // vivid aurora green peak MC
            Color(red: 0.320, green: 0.055, blue: 0.560),   // deep violet-magenta right curtain MR
            Color(red: 0.002, green: 0.004, blue: 0.016),   // void black ground BL
            Color(red: 0.006, green: 0.018, blue: 0.070),   // very dark indigo horizon BC
            Color(red: 0.002, green: 0.003, blue: 0.014)    // void black ground corner BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.004, green: 0.008, blue: 0.020),
        surfaceBackground:  Color(red: 0.010, green: 0.050, blue: 0.058),
        editorBackground:   Color(red: 0.006, green: 0.026, blue: 0.032),
        primaryText:        Color(red: 0.880, green: 0.980, blue: 0.940),   // crisp aurora-white
        secondaryText:      Color(red: 0.380, green: 0.860, blue: 0.640),   // soft aurora teal — readable
        placeholderText:    Color(red: 0.160, green: 0.280, blue: 0.240),
        accentColor:        Color(red: 0.040, green: 0.920, blue: 0.460),   // iconic aurora green
        linkColor:          Color(red: 0.040, green: 0.920, blue: 0.460),
        quoteBarColor:      Color(red: 0.040, green: 0.880, blue: 0.440),
        priorityHigh:       Color(red: 1.000, green: 0.300, blue: 0.400),
        priorityMedium:     Color(red: 1.000, green: 0.640, blue: 0.260),
        fabBackground:      Color(red: 0.040, green: 0.900, blue: 0.460),
        fabIcon:            Color(red: 0.003, green: 0.008, blue: 0.018),
        separatorColor:     Color(red: 0.015, green: 0.100, blue: 0.080),
        checkboxActive:     Color(red: 0.040, green: 0.920, blue: 0.460),
        checkboxInactive:   Color(red: 0.050, green: 0.260, blue: 0.175),   // visible dark-teal ring
        preferredScheme:    .dark,
        meshPoints: [
            [0.00, 0.00], [0.50, 0.00], [1.00, 0.00],
            [0.00, 0.36], [0.50, 0.26], [1.00, 0.34],   // aurora curtain: wavy drape, upper 1/3
            [0.00, 1.00], [0.50, 1.00], [1.00, 1.00]    // void black from band down to bottom
        ]
    )

    // ─────────────────────────────────────────────
    // PAID — Neon (cyberpunk dark, electric pink + cyan)
    // Target: Gen Z, gamers — bold & unapologetic
    // ─────────────────────────────────────────────
    public static let neon = AppTheme(
        id: "neon",
        name: "Neon",
        subtitle: "Electric & bold",
        tag: "Dark",
        isPaid: true,
        meshColors: [
            Color(red: 0.008, green: 0.005, blue: 0.022),   // void black TL
            Color(red: 0.055, green: 0.018, blue: 0.120),   // dark purple TC
            Color(red: 0.008, green: 0.005, blue: 0.018),   // void black TR
            Color(red: 0.095, green: 0.028, blue: 0.195),   // deep indigo ML
            Color(red: 0.980, green: 0.080, blue: 0.580),   // hot neon pink — CENTER
            Color(red: 0.065, green: 0.020, blue: 0.150),   // deep indigo MR
            Color(red: 0.005, green: 0.004, blue: 0.016),   // void black BL
            Color(red: 0.000, green: 0.820, blue: 0.960),   // electric cyan BC
            Color(red: 0.005, green: 0.004, blue: 0.016)    // void black BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.022, green: 0.015, blue: 0.065),
        surfaceBackground:  Color(red: 0.042, green: 0.030, blue: 0.115),
        editorBackground:   Color(red: 0.042, green: 0.030, blue: 0.115),
        primaryText:        Color(red: 0.960, green: 0.940, blue: 0.980),
        secondaryText:      Color(red: 0.320, green: 0.880, blue: 0.960),
        placeholderText:    Color(red: 0.360, green: 0.320, blue: 0.480),
        accentColor:        Color(red: 0.980, green: 0.200, blue: 0.600),
        linkColor:          Color(red: 0.200, green: 0.860, blue: 0.960),
        quoteBarColor:      Color(red: 0.980, green: 0.200, blue: 0.600),
        priorityHigh:       Color(red: 1.000, green: 0.280, blue: 0.350),
        priorityMedium:     Color(red: 1.000, green: 0.600, blue: 0.200),
        fabBackground:      Color(red: 0.980, green: 0.200, blue: 0.600),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.055, green: 0.042, blue: 0.170),
        checkboxActive:     Color(red: 0.200, green: 0.880, blue: 0.960),
        checkboxInactive:   Color(red: 0.235, green: 0.200, blue: 0.385),   // visible dark-purple ring
        preferredScheme:    .dark,
        meshPoints: [
            [0.00, 0.00], [0.50, 0.00], [1.00, 0.00],
            [0.00, 0.45], [0.62, 0.30], [1.00, 0.48],   // pink focal upper-right
            [0.00, 1.00], [0.26, 1.00], [1.00, 1.00]
        ]
    )

    // ─────────────────────────────────────────────
    // PAID — Terracotta (warm earthy clay)
    // Target: Interior design lovers, earth tones
    // ─────────────────────────────────────────────
    public static let terracotta = AppTheme(
        id: "terracotta",
        name: "Terracotta",
        subtitle: "Earthy & warm",
        tag: "Warm",
        isPaid: true,
        meshColors: [
            Color(red: 0.088, green: 0.048, blue: 0.028),   // dark clay shadow TL
            Color(red: 0.740, green: 0.355, blue: 0.150),   // warm terracotta TC
            Color(red: 0.078, green: 0.042, blue: 0.025),   // shadow TR
            Color(red: 0.500, green: 0.245, blue: 0.118),   // medium clay ML
            Color(red: 0.875, green: 0.470, blue: 0.210),   // bright terracotta focal MC
            Color(red: 0.420, green: 0.205, blue: 0.098),   // burnt sienna MR
            Color(red: 0.065, green: 0.036, blue: 0.022),   // dark clay shadow BL
            Color(red: 0.560, green: 0.310, blue: 0.120),   // warm amber BC
            Color(red: 0.062, green: 0.034, blue: 0.020)    // dark shadow BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.155, green: 0.095, blue: 0.070),
        surfaceBackground:  Color(red: 0.200, green: 0.130, blue: 0.098),
        editorBackground:   Color(red: 0.200, green: 0.130, blue: 0.098),
        primaryText:        Color(red: 0.955, green: 0.910, blue: 0.870),   // warm off-white — must be light on dark clay
        secondaryText:      Color(red: 0.640, green: 0.520, blue: 0.440),
        placeholderText:    Color(red: 0.440, green: 0.360, blue: 0.300),
        accentColor:        Color(red: 0.850, green: 0.480, blue: 0.280),
        linkColor:          Color(red: 0.850, green: 0.480, blue: 0.280),
        quoteBarColor:      Color(red: 0.800, green: 0.440, blue: 0.260),
        priorityHigh:       Color(red: 0.920, green: 0.300, blue: 0.250),
        priorityMedium:     Color(red: 0.940, green: 0.600, blue: 0.220),
        fabBackground:      Color(red: 0.850, green: 0.480, blue: 0.280),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.250, green: 0.165, blue: 0.125),
        checkboxActive:     Color(red: 0.850, green: 0.480, blue: 0.280),
        checkboxInactive:   Color(red: 0.360, green: 0.255, blue: 0.200),   // warm clay ring — visible
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Amethyst (rich purple crystal, luxury)
    // Target: Women, crystal/spiritual aesthetic
    // ─────────────────────────────────────────────
    public static let amethyst = AppTheme(
        id: "amethyst",
        name: "Amethyst",
        subtitle: "Rich & mystical",
        tag: "Dark",
        isPaid: true,
        meshColors: [
            Color(red: 0.055, green: 0.010, blue: 0.060),   // deep wine-black
            Color(red: 0.180, green: 0.040, blue: 0.200),   // dark wine-purple
            Color(red: 0.040, green: 0.010, blue: 0.070),   // near-black plum
            Color(red: 0.220, green: 0.050, blue: 0.260),   // deep amethyst left
            Color(red: 0.580, green: 0.180, blue: 0.820),   // vivid amethyst — CENTER
            Color(red: 0.160, green: 0.040, blue: 0.200),   // dark plum right
            Color(red: 0.040, green: 0.010, blue: 0.055),   // near-black
            Color(red: 0.480, green: 0.200, blue: 0.380),   // rose-gold shimmer
            Color(red: 0.035, green: 0.008, blue: 0.050)    // deepest plum-black
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.060, green: 0.025, blue: 0.145),   // deep vivid crystal purple
        surfaceBackground:  Color(red: 0.095, green: 0.048, blue: 0.200),   // rich amethyst surface
        editorBackground:   Color(red: 0.095, green: 0.048, blue: 0.200),
        primaryText:        Color(red: 0.955, green: 0.920, blue: 0.980),
        secondaryText:      Color(red: 0.780, green: 0.560, blue: 0.960),   // vivid lilac — 2nd color
        placeholderText:    Color(red: 0.420, green: 0.300, blue: 0.540),
        accentColor:        Color(red: 0.660, green: 0.320, blue: 0.920),   // vivid amethyst
        linkColor:          Color(red: 0.660, green: 0.320, blue: 0.920),
        quoteBarColor:      Color(red: 0.620, green: 0.280, blue: 0.860),
        priorityHigh:       Color(red: 1.000, green: 0.360, blue: 0.480),   // rose-pink high
        priorityMedium:     Color(red: 1.000, green: 0.640, blue: 0.280),
        fabBackground:      Color(red: 0.660, green: 0.320, blue: 0.920),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.140, green: 0.080, blue: 0.250),   // vivid purple separator
        checkboxActive:     Color(red: 0.820, green: 0.480, blue: 0.980),   // bright lilac — distinct from accent
        checkboxInactive:   Color(red: 0.290, green: 0.195, blue: 0.450),   // visible amethyst ring
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Matrix (pure black + neon green radial burst)
    // Target: Hacker aesthetic, dark mode power users
    // ─────────────────────────────────────────────
    public static let matrix = AppTheme(
        id: "matrix",
        name: "Matrix",
        subtitle: "Hack the planet",
        tag: "Dark",
        isPaid: true,
        meshColors: [
            // TL      TC      TR  — top row: all near-black void
            Color(red: 0.020, green: 0.031, blue: 0.012),
            Color(red: 0.015, green: 0.025, blue: 0.008),
            Color(red: 0.020, green: 0.031, blue: 0.012),
            // ML      MC      MR  — middle: dark, mid-green transition right
            Color(red: 0.000, green: 0.120, blue: 0.020),   // dark green fade left
            Color(red: 0.000, green: 0.300, blue: 0.055),   // mid green center
            Color(red: 0.015, green: 0.025, blue: 0.008),   // void right
            // BL      BC      BR  — bottom: neon BURST from lower-left
            Color(red: 0.000, green: 1.000, blue: 0.255),   // electric neon BL — SOURCE
            Color(red: 0.000, green: 0.680, blue: 0.140),   // bright green BC
            Color(red: 0.020, green: 0.031, blue: 0.012)    // void BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.020, green: 0.031, blue: 0.012),
        surfaceBackground:  Color(red: 0.025, green: 0.055, blue: 0.025),
        editorBackground:   Color(red: 0.025, green: 0.055, blue: 0.025),
        primaryText:        Color(red: 0.000, green: 1.000, blue: 0.255),  // neon green text
        secondaryText:      Color(red: 0.000, green: 0.700, blue: 0.180),
        placeholderText:    Color(red: 0.000, green: 0.400, blue: 0.100),
        accentColor:        Color(red: 0.000, green: 1.000, blue: 0.255),
        linkColor:          Color(red: 0.000, green: 0.900, blue: 0.200),
        quoteBarColor:      Color(red: 0.000, green: 0.800, blue: 0.150),
        priorityHigh:       Color(red: 1.000, green: 0.200, blue: 0.200),
        priorityMedium:     Color(red: 1.000, green: 0.600, blue: 0.100),   // system orange — not green
        fabBackground:      Color(red: 0.000, green: 0.800, blue: 0.150),
        fabIcon:            Color(red: 0.020, green: 0.031, blue: 0.012),
        separatorColor:     Color(red: 0.000, green: 0.180, blue: 0.035),
        checkboxActive:     Color(red: 0.000, green: 1.000, blue: 0.255),
        checkboxInactive:   Color(red: 0.040, green: 0.310, blue: 0.095),   // visible dark-green ring
        preferredScheme:    .dark,
        meshPoints: [
            [0.00, 0.00], [0.50, 0.00], [1.00, 0.00],
            [0.00, 0.55], [0.40, 0.62], [1.00, 0.55],   // mid row pushed down, left-leaning
            [0.00, 1.00], [0.30, 1.00], [1.00, 1.00]    // BL neon source stays bottom-left
        ]
    )

    // ─────────────────────────────────────────────
    // PAID — Midnight Blue (deep navy, cobalt blobs, premium dark)
    // Target: Professional, premium feel buyers
    // ─────────────────────────────────────────────
    public static let midnightBlue = AppTheme(
        id: "midnight-blue",
        name: "Midnight Blue",
        subtitle: "Deep & premium",
        tag: "Dark",
        isPaid: true,
        meshColors: [
            // TL      TC                                     TR — top: void + cobalt bloom at TC
            Color(red: 0.016, green: 0.024, blue: 0.133),   // void navy TL
            Color(red: 0.220, green: 0.220, blue: 0.780),   // bright cobalt bloom TC — SOURCE
            Color(red: 0.016, green: 0.024, blue: 0.133),   // void navy TR
            // ML      MC                                     MR — middle: fades from bloom
            Color(red: 0.030, green: 0.035, blue: 0.180),   // dark indigo ML
            Color(red: 0.090, green: 0.090, blue: 0.380),   // mid cobalt MC — fading
            Color(red: 0.016, green: 0.024, blue: 0.133),   // void navy MR
            // BL      BC      BR — bottom: all void navy
            Color(red: 0.010, green: 0.015, blue: 0.080),   // near-black BL
            Color(red: 0.016, green: 0.020, blue: 0.100),   // near-black BC
            Color(red: 0.010, green: 0.015, blue: 0.080)    // near-black BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.010, green: 0.015, blue: 0.080),
        surfaceBackground:  Color(red: 0.030, green: 0.035, blue: 0.160),
        editorBackground:   Color(red: 0.030, green: 0.035, blue: 0.160),
        primaryText:        .white,
        secondaryText:      Color(red: 0.600, green: 0.620, blue: 0.860),
        placeholderText:    Color(red: 0.380, green: 0.390, blue: 0.620),
        accentColor:        Color(red: 0.400, green: 0.600, blue: 1.000),
        linkColor:          Color(red: 0.400, green: 0.600, blue: 1.000),
        quoteBarColor:      Color(red: 0.300, green: 0.500, blue: 0.900),
        priorityHigh:       Color(red: 1.000, green: 0.300, blue: 0.400),
        priorityMedium:     Color(red: 0.400, green: 0.700, blue: 1.000),
        fabBackground:      Color(red: 0.400, green: 0.600, blue: 1.000),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.030, green: 0.035, blue: 0.160),
        checkboxActive:     Color(red: 0.400, green: 0.600, blue: 1.000),
        checkboxInactive:   Color(red: 0.175, green: 0.185, blue: 0.410),   // visible cobalt ring
        preferredScheme:    .dark,
        meshPoints: [
            [0.00, 0.00], [0.50, 0.00], [1.00, 0.00],   // top row — TC is the bloom source
            [0.00, 0.45], [0.50, 0.42], [1.00, 0.45],   // mid row pulled up to catch TC bloom
            [0.00, 1.00], [0.50, 1.00], [1.00, 1.00]    // bottom row: all void
        ]
    )

    // ─────────────────────────────────────────────
    // PAID — Brat Green (acid green + black, bold viral aesthetic)
    // Target: Gen Z, trend-chasers, bold personality buyers
    // ─────────────────────────────────────────────
    public static let bratGreen = AppTheme(
        id: "brat-green",
        name: "Brat",
        subtitle: "Loud & proud",
        tag: "Bold",
        isPaid: true,
        meshColors: [
            // TL      TC      TR — top: acid green left, BLACK HOLE at TR
            Color(red: 0.541, green: 0.808, blue: 0.000),   // acid green TL
            Color(red: 0.620, green: 0.860, blue: 0.000),   // bright lime TC
            Color(red: 0.040, green: 0.040, blue: 0.040),   // near-black TR — hole starts
            // ML      MC      MR — mid: green left/center, black right
            Color(red: 0.541, green: 0.808, blue: 0.000),   // acid green ML
            Color(red: 0.480, green: 0.740, blue: 0.000),   // mid green MC
            Color(red: 0.030, green: 0.030, blue: 0.030),   // near-black MR — hole
            // BL      BC      BR — bottom: all acid green
            Color(red: 0.500, green: 0.760, blue: 0.000),   // acid green BL
            Color(red: 0.541, green: 0.808, blue: 0.000),   // acid green BC
            Color(red: 0.400, green: 0.620, blue: 0.000)    // deeper green BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.067, green: 0.067, blue: 0.067),
        surfaceBackground:  Color(red: 0.100, green: 0.140, blue: 0.000),
        editorBackground:   Color(red: 0.100, green: 0.140, blue: 0.000),
        primaryText:        .black,
        secondaryText:      Color(red: 0.100, green: 0.160, blue: 0.000),
        placeholderText:    Color(red: 0.200, green: 0.300, blue: 0.000),
        accentColor:        Color(red: 0.040, green: 0.040, blue: 0.040),   // black accent on green bg
        linkColor:          Color(red: 0.040, green: 0.040, blue: 0.040),
        quoteBarColor:      Color(red: 0.040, green: 0.040, blue: 0.040),
        priorityHigh:       Color(red: 1.000, green: 0.200, blue: 0.400),
        priorityMedium:     Color(red: 0.040, green: 0.040, blue: 0.040),
        fabBackground:      Color(red: 0.040, green: 0.040, blue: 0.040),
        fabIcon:            Color(red: 0.541, green: 0.808, blue: 0.000),
        separatorColor:     Color(red: 0.300, green: 0.460, blue: 0.000),
        checkboxActive:     Color(red: 0.040, green: 0.040, blue: 0.040),
        checkboxInactive:   Color(red: 0.300, green: 0.460, blue: 0.000),
        preferredScheme:    .light,   // light mode — acid green bg needs dark text
        meshPoints: [
            [0.00, 0.00], [0.50, 0.00], [1.00, 0.00],
            [0.00, 0.50], [0.45, 0.45], [1.00, 0.50],   // black hole anchored right side
            [0.00, 1.00], [0.50, 1.00], [1.00, 1.00]
        ]
    )

    // MARK: — All themes ordered for display
    public static let all: [AppTheme] = [
        .defaultLight, .midnight,                           // free originals
        .tokyoNight, .nord, .forest,                        // dark essentials
        .rose, .void, .ocean,                               // premium dark
        .lavender,                                          // mood
        .aurora, .neon,                                     // vibe
        .terracotta, .amethyst,                             // earth & crystal
        .matrix, .midnightBlue, .bratGreen                  // hacker · premium · bold
    ]

    public static let free: [AppTheme] = all.filter { !$0.isPaid }
    public static let paid: [AppTheme] = all.filter { $0.isPaid }
}

