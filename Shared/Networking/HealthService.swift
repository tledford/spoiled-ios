import Foundation

struct HealthResponse: Decodable { let status: String }

protocol HealthChecking {
    func check() async -> Bool
}

struct HealthService: HealthChecking {
    private let client: APIClient
    init(client: APIClient = APIClient()) { self.client = client }

    private struct HealthRequest: APIRequest { typealias Response = HealthResponse; let path = "/health" }

    func check() async -> Bool {
        do { let resp = try await client.execute(HealthRequest()); return resp.status.lowercased() == "ok" } catch { return false }
    }
}
