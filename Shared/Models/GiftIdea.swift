import Foundation

struct GiftIdea: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    var personName: String
    var giftName: String
    var url: URL?
    var notes: String
    var isPurchased: Bool
    
    init(id: UUID = UUID(), personName: String, giftName: String, url: URL? = nil, notes: String = "", isPurchased: Bool = false) {
        self.id = id
        self.personName = personName
        self.giftName = giftName
        self.url = url
        self.notes = notes
        self.isPurchased = isPurchased
    }
} 
