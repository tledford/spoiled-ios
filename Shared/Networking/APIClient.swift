import Foundation
import FirebaseAuth
import Combine

protocol APIRequest: Sendable {
    associatedtype Response: Decodable
    var path: String { get }
    var method: String { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem]? { get }
    var body: Data? { get }
}

extension APIRequest {
    var method: String { "GET" }
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem]? { nil }
    var body: Data? { nil }
}

extension Notification.Name {
    static let authUnauthorized = Notification.Name("AuthUnauthorizedNotification")
}

struct APIClient {
    let config: APIConfig
    let urlSession: URLSession
    var tokenProvider: ((Bool) async -> String?)?

    init(config: APIConfig = AppConfig.api, urlSession: URLSession = .shared, tokenProvider: ((Bool) async -> String?)? = nil) {
        self.config = config
        self.urlSession = urlSession
        self.tokenProvider = tokenProvider
    }

    func execute<R: APIRequest>(_ request: R) async throws -> R.Response {
        var components = URLComponents(url: config.baseURL, resolvingAgainstBaseURL: false)!
        components.path += request.path
        components.queryItems = request.queryItems
        guard let url = components.url else { throw URLError(.badURL) }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body

        // Default headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if request.body != nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        // Firebase Bearer token via provider
        if let token = await tokenProvider?(false) {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let user = Auth.auth().currentUser, let token = try? await user.getIDToken() {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let user = Auth.auth().currentUser, let token = try? await user.getIDTokenResult(forcingRefresh: true).token {
            // As a last resort, force-refresh once to prime the token on first load
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // Merge custom headers last
        for (k, v) in request.headers { urlRequest.setValue(v, forHTTPHeaderField: k) }

        var (data, response) = try await urlSession.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        // On 401, try one forced refresh of the ID token and retry once
        if http.statusCode == 401 {
            if let fresh = await tokenProvider?(true) {
                var retryReq = urlRequest
                retryReq.setValue("Bearer \(fresh)", forHTTPHeaderField: "Authorization")
                (data, response) = try await urlSession.data(for: retryReq)
            } else if let user = Auth.auth().currentUser, let fresh = try? await user.getIDTokenResult(forcingRefresh: true).token {
                var retryReq = urlRequest
                retryReq.setValue("Bearer \(fresh)", forHTTPHeaderField: "Authorization")
                (data, response) = try await urlSession.data(for: retryReq)
            }
        }

        guard let http2 = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if !(200..<300).contains(http2.statusCode) {
            if http2.statusCode == 401 {
                NotificationCenter.default.post(name: .authUnauthorized, object: nil)
            }
            let requestId = http.allHeaderFields["X-Request-Id"] as? String
            // Try to decode error payload and optional reqId passthrough
            if let apiErrorWithReq = try? JSONDecoder().decode(APIErrorResponseWithReqId.self, from: data) {
                throw APIError.http(status: http2.statusCode, code: apiErrorWithReq.error.code, message: apiErrorWithReq.error.message, requestId: apiErrorWithReq.reqId ?? requestId, rawBody: nil)
            } else if let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.http(status: http2.statusCode, code: apiError.error.code, message: apiError.error.message, requestId: requestId, rawBody: nil)
            }
            let fallback = String(data: data, encoding: .utf8)
            throw APIError.http(status: http2.statusCode, code: "HTTP_\(http2.statusCode)", message: fallback ?? "Unknown error", requestId: requestId, rawBody: fallback)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(R.Response.self, from: data)
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

    var errorDescription: String? {
        switch self {
        case let .http(status, code, message, requestId, _):
            if let requestId, !requestId.isEmpty { return "HTTP \(status) [\(code)] (reqId=\(requestId)): \(message)" }
            return "HTTP \(status) [\(code)]: \(message)"
        case .decoding(let e):
            return "Decoding error: \(e.localizedDescription)"
        }
    }
}
