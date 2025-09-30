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
}

enum AppConfig {
    // Update these to swap environments quickly
   static var api: APIConfig = APIConfig(scheme: "http", host: "192.168.1.179", port: 8787, version: "v1") // Local dev
//      static var api: APIConfig = APIConfig(scheme: "https", host: "prod.tomled.dev", version: "v1") // CF Worker
}
