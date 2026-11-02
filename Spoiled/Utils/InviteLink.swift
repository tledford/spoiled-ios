import Foundation

enum InviteLink {
    /// The invite code in a link like `https://prod.tomled.dev/invite/ABCDE12345`, or nil if it isn't one.
    static func code(from url: URL) -> String? {
        guard url.scheme == "https" || url.scheme == "http",
              [AppConfig.production.host, AppConfig.api.host].contains(url.host) else { return nil }
        let parts = url.pathComponents
        guard parts.count == 3, parts[1] == "invite", !parts[2].isEmpty else { return nil }
        return parts[2]
    }
}
