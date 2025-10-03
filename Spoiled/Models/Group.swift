import Foundation

struct PendingInvitation: Identifiable, Codable, Hashable {
    var id: String { email } // Use email as ID since it's unique per group
    let email: String
    let role: String
    let invitedAt: String
}

struct Group: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isAdmin: Bool = false
    var members: [GroupMember]
    var pendingInvitations: [PendingInvitation]
    
    init(id: UUID = UUID(), name: String, isAdmin: Bool = false, members: [GroupMember] = [], pendingInvitations: [PendingInvitation] = []) {
        self.id = id
        self.name = name
        self.isAdmin = isAdmin
        self.members = members
        self.pendingInvitations = pendingInvitations
    }
} 
