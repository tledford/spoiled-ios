import SwiftUI

// MARK: - App Color Tokens
// All colors are defined here. Use these instead of hardcoded color literals.
enum AppColors {
    // MARK: Backgrounds
    /// Deep midnight navy — the primary app background
    static let background = Color("AppBackground")
    /// Slightly elevated surface for cards and list rows
    static let surface = Color("AppSurfappace")
    /// A more prominent elevated surface (e.g. modals)
    static let surfaceElevated = Color("AppSurfaceElevated")

    // MARK: Brand Accents
    /// Warm amber/gold — active states, badges, highlights
    static let gold = Color("BrandGold")
    /// Soft rose/pink — splash screen branding, decorative accents
    static let rose = Color("BrandRose")

    // MARK: Semantic
    /// Positive / purchased / success
    static let success = Color.green
    /// Destructive / error
    static let danger = Color.red

    // MARK: Text
    static let labelPrimary    = Color.primary
    static let labelSecondary  = Color.secondary
    static let labelTertiary   = Color(UIColor.tertiaryLabel)
}

// MARK: - Color Assets with dynamic fallbacks
// These are defined as programmatic colors if no asset exists.
// Xcode asset catalog entries with these names take priority.
extension Color {
    static func appBackground(scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.051, green: 0.055, blue: 0.102) : Color(UIColor.systemGroupedBackground)
    }
    static func appSurface(scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.10, green: 0.11, blue: 0.17) : Color(UIColor.secondarySystemGroupedBackground)
    }
    /// Adaptive background — deep navy in dark, systemGroupedBackground in light.
    static let appBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.051, green: 0.055, blue: 0.102, alpha: 1)
            : UIColor.systemGroupedBackground
    })
    /// Adaptive surface — slightly elevated in dark, secondarySystemGroupedBackground in light.
    static let appSurface = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 1)
            : UIColor.secondarySystemGroupedBackground
    })
    static let brandGold  = Color(red: 0.91, green: 0.67, blue: 0.24)  // #E8AA3C warm amber
    static let brandBlue  = Color(red: 0.40, green: 0.70, blue: 1.0)   // #66B2FF light blue
    static let brandRose  = Color(red: 0.94, green: 0.42, blue: 0.50)  // #F06B80 rose pink
    static let goldMuted  = Color(red: 0.91, green: 0.67, blue: 0.24).opacity(0.18)
    static let roseMuted  = Color(red: 0.94, green: 0.42, blue: 0.50).opacity(0.18)
}
