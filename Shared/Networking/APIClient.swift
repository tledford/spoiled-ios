import Foundation
import Combine

protocol APIRequest: Sendable {
    associatedtype Response: Decodable
    var path: String { get }
    var method: String { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
    /// How long to wait for the server, when the default isn't right for this request.
    var timeout: TimeInterval? { get }
}

extension APIRequest {
    var method: String { "GET" }
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem]? { nil }
    var body: Data? { nil }
    var timeout: TimeInterval? { nil }
}

extension Notification.Name {
    static let authUnauthorized = Notification.Name("AuthUnauthorizedNotification")
}

struct APIClient {
    let config: APIConfig
    let urlSession: URLSession
    /// The signed-in user's token, or nil if nobody is signed in. Throws `APIError.tokenUnavailable` or `.sessionOver`.
    var tokenProvider: ((Bool) async throws -> String?)?
    var onSessionEnded: @Sendable () -> Void

    init(config: APIConfig = AppConfig.api,
         urlSession: URLSession = .shared,
         tokenProvider: ((Bool) async throws -> String?)? = FirebaseSession.tokenProvider,
         onSessionEnded: @escaping @Sendable () -> Void = { NotificationCenter.default.post(name: .authUnauthorized, object: nil) }) {
        self.config = config
        self.urlSession = urlSession
        self.tokenProvider = tokenProvider
        self.onSessionEnded = onSessionEnded
    }

    func execute<R: APIRequest>(_ request: R) async throws -> R.Response {
        var components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false)!
        components.path += request.path
        components.queryItems = request.queryItems
        guard let url = components.url else { throw URLError(.badURL) }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        if let timeout = request.timeout { urlRequest.timeoutInterval = timeout }

        // Default headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let token = try await currentToken(forceRefresh: false)
        if let token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // Merge custom headers last
        for (k, v) in request.headers { urlRequest.setValue(v, forHTTPHeaderField: k) }

        var (data, response) = try await urlSession.data(for: urlRequest)
        guard var http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        // A rejected token may just be out of date. If its replacement is rejected too, the session is over.
        if http.statusCode == 401, token != nil {
            guard let fresh = try await currentToken(forceRefresh: true) else {
                onSessionEnded()
                throw APIError.sessionOver
            }
            urlRequest.setValue("Bearer \(fresh)", forHTTPHeaderField: "Authorization")
            (data, response) = try await urlSession.data(for: urlRequest)
            guard let retried = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            http = retried
            if http.statusCode == 401 { onSessionEnded() }
        }

        if !(200..<300).contains(http.statusCode) {
            let requestId = http.allHeaderFields["X-Request-Id"] as? String
            // Try to decode error payload and optional reqId passthrough
            if let apiErrorWithReq = try? JSONDecoder().decode(APIErrorResponseWithReqId.self, from: data) {
                throw APIError.http(status: http.statusCode, code: apiErrorWithReq.error.code, message: apiErrorWithReq.error.message, requestId: apiErrorWithReq.reqId ?? requestId, rawBody: nil)
            } else if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.http(status: http.statusCode, code: apiError.error.code, message: apiError.error.message, requestId: requestId, rawBody: nil)
            }
            let fallback = String(data: data, encoding: .utf8)
            throw APIError.http(status: http.statusCode, code: "HTTP_\(http.statusCode)", message: fallback ?? "Unknown error", requestId: requestId, rawBody: fallback)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(R.Response.self, from: data)
    }

    private func currentToken(forceRefresh: Bool) async throws -> String? {
        guard let tokenProvider else { return nil }
        do {
            return try await tokenProvider(forceRefresh)
        } catch APIError.sessionOver {
            onSessionEnded()
            throw APIError.sessionOver
        }
    }
}

extension APIClient {
    /// Perform a simple HEAD request to the API root to test reachability.
    func isReachable(timeout: TimeInterval = 5) async -> Bool {
        var request = URLRequest(url: config.baseURL)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        do {
            _ = try await urlSession.data(for: request)
            return true
        } catch { return false }
    }
}

struct APIErrorResponse: Decodable { let error: APIErrorPayload }
struct APIErrorResponseWithReqId: Decodable { let error: APIErrorPayload; let reqId: String? }
struct APIErrorPayload: Decodable { let code: String; let message: String }

enum APIError: Error, LocalizedError {
    case http(status: Int, code: String, message: String, requestId: String?, rawBody: String?)
    case decoding(Error)
    /// No token for now, for a temporary reason like having no connection. The session is still good.
    case tokenUnavailable
    /// Firebase says this session has ended, so the user has to sign in again.
    case sessionOver

    var errorDescription: String? {
        switch self {
        case let .http(status, code, message, requestId, _):
            if let requestId, !requestId.isEmpty { return "HTTP \(status) [\(code)] (reqId=\(requestId)): \(message)" }
            return "HTTP \(status) [\(code)]: \(message)"
        case .decoding(let e):
            return "Decoding error: \(e.localizedDescription)"
        case .tokenUnavailable:
            return "Couldn't confirm your sign-in. Check your connection and try again."
        case .sessionOver:
            return "Your session has ended. Please sign in again."
        }
    }
}
