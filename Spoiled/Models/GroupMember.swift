import Foundation

struct GroupMember: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var wishlistItems: [WishlistItem]
    var kids: [GroupMemberKid]

    init(id: UUID = UUID(), name: String, wishlistItems: [WishlistItem] = [], kids: [GroupMemberKid] = []) {
        self.id = id
        self.name = name
        self.wishlistItems = wishlistItems
        self.kids = kids
    }
}

struct GroupMemberKid: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var wishlistItems: [WishlistItem]

    init(id: UUID = UUID(), name: String, wishlistItems: [WishlistItem] = []) {
        self.id = id
        self.name = name
        self.wishlistItems = wishlistItems
    }
}