import Foundation
import FirebaseAuth

// Mirrors /api/v1/bootstrap response shape (tolerant decoding)
struct BootstrapResponse: Decodable {
    let currentUser: APIUser
    let groups: [APIGroup]
    let kids: [APIKid]
    let wishlistItems: [APIWishlistItem]
    let giftIdeas: [APIGiftIdea]
}

struct APIUser: Decodable {
    let id: String
    let name: String
    let email: String
    let birthdate: String? // Accept various formats/null; we'll parse later
    let sizes: Sizes
}

struct APIGroup: Decodable {
    let id: UUID
    let name: String
    let isAdmin: Bool
    let members: [APIMember]
}

struct APIMember: Decodable {
    let id: String
    let name: String
    let wishlistItems: [APIWishlistItem]
    let kids: [APIKidReference]? // Optional nested kids for context
    let sizes: Sizes?
    let birthdate: String?
}

struct APIKidReference: Decodable {
    let id: UUID
    let name: String
    let wishlistItems: [APIWishlistItem]
    let sizes: Sizes?
    let birthdate: String?
}

struct APIKid: Decodable {
    let id: UUID
    let name: String
    let birthdate: String? // Accept various formats/null; we'll parse later
    let wishlistItems: [APIWishlistItem]
    let sizes: Sizes
}

struct APIWishlistItem: Decodable {
    let id: UUID
    let name: String
    let description: String?
    let price: Double?
    let link: String? // decode as string to avoid throwing on invalid URLs
    let isPurchased: Bool?
    let purchasedAt: String?
    let purchasedBy: String?
    let assignedGroupIds: [UUID]?
}

struct APIGiftIdea: Decodable {
    let id: UUID
    let personName: String
    let giftName: String
    let url: String? // decode as string to avoid throwing on invalid URLs
    let notes: String?
    let isPurchased: Bool?
}

struct BootstrapRequest: APIRequest { typealias Response = BootstrapResponse; let path = "/bootstrap" }

struct BootstrapService {
    let client: APIClient
    init(client: APIClient = APIClient()) { self.client = client }

