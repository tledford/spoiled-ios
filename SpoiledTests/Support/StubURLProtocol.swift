import Foundation
@testable import Spoiled

/// Answers `URLSession` requests from a closure, so networking code can be tested end to end.
/// Each stub gets its own host, which keeps tests running in parallel out of each other's way.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (status: Int, body: Data)

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlers: [String: Handler] = [:]

    /// An `APIClient` whose requests all go to `handler`.
    static func client(tokenProvider: ((Bool) async throws -> String?)? = nil,
                       onSessionEnded: @escaping @Sendable () -> Void = {},
                       handler: @escaping Handler) -> APIClient {
        let host = "\(UUID().uuidString.lowercased()).test"
        lock.withLock { handlers[host] = handler }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return APIClient(config: APIConfig(scheme: "https", host: host),
                         urlSession: URLSession(configuration: configuration),
                         tokenProvider: tokenProvider,
                         onSessionEnded: onSessionEnded)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}

    override func startLoading() {
        let request = request
        let handler = Self.lock.withLock { request.url?.host.flatMap { Self.handlers[$0] } }
        // A handler may block to hold a request open, so keep it off the session's own queue.
        DispatchQueue.global().async { [self] in
            do {
                guard let handler else { throw URLError(.unsupportedURL) }
                let (status, body) = try handler(request)
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: body)
                client?.urlProtocolDidFinishLoading(self)
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
        }
    }
}

/// Thread-safe storage for what a stub handler saw.
final class Recorder<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Value] = []

    func append(_ value: Value) { lock.withLock { stored.append(value) } }
    var values: [Value] { lock.withLock { stored } }
    var count: Int { values.count }
}

extension Data {
    static func apiError(code: String, message: String = "Nope") -> Data {
        Data(#"{"error":{"code":"\#(code)","message":"\#(message)"}}"#.utf8)
    }

    /// A minimal successful `/bootstrap` response for the given user.
    static func bootstrap(userId: String = "me", name: String = "Me") -> Data {
        Data("""
        {"currentUser":{"id":"\(userId)","name":"\(name)","email":"\(userId)@example.com","birthdate":null,
        "sizes":{"shirt":"","pants":"","shoes":"","sweatshirt":"","hat":""},"wishlistPurchasesResetDate":null},
        "groups":[],"kids":[],"wishlistItems":[],"giftIdeas":[]}
        """.utf8)
    }
}
