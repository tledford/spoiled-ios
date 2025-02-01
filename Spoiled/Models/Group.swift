import Foundation

struct Group: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isAdmin: Bool = false
    var members: [GroupMember]
    
    init(id: UUID = UUID(), name: String, isAdmin: Bool = false, members: [GroupMember] = []) {
        self.id = id
        self.name = name
        self.isAdmin = isAdmin
        self.members = members
    }
} 
