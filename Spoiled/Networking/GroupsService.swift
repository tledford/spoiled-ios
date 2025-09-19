import Foundation

struct CreateGroupResponse: Decodable { let id: UUID }

private struct CreateGroupPayload: Encodable { let id: UUID?; let name: String }
private struct RenameGroupPayload: Encodable { let name: String }
private struct AddMemberPayload: Encodable { let userId: String?; let email: String?; let role: String? }

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

    init(groupId: UUID, userId: String? = nil, email: String? = nil, role: String? = nil) {
        self.path = "/groups/\(groupId.uuidString)/members"
        let payload = AddMemberPayload(userId: userId, email: email, role: role)
        self.body = try? JSONEncoder().encode(payload)
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

    func addMember(groupId: UUID, userId: String, role: String? = nil) async throws {
        _ = try await client.execute(AddMemberRequest(groupId: groupId, userId: userId, role: role))
    }

    func removeMember(groupId: UUID, userId: String) async throws {
        _ = try await client.execute(RemoveMemberRequest(groupId: groupId, userId: userId))
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
