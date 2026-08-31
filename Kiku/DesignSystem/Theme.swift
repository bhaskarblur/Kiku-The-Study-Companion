import SwiftUI

// MARK: - Dynamic color helper

extension Color {
    /// Creates a color that adapts to light/dark appearance on macOS.
    static func dynamic(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex))
    }
}

extension NSColor {
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b, a: CGFloat
        if s.count == 8 {
            r = CGFloat((value >> 24) & 0xFF) / 255
            g = CGFloat((value >> 16) & 0xFF) / 255
            b = CGFloat((value >> 8) & 0xFF) / 255
            a = CGFloat(value & 0xFF) / 255
        } else {
            r = CGFloat((value >> 16) & 0xFF) / 255
            g = CGFloat((value >> 8) & 0xFF) / 255
            b = CGFloat(value & 0xFF) / 255
            a = 1
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Design tokens

/// Central design system for Kiku. See docs/UI_DESIGN.md.
enum Theme {
    enum Palette {
        static let bg           = Color.dynamic(light: "#FAFAFA", dark: "#1A1A1D")
        static let surface      = Color.dynamic(light: "#FFFFFF", dark: "#242428")
        static let surfaceAlt   = Color.dynamic(light: "#F2F2F4", dark: "#2E2E33")
        static let border       = Color.dynamic(light: "#E7E7EA", dark: "#37373D")
        static let textPrimary  = Color.dynamic(light: "#1C1C1E", dark: "#F5F5F7")
        static let textSecondary = Color.dynamic(light: "#6B6B72", dark: "#A0A0A8")
        static let accent       = Color.dynamic(light: "#7C6BF0", dark: "#9A8BF5")
        static let success      = Color.dynamic(light: "#34C77B", dark: "#3FD98A")
        static let warning      = Color.dynamic(light: "#F5A623", dark: "#FFB84D")
    }

    /// Curated pastel palette for subjects. Soft in both light and dark.
    static let subjectColors: [String] = [
        "#9A8BF5", // lavender
        "#5CC8B8", // mint
        "#F5A88B", // peach
        "#7EC4F5", // sky
        "#F58BB0", // rose
        "#F5D06B"  // butter
    ]

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 8
        static let card: CGFloat = 14
        static let sheet: CGFloat = 18
    }

    enum Motion {
        static let spring = Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let quick = Animation.spring(response: 0.25, dampingFraction: 0.85)
    }
}

// MARK: - Typography

extension Font {
    static let kLargeTitle = Font.system(size: 28, weight: .bold, design: .rounded)
    static let kTitle      = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let kHeadline   = Font.system(size: 16, weight: .semibold, design: .default)
    static let kBody       = Font.system(size: 14, weight: .regular, design: .default)
    static let kCaption    = Font.system(size: 12, weight: .regular, design: .default)
    /// Rounded + tabular for timers and stats so digits don't jitter.
    static func kNumber(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
