import Foundation

struct CreateKidResponse: Decodable { let id: UUID }

private struct CreateKidPayload: Encodable {
    let id: UUID?
    let name: String
    let birthdate: Date
    let sizes: String?
}

private struct UpdateKidPayload: Encodable {
    let name: String?
    let birthdate: Date?
    let sizes: String?
}

private struct CreateKidRequest: APIRequest {
    typealias Response = CreateKidResponse
    let path: String
    let method: String = "POST"
    let body: Data?

    init(userId: UUID, kid: Kid, sizesJSON: String?) {
        self.path = "/users/\(userId.uuidString)/kids"
        let payload = CreateKidPayload(id: kid.id, name: kid.name, birthdate: kid.birthdate, sizes: sizesJSON)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.body = try? encoder.encode(payload)
    }
}

private struct UpdateKidRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "PATCH"
    let body: Data?

    init(userId: UUID, kid: Kid, sizesJSON: String?) {
        self.path = "/users/\(userId.uuidString)/kids/\(kid.id.uuidString)"
        let payload = UpdateKidPayload(name: kid.name, birthdate: kid.birthdate, sizes: sizesJSON)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.body = try? encoder.encode(payload)
    }
}

private struct DeleteKidRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "DELETE"

    init(userId: UUID, kidId: UUID) {
        self.path = "/users/\(userId.uuidString)/kids/\(kidId.uuidString)"
    }
}

struct KidsService {
    let client: APIClient
    init(client: APIClient = APIClient()) { self.client = client }

    func create(userId: UUID, kid: Kid) async throws -> UUID {
        let sizesData = try JSONEncoder().encode(kid.sizes)
        let sizesJSON = String(data: sizesData, encoding: .utf8)
        let res = try await client.execute(CreateKidRequest(userId: userId, kid: kid, sizesJSON: sizesJSON))
        return res.id
    }

    func update(userId: UUID, kid: Kid) async throws {
        let sizesData = try JSONEncoder().encode(kid.sizes)
        let sizesJSON = String(data: sizesData, encoding: .utf8)
        _ = try await client.execute(UpdateKidRequest(userId: userId, kid: kid, sizesJSON: sizesJSON))
    }

    func delete(userId: UUID, kidId: UUID) async throws {
        _ = try await client.execute(DeleteKidRequest(userId: userId, kidId: kidId))
    }
}
