import Foundation

struct CreateGroupResponse: Decodable { let id: UUID }

private struct CreateGroupPayload: Encodable { let id: UUID?; let name: String }
private struct RenameGroupPayload: Encodable { let name: String }
private struct AddMemberPayload: Encodable { let email: String; let role: String? }

private struct CreateGroupRequest: APIRequest {
    typealias Response = CreateGroupResponse
    let path: String = "/groups"
    let method: String = "POST"
    let body: Data?

    init(name: String) {
        let payload = CreateGroupPayload(id: nil, name: name)
        self.body = try? JSONEncoder().encode(payload)
    }
}

private struct RenameGroupRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "PATCH"
    let body: Data?

    init(groupId: UUID, name: String) {
        self.path = "/groups/\(groupId.uuidString)"
        let payload = RenameGroupPayload(name: name)
        self.body = try? JSONEncoder().encode(payload)
    }
}

private struct AddMemberRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "POST"
    let body: Data?

    init(groupId: UUID, email: String, role: String? = nil) {
        self.path = "/groups/\(groupId.uuidString)/members"
        let payload = AddMemberPayload(email: email, role: role)
        self.body = try? JSONEncoder().encode(payload)
    }
}

private struct InviteCodeRequest: APIRequest {
    typealias Response = GroupInviteCode
    let path: String
    let method: String

    init(groupId: UUID, replacing: Bool) {
        self.path = "/groups/\(groupId.uuidString)/invite-code"
        self.method = replacing ? "POST" : "GET"
    }
}

private struct InviteCodePreviewRequest: APIRequest {
    typealias Response = InviteCodePreview
    let path: String

    init(code: String) {
        self.path = "/invite-codes/\(code)"
    }
}

private struct AcceptInviteCodeRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "POST"

    init(code: String) {
        self.path = "/invite-codes/\(code)/accept"
    }
}

private struct RespondToInvitationRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "POST"

    init(invitationId: String, accept: Bool) {
        self.path = "/invitations/\(invitationId)/\(accept ? "accept" : "decline")"
    }
}

private struct RemoveMemberRequest: APIRequest {
    typealias Response = OkResponse
    let path: String
    let method: String = "DELETE"

    init(groupId: UUID, userId: String) {
        self.path = "/groups/\(groupId.uuidString)/members/\(userId)"
    }
}

struct GroupsService {
    let client: APIClient
    init(client: APIClient = APIClient()) { self.client = client }

    func create(name: String) async throws -> UUID {
        let res = try await client.execute(CreateGroupRequest(name: name))
        return res.id
    }

    func rename(groupId: UUID, name: String) async throws {
        _ = try await client.execute(RenameGroupRequest(groupId: groupId, name: name))
    }

    func addMember(groupId: UUID, email: String, role: String? = nil) async throws {
        _ = try await client.execute(AddMemberRequest(groupId: groupId, email: email, role: role))
    }

    func inviteCode(groupId: UUID, replacing: Bool) async throws -> GroupInviteCode {
        try await client.execute(InviteCodeRequest(groupId: groupId, replacing: replacing))
    }

    func previewInviteCode(_ code: String) async throws -> InviteCodePreview {
        try await client.execute(InviteCodePreviewRequest(code: code))
    }

    func acceptInviteCode(_ code: String) async throws {
        _ = try await client.execute(AcceptInviteCodeRequest(code: code))
    }

    func respondToInvitation(id: String, accept: Bool) async throws {
        _ = try await client.execute(RespondToInvitationRequest(invitationId: id, accept: accept))
    }

    func removeMember(groupId: UUID, userId: String) async throws {
        _ = try await client.execute(RemoveMemberRequest(groupId: groupId, userId: userId))
    }

    func removePendingInvitation(groupId: UUID, email: String) async throws {
        struct RemovePendingInvitationRequest: APIRequest {
            typealias Response = OkResponse
            let path: String
            let method: String = "DELETE"
            
            init(groupId: UUID, email: String) {
                // URL encode the email to handle special characters
                let encodedEmail = email.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? email
                self.path = "/groups/\(groupId.uuidString)/pending-invitations/\(encodedEmail)"
            }
        }
        _ = try await client.execute(RemovePendingInvitationRequest(groupId: groupId, email: email))
    }

    func delete(groupId: UUID) async throws {
        struct DeleteGroupRequest: APIRequest {
            typealias Response = OkResponse
            let path: String
            let method: String = "DELETE"
            init(groupId: UUID) { self.path = "/groups/\(groupId.uuidString)" }
        }
        _ = try await client.execute(DeleteGroupRequest(groupId: groupId))
    }
}
