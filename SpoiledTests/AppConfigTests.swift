import Foundation
import Testing
@testable import Spoiled

struct AppConfigTests {
    @Test func noHostMeansNoLocalServer() {
        #expect(APIConfig.local(host: nil, port: nil) == nil)
        // What an unset build setting becomes in Info.plist.
        #expect(APIConfig.local(host: "", port: "") == nil)
    }

    @Test func aHostAndPortPointAtALocalServer() {
        let config = APIConfig.local(host: "192.168.1.100", port: "8788")
        #expect(config?.baseURL.absoluteString == "http://192.168.1.100:8788/api/v1")
    }

    @Test func thePortIsOptional() {
        let config = APIConfig.local(host: "192.168.1.100", port: "")
        #expect(config?.baseURL.absoluteString == "http://192.168.1.100/api/v1")
    }

    @Test func productionIsTheDefault() {
        #expect(AppConfig.production.baseURL.absoluteString == "https://prod.tomled.dev/api/v1")
    }
}
