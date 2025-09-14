import Foundation

struct CreateWishlistItemResponse: Decodable { let id: UUID }

private struct CreateWishlistItemPayload: Encodable {
    let id: UUID?
    let name: String
    let description: String?
    let price: Double?
    let link: String?
    let assignedGroupIds: [UUID]?
}

private struct UpdateWishlistItemPayload: Encodable {
    let name: String?
    let description: String?
    let price: Double?
    let link: String?
    let isPurchased: Bool?
    let assignedGroupIds: [UUID]?
}

// MARK: - Requests

private struct CreateUserItemRequest: APIRequest {
    typealias Response = CreateWishlistItemResponse
    let path: String
    let method: String = "POST"
    let body: Data?

    init(userId: UUID, item: WishlistItem) {
        self.path = "/users/\(userId.uuidString)/wishlist"
        let payload = CreateWishlistItemPayload(
            id: item.id, // allow server to use our id or generate
            name: item.name,
            description: item.description.isEmpty ? nil : item.description,
            price: item.price,
            link: item.link?.absoluteString,
            assignedGroupIds: item.assignedGroupIds
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.body = try? encoder.encode(payload)
    }
}

private struct CreateKidItemRequest: APIRequest {
    typealias Response = CreateWishlistItemResponse
    let path: String
    let method: String = "POST"
    let body: Data?

    init(userId: UUID, kidId: UUID, item: WishlistItem) {
        self.path = "/users/\(userId.uuidString)/kids/\(kidId.uuidString)/wishlist"
        let payload = CreateWishlistItemPayload(
            id: item.id,
            name: item.name,
            description: item.description.isEmpty ? nil : item.description,
            price: item.price,
            link: item.link?.absoluteString,
            assignedGroupIds: item.assignedGroupIds
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.body = try? encoder.encode(payload)
    }
}

private struct UpdateUserItemRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "PATCH"
    let body: Data?

    init(userId: UUID, item: WishlistItem) {
        self.path = "/users/\(userId.uuidString)/wishlist/\(item.id.uuidString)"
        let payload = UpdateWishlistItemPayload(
            name: item.name,
            description: item.description,
            price: item.price,
            link: item.link?.absoluteString,
            isPurchased: item.isPurchased,
            assignedGroupIds: item.assignedGroupIds
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.body = try? encoder.encode(payload)
    }
}

private struct UpdateKidItemRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "PATCH"
    let body: Data?

    init(userId: UUID, kidId: UUID, item: WishlistItem) {
        self.path = "/users/\(userId.uuidString)/kids/\(kidId.uuidString)/wishlist/\(item.id.uuidString)"
        let payload = UpdateWishlistItemPayload(
            name: item.name,
            description: item.description,
            price: item.price,
            link: item.link?.absoluteString,
            isPurchased: item.isPurchased,
            assignedGroupIds: item.assignedGroupIds
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.body = try? encoder.encode(payload)
    }
}

private struct DeleteUserItemRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "DELETE"

    init(userId: UUID, itemId: UUID) {
        self.path = "/users/\(userId.uuidString)/wishlist/\(itemId.uuidString)"
    }
}

private struct DeleteKidItemRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "DELETE"

    init(userId: UUID, kidId: UUID, itemId: UUID) {
        self.path = "/users/\(userId.uuidString)/kids/\(kidId.uuidString)/wishlist/\(itemId.uuidString)"
    }
}

private struct ToggleGroupPurchaseRequest: APIRequest {
    struct ToggleResponse: Decodable { let ok: Bool; let isPurchased: Bool; let purchasedAt: String?; let purchasedBy: UUID? }
    typealias Response = ToggleResponse
    let path: String
    let method: String = "PATCH"
    init(groupId: UUID, memberUserId: UUID, itemId: UUID) {
        self.path = "/groups/\(groupId.uuidString)/members/\(memberUserId.uuidString)/wishlist/\(itemId.uuidString)/purchase"
    }
}

private struct ToggleGroupKidPurchaseRequest: APIRequest {
    struct ToggleResponse: Decodable { let ok: Bool; let isPurchased: Bool; let purchasedAt: String?; let purchasedBy: UUID? }
    typealias Response = ToggleResponse
    let path: String
    let method: String = "PATCH"
    init(groupId: UUID, kidId: UUID, itemId: UUID) {
        self.path = "/groups/\(groupId.uuidString)/kids/\(kidId.uuidString)/wishlist/\(itemId.uuidString)/purchase"
    }
}

struct WishlistService {
    let client: APIClient
    init(client: APIClient = APIClient()) { self.client = client }

    func createUserItem(userId: UUID, item: WishlistItem) async throws -> UUID {
        let res = try await client.execute(CreateUserItemRequest(userId: userId, item: item))
        return res.id
    }

    func createKidItem(userId: UUID, kidId: UUID, item: WishlistItem) async throws -> UUID {
        let res = try await client.execute(CreateKidItemRequest(userId: userId, kidId: kidId, item: item))
        return res.id
    }

    func updateUserItem(userId: UUID, item: WishlistItem) async throws {
        _ = try await client.execute(UpdateUserItemRequest(userId: userId, item: item))
    }

    func updateKidItem(userId: UUID, kidId: UUID, item: WishlistItem) async throws {
        _ = try await client.execute(UpdateKidItemRequest(userId: userId, kidId: kidId, item: item))
    }

    func deleteUserItem(userId: UUID, itemId: UUID) async throws {
        _ = try await client.execute(DeleteUserItemRequest(userId: userId, itemId: itemId))
    }

    func deleteKidItem(userId: UUID, kidId: UUID, itemId: UUID) async throws {
        _ = try await client.execute(DeleteKidItemRequest(userId: userId, kidId: kidId, itemId: itemId))
    }

    func toggleGroupMemberItem(groupId: UUID, memberUserId: UUID, itemId: UUID) async throws -> (isPurchased: Bool, purchasedAt: Date?, purchasedBy: UUID?) {
        let res = try await client.execute(ToggleGroupPurchaseRequest(groupId: groupId, memberUserId: memberUserId, itemId: itemId))
        let date = parseAPIDate(res.purchasedAt)
        return (res.isPurchased, date, res.purchasedBy)
    }

    func toggleGroupKidItem(groupId: UUID, kidId: UUID, itemId: UUID) async throws -> (isPurchased: Bool, purchasedAt: Date?, purchasedBy: UUID?) {
        let res = try await client.execute(ToggleGroupKidPurchaseRequest(groupId: groupId, kidId: kidId, itemId: itemId))
        let date = parseAPIDate(res.purchasedAt)
        return (res.isPurchased, date, res.purchasedBy)
    }
}
