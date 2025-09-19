import Foundation

struct CreateGiftIdeaResponse: Decodable { let id: UUID }

private struct CreateGiftIdeaPayload: Encodable {
    let id: UUID?
    let personName: String
    let giftName: String
    let url: String?
    let notes: String
    let isPurchased: Bool
}

private struct UpdateGiftIdeaPayload: Encodable {
    let personName: String?
    let giftName: String?
    let url: String?
    let notes: String?
    let isPurchased: Bool?
}

private struct CreateGiftIdeaRequest: APIRequest {
    typealias Response = CreateGiftIdeaResponse
    let path: String
    let method: String = "POST"
    let body: Data?

    init(userId: String, idea: GiftIdea) {
        self.path = "/users/\(userId)/gift-ideas"
        let payload = CreateGiftIdeaPayload(
            id: idea.id, // allow server to use our id or generate
            personName: idea.personName,
            giftName: idea.giftName,
            url: idea.url?.absoluteString,
            notes: idea.notes,
            isPurchased: idea.isPurchased
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.body = try? encoder.encode(payload)
    }
}

private struct UpdateGiftIdeaRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "PATCH"
    let body: Data?

    init(userId: String, idea: GiftIdea) {
        self.path = "/users/\(userId)/gift-ideas/\(idea.id.uuidString)"
        let payload = UpdateGiftIdeaPayload(
            personName: idea.personName,
            giftName: idea.giftName,
            url: idea.url?.absoluteString,
            notes: idea.notes,
            isPurchased: idea.isPurchased
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.body = try? encoder.encode(payload)
    }
}

private struct DeleteGiftIdeaRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "DELETE"

    init(userId: String, ideaId: UUID) {
        self.path = "/users/\(userId)/gift-ideas/\(ideaId.uuidString)"
    }
}

struct GiftIdeasService {
    let client: APIClient
    init(client: APIClient = APIClient()) { self.client = client }

    func create(userId: String, idea: GiftIdea) async throws -> UUID {
        let res = try await client.execute(CreateGiftIdeaRequest(userId: userId, idea: idea))
        return res.id
    }

    func update(userId: String, idea: GiftIdea) async throws {
        _ = try await client.execute(UpdateGiftIdeaRequest(userId: userId, idea: idea))
    }

    func delete(userId: String, ideaId: UUID) async throws {
        _ = try await client.execute(DeleteGiftIdeaRequest(userId: userId, ideaId: ideaId))
    }
}
