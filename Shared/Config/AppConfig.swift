import Foundation

struct APIConfig: Sendable {
    var scheme: String
    var host: String
    var port: Int?
    var version: String

    init(scheme: String = "http", host: String = "localhost", port: Int? = nil, version: String = "v1") {
        self.scheme = scheme
        self.host = host
        self.port = port
        self.version = version
    }

    var baseURL: URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if let port { components.port = port }
        components.path = "/api/\(version)"
        return components.url! // Safe for known-good config
    }

    // Root (no /api/v1) for serving static/legal docs
    var rootURL: URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if let port { components.port = port }
        return components.url!
    }

    var privacyPolicyURL: URL { rootURL.appendingPathComponent("legal/privacy_policy") }

    /// A worker on the local network, or nil when no host has been set.
    static func local(host: String?, port: String?) -> APIConfig? {
        guard let host, !host.isEmpty else { return nil }
        return APIConfig(scheme: "http", host: host, port: port.flatMap(Int.init), version: "v1")
    }
}

enum AppConfig {
    static let production = APIConfig(scheme: "https", host: "prod.tomled.dev", version: "v1")

    /// Production, unless this is a Debug build that was given a local worker's address.
    /// A Release build can't point anywhere else. See "Environment switching" in AGENTS.md.
    static var api: APIConfig {
        #if DEBUG
        let info = Bundle.main.infoDictionary
        if let local = APIConfig.local(host: info?["SpoiledLocalAPIHost"] as? String, port: info?["SpoiledLocalAPIPort"] as? String) {
            return local
        }
        #endif
        return production
    }
}
