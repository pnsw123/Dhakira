import SwiftUI

// MARK: - AppTheme
// Central theme struct. Every color, font, and spacing token lives here.
// Add a new theme = add one static let. All views update automatically.

struct AppTheme: Equatable, Hashable, Identifiable {

    let id: String
    let name: String
    let subtitle: String
    let isPaid: Bool

    // MARK: — Background
    let meshColors: [Color]          // 9 colors for 3×3 MeshGradient card preview
    let backgroundStyle: BackgroundStyle

    // MARK: — Surface colors
    let screenBackground: Color
    let surfaceBackground: Color     // cards, rows
    let editorBackground: Color

    // MARK: — Text colors
    let primaryText: Color
    let secondaryText: Color
    let placeholderText: Color

    // MARK: — Accent
    let accentColor: Color
    let linkColor: Color
    let quoteBarColor: Color

    // MARK: — Priority (carried from existing Color+App.swift)
    let priorityHigh: Color
    let priorityMedium: Color

    // MARK: — Components
    let fabBackground: Color
    let fabIcon: Color
    let separatorColor: Color
    let checkboxActive: Color
    let checkboxInactive: Color

    // MARK: — Preferred color scheme
    let preferredScheme: ColorScheme?   // nil = follow system

    // MARK: — StoreKit product ID (nil for free themes)
    var productId: String? {
        guard isPaid else { return nil }
        switch id {
        case "academia":     return "com.prodnote.theme.academia"
        case "nord":         return "com.prodnote.theme.nord"
        case "tokyo-night":  return "com.prodnote.theme.tokyonight"
        case "forest":       return "com.prodnote.theme.forest"
        case "rose":         return "com.prodnote.theme.rose"
        case "void":         return "com.prodnote.theme.void"
        default:             return nil
        }
    }

    enum BackgroundStyle: String, Equatable, Hashable {
        case gradient, color, photo, blur
    }
}

// MARK: - EnvironmentKey
extension EnvironmentValues {
    @Entry var appTheme: AppTheme = .defaultLight
}

// MARK: - Preset Themes

extension AppTheme {

