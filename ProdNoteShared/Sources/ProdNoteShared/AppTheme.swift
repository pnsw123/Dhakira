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
        case "forest":       return "com.prodnote.theme.forest"
        case "ocean":        return "com.prodnote.theme.ocean"
        case "aurora":       return "com.prodnote.theme.aurora"

        case "midnight-blue": return "com.prodnote.theme.midnightblue"
        case "sakura":       return "com.prodnote.theme.sakura"
        case "arctic":       return "com.prodnote.theme.arctic"
        case "slate":        return "com.prodnote.theme.slate"
        case "mint":         return "com.prodnote.theme.mint"
        case "dusk":         return "com.prodnote.theme.dusk"
        case "crimson":      return "com.prodnote.theme.crimson"
        case "coral":        return "com.prodnote.theme.coral"
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
        preferredScheme:    nil   // follow system dark/light mode natively
    )

    // ─────────────────────────────────────────────
    // PAID — Midnight (deep charcoal dark)
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

    // ─────────────────────────────────────────────
    // PAID — Academia (warm sepia, library warmth)
    // Target: Millennial women, students
    // Adaptive: light = cream/parchment, dark = deep amber/brown
    // ─────────────────────────────────────────────

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
            Color(red: 0.048, green: 0.100, blue: 0.038),   // deep moss green (was brown)
            Color(red: 0.018, green: 0.034, blue: 0.015),
            Color(red: 0.038, green: 0.090, blue: 0.032),   // dark forest green (was golden-brown)
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
            Color(red: 0.010, green: 0.200, blue: 0.320),   // deep blue-teal curtain ML
            Color(red: 0.030, green: 0.620, blue: 0.680),   // vivid cyan-teal peak MC
            Color(red: 0.320, green: 0.055, blue: 0.560),   // deep violet-magenta right curtain MR
            Color(red: 0.002, green: 0.004, blue: 0.016),   // void black ground BL
            Color(red: 0.006, green: 0.018, blue: 0.070),   // very dark indigo horizon BC
            Color(red: 0.002, green: 0.003, blue: 0.014)    // void black ground corner BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.004, green: 0.010, blue: 0.025),
        surfaceBackground:  Color(red: 0.008, green: 0.040, blue: 0.068),
        editorBackground:   Color(red: 0.006, green: 0.026, blue: 0.042),
        primaryText:        Color(red: 0.880, green: 0.968, blue: 0.980),   // crisp aurora-white with blue tint
        secondaryText:      Color(red: 0.300, green: 0.780, blue: 0.880),   // soft cyan — readable
        placeholderText:    Color(red: 0.140, green: 0.250, blue: 0.300),
        accentColor:        Color(red: 0.040, green: 0.720, blue: 0.860),   // cyan-teal accent
        linkColor:          Color(red: 0.040, green: 0.720, blue: 0.860),
        quoteBarColor:      Color(red: 0.040, green: 0.680, blue: 0.820),
        priorityHigh:       Color(red: 1.000, green: 0.300, blue: 0.400),
        priorityMedium:     Color(red: 1.000, green: 0.640, blue: 0.260),
        fabBackground:      Color(red: 0.040, green: 0.700, blue: 0.840),
        fabIcon:            Color(red: 0.003, green: 0.008, blue: 0.020),
        separatorColor:     Color(red: 0.020, green: 0.100, blue: 0.140),   // muted dark-cyan separator
        checkboxActive:     Color(red: 0.040, green: 0.720, blue: 0.860),
        checkboxInactive:   Color(red: 0.040, green: 0.200, blue: 0.280),   // visible dark-teal ring
        preferredScheme:    .dark,
        meshPoints: [
            [0.00, 0.00], [0.50, 0.00], [1.00, 0.00],
            [0.00, 0.36], [0.50, 0.26], [1.00, 0.34],   // aurora curtain: wavy drape, upper 1/3
            [0.00, 1.00], [0.50, 1.00], [1.00, 1.00]    // void black from band down to bottom
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
    // PAID — Sakura (rich cherry blossom, warm dreamy pink)
    // Target: feminine, journaling crowd — luxurious rose-gold feel
    // ─────────────────────────────────────────────
    public static let sakura = AppTheme(
        id: "sakura",
        name: "Sakura",
        subtitle: "Cherry blossom dreams",
        tag: "Soft",
        isPaid: true,
        meshColors: [
            Color(red: 1.000, green: 0.718, blue: 0.773),   // #FFB7C5 warm sakura pink TL
            Color(red: 0.910, green: 0.628, blue: 0.749),   // #E8A0BF rose-gold TC
            Color(red: 1.000, green: 0.761, blue: 0.820),   // #FFC2D1 soft petal pink TR
            Color(red: 0.910, green: 0.628, blue: 0.749),   // rose-gold ML
            Color(red: 1.000, green: 0.820, blue: 0.860),   // soft pink center MC (was near-white)
            Color(red: 1.000, green: 0.718, blue: 0.773),   // warm pink MR
            Color(red: 1.000, green: 0.761, blue: 0.820),   // petal pink BL
            Color(red: 1.000, green: 0.800, blue: 0.840),   // soft pink blush BC (was near-white)
            Color(red: 0.940, green: 0.680, blue: 0.780)    // deeper rose-gold BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 1.000, green: 0.960, blue: 0.969),   // #FFF5F7
        surfaceBackground:  Color(red: 1.000, green: 0.975, blue: 0.982),   // creamy pink-white
        editorBackground:   Color(red: 1.000, green: 0.968, blue: 0.976),
        primaryText:        Color(red: 0.220, green: 0.120, blue: 0.160),
        secondaryText:      Color(red: 0.420, green: 0.300, blue: 0.350),
        placeholderText:    Color(red: 0.620, green: 0.500, blue: 0.550),
        accentColor:        Color(red: 0.880, green: 0.380, blue: 0.520),   // warm rose-pink
        linkColor:          Color(red: 0.820, green: 0.340, blue: 0.480),
        quoteBarColor:      Color(red: 0.910, green: 0.500, blue: 0.600),
        priorityHigh:       Color(red: 0.900, green: 0.250, blue: 0.350),
        priorityMedium:     Color(red: 0.900, green: 0.600, blue: 0.300),
        fabBackground:      Color(red: 0.880, green: 0.380, blue: 0.520),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.900, green: 0.780, blue: 0.820),   // soft rose-pink separator
        checkboxActive:     Color(red: 0.880, green: 0.380, blue: 0.520),
        checkboxInactive:   .white,
        preferredScheme:    .light,
        meshPoints: [
            [0.00, 0.00], [0.50, 0.00], [1.00, 0.00],
            [0.00, 0.45], [0.48, 0.40], [1.00, 0.50],   // creamy center slightly above mid
            [0.00, 1.00], [0.50, 1.00], [1.00, 1.00]
        ]
    )

    // ─────────────────────────────────────────────
    // PAID — Arctic (icy white-blue, crisp and cold)
    // Target: minimalists
    // ─────────────────────────────────────────────
    public static let arctic = AppTheme(
        id: "arctic",
        name: "Arctic",
        subtitle: "Crystal clear ice",
        tag: "Crisp",
        isPaid: true,
        meshColors: [
            Color(red: 0.920, green: 0.960, blue: 1.000),   // ice white TL
            Color(red: 0.850, green: 0.920, blue: 0.980),   // pale blue TC
            Color(red: 0.940, green: 0.970, blue: 1.000),   // near-white TR
            Color(red: 0.800, green: 0.880, blue: 0.960),   // light blue ML
            Color(red: 0.700, green: 0.820, blue: 0.940),   // medium ice MC
            Color(red: 0.850, green: 0.910, blue: 0.970),   // soft blue MR
            Color(red: 0.930, green: 0.960, blue: 0.990),   // ice white BL
            Color(red: 0.780, green: 0.870, blue: 0.950),   // blue tint BC
            Color(red: 0.900, green: 0.940, blue: 0.980)    // pale ice BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.955, green: 0.970, blue: 0.990),
        surfaceBackground:  Color(red: 0.980, green: 0.988, blue: 1.000),
        editorBackground:   Color(red: 0.965, green: 0.978, blue: 0.995),
        primaryText:        Color(red: 0.120, green: 0.160, blue: 0.220),
        secondaryText:      Color(red: 0.350, green: 0.400, blue: 0.480),
        placeholderText:    Color(red: 0.550, green: 0.600, blue: 0.670),
        accentColor:        Color(red: 0.200, green: 0.500, blue: 0.850),
        linkColor:          Color(red: 0.150, green: 0.450, blue: 0.800),
        quoteBarColor:      Color(red: 0.350, green: 0.600, blue: 0.900),
        priorityHigh:       Color(red: 0.850, green: 0.200, blue: 0.250),
        priorityMedium:     Color(red: 0.850, green: 0.600, blue: 0.200),
        fabBackground:      Color(red: 0.200, green: 0.500, blue: 0.850),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.850, green: 0.890, blue: 0.930),
        checkboxActive:     Color(red: 0.200, green: 0.500, blue: 0.850),
        checkboxInactive:   Color(red: 0.750, green: 0.800, blue: 0.850),
        preferredScheme:    .light
    )

    // ─────────────────────────────────────────────
    // PAID — Slate (neutral dark gray with blue undertones)
    // Target: professionals, no-nonsense
    // ─────────────────────────────────────────────
    public static let slate = AppTheme(
        id: "slate",
        name: "Slate",
        subtitle: "Clean & professional",
        tag: "Pro",
        isPaid: true,
        meshColors: [
            Color(red: 0.120, green: 0.135, blue: 0.160),   // dark slate TL
            Color(red: 0.140, green: 0.155, blue: 0.185),   // blue-gray TC
            Color(red: 0.100, green: 0.115, blue: 0.140),   // darker TR
            Color(red: 0.150, green: 0.168, blue: 0.200),   // medium slate ML
            Color(red: 0.200, green: 0.225, blue: 0.270),   // lighter center MC
            Color(red: 0.130, green: 0.145, blue: 0.175),   // dark slate MR
            Color(red: 0.090, green: 0.100, blue: 0.125),   // deep slate BL
            Color(red: 0.160, green: 0.178, blue: 0.210),   // blue-gray BC
            Color(red: 0.110, green: 0.125, blue: 0.150)    // dark slate BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.095, green: 0.105, blue: 0.130),
        surfaceBackground:  Color(red: 0.135, green: 0.150, blue: 0.178),
        editorBackground:   Color(red: 0.115, green: 0.128, blue: 0.155),
        primaryText:        Color(red: 0.920, green: 0.930, blue: 0.950),
        secondaryText:      Color(red: 0.580, green: 0.610, blue: 0.660),
        placeholderText:    Color(red: 0.400, green: 0.430, blue: 0.475),
        accentColor:        Color(red: 0.400, green: 0.560, blue: 0.800),
        linkColor:          Color(red: 0.450, green: 0.600, blue: 0.850),
        quoteBarColor:      Color(red: 0.350, green: 0.500, blue: 0.750),
        priorityHigh:       Color(red: 0.900, green: 0.300, blue: 0.300),
        priorityMedium:     Color(red: 0.880, green: 0.650, blue: 0.250),
        fabBackground:      Color(red: 0.400, green: 0.560, blue: 0.800),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.180, green: 0.200, blue: 0.235),
        checkboxActive:     Color(red: 0.400, green: 0.560, blue: 0.800),
        checkboxInactive:   Color(red: 0.250, green: 0.275, blue: 0.320),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Mint (fresh green-teal on dark)
    // Target: wellness/health crowd
    // ─────────────────────────────────────────────
    public static let mint = AppTheme(
        id: "mint",
        name: "Mint",
        subtitle: "Fresh & calming",
        tag: "Fresh",
        isPaid: true,
        meshColors: [
            Color(red: 0.040, green: 0.080, blue: 0.075),   // dark teal TL
            Color(red: 0.060, green: 0.110, blue: 0.100),   // teal TC
            Color(red: 0.035, green: 0.070, blue: 0.068),   // near-black TR
            Color(red: 0.070, green: 0.130, blue: 0.120),   // medium teal ML
            Color(red: 0.075, green: 0.255, blue: 0.225),   // muted mint MC — reduced from 0.8 to avoid spotlight effect
            Color(red: 0.055, green: 0.105, blue: 0.095),   // dark teal MR
            Color(red: 0.030, green: 0.065, blue: 0.060),   // deep dark BL
            Color(red: 0.100, green: 0.200, blue: 0.180),   // muted mint BC
            Color(red: 0.040, green: 0.080, blue: 0.075)    // dark teal BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.035, green: 0.068, blue: 0.065),
        surfaceBackground:  Color(red: 0.065, green: 0.105, blue: 0.098),
        editorBackground:   Color(red: 0.050, green: 0.088, blue: 0.082),
        primaryText:        Color(red: 0.910, green: 0.970, blue: 0.960),
        secondaryText:      Color(red: 0.550, green: 0.680, blue: 0.660),
        placeholderText:    Color(red: 0.350, green: 0.460, blue: 0.440),
        accentColor:        Color(red: 0.300, green: 0.800, blue: 0.700),
        linkColor:          Color(red: 0.250, green: 0.750, blue: 0.680),
        quoteBarColor:      Color(red: 0.300, green: 0.800, blue: 0.700),
        priorityHigh:       Color(red: 0.950, green: 0.300, blue: 0.350),
        priorityMedium:     Color(red: 0.900, green: 0.680, blue: 0.250),
        fabBackground:      Color(red: 0.300, green: 0.800, blue: 0.700),
        fabIcon:            Color(red: 0.035, green: 0.068, blue: 0.065),
        separatorColor:     Color(red: 0.090, green: 0.150, blue: 0.140),
        checkboxActive:     Color(red: 0.300, green: 0.800, blue: 0.700),
        checkboxInactive:   Color(red: 0.150, green: 0.240, blue: 0.220),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Dusk (twilight blue-to-pink horizon)
    // Target: dreamers, aesthetic crowd
    // ─────────────────────────────────────────────
    public static let dusk = AppTheme(
        id: "dusk",
        name: "Dusk",
        subtitle: "Twilight horizon",
        tag: "Dreamy",
        isPaid: true,
        meshColors: [
            Color(red: 0.120, green: 0.080, blue: 0.200),   // deep indigo TL
            Color(red: 0.160, green: 0.100, blue: 0.240),   // purple TC
            Color(red: 0.200, green: 0.100, blue: 0.220),   // violet TR
            Color(red: 0.180, green: 0.100, blue: 0.260),   // rich purple ML
            Color(red: 0.350, green: 0.180, blue: 0.350),   // mauve MC
            Color(red: 0.280, green: 0.140, blue: 0.300),   // twilight MR
            Color(red: 0.500, green: 0.250, blue: 0.350),   // warm pink BL
            Color(red: 0.600, green: 0.300, blue: 0.380),   // rose BC
            Color(red: 0.450, green: 0.220, blue: 0.320)    // dusty rose BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.080, green: 0.055, blue: 0.130),
        surfaceBackground:  Color(red: 0.120, green: 0.085, blue: 0.170),
        editorBackground:   Color(red: 0.100, green: 0.070, blue: 0.150),
        primaryText:        Color(red: 0.950, green: 0.920, blue: 0.960),
        secondaryText:      Color(red: 0.650, green: 0.580, blue: 0.700),
        placeholderText:    Color(red: 0.440, green: 0.380, blue: 0.500),
        accentColor:        Color(red: 0.700, green: 0.400, blue: 0.750),
        linkColor:          Color(red: 0.750, green: 0.450, blue: 0.800),
        quoteBarColor:      Color(red: 0.600, green: 0.350, blue: 0.650),
        priorityHigh:       Color(red: 0.950, green: 0.300, blue: 0.380),
        priorityMedium:     Color(red: 0.900, green: 0.650, blue: 0.300),
        fabBackground:      Color(red: 0.700, green: 0.400, blue: 0.750),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.150, green: 0.105, blue: 0.185),   // muted twilight blue-pink separator
        checkboxActive:     Color(red: 0.700, green: 0.400, blue: 0.750),
        checkboxInactive:   Color(red: 0.250, green: 0.200, blue: 0.300),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Crimson (deep wine red, moody)
    // Target: bold personality
    // ─────────────────────────────────────────────
    public static let crimson = AppTheme(
        id: "crimson",
        name: "Crimson",
        subtitle: "Velvet wine cellar",
        tag: "Bold",
        isPaid: true,
        meshColors: [
            Color(red: 0.045, green: 0.008, blue: 0.018),   // deepest blood-black TL
            Color(red: 0.080, green: 0.015, blue: 0.030),   // dark burgundy TC
            Color(red: 0.035, green: 0.006, blue: 0.015),   // near-black wine TR
            Color(red: 0.120, green: 0.025, blue: 0.045),   // deep wine ML
            Color(red: 0.420, green: 0.050, blue: 0.090),   // rich burgundy focal MC
            Color(red: 0.055, green: 0.010, blue: 0.025),   // dark blood shadow MR
            Color(red: 0.030, green: 0.005, blue: 0.012),   // deepest corner BL
            Color(red: 0.280, green: 0.080, blue: 0.065),   // subtle warm wine highlight BC
            Color(red: 0.040, green: 0.008, blue: 0.016)    // deep blood-black BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.070, green: 0.020, blue: 0.030),
        surfaceBackground:  Color(red: 0.110, green: 0.038, blue: 0.052),
        editorBackground:   Color(red: 0.090, green: 0.028, blue: 0.042),
        primaryText:        Color(red: 0.960, green: 0.920, blue: 0.925),
        secondaryText:      Color(red: 0.650, green: 0.520, blue: 0.540),
        placeholderText:    Color(red: 0.440, green: 0.340, blue: 0.360),
        accentColor:        Color(red: 0.800, green: 0.150, blue: 0.200),
        linkColor:          Color(red: 0.850, green: 0.250, blue: 0.300),
        quoteBarColor:      Color(red: 0.700, green: 0.120, blue: 0.170),
        priorityHigh:       Color(red: 1.000, green: 0.300, blue: 0.300),
        priorityMedium:     Color(red: 0.900, green: 0.600, blue: 0.200),
        fabBackground:      Color(red: 0.800, green: 0.150, blue: 0.200),
        fabIcon:            Color(red: 0.960, green: 0.920, blue: 0.925),
        separatorColor:     Color(red: 0.165, green: 0.055, blue: 0.072),
        checkboxActive:     Color(red: 0.800, green: 0.150, blue: 0.200),
        checkboxInactive:   Color(red: 0.250, green: 0.100, blue: 0.120),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Coral (vibrant coral-to-peach, warm light theme)
    // Target: energetic, social
    // ─────────────────────────────────────────────
    public static let coral = AppTheme(
        id: "coral",
        name: "Coral",
        subtitle: "Warm terracotta glow",
        tag: "Warm",
        isPaid: true,
        meshColors: [
            Color(red: 0.048, green: 0.015, blue: 0.010),   // deep terracotta-black TL
            Color(red: 0.080, green: 0.025, blue: 0.015),   // dark burnt coral TC
            Color(red: 0.035, green: 0.010, blue: 0.008),   // near-black TR
            Color(red: 0.120, green: 0.035, blue: 0.020),   // deep coral ML
            Color(red: 0.520, green: 0.155, blue: 0.088),   // rich terracotta focal MC
            Color(red: 0.055, green: 0.018, blue: 0.010),   // dark shadow MR
            Color(red: 0.028, green: 0.008, blue: 0.006),   // near-black BL
            Color(red: 0.260, green: 0.085, blue: 0.050),   // warm coral glow BC
            Color(red: 0.035, green: 0.012, blue: 0.008)    // deep coral-black BR
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.055, green: 0.018, blue: 0.010),
        surfaceBackground:  Color(red: 0.085, green: 0.030, blue: 0.018),
        editorBackground:   Color(red: 0.070, green: 0.022, blue: 0.012),
        primaryText:        Color(red: 0.960, green: 0.920, blue: 0.900),
        secondaryText:      Color(red: 0.680, green: 0.500, blue: 0.460),
        placeholderText:    Color(red: 0.460, green: 0.320, blue: 0.280),
        accentColor:        Color(red: 0.920, green: 0.380, blue: 0.240),
        linkColor:          Color(red: 0.880, green: 0.340, blue: 0.200),
        quoteBarColor:      Color(red: 0.800, green: 0.300, blue: 0.180),
        priorityHigh:       Color(red: 1.000, green: 0.300, blue: 0.280),
        priorityMedium:     Color(red: 0.920, green: 0.620, blue: 0.200),
        fabBackground:      Color(red: 0.920, green: 0.380, blue: 0.240),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.110, green: 0.040, blue: 0.025),
        checkboxActive:     Color(red: 0.920, green: 0.380, blue: 0.240),
        checkboxInactive:   Color(red: 0.300, green: 0.120, blue: 0.080),
        preferredScheme:    .dark
    )

    // MARK: — All themes ordered for display (gallery only — no free defaults)
    // midnight is excluded — it is the automatic free dark-mode theme, not a gallery choice
    public static let all: [AppTheme] = [
        // Anchor
        .slate, .midnightBlue,
        // Hero row — best-looking themes front and center
        .sakura, .aurora, .crimson, .mint, .arctic,
        // Mid tier
        .coral, .dusk,
        // Bottom
        .forest,
    ]

    public static let free: [AppTheme] = all.filter { !$0.isPaid }
    public static let paid: [AppTheme] = all.filter { $0.isPaid }
}

