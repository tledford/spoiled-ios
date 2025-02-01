import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var email: String
    var birthdate: Date
    var sizes: Sizes
    
    init(id: UUID = UUID(), 
         name: String, 
         email: String,
         birthdate: Date = Date(),
         sizes: Sizes = Sizes()) {
        self.id = id
        self.name = name
        self.email = email
        self.birthdate = birthdate
        self.sizes = sizes
    }
}

struct Sizes: Codable, Hashable {
    var shirt: String
    var pants: String
    var shoes: String
    var sweatshirt: String
    var hat: String
    
    init(shirt: String = "", pants: String = "", shoes: String = "", sweatshirt: String = "", hat: String = "") {
        self.shirt = shirt
        self.pants = pants
        self.shoes = shoes
        self.sweatshirt = sweatshirt
        self.hat = hat
    }
}

// Simple reference to avoid circular dependency
// struct GroupReference: Identifiable, Codable, Hashable {
//     let id: UUID
//     let name: String
// } 
