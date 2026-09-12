import Foundation

struct GroupMember: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var wishlistItems: [WishlistItem]
    var kids: [GroupMemberKid]
    var sizes: Sizes
    var birthdate: Date?

    init(id: String = "", name: String, wishlistItems: [WishlistItem] = [], kids: [GroupMemberKid] = [], sizes: Sizes = Sizes(), birthdate: Date? = nil) {
        self.id = id
        self.name = name
        self.wishlistItems = wishlistItems
        self.kids = kids
        self.sizes = sizes
        self.birthdate = birthdate
    }
}

struct GroupMemberKid: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var wishlistItems: [WishlistItem]
    var sizes: Sizes
    var birthdate: Date?
    var guardianEmails: [String]

    init(id: UUID = UUID(), name: String, wishlistItems: [WishlistItem] = [], sizes: Sizes = Sizes(), birthdate: Date? = nil, guardianEmails: [String] = []) {
        self.id = id
        self.name = name
        self.wishlistItems = wishlistItems
        self.sizes = sizes
        self.birthdate = birthdate
        self.guardianEmails = guardianEmails
    }
}