    // ─────────────────────────────────────────────
    // FREE — Default (current warm off-white look)
    // ─────────────────────────────────────────────
    // Default theme uses iOS semantic (adaptive) colors so it follows system dark/light mode.
    static let defaultLight = AppTheme(
        id: "default",
        name: "Default",
        subtitle: "Warm & clean",
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
    // FREE — Midnight (deep charcoal dark)
    // ─────────────────────────────────────────────
    static let midnight = AppTheme(
        id: "midnight",
        name: "Midnight",
        subtitle: "Deep & focused",
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
    // ─────────────────────────────────────────────
    static let academia = AppTheme(
        id: "academia",
        name: "Academia",
        subtitle: "Warm & scholarly",
        isPaid: true,
        meshColors: [
            Color(red: 0.965, green: 0.945, blue: 0.900),
            Color(red: 0.870, green: 0.790, blue: 0.680),
            Color(red: 0.940, green: 0.910, blue: 0.860),
            Color(red: 0.820, green: 0.720, blue: 0.590),
            Color(red: 0.900, green: 0.850, blue: 0.780),
            Color(red: 0.960, green: 0.930, blue: 0.880),
            Color(red: 0.850, green: 0.760, blue: 0.630),
            Color(red: 0.920, green: 0.880, blue: 0.820),
            Color(red: 0.880, green: 0.820, blue: 0.730)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.965, green: 0.945, blue: 0.900),
        surfaceBackground:  Color(red: 0.975, green: 0.960, blue: 0.920),
        editorBackground:   Color(red: 0.975, green: 0.960, blue: 0.920),
        primaryText:        Color(red: 0.220, green: 0.160, blue: 0.090),
        secondaryText:      Color(red: 0.500, green: 0.400, blue: 0.280),
        placeholderText:    Color(red: 0.660, green: 0.580, blue: 0.460),
        accentColor:        Color(red: 0.600, green: 0.340, blue: 0.100),
        linkColor:          Color(red: 0.600, green: 0.340, blue: 0.100),
        quoteBarColor:      Color(red: 0.700, green: 0.450, blue: 0.180),
        priorityHigh:       Color(red: 0.780, green: 0.200, blue: 0.150),
        priorityMedium:     Color(red: 0.820, green: 0.480, blue: 0.100),
        fabBackground:      Color(red: 0.320, green: 0.200, blue: 0.080),
        fabIcon:            Color(red: 0.965, green: 0.945, blue: 0.900),
        separatorColor:     Color(red: 0.850, green: 0.810, blue: 0.750),
        checkboxActive:     Color(red: 0.600, green: 0.340, blue: 0.100),
        checkboxInactive:   Color(red: 0.750, green: 0.680, blue: 0.580),
        preferredScheme:    .light
    )

    // ─────────────────────────────────────────────
    // PAID — Nord (arctic blue-grey, Scandinavian)
    // Target: Men, professionals
    // ─────────────────────────────────────────────
    static let nord = AppTheme(
        id: "nord",
        name: "Nord",
        subtitle: "Arctic & minimal",
        isPaid: true,
        meshColors: [
            Color(red: 0.180, green: 0.204, blue: 0.251),   // #2E3440
            Color(red: 0.231, green: 0.259, blue: 0.322),   // #3B4252
            Color(red: 0.263, green: 0.298, blue: 0.369),   // #434C5E
            Color(red: 0.298, green: 0.337, blue: 0.416),   // #4C566A
            Color(red: 0.557, green: 0.737, blue: 0.773),   // #8EBCBB → polar frost
            Color(red: 0.533, green: 0.702, blue: 0.780),   // #88B2C6
            Color(red: 0.506, green: 0.631, blue: 0.757),   // #81A1C1
            Color(red: 0.404, green: 0.573, blue: 0.749),   // #6792BF
            Color(red: 0.231, green: 0.259, blue: 0.322)
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
    static let tokyoNight = AppTheme(
        id: "tokyo-night",
        name: "Tokyo Night",
        subtitle: "City at 2am",
        isPaid: true,
        meshColors: [
            Color(red: 0.063, green: 0.075, blue: 0.141),   // deep navy
            Color(red: 0.094, green: 0.110, blue: 0.196),
            Color(red: 0.078, green: 0.090, blue: 0.169),
            Color(red: 0.431, green: 0.302, blue: 0.773),   // purple glow
            Color(red: 0.125, green: 0.141, blue: 0.251),
            Color(red: 0.094, green: 0.110, blue: 0.196),
            Color(red: 0.196, green: 0.376, blue: 0.780),   // electric blue
            Color(red: 0.078, green: 0.090, blue: 0.169),
            Color(red: 0.063, green: 0.075, blue: 0.141)
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
    static let forest = AppTheme(
        id: "forest",
        name: "Forest",
        subtitle: "Earthy & calm",
        isPaid: true,
        meshColors: [
            Color(red: 0.133, green: 0.180, blue: 0.133),
            Color(red: 0.200, green: 0.267, blue: 0.176),
            Color(red: 0.153, green: 0.208, blue: 0.153),
            Color(red: 0.290, green: 0.380, blue: 0.220),   // sage green
            Color(red: 0.176, green: 0.235, blue: 0.165),
            Color(red: 0.400, green: 0.310, blue: 0.220),   // warm brown
            Color(red: 0.220, green: 0.290, blue: 0.200),
            Color(red: 0.165, green: 0.220, blue: 0.155),
            Color(red: 0.350, green: 0.270, blue: 0.190)
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
    // ─────────────────────────────────────────────
    static let rose = AppTheme(
        id: "rose",
        name: "Rosé",
        subtitle: "Soft & romantic",
        isPaid: true,
        meshColors: [
            Color(red: 0.980, green: 0.930, blue: 0.930),
            Color(red: 0.940, green: 0.820, blue: 0.840),
            Color(red: 0.970, green: 0.900, blue: 0.910),
            Color(red: 0.880, green: 0.720, blue: 0.740),   // dusty rose
            Color(red: 0.960, green: 0.870, blue: 0.880),
            Color(red: 0.990, green: 0.950, blue: 0.940),   // cream
            Color(red: 0.920, green: 0.780, blue: 0.800),
            Color(red: 0.975, green: 0.920, blue: 0.925),
            Color(red: 0.950, green: 0.860, blue: 0.870)
        ],
        backgroundStyle: .gradient,
        screenBackground:   Color(red: 0.980, green: 0.930, blue: 0.930),
        surfaceBackground:  Color(red: 0.990, green: 0.950, blue: 0.950),
        editorBackground:   Color(red: 0.990, green: 0.950, blue: 0.950),
        primaryText:        Color(red: 0.280, green: 0.140, blue: 0.160),
        secondaryText:      Color(red: 0.560, green: 0.380, blue: 0.400),
        placeholderText:    Color(red: 0.720, green: 0.560, blue: 0.580),
        accentColor:        Color(red: 0.780, green: 0.340, blue: 0.420),   // rose accent
        linkColor:          Color(red: 0.780, green: 0.340, blue: 0.420),
        quoteBarColor:      Color(red: 0.820, green: 0.440, blue: 0.520),
        priorityHigh:       Color(red: 0.860, green: 0.200, blue: 0.280),
        priorityMedium:     Color(red: 0.880, green: 0.500, blue: 0.200),
        fabBackground:      Color(red: 0.780, green: 0.340, blue: 0.420),
        fabIcon:            .white,
        separatorColor:     Color(red: 0.920, green: 0.840, blue: 0.850),
        checkboxActive:     Color(red: 0.780, green: 0.340, blue: 0.420),
        checkboxInactive:   Color(red: 0.840, green: 0.720, blue: 0.740),
        preferredScheme:    .light
    )

    // ─────────────────────────────────────────────
    // PAID — Void (pure OLED black)
    // Target: Power users, OLED screens
    // ─────────────────────────────────────────────
    static let void = AppTheme(
        id: "void",
        name: "Void",
        subtitle: "Pure black, OLED",
        isPaid: true,
        meshColors: [
            Color(red: 0.000, green: 0.000, blue: 0.000),
            Color(red: 0.040, green: 0.040, blue: 0.040),
            Color(red: 0.020, green: 0.020, blue: 0.020),
            Color(red: 0.000, green: 0.000, blue: 0.000),
            Color(red: 0.060, green: 0.060, blue: 0.060),
            Color(red: 0.030, green: 0.030, blue: 0.030),
            Color(red: 0.000, green: 0.000, blue: 0.000),
            Color(red: 0.040, green: 0.040, blue: 0.040),
            Color(red: 0.010, green: 0.010, blue: 0.010)
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

    // MARK: — All themes ordered for display (randomised groups, free first)
    static let all: [AppTheme] = [
        .defaultLight, .midnight,          // free
        .academia, .nord, .tokyoNight,     // paid — batch 1
        .forest, .rose, .void              // paid — batch 2
    ]

    static let free: [AppTheme] = all.filter { !$0.isPaid }
    static let paid: [AppTheme] = all.filter { $0.isPaid }
}
