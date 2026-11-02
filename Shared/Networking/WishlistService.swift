import Foundation

struct CreateWishlistItemResponse: Decodable { let id: UUID }

private struct CreateWishlistItemPayload: Encodable {
    let id: UUID?
    let name: String
    let description: String?
    let link: String?
    let quantityDesired: Int?
    let assignedGroupIds: [UUID]?
}

private struct UpdateWishlistItemPayload: Encodable {
    let name: String?
    let description: String?
    let link: String?
    let quantityDesired: Int?
    let assignedGroupIds: [UUID]?
}

private struct SetPurchaseQuantityPayload: Encodable {
    let quantity: Int
}

// MARK: - Requests

private struct CreateUserItemRequest: APIRequest {
    typealias Response = CreateWishlistItemResponse
    let path: String
    let method: String = "POST"
    let body: Data?

    init(userId: String, item: WishlistItem) {
        self.path = "/users/\(userId)/wishlist"
        let payload = CreateWishlistItemPayload(
            id: item.id, // allow server to use our id or generate
            name: item.name,
            description: item.description.isEmpty ? nil : item.description,
            link: item.link?.absoluteString,
            quantityDesired: item.quantityDesired,
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

    init(userId: String, kidId: UUID, item: WishlistItem) {
        self.path = "/users/\(userId)/kids/\(kidId.uuidString)/wishlist"
        let payload = CreateWishlistItemPayload(
            id: item.id,
            name: item.name,
            description: item.description.isEmpty ? nil : item.description,
            link: item.link?.absoluteString,
            quantityDesired: item.quantityDesired,
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

    init(userId: String, item: WishlistItem) {
        self.path = "/users/\(userId)/wishlist/\(item.id.uuidString)"
        let payload = UpdateWishlistItemPayload(
            name: item.name,
            description: item.description,
            link: item.link?.absoluteString,
            quantityDesired: item.quantityDesired,
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

    init(userId: String, kidId: UUID, item: WishlistItem) {
        self.path = "/users/\(userId)/kids/\(kidId.uuidString)/wishlist/\(item.id.uuidString)"
        let payload = UpdateWishlistItemPayload(
            name: item.name,
            description: item.description,
            link: item.link?.absoluteString,
            quantityDesired: item.quantityDesired,
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

    init(userId: String, itemId: UUID) {
        self.path = "/users/\(userId)/wishlist/\(itemId.uuidString)"
    }
}

private struct DeleteKidItemRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "DELETE"

    init(userId: String, kidId: UUID, itemId: UUID) {
        self.path = "/users/\(userId)/kids/\(kidId.uuidString)/wishlist/\(itemId.uuidString)"
    }
}

struct SetPurchaseQuantityResponse: Decodable { let ok: Bool; let isPurchased: Bool }

private struct SetGroupPurchaseQuantityRequest: APIRequest {
    typealias Response = SetPurchaseQuantityResponse
    let path: String
    let method: String = "PATCH"
    let body: Data?
    init(groupId: UUID, memberUserId: String, itemId: UUID, quantity: Int) {
        self.path = "/groups/\(groupId.uuidString)/members/\(memberUserId)/wishlist/\(itemId.uuidString)/purchase"
        self.body = try? JSONEncoder().encode(SetPurchaseQuantityPayload(quantity: quantity))
    }
}

private struct SetGroupKidPurchaseQuantityRequest: APIRequest {
    typealias Response = SetPurchaseQuantityResponse
    let path: String
    let method: String = "PATCH"
    let body: Data?
    init(groupId: UUID, kidId: UUID, itemId: UUID, quantity: Int) {
        self.path = "/groups/\(groupId.uuidString)/kids/\(kidId.uuidString)/wishlist/\(itemId.uuidString)/purchase"
        self.body = try? JSONEncoder().encode(SetPurchaseQuantityPayload(quantity: quantity))
    }
}

struct WishlistService {
    let client: APIClient
    init(client: APIClient = APIClient()) { self.client = client }

    func createUserItem(userId: String, item: WishlistItem) async throws -> UUID {
        let res = try await client.execute(CreateUserItemRequest(userId: userId, item: item))
        return res.id
    }

    func createKidItem(userId: String, kidId: UUID, item: WishlistItem) async throws -> UUID {
        let res = try await client.execute(CreateKidItemRequest(userId: userId, kidId: kidId, item: item))
        return res.id
    }

    func updateUserItem(userId: String, item: WishlistItem) async throws {
        _ = try await client.execute(UpdateUserItemRequest(userId: userId, item: item))
    }

    func updateKidItem(userId: String, kidId: UUID, item: WishlistItem) async throws {
        _ = try await client.execute(UpdateKidItemRequest(userId: userId, kidId: kidId, item: item))
    }

    func deleteUserItem(userId: String, itemId: UUID) async throws {
        _ = try await client.execute(DeleteUserItemRequest(userId: userId, itemId: itemId))
    }

    func deleteKidItem(userId: String, kidId: UUID, itemId: UUID) async throws {
        _ = try await client.execute(DeleteKidItemRequest(userId: userId, kidId: kidId, itemId: itemId))
    }

    /// Sets how many of the item the caller has bought. Returns whether the item is now fully purchased.
    func setGroupMemberItemPurchase(groupId: UUID, memberUserId: String, itemId: UUID, quantity: Int) async throws -> Bool {
        try await client.execute(SetGroupPurchaseQuantityRequest(groupId: groupId, memberUserId: memberUserId, itemId: itemId, quantity: quantity)).isPurchased
    }

    /// Sets how many of the kid's item the caller has bought. Returns whether the item is now fully purchased.
    func setGroupKidItemPurchase(groupId: UUID, kidId: UUID, itemId: UUID, quantity: Int) async throws -> Bool {
        try await client.execute(SetGroupKidPurchaseQuantityRequest(groupId: groupId, kidId: kidId, itemId: itemId, quantity: quantity)).isPurchased
    }
}
