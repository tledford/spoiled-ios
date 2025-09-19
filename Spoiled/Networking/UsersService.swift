import Foundation

struct OkResponse: Decodable { let ok: Bool }

private struct UpdateUserPayload: Encodable {
    let name: String?
    let email: String?
    let birthdate: Date?
    let sizes: String?
}

private struct UpdateUserRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "PATCH"
    let headers: [String: String] = [:]
    let body: Data?

    init(userId: String, name: String?, email: String?, birthdate: Date?, sizesJSON: String?) {
        self.path = "/users/\(userId)"
        let payload = UpdateUserPayload(name: name, email: email, birthdate: birthdate, sizes: sizesJSON)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.body = try? encoder.encode(payload)
    }
}

struct UsersService {
    let client: APIClient
    init(client: APIClient = APIClient()) { self.client = client }

    func updateUser(userId: String, name: String, email: String, birthdate: Date, sizes: Sizes) async throws {
        // sizes must be a JSON string per API schema
        let sizesData = try JSONEncoder().encode(sizes)
        let sizesJSON = String(data: sizesData, encoding: .utf8)
        _ = try await client.execute(UpdateUserRequest(userId: userId, name: name, email: email, birthdate: birthdate, sizesJSON: sizesJSON))
    }
}
