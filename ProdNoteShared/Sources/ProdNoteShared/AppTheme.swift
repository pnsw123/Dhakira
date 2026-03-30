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

    // MARK: — StoreKit product ID (nil for free themes)
    public var productId: String? {
        guard isPaid else { return nil }
        switch id {
        case "academia":     return "com.prodnote.theme.academia"
        case "nord":         return "com.prodnote.theme.nord"
        case "tokyo-night":  return "com.prodnote.theme.tokyonight"
        case "forest":       return "com.prodnote.theme.forest"
        case "rose":         return "com.prodnote.theme.rose"
        case "void":         return "com.prodnote.theme.void"
        case "ocean":        return "com.prodnote.theme.ocean"
        case "sunset":       return "com.prodnote.theme.sunset"
        case "lavender":     return "com.prodnote.theme.lavender"
        case "mocha":        return "com.prodnote.theme.mocha"
        case "cherry-blossom": return "com.prodnote.theme.cherryblossom"
        case "iced-latte":   return "com.prodnote.theme.icedlatte"
        case "aurora":       return "com.prodnote.theme.aurora"
        case "neon":         return "com.prodnote.theme.neon"
        case "matcha":       return "com.prodnote.theme.matcha"
        case "obsidian":     return "com.prodnote.theme.obsidian"
        case "terracotta":   return "com.prodnote.theme.terracotta"
        case "amethyst":     return "com.prodnote.theme.amethyst"
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
        preferredScheme:    nil
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
    public static let academia = AppTheme(
        id: "academia",
        name: "Academia",
        subtitle: "Warm & scholarly",
        tag: "Warm",
        isPaid: true,
        meshColors: [
            Color(red: 0.200, green: 0.130, blue: 0.060),   // deep dark brown corner
            Color(red: 0.860, green: 0.680, blue: 0.380),   // warm gold mid-top
            Color(red: 0.180, green: 0.110, blue: 0.048),   // deep dark brown corner
            Color(red: 0.750, green: 0.520, blue: 0.220),   // amber left
            Color(red: 0.980, green: 0.860, blue: 0.560),   // bright warm gold focal center
            Color(red: 0.700, green: 0.480, blue: 0.200),   // amber right
            Color(red: 0.190, green: 0.125, blue: 0.052),   // deep dark brown corner
            Color(red: 0.820, green: 0.640, blue: 0.320),   // warm gold mid-bottom
            Color(red: 0.175, green: 0.112, blue: 0.044)    // deep dark brown corner
        ],
        backgroundStyle: .gradient,
        screenBackground:  Color(light: Color(red: 0.965, green: 0.945, blue: 0.900),
                                 dark:  Color(red: 0.145, green: 0.110, blue: 0.072)),
        surfaceBackground: Color(light: Color(red: 0.975, green: 0.960, blue: 0.920),
                                 dark:  Color(red: 0.190, green: 0.152, blue: 0.100)),
        editorBackground:  Color(light: Color(red: 0.975, green: 0.960, blue: 0.920),
                                 dark:  Color(red: 0.190, green: 0.152, blue: 0.100)),
        primaryText:       Color(light: Color(red: 0.220, green: 0.160, blue: 0.090),
                                 dark:  Color(red: 0.918, green: 0.875, blue: 0.780)),
        secondaryText:     Color(light: Color(red: 0.500, green: 0.400, blue: 0.280),
                                 dark:  Color(red: 0.610, green: 0.528, blue: 0.410)),
        placeholderText:   Color(light: Color(red: 0.660, green: 0.580, blue: 0.460),
                                 dark:  Color(red: 0.400, green: 0.345, blue: 0.265)),
        accentColor:       Color(light: Color(red: 0.600, green: 0.340, blue: 0.100),
                                 dark:  Color(red: 0.740, green: 0.490, blue: 0.180)),
        linkColor:         Color(light: Color(red: 0.600, green: 0.340, blue: 0.100),
                                 dark:  Color(red: 0.740, green: 0.490, blue: 0.180)),
        quoteBarColor:     Color(light: Color(red: 0.700, green: 0.450, blue: 0.180),
                                 dark:  Color(red: 0.720, green: 0.480, blue: 0.200)),
        priorityHigh:      Color(light: Color(red: 0.780, green: 0.200, blue: 0.150),
                                 dark:  Color(red: 0.900, green: 0.340, blue: 0.260)),
        priorityMedium:    Color(light: Color(red: 0.820, green: 0.480, blue: 0.100),
                                 dark:  Color(red: 0.920, green: 0.600, blue: 0.200)),
        fabBackground:     Color(light: Color(red: 0.320, green: 0.200, blue: 0.080),
                                 dark:  Color(red: 0.720, green: 0.450, blue: 0.150)),
        fabIcon:           Color(light: Color(red: 0.965, green: 0.945, blue: 0.900),
                                 dark:  Color(red: 0.145, green: 0.110, blue: 0.072)),
        separatorColor:    Color(light: Color(red: 0.850, green: 0.810, blue: 0.750),
                                 dark:  Color(red: 0.260, green: 0.205, blue: 0.140)),
        checkboxActive:    Color(light: Color(red: 0.600, green: 0.340, blue: 0.100),
                                 dark:  Color(red: 0.740, green: 0.490, blue: 0.180)),
        checkboxInactive:  Color(light: Color(red: 0.750, green: 0.680, blue: 0.580),
                                 dark:  Color(red: 0.360, green: 0.290, blue: 0.200)),
        preferredScheme:   nil   // follows system dark / light mode
    )

    // ─────────────────────────────────────────────
    // PAID — Nord (arctic blue-grey, Scandinavian)
    // Target: Men, professionals
    // ─────────────────────────────────────────────
    public static let nord = AppTheme(
        id: "nord",
        name: "Nord",
        subtitle: "Arctic & minimal",
        tag: "Cool",
        isPaid: true,
        meshColors: [
            Color(red: 0.120, green: 0.140, blue: 0.190),   // near-black navy
            Color(red: 0.180, green: 0.210, blue: 0.280),   // dark navy
            Color(red: 0.140, green: 0.160, blue: 0.220),   // dark blue-gray
            Color(red: 0.160, green: 0.200, blue: 0.280),   // dark slate
            Color(red: 0.440, green: 0.740, blue: 0.820),   // vibrant frost focal
            Color(red: 0.320, green: 0.580, blue: 0.740),   // polar blue
            Color(red: 0.120, green: 0.150, blue: 0.210),   // near-black
            Color(red: 0.260, green: 0.440, blue: 0.600),   // medium arctic blue
            Color(red: 0.130, green: 0.155, blue: 0.210)    // dark navy
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.180, green: 0.204, blue: 0.251),
        surfaceBackground:  Color(red: 0.231, green: 0.259, blue: 0.322),
        editorBackground:   Color(red: 0.231, green: 0.259, blue: 0.322),
        primaryText:        Color(red: 0.925, green: 0.937, blue: 0.953),   // #ECEFF4
        secondaryText:      Color(red: 0.698, green: 0.733, blue: 0.784),   // #B2BAC8
        placeholderText:    Color(red: 0.506, green: 0.549, blue: 0.608),
        accentColor:        Color(red: 0.506, green: 0.631, blue: 0.757),   // #81A1C1
        linkColor:          Color(red: 0.404, green: 0.573, blue: 0.749),
        quoteBarColor:      Color(red: 0.557, green: 0.737, blue: 0.773),
        priorityHigh:       Color(red: 0.749, green: 0.380, blue: 0.416),   // #BF616A
        priorityMedium:     Color(red: 0.824, green: 0.584, blue: 0.349),   // #D2955A
        fabBackground:      Color(red: 0.557, green: 0.737, blue: 0.773),
        fabIcon:            Color(red: 0.180, green: 0.204, blue: 0.251),
        separatorColor:     Color(red: 0.263, green: 0.298, blue: 0.369),
        checkboxActive:     Color(red: 0.643, green: 0.773, blue: 0.537),   // #A3C589 — aurora green
        checkboxInactive:   Color(red: 0.298, green: 0.337, blue: 0.416),
        preferredScheme:    .dark
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
            Color(red: 0.030, green: 0.035, blue: 0.080),   // near-black navy
            Color(red: 0.050, green: 0.060, blue: 0.130),   // very dark navy
            Color(red: 0.035, green: 0.042, blue: 0.095),   // dark navy
            Color(red: 0.080, green: 0.090, blue: 0.200),   // dark navy-purple left
            Color(red: 0.420, green: 0.220, blue: 0.820),   // vivid purple — CENTER focal
            Color(red: 0.040, green: 0.050, blue: 0.110),   // near-black
            Color(red: 0.140, green: 0.300, blue: 0.800),   // electric blue accent
            Color(red: 0.035, green: 0.042, blue: 0.095),   // near-black
            Color(red: 0.025, green: 0.030, blue: 0.070)    // deepest black-navy
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
        checkboxInactive:   Color(red: 0.200, green: 0.220, blue: 0.340),
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
            Color(red: 0.072, green: 0.100, blue: 0.072),   // near-black forest
            Color(red: 0.140, green: 0.200, blue: 0.110),   // dark green
            Color(red: 0.085, green: 0.120, blue: 0.085),   // dark forest
            Color(red: 0.110, green: 0.155, blue: 0.095),   // medium dark green left
            Color(red: 0.320, green: 0.420, blue: 0.200),   // bright sage — CENTER focal
            Color(red: 0.440, green: 0.320, blue: 0.180),   // warm brown accent
            Color(red: 0.055, green: 0.075, blue: 0.055),   // very dark green
            Color(red: 0.300, green: 0.230, blue: 0.130),   // warm earthy
            Color(red: 0.070, green: 0.095, blue: 0.065)    // near-black green
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.133, green: 0.180, blue: 0.133),
        surfaceBackground:  Color(red: 0.165, green: 0.220, blue: 0.165),
        editorBackground:   Color(red: 0.165, green: 0.220, blue: 0.165),
        primaryText:        Color(red: 0.867, green: 0.886, blue: 0.824),   // soft off-white
        secondaryText:      Color(red: 0.580, green: 0.620, blue: 0.510),
        placeholderText:    Color(red: 0.420, green: 0.460, blue: 0.360),
        accentColor:        Color(red: 0.525, green: 0.745, blue: 0.380),   // bright moss
        linkColor:          Color(red: 0.525, green: 0.745, blue: 0.380),
        quoteBarColor:      Color(red: 0.400, green: 0.620, blue: 0.280),
        priorityHigh:       Color(red: 0.820, green: 0.330, blue: 0.220),
        priorityMedium:     Color(red: 0.820, green: 0.580, blue: 0.200),
        fabBackground:      Color(red: 0.525, green: 0.745, blue: 0.380),
        fabIcon:            Color(red: 0.133, green: 0.180, blue: 0.133),
        separatorColor:     Color(red: 0.200, green: 0.267, blue: 0.200),
        checkboxActive:     Color(red: 0.525, green: 0.745, blue: 0.380),
        checkboxInactive:   Color(red: 0.280, green: 0.360, blue: 0.260),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Rosé (dusty pink, warm cream)
    // Target: Women 20–35
    // Adaptive: light = blush/cream, dark = deep burgundy/wine
    // ─────────────────────────────────────────────
    public static let rose = AppTheme(
        id: "rose",
        name: "Rosé",
        subtitle: "Soft & romantic",
        tag: "Active",
        isPaid: true,
        meshColors: [
            Color(red: 0.995, green: 0.955, blue: 0.955),   // near-white pink
            Color(red: 0.970, green: 0.860, blue: 0.870),   // light pink
            Color(red: 0.990, green: 0.940, blue: 0.940),   // soft blush
            Color(red: 0.950, green: 0.820, blue: 0.830),   // medium pink left
            Color(red: 0.780, green: 0.480, blue: 0.540),   // vibrant dusty rose — CENTER focal
            Color(red: 0.985, green: 0.950, blue: 0.945),   // warm cream
            Color(red: 0.480, green: 0.260, blue: 0.320),   // deep burgundy-rose (dark)
            Color(red: 0.760, green: 0.560, blue: 0.580),   // medium rose
            Color(red: 0.580, green: 0.360, blue: 0.400)    // dark rose
        ],
        backgroundStyle: .gradient,
        screenBackground:  Color(light: Color(red: 0.980, green: 0.930, blue: 0.930),
                                 dark:  Color(red: 0.182, green: 0.098, blue: 0.118)),
        surfaceBackground: Color(light: Color(red: 0.990, green: 0.950, blue: 0.950),
                                 dark:  Color(red: 0.235, green: 0.130, blue: 0.158)),
        editorBackground:  Color(light: Color(red: 0.990, green: 0.950, blue: 0.950),
                                 dark:  Color(red: 0.235, green: 0.130, blue: 0.158)),
        primaryText:       Color(light: Color(red: 0.280, green: 0.140, blue: 0.160),
                                 dark:  Color(red: 0.958, green: 0.858, blue: 0.878)),
        secondaryText:     Color(light: Color(red: 0.560, green: 0.380, blue: 0.400),
                                 dark:  Color(red: 0.640, green: 0.465, blue: 0.500)),
        placeholderText:   Color(light: Color(red: 0.720, green: 0.560, blue: 0.580),
                                 dark:  Color(red: 0.420, green: 0.305, blue: 0.332)),
        accentColor:       Color(light: Color(red: 0.780, green: 0.340, blue: 0.420),
                                 dark:  Color(red: 0.920, green: 0.525, blue: 0.608)),
        linkColor:         Color(light: Color(red: 0.780, green: 0.340, blue: 0.420),
                                 dark:  Color(red: 0.920, green: 0.525, blue: 0.608)),
        quoteBarColor:     Color(light: Color(red: 0.820, green: 0.440, blue: 0.520),
                                 dark:  Color(red: 0.880, green: 0.500, blue: 0.580)),
        priorityHigh:      Color(light: Color(red: 0.860, green: 0.200, blue: 0.280),
                                 dark:  Color(red: 0.960, green: 0.340, blue: 0.420)),
        priorityMedium:    Color(light: Color(red: 0.880, green: 0.500, blue: 0.200),
                                 dark:  Color(red: 0.960, green: 0.620, blue: 0.280)),
        fabBackground:     Color(red: 0.780, green: 0.340, blue: 0.420),   // same rose in both modes
        fabIcon:           .white,
        separatorColor:    Color(light: Color(red: 0.920, green: 0.840, blue: 0.850),
                                 dark:  Color(red: 0.285, green: 0.162, blue: 0.195)),
        checkboxActive:    Color(light: Color(red: 0.780, green: 0.340, blue: 0.420),
                                 dark:  Color(red: 0.920, green: 0.525, blue: 0.608)),
        checkboxInactive:  Color(light: Color(red: 0.840, green: 0.720, blue: 0.740),
                                 dark:  Color(red: 0.385, green: 0.240, blue: 0.272)),
        preferredScheme:   nil   // follows system dark / light mode
    )

    // ─────────────────────────────────────────────
    // PAID — Void (pure OLED black)
    // Target: Power users, OLED screens
    // ─────────────────────────────────────────────
    public static let void = AppTheme(
        id: "void",
        name: "Void",
        subtitle: "Pure black, OLED",
        tag: "Minimal",
        isPaid: true,
        meshColors: [
            Color(red: 0.000, green: 0.000, blue: 0.000),   // pure black corner
            Color(red: 0.020, green: 0.040, blue: 0.100),   // very dark blue
            Color(red: 0.000, green: 0.000, blue: 0.000),   // pure black corner
            Color(red: 0.010, green: 0.020, blue: 0.060),   // near-black deep blue
            Color(red: 0.039, green: 0.518, blue: 1.000),   // electric blue focal center
            Color(red: 0.008, green: 0.018, blue: 0.055),   // near-black deep blue
            Color(red: 0.000, green: 0.000, blue: 0.000),   // pure black corner
            Color(red: 0.015, green: 0.035, blue: 0.090),   // very dark blue
            Color(red: 0.000, green: 0.000, blue: 0.000)    // pure black corner
        ],
        backgroundStyle: .gradient,
        screenBackground:   .black,
        surfaceBackground:  Color(red: 0.060, green: 0.060, blue: 0.060),
        editorBackground:   Color(red: 0.060, green: 0.060, blue: 0.060),
        primaryText:        .white,
        secondaryText:      Color(red: 0.600, green: 0.600, blue: 0.600),
        placeholderText:    Color(red: 0.380, green: 0.380, blue: 0.380),
        accentColor:        Color(red: 0.039, green: 0.518, blue: 1.000),
        linkColor:          Color(red: 0.039, green: 0.518, blue: 1.000),
        quoteBarColor:      Color(red: 0.039, green: 0.518, blue: 1.000),
        priorityHigh:       Color(red: 1.000, green: 0.300, blue: 0.300),
        priorityMedium:     Color(red: 1.000, green: 0.580, blue: 0.200),
        fabBackground:      Color(red: 0.039, green: 0.518, blue: 1.000),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.120, green: 0.120, blue: 0.120),
        checkboxActive:     Color(red: 0.039, green: 0.518, blue: 1.000),
        checkboxInactive:   Color(red: 0.200, green: 0.200, blue: 0.200),
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
            Color(red: 0.020, green: 0.060, blue: 0.140),
            Color(red: 0.040, green: 0.120, blue: 0.220),
            Color(red: 0.025, green: 0.070, blue: 0.160),
            Color(red: 0.060, green: 0.160, blue: 0.300),
            Color(red: 0.100, green: 0.500, blue: 0.600),   // teal focal
            Color(red: 0.050, green: 0.140, blue: 0.280),
            Color(red: 0.015, green: 0.050, blue: 0.120),
            Color(red: 0.070, green: 0.180, blue: 0.340),
            Color(red: 0.020, green: 0.055, blue: 0.130)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.040, green: 0.080, blue: 0.160),
        surfaceBackground:  Color(red: 0.060, green: 0.110, blue: 0.200),
        editorBackground:   Color(red: 0.060, green: 0.110, blue: 0.200),
        primaryText:        Color(red: 0.880, green: 0.930, blue: 0.960),
        secondaryText:      Color(red: 0.500, green: 0.600, blue: 0.680),
        placeholderText:    Color(red: 0.340, green: 0.430, blue: 0.510),
        accentColor:        Color(red: 0.180, green: 0.650, blue: 0.740),
        linkColor:          Color(red: 0.180, green: 0.650, blue: 0.740),
        quoteBarColor:      Color(red: 0.180, green: 0.650, blue: 0.740),
        priorityHigh:       Color(red: 1.000, green: 0.400, blue: 0.380),
        priorityMedium:     Color(red: 1.000, green: 0.620, blue: 0.260),
        fabBackground:      Color(red: 0.180, green: 0.650, blue: 0.740),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.090, green: 0.150, blue: 0.260),
        checkboxActive:     Color(red: 0.180, green: 0.650, blue: 0.740),
        checkboxInactive:   Color(red: 0.160, green: 0.240, blue: 0.340),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Sunset (golden hour warmth)
    // Target: Creatives, women
    // ─────────────────────────────────────────────
    public static let sunset = AppTheme(
        id: "sunset",
        name: "Sunset",
        subtitle: "Golden hour glow",
        tag: "Warm",
        isPaid: true,
        meshColors: [
            Color(red: 0.160, green: 0.060, blue: 0.100),
            Color(red: 0.400, green: 0.120, blue: 0.160),
            Color(red: 0.180, green: 0.070, blue: 0.110),
            Color(red: 0.600, green: 0.200, blue: 0.180),
            Color(red: 0.950, green: 0.500, blue: 0.200),   // golden focal
            Color(red: 0.500, green: 0.150, blue: 0.200),
            Color(red: 0.140, green: 0.050, blue: 0.090),
            Color(red: 0.700, green: 0.280, blue: 0.220),
            Color(red: 0.120, green: 0.045, blue: 0.080)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.140, green: 0.065, blue: 0.095),
        surfaceBackground:  Color(red: 0.190, green: 0.090, blue: 0.120),
        editorBackground:   Color(red: 0.190, green: 0.090, blue: 0.120),
        primaryText:        Color(red: 0.980, green: 0.920, blue: 0.870),
        secondaryText:      Color(red: 0.680, green: 0.520, blue: 0.460),
        placeholderText:    Color(red: 0.480, green: 0.360, blue: 0.320),
        accentColor:        Color(red: 0.960, green: 0.520, blue: 0.220),
        linkColor:          Color(red: 0.960, green: 0.520, blue: 0.220),
        quoteBarColor:      Color(red: 0.920, green: 0.440, blue: 0.200),
        priorityHigh:       Color(red: 1.000, green: 0.340, blue: 0.300),
        priorityMedium:     Color(red: 1.000, green: 0.650, blue: 0.240),
        fabBackground:      Color(red: 0.960, green: 0.520, blue: 0.220),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.240, green: 0.120, blue: 0.150),
        checkboxActive:     Color(red: 0.960, green: 0.520, blue: 0.220),
        checkboxInactive:   Color(red: 0.300, green: 0.180, blue: 0.180),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Lavender (soft dreamy purple)
    // Target: Women 18–30
    // ─────────────────────────────────────────────
    public static let lavender = AppTheme(
        id: "lavender",
        name: "Lavender",
        subtitle: "Soft & dreamy",
        tag: "Pastel",
        isPaid: true,
        meshColors: [
            Color(red: 0.920, green: 0.890, blue: 0.960),
            Color(red: 0.860, green: 0.810, blue: 0.940),
            Color(red: 0.940, green: 0.910, blue: 0.970),
            Color(red: 0.830, green: 0.770, blue: 0.920),
            Color(red: 0.640, green: 0.520, blue: 0.800),   // rich lavender focal
            Color(red: 0.900, green: 0.870, blue: 0.950),
            Color(red: 0.500, green: 0.380, blue: 0.680),
            Color(red: 0.720, green: 0.640, blue: 0.860),
            Color(red: 0.560, green: 0.440, blue: 0.740)
        ],
        backgroundStyle: .gradient,
        screenBackground:  Color(light: Color(red: 0.950, green: 0.930, blue: 0.975),
                                 dark:  Color(red: 0.120, green: 0.095, blue: 0.170)),
        surfaceBackground: Color(light: Color(red: 0.965, green: 0.950, blue: 0.985),
                                 dark:  Color(red: 0.160, green: 0.130, blue: 0.220)),
        editorBackground:  Color(light: Color(red: 0.965, green: 0.950, blue: 0.985),
                                 dark:  Color(red: 0.160, green: 0.130, blue: 0.220)),
        primaryText:       Color(light: Color(red: 0.200, green: 0.150, blue: 0.300),
                                 dark:  Color(red: 0.900, green: 0.870, blue: 0.960)),
        secondaryText:     Color(light: Color(red: 0.460, green: 0.400, blue: 0.560),
                                 dark:  Color(red: 0.580, green: 0.520, blue: 0.680)),
        placeholderText:   Color(light: Color(red: 0.620, green: 0.570, blue: 0.700),
                                 dark:  Color(red: 0.380, green: 0.330, blue: 0.470)),
        accentColor:       Color(light: Color(red: 0.520, green: 0.360, blue: 0.760),
                                 dark:  Color(red: 0.660, green: 0.500, blue: 0.880)),
        linkColor:         Color(light: Color(red: 0.520, green: 0.360, blue: 0.760),
                                 dark:  Color(red: 0.660, green: 0.500, blue: 0.880)),
        quoteBarColor:     Color(light: Color(red: 0.560, green: 0.400, blue: 0.780),
                                 dark:  Color(red: 0.640, green: 0.480, blue: 0.860)),
        priorityHigh:      Color(light: Color(red: 0.820, green: 0.220, blue: 0.300),
                                 dark:  Color(red: 0.940, green: 0.360, blue: 0.420)),
        priorityMedium:    Color(light: Color(red: 0.860, green: 0.500, blue: 0.180),
                                 dark:  Color(red: 0.960, green: 0.620, blue: 0.280)),
        fabBackground:     Color(red: 0.560, green: 0.380, blue: 0.780),
        fabIcon:           .white,
        separatorColor:    Color(light: Color(red: 0.880, green: 0.850, blue: 0.920),
                                 dark:  Color(red: 0.210, green: 0.175, blue: 0.300)),
        checkboxActive:    Color(light: Color(red: 0.520, green: 0.360, blue: 0.760),
                                 dark:  Color(red: 0.660, green: 0.500, blue: 0.880)),
        checkboxInactive:  Color(light: Color(red: 0.780, green: 0.740, blue: 0.840),
                                 dark:  Color(red: 0.300, green: 0.260, blue: 0.400)),
        preferredScheme:   nil
    )

    // ─────────────────────────────────────────────
    // PAID — Mocha (rich coffee, cozy warmth)
    // Target: Professionals, café lovers
    // ─────────────────────────────────────────────
    public static let mocha = AppTheme(
        id: "mocha",
        name: "Mocha",
        subtitle: "Rich & cozy",
        tag: "Warm",
        isPaid: true,
        meshColors: [
            Color(red: 0.120, green: 0.080, blue: 0.055),
            Color(red: 0.220, green: 0.150, blue: 0.100),
            Color(red: 0.140, green: 0.095, blue: 0.065),
            Color(red: 0.280, green: 0.180, blue: 0.120),
            Color(red: 0.500, green: 0.340, blue: 0.200),   // warm coffee focal
            Color(red: 0.240, green: 0.160, blue: 0.110),
            Color(red: 0.100, green: 0.065, blue: 0.045),
            Color(red: 0.360, green: 0.240, blue: 0.160),
            Color(red: 0.110, green: 0.072, blue: 0.050)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.130, green: 0.090, blue: 0.065),
        surfaceBackground:  Color(red: 0.175, green: 0.125, blue: 0.090),
        editorBackground:   Color(red: 0.175, green: 0.125, blue: 0.090),
        primaryText:        Color(red: 0.940, green: 0.900, blue: 0.850),
        secondaryText:      Color(red: 0.620, green: 0.540, blue: 0.460),
        placeholderText:    Color(red: 0.440, green: 0.380, blue: 0.320),
        accentColor:        Color(red: 0.780, green: 0.540, blue: 0.300),
        linkColor:          Color(red: 0.780, green: 0.540, blue: 0.300),
        quoteBarColor:      Color(red: 0.720, green: 0.480, blue: 0.260),
        priorityHigh:       Color(red: 0.900, green: 0.340, blue: 0.280),
        priorityMedium:     Color(red: 0.920, green: 0.580, blue: 0.220),
        fabBackground:      Color(red: 0.780, green: 0.540, blue: 0.300),
        fabIcon:            Color(red: 0.130, green: 0.090, blue: 0.065),
        separatorColor:     Color(red: 0.220, green: 0.160, blue: 0.120),
        checkboxActive:     Color(red: 0.780, green: 0.540, blue: 0.300),
        checkboxInactive:   Color(red: 0.300, green: 0.230, blue: 0.170),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Cherry Blossom (sakura pink, Japanese aesthetic)
    // Target: Aesthetic lovers, women 18–35 — viral on social media
    // ─────────────────────────────────────────────
    public static let cherryBlossom = AppTheme(
        id: "cherry-blossom",
        name: "Cherry Blossom",
        subtitle: "Sakura season",
        tag: "Pastel",
        isPaid: true,
        meshColors: [
            Color(red: 0.990, green: 0.940, blue: 0.950),
            Color(red: 0.970, green: 0.870, blue: 0.900),
            Color(red: 0.995, green: 0.955, blue: 0.960),
            Color(red: 0.960, green: 0.830, blue: 0.870),
            Color(red: 0.920, green: 0.600, blue: 0.700),   // soft sakura focal
            Color(red: 0.985, green: 0.920, blue: 0.940),
            Color(red: 0.700, green: 0.400, blue: 0.500),
            Color(red: 0.850, green: 0.650, blue: 0.720),
            Color(red: 0.750, green: 0.450, blue: 0.550)
        ],
        backgroundStyle: .gradient,
        screenBackground:  Color(light: Color(red: 0.990, green: 0.955, blue: 0.965),
                                 dark:  Color(red: 0.140, green: 0.080, blue: 0.100)),
        surfaceBackground: Color(light: Color(red: 0.995, green: 0.970, blue: 0.975),
                                 dark:  Color(red: 0.185, green: 0.110, blue: 0.135)),
        editorBackground:  Color(light: Color(red: 0.995, green: 0.970, blue: 0.975),
                                 dark:  Color(red: 0.185, green: 0.110, blue: 0.135)),
        primaryText:       Color(light: Color(red: 0.250, green: 0.120, blue: 0.150),
                                 dark:  Color(red: 0.960, green: 0.890, blue: 0.910)),
        secondaryText:     Color(light: Color(red: 0.520, green: 0.380, blue: 0.420),
                                 dark:  Color(red: 0.640, green: 0.500, blue: 0.540)),
        placeholderText:   Color(light: Color(red: 0.680, green: 0.540, blue: 0.580),
                                 dark:  Color(red: 0.420, green: 0.300, blue: 0.340)),
        accentColor:       Color(light: Color(red: 0.860, green: 0.460, blue: 0.560),
                                 dark:  Color(red: 0.940, green: 0.560, blue: 0.660)),
        linkColor:         Color(light: Color(red: 0.860, green: 0.460, blue: 0.560),
                                 dark:  Color(red: 0.940, green: 0.560, blue: 0.660)),
        quoteBarColor:     Color(light: Color(red: 0.880, green: 0.500, blue: 0.600),
                                 dark:  Color(red: 0.920, green: 0.540, blue: 0.640)),
        priorityHigh:      Color(light: Color(red: 0.820, green: 0.200, blue: 0.260),
                                 dark:  Color(red: 0.950, green: 0.340, blue: 0.400)),
        priorityMedium:    Color(light: Color(red: 0.870, green: 0.500, blue: 0.200),
                                 dark:  Color(red: 0.950, green: 0.620, blue: 0.300)),
        fabBackground:     Color(red: 0.880, green: 0.480, blue: 0.580),
        fabIcon:           .white,
        separatorColor:    Color(light: Color(red: 0.940, green: 0.880, blue: 0.900),
                                 dark:  Color(red: 0.240, green: 0.150, blue: 0.175)),
        checkboxActive:    Color(light: Color(red: 0.860, green: 0.460, blue: 0.560),
                                 dark:  Color(red: 0.940, green: 0.560, blue: 0.660)),
        checkboxInactive:  Color(light: Color(red: 0.860, green: 0.780, blue: 0.800),
                                 dark:  Color(red: 0.340, green: 0.220, blue: 0.260)),
        preferredScheme:   nil
    )

    // ─────────────────────────────────────────────
    // PAID — Iced Latte (clean beige, "that girl" aesthetic)
    // Target: Women 20–30, minimalists — viral TikTok aesthetic
    // ─────────────────────────────────────────────
    public static let icedLatte = AppTheme(
        id: "iced-latte",
        name: "Iced Latte",
        subtitle: "Clean & effortless",
        tag: "Warm",
        isPaid: true,
        meshColors: [
            Color(red: 0.960, green: 0.940, blue: 0.920),
            Color(red: 0.930, green: 0.900, blue: 0.870),
            Color(red: 0.970, green: 0.950, blue: 0.930),
            Color(red: 0.910, green: 0.880, blue: 0.840),
            Color(red: 0.780, green: 0.720, blue: 0.640),   // warm latte focal
            Color(red: 0.945, green: 0.920, blue: 0.895),
            Color(red: 0.600, green: 0.540, blue: 0.460),
            Color(red: 0.840, green: 0.790, blue: 0.720),
            Color(red: 0.650, green: 0.580, blue: 0.500)
        ],
        backgroundStyle: .gradient,
        screenBackground:  Color(light: Color(red: 0.965, green: 0.950, blue: 0.935),
                                 dark:  Color(red: 0.120, green: 0.105, blue: 0.090)),
        surfaceBackground: Color(light: Color(red: 0.978, green: 0.965, blue: 0.950),
                                 dark:  Color(red: 0.160, green: 0.142, blue: 0.122)),
        editorBackground:  Color(light: Color(red: 0.978, green: 0.965, blue: 0.950),
                                 dark:  Color(red: 0.160, green: 0.142, blue: 0.122)),
        primaryText:       Color(light: Color(red: 0.220, green: 0.180, blue: 0.140),
                                 dark:  Color(red: 0.930, green: 0.900, blue: 0.860)),
        secondaryText:     Color(light: Color(red: 0.480, green: 0.420, blue: 0.360),
                                 dark:  Color(red: 0.600, green: 0.540, blue: 0.470)),
        placeholderText:   Color(light: Color(red: 0.640, green: 0.580, blue: 0.520),
                                 dark:  Color(red: 0.380, green: 0.340, blue: 0.290)),
        accentColor:       Color(light: Color(red: 0.580, green: 0.440, blue: 0.300),
                                 dark:  Color(red: 0.740, green: 0.600, blue: 0.440)),
        linkColor:         Color(light: Color(red: 0.580, green: 0.440, blue: 0.300),
                                 dark:  Color(red: 0.740, green: 0.600, blue: 0.440)),
        quoteBarColor:     Color(light: Color(red: 0.620, green: 0.480, blue: 0.340),
                                 dark:  Color(red: 0.700, green: 0.560, blue: 0.400)),
        priorityHigh:      Color(light: Color(red: 0.780, green: 0.220, blue: 0.200),
                                 dark:  Color(red: 0.900, green: 0.340, blue: 0.300)),
        priorityMedium:    Color(light: Color(red: 0.840, green: 0.520, blue: 0.200),
                                 dark:  Color(red: 0.940, green: 0.620, blue: 0.280)),
        fabBackground:     Color(light: Color(red: 0.380, green: 0.300, blue: 0.220),
                                 dark:  Color(red: 0.740, green: 0.600, blue: 0.440)),
        fabIcon:           Color(light: .white,
                                 dark:  Color(red: 0.120, green: 0.105, blue: 0.090)),
        separatorColor:    Color(light: Color(red: 0.900, green: 0.880, blue: 0.860),
                                 dark:  Color(red: 0.210, green: 0.185, blue: 0.160)),
        checkboxActive:    Color(light: Color(red: 0.580, green: 0.440, blue: 0.300),
                                 dark:  Color(red: 0.740, green: 0.600, blue: 0.440)),
        checkboxInactive:  Color(light: Color(red: 0.800, green: 0.760, blue: 0.720),
                                 dark:  Color(red: 0.300, green: 0.260, blue: 0.220)),
        preferredScheme:   nil
    )

    // ─────────────────────────────────────────────
    // PAID — Aurora (northern lights, mystical)
    // Target: Adventurers, dreamers
    // ─────────────────────────────────────────────
    public static let aurora = AppTheme(
        id: "aurora",
        name: "Aurora",
        subtitle: "Northern lights magic",
        tag: "Dark",
        isPaid: true,
        meshColors: [
            Color(red: 0.030, green: 0.040, blue: 0.080),
            Color(red: 0.060, green: 0.100, blue: 0.150),
            Color(red: 0.035, green: 0.050, blue: 0.090),
            Color(red: 0.100, green: 0.250, blue: 0.200),
            Color(red: 0.200, green: 0.700, blue: 0.500),   // aurora green focal
            Color(red: 0.200, green: 0.150, blue: 0.400),   // purple accent
            Color(red: 0.025, green: 0.035, blue: 0.070),
            Color(red: 0.150, green: 0.100, blue: 0.350),
            Color(red: 0.020, green: 0.030, blue: 0.065)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.040, green: 0.050, blue: 0.095),
        surfaceBackground:  Color(red: 0.065, green: 0.080, blue: 0.140),
        editorBackground:   Color(red: 0.065, green: 0.080, blue: 0.140),
        primaryText:        Color(red: 0.880, green: 0.940, blue: 0.920),
        secondaryText:      Color(red: 0.500, green: 0.600, blue: 0.570),
        placeholderText:    Color(red: 0.340, green: 0.420, blue: 0.400),
        accentColor:        Color(red: 0.250, green: 0.780, blue: 0.560),
        linkColor:          Color(red: 0.250, green: 0.780, blue: 0.560),
        quoteBarColor:      Color(red: 0.300, green: 0.700, blue: 0.500),
        priorityHigh:       Color(red: 1.000, green: 0.380, blue: 0.400),
        priorityMedium:     Color(red: 1.000, green: 0.640, blue: 0.280),
        fabBackground:      Color(red: 0.250, green: 0.780, blue: 0.560),
        fabIcon:            Color(red: 0.040, green: 0.050, blue: 0.095),
        separatorColor:     Color(red: 0.090, green: 0.110, blue: 0.190),
        checkboxActive:     Color(red: 0.250, green: 0.780, blue: 0.560),
        checkboxInactive:   Color(red: 0.160, green: 0.220, blue: 0.260),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Ember (warm fire glow)
    // Target: Power users, night workers
    // ─────────────────────────────────────────────
    public static let ember = AppTheme(
        id: "ember",
        name: "Ember",
        subtitle: "Warm & intense",
        tag: "Dark",
        isPaid: true,
        meshColors: [
            Color(red: 0.120, green: 0.040, blue: 0.030),
            Color(red: 0.220, green: 0.070, blue: 0.040),
            Color(red: 0.140, green: 0.050, blue: 0.035),
            Color(red: 0.320, green: 0.100, blue: 0.050),
            Color(red: 0.800, green: 0.280, blue: 0.100),   // ember glow focal
            Color(red: 0.260, green: 0.080, blue: 0.045),
            Color(red: 0.100, green: 0.035, blue: 0.025),
            Color(red: 0.500, green: 0.160, blue: 0.060),
            Color(red: 0.090, green: 0.030, blue: 0.020)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.110, green: 0.045, blue: 0.035),
        surfaceBackground:  Color(red: 0.155, green: 0.065, blue: 0.050),
        editorBackground:   Color(red: 0.155, green: 0.065, blue: 0.050),
        primaryText:        Color(red: 0.960, green: 0.900, blue: 0.870),
        secondaryText:      Color(red: 0.640, green: 0.480, blue: 0.420),
        placeholderText:    Color(red: 0.440, green: 0.330, blue: 0.290),
        accentColor:        Color(red: 0.920, green: 0.380, blue: 0.140),
        linkColor:          Color(red: 0.920, green: 0.380, blue: 0.140),
        quoteBarColor:      Color(red: 0.880, green: 0.340, blue: 0.120),
        priorityHigh:       Color(red: 1.000, green: 0.320, blue: 0.280),
        priorityMedium:     Color(red: 1.000, green: 0.600, blue: 0.200),
        fabBackground:      Color(red: 0.920, green: 0.380, blue: 0.140),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.200, green: 0.090, blue: 0.065),
        checkboxActive:     Color(red: 0.920, green: 0.380, blue: 0.140),
        checkboxInactive:   Color(red: 0.280, green: 0.150, blue: 0.110),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Sage (modern muted green)
    // Target: Design-conscious, minimalists
    // ─────────────────────────────────────────────
    public static let sage = AppTheme(
        id: "sage",
        name: "Sage",
        subtitle: "Modern & balanced",
        tag: "Pastel",
        isPaid: true,
        meshColors: [
            Color(red: 0.890, green: 0.910, blue: 0.880),
            Color(red: 0.830, green: 0.870, blue: 0.820),
            Color(red: 0.900, green: 0.920, blue: 0.890),
            Color(red: 0.800, green: 0.850, blue: 0.790),
            Color(red: 0.560, green: 0.640, blue: 0.520),   // muted sage focal
            Color(red: 0.860, green: 0.890, blue: 0.850),
            Color(red: 0.400, green: 0.480, blue: 0.370),
            Color(red: 0.680, green: 0.740, blue: 0.650),
            Color(red: 0.440, green: 0.520, blue: 0.400)
        ],
        backgroundStyle: .gradient,
        screenBackground:  Color(light: Color(red: 0.935, green: 0.950, blue: 0.925),
                                 dark:  Color(red: 0.100, green: 0.120, blue: 0.095)),
        surfaceBackground: Color(light: Color(red: 0.955, green: 0.965, blue: 0.945),
                                 dark:  Color(red: 0.140, green: 0.165, blue: 0.130)),
        editorBackground:  Color(light: Color(red: 0.955, green: 0.965, blue: 0.945),
                                 dark:  Color(red: 0.140, green: 0.165, blue: 0.130)),
        primaryText:       Color(light: Color(red: 0.160, green: 0.200, blue: 0.140),
                                 dark:  Color(red: 0.880, green: 0.910, blue: 0.860)),
        secondaryText:     Color(light: Color(red: 0.400, green: 0.460, blue: 0.370),
                                 dark:  Color(red: 0.540, green: 0.600, blue: 0.500)),
        placeholderText:   Color(light: Color(red: 0.580, green: 0.630, blue: 0.540),
                                 dark:  Color(red: 0.340, green: 0.400, blue: 0.310)),
        accentColor:       Color(light: Color(red: 0.380, green: 0.520, blue: 0.320),
                                 dark:  Color(red: 0.480, green: 0.660, blue: 0.400)),
        linkColor:         Color(light: Color(red: 0.380, green: 0.520, blue: 0.320),
                                 dark:  Color(red: 0.480, green: 0.660, blue: 0.400)),
        quoteBarColor:     Color(light: Color(red: 0.420, green: 0.560, blue: 0.360),
                                 dark:  Color(red: 0.460, green: 0.640, blue: 0.380)),
        priorityHigh:      Color(light: Color(red: 0.800, green: 0.240, blue: 0.200),
                                 dark:  Color(red: 0.920, green: 0.360, blue: 0.320)),
        priorityMedium:    Color(light: Color(red: 0.840, green: 0.520, blue: 0.180),
                                 dark:  Color(red: 0.940, green: 0.620, blue: 0.260)),
        fabBackground:     Color(red: 0.420, green: 0.560, blue: 0.360),
        fabIcon:           .white,
        separatorColor:    Color(light: Color(red: 0.860, green: 0.880, blue: 0.845),
                                 dark:  Color(red: 0.190, green: 0.220, blue: 0.175)),
        checkboxActive:    Color(light: Color(red: 0.380, green: 0.520, blue: 0.320),
                                 dark:  Color(red: 0.480, green: 0.660, blue: 0.400)),
        checkboxInactive:  Color(light: Color(red: 0.740, green: 0.780, blue: 0.720),
                                 dark:  Color(red: 0.260, green: 0.310, blue: 0.240)),
        preferredScheme:   nil
    )

    // ─────────────────────────────────────────────
    // PAID — Obsidian (dark luxury, gold accents)
    // Target: Premium users
    // ─────────────────────────────────────────────
    public static let obsidian = AppTheme(
        id: "obsidian",
        name: "Obsidian",
        subtitle: "Dark luxury",
        tag: "Minimal",
        isPaid: true,
        meshColors: [
            Color(red: 0.060, green: 0.060, blue: 0.065),
            Color(red: 0.100, green: 0.095, blue: 0.090),
            Color(red: 0.070, green: 0.068, blue: 0.072),
            Color(red: 0.120, green: 0.110, blue: 0.100),
            Color(red: 0.720, green: 0.620, blue: 0.380),   // gold focal
            Color(red: 0.110, green: 0.105, blue: 0.095),
            Color(red: 0.050, green: 0.050, blue: 0.055),
            Color(red: 0.400, green: 0.350, blue: 0.220),
            Color(red: 0.055, green: 0.053, blue: 0.058)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.065, green: 0.063, blue: 0.068),
        surfaceBackground:  Color(red: 0.100, green: 0.097, blue: 0.105),
        editorBackground:   Color(red: 0.100, green: 0.097, blue: 0.105),
        primaryText:        Color(red: 0.930, green: 0.910, blue: 0.870),
        secondaryText:      Color(red: 0.560, green: 0.540, blue: 0.500),
        placeholderText:    Color(red: 0.380, green: 0.365, blue: 0.340),
        accentColor:        Color(red: 0.780, green: 0.680, blue: 0.420),
        linkColor:          Color(red: 0.780, green: 0.680, blue: 0.420),
        quoteBarColor:      Color(red: 0.720, green: 0.620, blue: 0.380),
        priorityHigh:       Color(red: 0.920, green: 0.340, blue: 0.300),
        priorityMedium:     Color(red: 0.920, green: 0.600, blue: 0.240),
        fabBackground:      Color(red: 0.780, green: 0.680, blue: 0.420),
        fabIcon:            Color(red: 0.065, green: 0.063, blue: 0.068),
        separatorColor:     Color(red: 0.150, green: 0.145, blue: 0.155),
        checkboxActive:     Color(red: 0.780, green: 0.680, blue: 0.420),
        checkboxInactive:   Color(red: 0.240, green: 0.230, blue: 0.215),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Neon (cyberpunk dark, electric accents)
    // Target: Gen Z, gamers — bold & unapologetic
    // ─────────────────────────────────────────────
    public static let neon = AppTheme(
        id: "neon",
        name: "Neon",
        subtitle: "Electric & bold",
        tag: "Dark",
        isPaid: true,
        meshColors: [
            Color(red: 0.025, green: 0.020, blue: 0.060),
            Color(red: 0.050, green: 0.030, blue: 0.100),
            Color(red: 0.030, green: 0.025, blue: 0.070),
            Color(red: 0.080, green: 0.040, blue: 0.160),
            Color(red: 0.950, green: 0.150, blue: 0.600),   // hot pink focal
            Color(red: 0.060, green: 0.035, blue: 0.120),
            Color(red: 0.020, green: 0.015, blue: 0.050),
            Color(red: 0.100, green: 0.800, blue: 0.900),   // cyan accent
            Color(red: 0.025, green: 0.018, blue: 0.055)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.035, green: 0.025, blue: 0.070),
        surfaceBackground:  Color(red: 0.055, green: 0.042, blue: 0.110),
        editorBackground:   Color(red: 0.055, green: 0.042, blue: 0.110),
        primaryText:        Color(red: 0.950, green: 0.930, blue: 0.970),
        secondaryText:      Color(red: 0.580, green: 0.520, blue: 0.660),
        placeholderText:    Color(red: 0.380, green: 0.340, blue: 0.450),
        accentColor:        Color(red: 0.950, green: 0.200, blue: 0.580),
        linkColor:          Color(red: 0.200, green: 0.820, blue: 0.920),
        quoteBarColor:      Color(red: 0.950, green: 0.200, blue: 0.580),
        priorityHigh:       Color(red: 1.000, green: 0.280, blue: 0.350),
        priorityMedium:     Color(red: 1.000, green: 0.600, blue: 0.200),
        fabBackground:      Color(red: 0.950, green: 0.200, blue: 0.580),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.080, green: 0.060, blue: 0.150),
        checkboxActive:     Color(red: 0.200, green: 0.820, blue: 0.920),
        checkboxInactive:   Color(red: 0.180, green: 0.150, blue: 0.260),
        preferredScheme:    .dark
    )

    // ─────────────────────────────────────────────
    // PAID — Matcha (zen green tea, Japanese calm)
    // Target: Wellness crowd, TikTok viral aesthetic
    // ─────────────────────────────────────────────
    public static let matcha = AppTheme(
        id: "matcha",
        name: "Matcha",
        subtitle: "Zen & grounded",
        tag: "Pastel",
        isPaid: true,
        meshColors: [
            Color(red: 0.900, green: 0.920, blue: 0.860),
            Color(red: 0.840, green: 0.880, blue: 0.780),
            Color(red: 0.910, green: 0.930, blue: 0.870),
            Color(red: 0.800, green: 0.860, blue: 0.720),
            Color(red: 0.520, green: 0.620, blue: 0.400),   // matcha green focal
            Color(red: 0.870, green: 0.900, blue: 0.820),
            Color(red: 0.380, green: 0.480, blue: 0.300),
            Color(red: 0.680, green: 0.750, blue: 0.580),
            Color(red: 0.420, green: 0.520, blue: 0.340)
        ],
        backgroundStyle: .gradient,
        screenBackground:  Color(light: Color(red: 0.940, green: 0.955, blue: 0.910),
                                 dark:  Color(red: 0.090, green: 0.110, blue: 0.075)),
        surfaceBackground: Color(light: Color(red: 0.960, green: 0.970, blue: 0.935),
                                 dark:  Color(red: 0.125, green: 0.150, blue: 0.105)),
        editorBackground:  Color(light: Color(red: 0.960, green: 0.970, blue: 0.935),
                                 dark:  Color(red: 0.125, green: 0.150, blue: 0.105)),
        primaryText:       Color(light: Color(red: 0.150, green: 0.200, blue: 0.100),
                                 dark:  Color(red: 0.870, green: 0.910, blue: 0.830)),
        secondaryText:     Color(light: Color(red: 0.380, green: 0.440, blue: 0.320),
                                 dark:  Color(red: 0.520, green: 0.580, blue: 0.450)),
        placeholderText:   Color(light: Color(red: 0.550, green: 0.600, blue: 0.480),
                                 dark:  Color(red: 0.320, green: 0.380, blue: 0.270)),
        accentColor:       Color(light: Color(red: 0.400, green: 0.540, blue: 0.260),
                                 dark:  Color(red: 0.500, green: 0.680, blue: 0.340)),
        linkColor:         Color(light: Color(red: 0.400, green: 0.540, blue: 0.260),
                                 dark:  Color(red: 0.500, green: 0.680, blue: 0.340)),
        quoteBarColor:     Color(light: Color(red: 0.440, green: 0.580, blue: 0.300),
                                 dark:  Color(red: 0.480, green: 0.660, blue: 0.320)),
        priorityHigh:      Color(light: Color(red: 0.800, green: 0.220, blue: 0.180),
                                 dark:  Color(red: 0.920, green: 0.350, blue: 0.300)),
        priorityMedium:    Color(light: Color(red: 0.830, green: 0.520, blue: 0.180),
                                 dark:  Color(red: 0.940, green: 0.630, blue: 0.260)),
        fabBackground:     Color(red: 0.440, green: 0.580, blue: 0.300),
        fabIcon:           .white,
        separatorColor:    Color(light: Color(red: 0.870, green: 0.895, blue: 0.835),
                                 dark:  Color(red: 0.170, green: 0.200, blue: 0.145)),
        checkboxActive:    Color(light: Color(red: 0.400, green: 0.540, blue: 0.260),
                                 dark:  Color(red: 0.500, green: 0.680, blue: 0.340)),
        checkboxInactive:  Color(light: Color(red: 0.740, green: 0.780, blue: 0.700),
                                 dark:  Color(red: 0.240, green: 0.290, blue: 0.200)),
        preferredScheme:   nil
    )

    // ─────────────────────────────────────────────
    // PAID — Terracotta (warm earthy clay)
    // Target: Interior design lovers, earth tones trend
    // ─────────────────────────────────────────────
    public static let terracotta = AppTheme(
        id: "terracotta",
        name: "Terracotta",
        subtitle: "Earthy & warm",
        tag: "Warm",
        isPaid: true,
        meshColors: [
            Color(red: 0.160, green: 0.090, blue: 0.065),
            Color(red: 0.280, green: 0.150, blue: 0.100),
            Color(red: 0.180, green: 0.100, blue: 0.072),
            Color(red: 0.400, green: 0.200, blue: 0.130),
            Color(red: 0.780, green: 0.420, blue: 0.260),   // terracotta focal
            Color(red: 0.340, green: 0.175, blue: 0.115),
            Color(red: 0.140, green: 0.078, blue: 0.058),
            Color(red: 0.560, green: 0.300, blue: 0.180),
            Color(red: 0.130, green: 0.072, blue: 0.052)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.155, green: 0.095, blue: 0.070),
        surfaceBackground:  Color(red: 0.200, green: 0.130, blue: 0.098),
        editorBackground:   Color(red: 0.200, green: 0.130, blue: 0.098),
        primaryText:        Color(red: 0.955, green: 0.910, blue: 0.870),
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
        checkboxInactive:   Color(red: 0.300, green: 0.210, blue: 0.165),
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
            Color(red: 0.080, green: 0.040, blue: 0.120),
            Color(red: 0.140, green: 0.060, blue: 0.200),
            Color(red: 0.090, green: 0.045, blue: 0.130),
            Color(red: 0.200, green: 0.080, blue: 0.280),
            Color(red: 0.500, green: 0.200, blue: 0.680),   // amethyst focal
            Color(red: 0.170, green: 0.070, blue: 0.240),
            Color(red: 0.060, green: 0.030, blue: 0.100),
            Color(red: 0.340, green: 0.140, blue: 0.460),
            Color(red: 0.070, green: 0.035, blue: 0.110)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.085, green: 0.045, blue: 0.125),
        surfaceBackground:  Color(red: 0.120, green: 0.068, blue: 0.170),
        editorBackground:   Color(red: 0.120, green: 0.068, blue: 0.170),
        primaryText:        Color(red: 0.940, green: 0.900, blue: 0.970),
        secondaryText:      Color(red: 0.600, green: 0.500, blue: 0.660),
        placeholderText:    Color(red: 0.400, green: 0.330, blue: 0.450),
        accentColor:        Color(red: 0.620, green: 0.320, blue: 0.840),
        linkColor:          Color(red: 0.620, green: 0.320, blue: 0.840),
        quoteBarColor:      Color(red: 0.580, green: 0.280, blue: 0.800),
        priorityHigh:       Color(red: 1.000, green: 0.360, blue: 0.380),
        priorityMedium:     Color(red: 1.000, green: 0.620, blue: 0.260),
        fabBackground:      Color(red: 0.620, green: 0.320, blue: 0.840),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.160, green: 0.095, blue: 0.220),
        checkboxActive:     Color(red: 0.620, green: 0.320, blue: 0.840),
        checkboxInactive:   Color(red: 0.220, green: 0.160, blue: 0.300),
        preferredScheme:    .dark
    )

    // MARK: — All themes ordered for display (all paid)
    public static let all: [AppTheme] = [
        .defaultLight, .midnight,                                  // originals
        .academia, .nord, .tokyoNight,                             // batch 1
        .forest, .rose, .void,                                     // batch 2
        .ocean, .sunset, .lavender, .mocha, .cherryBlossom,        // batch 3
        .icedLatte, .aurora, .ember, .sage, .obsidian,             // batch 4
        .neon, .matcha, .terracotta, .amethyst                     // batch 5
    ]

    public static let free: [AppTheme] = all.filter { !$0.isPaid }
    public static let paid: [AppTheme] = all.filter { $0.isPaid }
}

