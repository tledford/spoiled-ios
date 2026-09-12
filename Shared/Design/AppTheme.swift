import SwiftUI
import Combine

// MARK: - AppTheme
/// The user's appearance preference. `system` follows the device setting.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: return "iphone"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    /// The scheme to force, or `nil` to follow the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - ThemeStore
/// Holds the selected `AppTheme` and persists it to the App Group so the share
/// extension renders in the same appearance as the app.
@MainActor
final class ThemeStore: ObservableObject {
    private static let key = "appTheme"

    @Published var theme: AppTheme {
        didSet {
            guard theme != oldValue else { return }
            Self.store.set(theme.rawValue, forKey: Self.key)
        }
    }

    init() {
        theme = Self.load()
    }

    /// App Group defaults when available, falling back to the process's own defaults.
    private nonisolated static var store: UserDefaults { SharedContainer.defaults ?? .standard }

    private nonisolated static func load() -> AppTheme {
        guard let raw = store.string(forKey: key), let theme = AppTheme(rawValue: raw) else {
            return .system
        }
        return theme
    }

    /// The scheme to apply, or `nil` to follow the device.
    var colorScheme: ColorScheme? { theme.colorScheme }

    /// Read the stored preference without building a store. Used by the share
    /// extension, which only needs the value once at launch.
    nonisolated static var currentColorScheme: ColorScheme? { load().colorScheme }
}
