import Foundation

struct WishlistItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var price: Double?
    var link: URL?
    var isPurchased: Bool
    var assignedGroupIds: [UUID]
    
    init(id: UUID = UUID(), name: String, description: String = "", price: Double? = nil, link: URL? = nil, isPurchased: Bool = false, assignedGroupIds: [UUID] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.link = link
        self.isPurchased = isPurchased
        self.assignedGroupIds = assignedGroupIds
    }
} 
