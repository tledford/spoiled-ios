import Foundation

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

struct APIClient {
    let config: APIConfig
    let urlSession: URLSession

    init(config: APIConfig = AppConfig.api, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
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
        // Dev header for current user
        urlRequest.setValue(AppConfig.devUserId.uuidString, forHTTPHeaderField: "X-User-Id")
        // Merge custom headers last
        for (k, v) in request.headers { urlRequest.setValue(v, forHTTPHeaderField: k) }

        let (data, response) = try await urlSession.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

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