    func load() async throws -> (User, [Group], [Kid], [WishlistItem], [GiftIdea], Bool) {
        do {
            let response = try await client.execute(BootstrapRequest())
            // Map API models to app models
            let user = User(id: response.currentUser.id,
                            name: response.currentUser.name,
                            email: response.currentUser.email,
                            birthdate: parseAPIDate(response.currentUser.birthdate) ?? Date(),
                            sizes: response.currentUser.sizes)

            let groups: [Group] = response.groups.map { g in
                let members: [GroupMember] = g.members.map { m in
                    let kidModels: [GroupMemberKid] = (m.kids ?? []).map { k in
                        GroupMemberKid(
                            id: k.id,
                            name: k.name,
                            wishlistItems: k.wishlistItems.map { $0.asAppModel() },
                            sizes: k.sizes ?? Sizes(),
                            birthdate: parseAPIDate(k.birthdate)
                        )
                    }
                    return GroupMember(
                        id: m.id,
                        name: m.name,
                        wishlistItems: m.wishlistItems.map { $0.asAppModel() },
                        kids: kidModels,
                        sizes: m.sizes ?? Sizes(),
                        birthdate: parseAPIDate(m.birthdate)
                    )
                }
                return Group(id: g.id, name: g.name, isAdmin: g.isAdmin, members: members)
            }

            let kids: [Kid] = response.kids.map { k in
                Kid(id: k.id, name: k.name, birthdate: parseAPIDate(k.birthdate) ?? Date(), wishlistItems: k.wishlistItems.map { $0.asAppModel() }, sizes: k.sizes)
            }

            let myItems: [WishlistItem] = response.wishlistItems.map { $0.asAppModel() }
            let ideas: [GiftIdea] = response.giftIdeas.map { g in
                GiftIdea(
                    id: g.id,
                    personName: g.personName,
                    giftName: g.giftName,
                    url: g.url.flatMap { URL(string: $0) },
                    notes: g.notes ?? "",
                    isPurchased: g.isPurchased ?? false
                )
            }

            return (user, groups, kids, myItems, ideas, false)
        } catch let e as DecodingError {
            throw APIError.decoding(e)
        } catch let api as APIError {
            // If current user not found, attempt to create and retry once
            if case let .http(status, code, _, _, _) = api, status == 404, code == "NOT_FOUND" {
                // Try to create the user, then retry bootstrap once
                try await createCurrentUserIfNeeded()
                let response = try await client.execute(BootstrapRequest())
                let user = User(id: response.currentUser.id,
                                name: response.currentUser.name,
                                email: response.currentUser.email,
                                birthdate: parseAPIDate(response.currentUser.birthdate) ?? Date(),
                                sizes: response.currentUser.sizes)
                let groups: [Group] = response.groups.map { g in
                    let members: [GroupMember] = g.members.map { m in
                        let kidModels: [GroupMemberKid] = (m.kids ?? []).map { k in
                            GroupMemberKid(
                                id: k.id,
                                name: k.name,
                                wishlistItems: k.wishlistItems.map { $0.asAppModel() },
                                sizes: k.sizes ?? Sizes(),
                                birthdate: parseAPIDate(k.birthdate)
                            )
                        }
                        return GroupMember(
                            id: m.id,
                            name: m.name,
                            wishlistItems: m.wishlistItems.map { $0.asAppModel() },
                            kids: kidModels,
                            sizes: m.sizes ?? Sizes(),
                            birthdate: parseAPIDate(m.birthdate)
                        )
                    }
                    return Group(id: g.id, name: g.name, isAdmin: g.isAdmin, members: members)
                }
                let kids: [Kid] = response.kids.map { k in
                    Kid(id: k.id, name: k.name, birthdate: parseAPIDate(k.birthdate) ?? Date(), wishlistItems: k.wishlistItems.map { $0.asAppModel() }, sizes: k.sizes)
                }
                let myItems: [WishlistItem] = response.wishlistItems.map { $0.asAppModel() }
                let ideas: [GiftIdea] = response.giftIdeas.map { g in
                    GiftIdea(
                        id: g.id,
                        personName: g.personName,
                        giftName: g.giftName,
                        url: g.url.flatMap { URL(string: $0) },
                        notes: g.notes ?? "",
                        isPurchased: g.isPurchased ?? false
                    )
                }
                return (user, groups, kids, myItems, ideas, true)
            }
            throw api
        }
    }

    // POST /api/v1/users using current auth context, optionally sending email/name from Firebase token
    private func createCurrentUserIfNeeded() async throws {
        struct CreateUserRequest: APIRequest {
            typealias Response = CreateUserResponse
            let path = "/users"
            let method = "POST"
            let body: Data?
            init(email: String?, name: String?) {
                var payload: [String: Any] = [:]
                if let email, !email.isEmpty { payload["email"] = email }
                if let name, !name.isEmpty { payload["name"] = name }
                if payload.isEmpty {
                    self.body = nil
                } else {
                    self.body = try? JSONSerialization.data(withJSONObject: payload, options: [])
                }
            }
        }
        struct CreateUserResponse: Decodable { let id: String }
        let user = Auth.auth().currentUser
        let email = user?.email
        let name = user?.displayName
        _ = try await client.execute(CreateUserRequest(email: email, name: name))
    }
}

private extension APIWishlistItem {
    func asAppModel() -> WishlistItem {
        WishlistItem(
            id: id,
            name: name,
            description: description ?? "",
            price: price,
            link: link.flatMap { URL(string: $0) },
            isPurchased: isPurchased ?? false,
            purchasedAt: parseAPIDate(purchasedAt),
            purchasedBy: purchasedBy,
            assignedGroupIds: assignedGroupIds ?? []
        )
    }
}

// (Removed local parseDate; using shared parseAPIDate in Utils.)
