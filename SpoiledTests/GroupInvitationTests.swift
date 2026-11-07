import Foundation
import Testing
@testable import Spoiled

struct InviteLinkTests {
    @Test func readsTheCodeFromAnInviteLink() {
        #expect(InviteLink.code(from: URL(string: "https://prod.tomled.dev/invite/ABCDE12345")!) == "ABCDE12345")
    }

    @Test(arguments: [
        "https://prod.tomled.dev/invite",
        "https://prod.tomled.dev/invite/",
        "https://prod.tomled.dev/other/ABCDE12345",
        "https://prod.tomled.dev/invite/ABCDE12345/extra",
        "https://example.com/invite/ABCDE12345",
        "com.googleusercontent.apps.123:/oauth2redirect",
    ])
    func ignoresAnythingElse(link: String) {
        #expect(InviteLink.code(from: URL(string: link)!) == nil)
    }
}

@MainActor
struct GroupInvitationTests {
    private static let groupId = "10000000-0000-0000-0000-000000000001"
    private static let invitation = """
    {"id":"invite-1","groupId":"\(groupId)","groupName":"Family","invitedByName":"Alex","invitedAt":"2026-01-01T00:00:00.000Z"}
    """
    private static let group = """
    {"id":"\(groupId)","name":"Family","isAdmin":true,"members":[],
    "pendingInvitations":[{"email":"someone@example.com","role":"member","invitedAt":"2026-01-01T00:00:00.000Z"}]}
    """
    private static let ok = (status: 200, body: Data(#"{"ok":true,"groupId":"\#(groupId)"}"#.utf8))

    private nonisolated static func requestLine(_ request: URLRequest) -> String {
        "\(request.httpMethod ?? "") \(request.url?.path().replacingOccurrences(of: "/api/v1", with: "") ?? "")"
    }

    @Test func aLoadPicksUpInvitationsAndAdminsPendingList() async {
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { _ in
            (200, .bootstrap(groups: "[\(Self.group)]", invitations: "[\(Self.invitation)]"))
        }, startLoading: false)
        await viewModel.load()

        #expect(viewModel.groupInvitations.map(\.groupName) == ["Family"])
        #expect(viewModel.groupInvitations.first?.invitedByName == "Alex")
        #expect(viewModel.groups?.first?.pendingInvitations.map(\.email) == ["someone@example.com"])
    }

    @Test func aServerWithoutInvitationsStillLoads() async {
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { _ in (200, .bootstrap()) }, startLoading: false)
        await viewModel.load()
        #expect(viewModel.currentUser != nil)
        #expect(viewModel.groupInvitations.isEmpty)
    }

    @Test func acceptingJoinsAndReloads() async {
        let calls = Recorder<String>()
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { request in
            let line = Self.requestLine(request)
            calls.append(line)
            if line == "POST /invitations/invite-1/accept" { return Self.ok }
            let accepted = calls.values.contains("POST /invitations/invite-1/accept")
            return (200, .bootstrap(groups: accepted ? "[\(Self.group)]" : "[]", invitations: accepted ? "[]" : "[\(Self.invitation)]"))
        }, startLoading: false)
        await viewModel.load()

        let ok = await viewModel.respondToInvitation(viewModel.groupInvitations[0], accept: true)

