import Foundation

struct PendingInvitation: Identifiable, Codable, Hashable {
    var id: String { email } // Use email as ID since it's unique per group
    let email: String
    let role: String
    let invitedAt: String
}

/// An invitation sent to the signed-in user's email address, waiting for them to accept or decline.
struct GroupInvitation: Identifiable, Codable, Hashable {
    let id: String
    let groupId: UUID
    let groupName: String
    let invitedByName: String?
    let invitedAt: String
}

/// A group's shareable invite code and link. Only admins get to see these.
struct GroupInviteCode: Decodable, Hashable {
    let code: String
    let url: String
    let expiresAt: String
}

/// What an invite code leads to, shown before anyone joins.
struct InviteCodePreview: Decodable, Hashable {
    let groupId: UUID
    let groupName: String
    let invitedByName: String?
    let alreadyMember: Bool
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
