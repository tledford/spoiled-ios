import Foundation

struct APIConfig: Sendable {
    var scheme: String
    var host: String
    var port: Int?
    var version: String

    init(scheme: String = "http", host: String = "localhost", port: Int? = 8787, version: String = "v1") {
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
}

enum AppConfig {
    // Update these to swap environments quickly
    static var api: APIConfig = APIConfig(host: "192.168.1.179")
}
