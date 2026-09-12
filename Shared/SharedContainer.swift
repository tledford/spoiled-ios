import Foundation

/// Identifiers that let the app and its extensions talk to each other.
///
/// The share extension runs in a separate process with its own container, so it needs
/// two things from the app: the App Group (to read the cached kids/groups snapshot) and
/// the keychain access group (to read the Firebase session the app signed in with).
enum SharedContainer {
    static let appGroupId = "group.dev.tomled.Spoiled"

    /// Keychain access group shared by the app and the share extension.
    ///
    /// `AppIdentifierPrefix` is a build-time variable each target writes into its own
    /// Info.plist, so this resolves to `<TEAMID>.dev.tomled.Spoiled` at runtime.
    static var keychainAccessGroup: String? {
        guard let prefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String,
              !prefix.isEmpty else { return nil }
        return prefix + "dev.tomled.Spoiled"
    }

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroupId) }
}
