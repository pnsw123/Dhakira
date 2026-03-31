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
            Color(red: 0.180, green: 0.204, blue: 0.251),   // Nord3 – polar night mid
            Color(red: 0.533, green: 0.753, blue: 0.816),   // Nord8 – arctic blue (frost highlight)
            Color(red: 0.160, green: 0.188, blue: 0.235),   // Nord2 – polar night
            Color(red: 0.118, green: 0.137, blue: 0.173),   // Nord1 – deep polar night
            Color(red: 0.368, green: 0.506, blue: 0.675),   // Nord9 – frost blue focal CENTER
            Color(red: 0.098, green: 0.118, blue: 0.157),   // Nord0 – deepest polar night
            Color(red: 0.082, green: 0.098, blue: 0.130),   // very deep polar
            Color(red: 0.294, green: 0.380, blue: 0.506),   // Nord10 – darker frost
            Color(red: 0.075, green: 0.090, blue: 0.120)    // darkest corner
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.118, green: 0.137, blue: 0.173),   // Nord1 polar night
        surfaceBackground:  Color(red: 0.160, green: 0.188, blue: 0.235),   // Nord2
        editorBackground:   Color(red: 0.160, green: 0.188, blue: 0.235),
        primaryText:        Color(red: 0.925, green: 0.937, blue: 0.953),   // #ECEFF4 Nord6
        secondaryText:      Color(red: 0.698, green: 0.733, blue: 0.784),   // #B2BAC8
        placeholderText:    Color(red: 0.506, green: 0.549, blue: 0.608),
        accentColor:        Color(red: 0.533, green: 0.753, blue: 0.816),   // Nord8 arctic blue
        linkColor:          Color(red: 0.404, green: 0.573, blue: 0.749),
        quoteBarColor:      Color(red: 0.533, green: 0.753, blue: 0.816),
        priorityHigh:       Color(red: 0.749, green: 0.380, blue: 0.416),   // #BF616A aurora red
        priorityMedium:     Color(red: 0.824, green: 0.584, blue: 0.349),   // #D2955A aurora orange
        fabBackground:      Color(red: 0.533, green: 0.753, blue: 0.816),   // Nord8 arctic blue
        fabIcon:            Color(red: 0.118, green: 0.137, blue: 0.173),
        separatorColor:     Color(red: 0.200, green: 0.230, blue: 0.290),   // subtle polar line
        checkboxActive:     Color(red: 0.533, green: 0.753, blue: 0.816),   // Nord8 arctic blue
        checkboxInactive:   Color(red: 0.270, green: 0.310, blue: 0.390),
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
            Color(red: 0.022, green: 0.042, blue: 0.018),   // forest floor black
            Color(red: 0.048, green: 0.130, blue: 0.030),   // dark canopy green
            Color(red: 0.025, green: 0.045, blue: 0.020),   // shadow black
            Color(red: 0.042, green: 0.090, blue: 0.032),   // dark undergrowth
            Color(red: 0.148, green: 0.440, blue: 0.082),   // muted forest green — CENTER (toned down from vivid lime)
            Color(red: 0.280, green: 0.200, blue: 0.048),   // subtle golden sunlight
            Color(red: 0.018, green: 0.034, blue: 0.015),   // root darkness
            Color(red: 0.240, green: 0.170, blue: 0.040),   // faint dappled gold
            Color(red: 0.020, green: 0.036, blue: 0.018)    // deep shadow
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.028, green: 0.050, blue: 0.022),   // deep forest floor
        surfaceBackground:  Color(red: 0.055, green: 0.090, blue: 0.048),
        editorBackground:   Color(red: 0.055, green: 0.090, blue: 0.048),
        primaryText:        Color(red: 0.867, green: 0.886, blue: 0.824),   // soft off-white
        secondaryText:      Color(red: 0.580, green: 0.620, blue: 0.510),
        placeholderText:    Color(red: 0.420, green: 0.460, blue: 0.360),
        accentColor:        Color(red: 0.480, green: 0.700, blue: 0.330),   // muted moss
        linkColor:          Color(red: 0.480, green: 0.700, blue: 0.330),
        quoteBarColor:      Color(red: 0.380, green: 0.580, blue: 0.260),
        priorityHigh:       Color(red: 0.820, green: 0.330, blue: 0.220),
        priorityMedium:     Color(red: 0.820, green: 0.580, blue: 0.200),
        fabBackground:      Color(red: 0.480, green: 0.700, blue: 0.330),
        fabIcon:            Color(red: 0.100, green: 0.140, blue: 0.100),
        separatorColor:     Color(red: 0.080, green: 0.120, blue: 0.068),   // subtle dark green line
        checkboxActive:     Color(red: 0.480, green: 0.700, blue: 0.330),
        checkboxInactive:   Color(red: 0.220, green: 0.300, blue: 0.200),
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
            Color(red: 0.160, green: 0.065, blue: 0.110),   // deep rose shadow corner
            Color(red: 0.980, green: 0.840, blue: 0.880),   // petal white-blush top
            Color(red: 0.140, green: 0.055, blue: 0.095),   // deep rose shadow
            Color(red: 0.360, green: 0.105, blue: 0.185),   // deep fuchsia left
            Color(red: 0.920, green: 0.400, blue: 0.580),   // warm sakura focal CENTER (softer than cerise)
            Color(red: 0.260, green: 0.082, blue: 0.150),   // deep fuchsia right
            Color(red: 0.120, green: 0.048, blue: 0.082),   // deep rose shadow
            Color(red: 0.740, green: 0.460, blue: 0.340),   // warm rose-gold glow bottom
            Color(red: 0.110, green: 0.044, blue: 0.075)    // deep shadow corner
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
                                 dark:  Color(red: 0.200, green: 0.120, blue: 0.300)),  // dark plum-tinted
        preferredScheme:   nil
    )

    // ─────────────────────────────────────────────
    // PAID — Void (pure OLED black, cosmic gold accent)
    // Target: Power users, OLED screens
    // Distinct from Dark Mode: gold accent vs blue
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
        surfaceBackground:  Color(red: 0.060, green: 0.058, blue: 0.052),  // warm-tinted dark
        editorBackground:   Color(red: 0.060, green: 0.058, blue: 0.052),
        primaryText:        .white,
        secondaryText:      Color(red: 0.580, green: 0.560, blue: 0.480),  // warm silver
        placeholderText:    Color(red: 0.360, green: 0.350, blue: 0.300),
        accentColor:        Color(red: 0.880, green: 0.640, blue: 0.120),  // cosmic gold
        linkColor:          Color(red: 0.880, green: 0.640, blue: 0.120),
        quoteBarColor:      Color(red: 0.820, green: 0.580, blue: 0.100),
        priorityHigh:       Color(red: 1.000, green: 0.300, blue: 0.300),
        priorityMedium:     Color(red: 0.960, green: 0.700, blue: 0.180),
        fabBackground:      Color(red: 0.880, green: 0.640, blue: 0.120),
        fabIcon:            .black,
        separatorColor:     Color(red: 0.140, green: 0.130, blue: 0.100),  // warm gold tint
        checkboxActive:     Color(red: 0.880, green: 0.640, blue: 0.120),  // gold
        checkboxInactive:   Color(red: 0.200, green: 0.195, blue: 0.165),  // warm dark
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
        checkboxInactive:   Color(red: 0.120, green: 0.200, blue: 0.360),
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
        screenBackground:  Color(light: Color(red: 0.945, green: 0.920, blue: 0.982),
                                 dark:  Color(red: 0.095, green: 0.060, blue: 0.180)),  // vivid purple, not grey
        surfaceBackground: Color(light: Color(red: 0.960, green: 0.945, blue: 0.992),
                                 dark:  Color(red: 0.130, green: 0.090, blue: 0.230)),
        editorBackground:  Color(light: Color(red: 0.960, green: 0.945, blue: 0.992),
                                 dark:  Color(red: 0.130, green: 0.090, blue: 0.230)),
        primaryText:       Color(light: Color(red: 0.200, green: 0.150, blue: 0.300),
                                 dark:  Color(red: 0.920, green: 0.890, blue: 0.970)),
        secondaryText:     Color(light: Color(red: 0.440, green: 0.360, blue: 0.580),
                                 dark:  Color(red: 0.640, green: 0.540, blue: 0.800)),  // vivid lilac — 2nd color
        placeholderText:   Color(light: Color(red: 0.620, green: 0.570, blue: 0.700),
                                 dark:  Color(red: 0.380, green: 0.300, blue: 0.500)),
        accentColor:       Color(light: Color(red: 0.520, green: 0.360, blue: 0.760),
                                 dark:  Color(red: 0.700, green: 0.520, blue: 0.940)),
        linkColor:         Color(light: Color(red: 0.520, green: 0.360, blue: 0.760),
                                 dark:  Color(red: 0.700, green: 0.520, blue: 0.940)),
        quoteBarColor:     Color(light: Color(red: 0.560, green: 0.400, blue: 0.780),
                                 dark:  Color(red: 0.680, green: 0.500, blue: 0.900)),
        priorityHigh:      Color(light: Color(red: 0.820, green: 0.220, blue: 0.300),
                                 dark:  Color(red: 0.960, green: 0.380, blue: 0.460)),
        priorityMedium:    Color(light: Color(red: 0.860, green: 0.500, blue: 0.180),
                                 dark:  Color(red: 0.980, green: 0.640, blue: 0.300)),
        fabBackground:     Color(red: 0.580, green: 0.380, blue: 0.820),
        fabIcon:           .white,
        separatorColor:    Color(light: Color(red: 0.840, green: 0.800, blue: 0.920),
                                 dark:  Color(red: 0.190, green: 0.145, blue: 0.310)),  // vivid purple separator
        checkboxActive:    Color(light: Color(red: 0.520, green: 0.360, blue: 0.760),
                                 dark:  Color(red: 0.600, green: 0.420, blue: 0.860)),  // slightly diff from accent
        checkboxInactive:  Color(light: Color(red: 0.780, green: 0.740, blue: 0.860),
                                 dark:  Color(red: 0.280, green: 0.220, blue: 0.420)),  // purple-tinted
        preferredScheme:   .light
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
            Color(red: 0.004, green: 0.006, blue: 0.022),   // void black sky top
            Color(red: 0.006, green: 0.018, blue: 0.035),   // deep night blue sky
            Color(red: 0.004, green: 0.006, blue: 0.020),   // void black sky
            Color(red: 0.018, green: 0.165, blue: 0.092),   // aurora green band — left
            Color(red: 0.100, green: 0.820, blue: 0.420),   // vivid aurora green curtain — CENTER
            Color(red: 0.058, green: 0.055, blue: 0.220),   // deep aurora violet — right band
            Color(red: 0.004, green: 0.005, blue: 0.018),   // void black bottom
            Color(red: 0.038, green: 0.016, blue: 0.160),   // deep indigo horizon
            Color(red: 0.004, green: 0.005, blue: 0.015)    // void black corner
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.006, green: 0.010, blue: 0.020),   // true night sky black
        surfaceBackground:  Color(red: 0.012, green: 0.055, blue: 0.060),   // very dark teal surface
        editorBackground:   Color(red: 0.008, green: 0.030, blue: 0.035),   // near-black teal editor
        primaryText:        Color(red: 0.880, green: 0.980, blue: 0.940),   // crisp aurora-white
        secondaryText:      Color(red: 0.760, green: 0.120, blue: 0.560),   // aurora magenta — 2nd color
        placeholderText:    Color(red: 0.180, green: 0.300, blue: 0.260),
        accentColor:        Color(red: 0.060, green: 0.920, blue: 0.480),   // iconic aurora green
        linkColor:          Color(red: 0.060, green: 0.920, blue: 0.480),
        quoteBarColor:      Color(red: 0.060, green: 0.920, blue: 0.480),
        priorityHigh:       Color(red: 1.000, green: 0.340, blue: 0.380),
        priorityMedium:     Color(red: 1.000, green: 0.640, blue: 0.280),
        fabBackground:      Color(red: 0.060, green: 0.920, blue: 0.480),   // aurora green FAB
        fabIcon:            Color(red: 0.004, green: 0.008, blue: 0.018),   // near-black icon
        separatorColor:     Color(red: 0.018, green: 0.095, blue: 0.075),   // dark aurora green line
        checkboxActive:     Color(red: 0.060, green: 0.920, blue: 0.480),   // aurora green check
        checkboxInactive:   Color(red: 0.040, green: 0.120, blue: 0.100),   // very dark teal ring
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
            Color(red: 0.008, green: 0.005, blue: 0.022),   // void black
            Color(red: 0.055, green: 0.018, blue: 0.120),   // dark purple
            Color(red: 0.008, green: 0.005, blue: 0.018),   // void black
            Color(red: 0.095, green: 0.028, blue: 0.195),   // deep indigo left
            Color(red: 0.980, green: 0.080, blue: 0.580),   // hot neon pink — CENTER
            Color(red: 0.065, green: 0.020, blue: 0.150),   // deep indigo right
            Color(red: 0.005, green: 0.004, blue: 0.016),   // void black
            Color(red: 0.000, green: 0.820, blue: 0.960),   // electric cyan bottom (slightly less max)
            Color(red: 0.005, green: 0.004, blue: 0.016)    // void black
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.022, green: 0.015, blue: 0.065),   // deep cyberpunk purple
        surfaceBackground:  Color(red: 0.042, green: 0.030, blue: 0.115),   // vivid indigo surface
        editorBackground:   Color(red: 0.042, green: 0.030, blue: 0.115),
        primaryText:        Color(red: 0.960, green: 0.940, blue: 0.980),
        secondaryText:      Color(red: 0.320, green: 0.880, blue: 0.960),   // electric cyan — 2nd color
        placeholderText:    Color(red: 0.360, green: 0.320, blue: 0.480),
        accentColor:        Color(red: 0.980, green: 0.200, blue: 0.600),   // neon hot pink
        linkColor:          Color(red: 0.200, green: 0.860, blue: 0.960),   // electric cyan
        quoteBarColor:      Color(red: 0.980, green: 0.200, blue: 0.600),
        priorityHigh:       Color(red: 1.000, green: 0.280, blue: 0.350),
        priorityMedium:     Color(red: 1.000, green: 0.600, blue: 0.200),
        fabBackground:      Color(red: 0.980, green: 0.200, blue: 0.600),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.055, green: 0.042, blue: 0.170),   // indigo-tinted separator
        checkboxActive:     Color(red: 0.200, green: 0.880, blue: 0.960),   // cyan — distinct from pink accent
        checkboxInactive:   Color(red: 0.160, green: 0.130, blue: 0.280),   // deep indigo
        preferredScheme:    .dark
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
            Color(red: 0.088, green: 0.048, blue: 0.028),   // dark clay shadow corner
            Color(red: 0.740, green: 0.355, blue: 0.150),   // warm terracotta top
            Color(red: 0.078, green: 0.042, blue: 0.025),   // shadow corner
            Color(red: 0.500, green: 0.245, blue: 0.118),   // medium clay
            Color(red: 0.875, green: 0.470, blue: 0.210),   // bright terracotta focal — CENTER
            Color(red: 0.420, green: 0.205, blue: 0.098),   // burnt sienna
            Color(red: 0.065, green: 0.036, blue: 0.022),   // dark clay shadow
            Color(red: 0.560, green: 0.310, blue: 0.120),   // warm amber bottom (replaces sage-olive)
            Color(red: 0.062, green: 0.034, blue: 0.020)    // dark shadow corner
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
        checkboxInactive:   Color(red: 0.220, green: 0.140, blue: 0.360),   // deep purple-tinted
        preferredScheme:    .dark
    )

    // MARK: — All themes ordered for display
    public static let all: [AppTheme] = [
        .defaultLight, .midnight,                           // free originals
        .tokyoNight, .nord, .forest,                        // dark essentials
        .rose, .void, .ocean,                               // premium dark
        .lavender,                                          // mood
        .aurora, .neon,                                     // vibe
        .terracotta, .amethyst                              // earth & crystal
    ]

    public static let free: [AppTheme] = all.filter { !$0.isPaid }
    public static let paid: [AppTheme] = all.filter { $0.isPaid }
}