        #expect(ok)
        #expect(viewModel.groupInvitations.isEmpty)
        #expect(viewModel.groups?.map(\.name) == ["Family"])
    }

    @Test func decliningRemovesTheInvitation() async {
        let calls = Recorder<String>()
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { request in
            let line = Self.requestLine(request)
            calls.append(line)
            if line == "POST /invitations/invite-1/decline" { return Self.ok }
            return (200, .bootstrap(invitations: calls.values.contains("POST /invitations/invite-1/decline") ? "[]" : "[\(Self.invitation)]"))
        }, startLoading: false)
        await viewModel.load()

        let ok = await viewModel.respondToInvitation(viewModel.groupInvitations[0], accept: false)

        #expect(ok)
        #expect(viewModel.groupInvitations.isEmpty)
        #expect(viewModel.groups == [])
    }

    @Test func aFailedResponseKeepsTheInvitationAndSaysWhy() async {
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { request in
            if Self.requestLine(request).hasSuffix("/accept") { return (404, .apiError(code: "NOT_FOUND", message: "This invitation is no longer available.")) }
            return (200, .bootstrap(invitations: "[\(Self.invitation)]"))
        }, startLoading: false)
        await viewModel.load()

        let ok = await viewModel.respondToInvitation(viewModel.groupInvitations[0], accept: true)

        #expect(!ok)
        #expect(viewModel.groupInvitations.count == 1)
        #expect(viewModel.errorMessage?.contains("no longer available") == true)
    }

    @Test func previewingACodeShowsTheGroupAndAddsNothing() async {
        let calls = Recorder<String>()
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { request in
            calls.append(Self.requestLine(request))
            return (200, Data(#"{"groupId":"\#(Self.groupId)","groupName":"Family","invitedByName":"Alex","alreadyMember":false}"#.utf8))
        }, startLoading: false)

        let preview = await viewModel.previewInviteCode("abc-de/../f")

        #expect(preview?.groupName == "Family")
        #expect(preview?.alreadyMember == false)
        #expect(calls.values == ["GET /invite-codes/abcdef"])
    }

    @Test func anInvalidCodeSaysWhy() async {
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { _ in
            (404, .apiError(code: "INVITE_CODE_NOT_FOUND", message: "That code isn't valid or has expired."))
        }, startLoading: false)

        let preview = await viewModel.previewInviteCode("NOPE")

        #expect(preview == nil)
        #expect(viewModel.errorMessage?.contains("isn't valid") == true)
    }

    @Test func joiningWithACodeAddsTheGroup() async {
        let calls = Recorder<String>()
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { request in
            let line = Self.requestLine(request)
            calls.append(line)
            if line == "POST /invite-codes/CODE/accept" { return Self.ok }
            return (200, .bootstrap(groups: "[\(Self.group)]"))
        }, startLoading: false)

        let ok = await viewModel.joinGroup(code: "CODE")

        #expect(ok)
        #expect(viewModel.groups?.map(\.name) == ["Family"])
    }

    @Test func leavingRemovesTheGroup() async {
        let calls = Recorder<String>()
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { request in
            let line = Self.requestLine(request)
            calls.append(line)
            return line.hasPrefix("DELETE") ? (200, Data(#"{"ok":true}"#.utf8)) : (200, .bootstrap(groups: "[\(Self.group)]"))
        }, startLoading: false)
        await viewModel.load()

        let ok = await viewModel.leaveGroup(viewModel.groups![0])

        #expect(ok)
        #expect(viewModel.groups == [])
        #expect(calls.values.contains("DELETE /groups/\(Self.groupId.uppercased())/members/me"))
    }

    @Test func theOnlyAdminGetsTheServersExplanation() async {
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { request in
            if Self.requestLine(request).hasPrefix("DELETE") { return (403, .apiError(code: "FORBIDDEN", message: "Delete the group instead.")) }
            return (200, .bootstrap(groups: "[\(Self.group)]"))
        }, startLoading: false)
        await viewModel.load()

        let ok = await viewModel.leaveGroup(viewModel.groups![0])

        #expect(!ok)
        #expect(viewModel.groups?.count == 1)
        #expect(viewModel.errorMessage?.contains("Delete the group instead") == true)
    }

    @Test func gettingAndReplacingAnInviteCode() async {
        let calls = Recorder<String>()
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { request in
            calls.append(Self.requestLine(request))
            return (200, Data(#"{"code":"ABCDE12345","url":"https://prod.tomled.dev/invite/ABCDE12345","expiresAt":"2026-02-01T00:00:00.000Z"}"#.utf8))
        }, startLoading: false)
        let group = Group(id: UUID(uuidString: Self.groupId)!, name: "Family", isAdmin: true)

        let existing = await viewModel.inviteCode(for: group)
        let replaced = await viewModel.inviteCode(for: group, replacing: true)

        #expect(existing?.code == "ABCDE12345")
        #expect(replaced?.url == "https://prod.tomled.dev/invite/ABCDE12345")
        #expect(calls.values.map { $0.prefix(4) } == ["GET ", "POST"])
    }

    @Test func signingOutForgetsInvitations() async {
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { _ in (200, .bootstrap(invitations: "[\(Self.invitation)]")) }, startLoading: false)
        await viewModel.load()
        viewModel.resetForSignOut()
        #expect(viewModel.groupInvitations.isEmpty)
    }
}
