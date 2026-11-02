import Foundation
import FirebaseAuth

// Mirrors /api/v1/bootstrap response shape (tolerant decoding)
struct BootstrapResponse: Decodable {
    let currentUser: APIUser
    let groups: [APIGroup]
    let kids: [APIKid]
    let wishlistItems: [APIWishlistItem]
    let giftIdeas: [APIGiftIdea]
    let invitations: [APIGroupInvitation]?
}

/// Everything `/bootstrap` returns, as app models.
struct BootstrapData: Codable {
    var user: User
    var groups: [Group]
    var kids: [Kid]
    var wishlistItems: [WishlistItem]
    var giftIdeas: [GiftIdea]
    var invitations: [GroupInvitation]
}

struct APIUser: Decodable {
    let id: String
    let name: String
    let email: String
    let birthdate: String? // Accept various formats/null; we'll parse later
    let sizes: Sizes
    let wishlistPurchasesResetDate: String?
}

struct APIGroup: Decodable {
    let id: UUID
    let name: String
    let isAdmin: Bool
    let members: [APIMember]
    let pendingInvitations: [APIPendingInvitation]?
}

struct APIGroupInvitation: Decodable {
    let id: String
    let groupId: UUID
    let groupName: String
    let invitedByName: String?
    let invitedAt: String
}

struct APIPendingInvitation: Decodable {
    let email: String
    let role: String
    let invitedAt: String
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
    let guardianEmails: [String]?
}

struct APIKid: Decodable {
    let id: UUID
    let name: String
    let birthdate: String? // Accept various formats/null; we'll parse later
    let wishlistItems: [APIWishlistItem]
    let sizes: Sizes
    let guardianEmails: [String]?
}

struct APIWishlistItem: Decodable {
    let id: UUID
    let name: String
    let description: String?
    let price: Double?
    let link: String? // decode as string to avoid throwing on invalid URLs
    let quantityDesired: Int?
    let purchases: [APIWishlistItemPurchase]?
    let assignedGroupIds: [UUID]?
}

struct APIWishlistItemPurchase: Decodable {
    let userId: String?
    let quantity: Int
    let purchasedAt: String?
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

    func load() async throws -> (data: BootstrapData, isNewUser: Bool) {
        do {
            return (try await fetch(), false)
        } catch let api as APIError {
            // If current user not found, attempt to create and retry once
            if case let .http(status, code, _, _, _) = api, status == 404, code == "NOT_FOUND" {
                // Try to create the user, then retry bootstrap once
                try await createCurrentUserIfNeeded()
                return (try await fetch(), true)
            }
            throw api
        }
    }

    private func fetch() async throws -> BootstrapData {
        do {
            return try await client.execute(BootstrapRequest()).asAppModel()
        } catch let e as DecodingError {
            throw APIError.decoding(e)
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

private extension BootstrapResponse {
    func asAppModel() -> BootstrapData {
        let user = User(id: currentUser.id,
                        name: currentUser.name,
                        email: currentUser.email,
                        birthdate: parseAPIDate(currentUser.birthdate) ?? Date(),
                        sizes: currentUser.sizes,
                        wishlistPurchasesResetDate: parseAPIDate(currentUser.wishlistPurchasesResetDate))

        let groups: [Group] = self.groups.map { g in
            let members: [GroupMember] = g.members.map { m in
                let kidModels: [GroupMemberKid] = (m.kids ?? []).map { k in
                    GroupMemberKid(
                        id: k.id,
                        name: k.name,
                        wishlistItems: k.wishlistItems.map { $0.asAppModel() },
                        sizes: k.sizes ?? Sizes(),
                        birthdate: parseAPIDate(k.birthdate),
                        guardianEmails: k.guardianEmails ?? []
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
            return Group(id: g.id, name: g.name, isAdmin: g.isAdmin, members: members, pendingInvitations: (g.pendingInvitations ?? []).map { pi in
                PendingInvitation(email: pi.email, role: pi.role, invitedAt: pi.invitedAt)
            })
        }

        let kids: [Kid] = self.kids.map { k in
            Kid(id: k.id, name: k.name, birthdate: parseAPIDate(k.birthdate) ?? Date(), wishlistItems: k.wishlistItems.map { $0.asAppModel() }, sizes: k.sizes, guardianEmails: k.guardianEmails ?? [])
        }

        let ideas: [GiftIdea] = giftIdeas.map { g in
            GiftIdea(
                id: g.id,
                personName: g.personName,
                giftName: g.giftName,
                url: g.url.flatMap { URL(string: $0) },
                notes: g.notes ?? "",
                isPurchased: g.isPurchased ?? false
            )
        }

        let invitations = (self.invitations ?? []).map { i in
            GroupInvitation(id: i.id, groupId: i.groupId, groupName: i.groupName, invitedByName: i.invitedByName, invitedAt: i.invitedAt)
        }

        return BootstrapData(user: user,
                             groups: groups,
                             kids: kids,
                             wishlistItems: wishlistItems.map { $0.asAppModel() },
                             giftIdeas: ideas,
                             invitations: invitations)
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
            quantityDesired: quantityDesired ?? 1,
            purchases: (purchases ?? []).map {
                WishlistItemPurchase(userId: $0.userId, quantity: $0.quantity, purchasedAt: parseAPIDate($0.purchasedAt))
            },
            assignedGroupIds: assignedGroupIds ?? []
        )
    }
}

// (Removed local parseDate; using shared parseAPIDate in Utils.)
