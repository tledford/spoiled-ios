import Foundation

struct User: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var email: String
    var birthdate: Date
    var sizes: Sizes
    
    init(id: String = "", 
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

    // Be tolerant of empty/missing fields when decoding from API
    private enum CodingKeys: String, CodingKey { case shirt, pants, shoes, sweatshirt, hat }

    init(from decoder: Decoder) throws {
        // If sizes is null or not an object, default to empty strings
        guard let container = try? decoder.container(keyedBy: CodingKeys.self) else {
            self.init()
            return
        }
        let shirt = try container.decodeIfPresent(String.self, forKey: .shirt) ?? ""
        let pants = try container.decodeIfPresent(String.self, forKey: .pants) ?? ""
        let shoes = try container.decodeIfPresent(String.self, forKey: .shoes) ?? ""
        let sweatshirt = try container.decodeIfPresent(String.self, forKey: .sweatshirt) ?? ""
        let hat = try container.decodeIfPresent(String.self, forKey: .hat) ?? ""
        self.init(shirt: shirt, pants: pants, shoes: shoes, sweatshirt: sweatshirt, hat: hat)
    }
}

// Simple reference to avoid circular dependency
// struct GroupReference: Identifiable, Codable, Hashable {
//     let id: UUID
//     let name: String
// } 
