import Foundation

struct Kid: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    var name: String
    var birthdate: Date
    var wishlistItems: [WishlistItem]
    var sizes: Sizes
    var guardianEmails: [String]
    
    init(id: UUID = UUID(), 
         name: String, 
         birthdate: Date, 
         wishlistItems: [WishlistItem] = [],
         sizes: Sizes = Sizes(),
         guardianEmails: [String] = []) {
        self.id = id
        self.name = name
        self.birthdate = birthdate
        self.wishlistItems = wishlistItems
        self.sizes = sizes
        self.guardianEmails = guardianEmails
    }
} 
