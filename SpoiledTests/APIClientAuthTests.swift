import Foundation
import Testing
@testable import Spoiled

struct APIClientAuthTests {
    private struct Ping: APIRequest {
        typealias Response = OkResponse
        let path = "/ping"
    }

    private static let ok = (status: 200, body: Data(#"{"ok":true}"#.utf8))
    private static let unauthorized = (status: 401, body: Data.apiError(code: "INVALID_TOKEN"))

    /// Records each request's token and each time the session is ended.
    private final class Harness: @unchecked Sendable {
        let tokens = Recorder<String?>()
        let sessionEnds = Recorder<Void>()

        func client(tokenProvider: ((Bool) async throws -> String?)?,
                    responses: [(status: Int, body: Data)]) -> APIClient {
            let tokens = tokens
            let queue = Recorder<Int>()
            return StubURLProtocol.client(tokenProvider: tokenProvider,
                                          onSessionEnded: { [sessionEnds] in sessionEnds.append(()) }) { request in
                tokens.append(request.value(forHTTPHeaderField: "Authorization"))
                queue.append(0)
                return responses[min(queue.count - 1, responses.count - 1)]
            }
        }
    }

    private func tokenProvider(cached: String? = "stale", refreshed: String? = "fresh") -> (Bool) async throws -> String? {
        { force in force ? refreshed : cached }
    }

    @Test func sendsTheToken() async throws {
        let harness = Harness()
        let client = harness.client(tokenProvider: tokenProvider(), responses: [Self.ok])
        _ = try await client.execute(Ping())
        #expect(harness.tokens.values == ["Bearer stale"])
        #expect(harness.sessionEnds.count == 0)
    }

    @Test func retriesOnceWithAFreshTokenAndStaysSignedIn() async throws {
        let harness = Harness()
        let client = harness.client(tokenProvider: tokenProvider(), responses: [Self.unauthorized, Self.ok])
        _ = try await client.execute(Ping())
        #expect(harness.tokens.values == ["Bearer stale", "Bearer fresh"])
        #expect(harness.sessionEnds.count == 0)
    }

    @Test func endsTheSessionWhenTheFreshTokenIsRejectedToo() async {
        let harness = Harness()
        let client = harness.client(tokenProvider: tokenProvider(), responses: [Self.unauthorized, Self.unauthorized])
        await #expect(throws: APIError.self) { _ = try await client.execute(Ping()) }
        #expect(harness.tokens.count == 2)
        #expect(harness.sessionEnds.count == 1)
    }

    @Test func aTemporaryTokenFailureSendsNothingAndStaysSignedIn() async {
        let harness = Harness()
        let client = harness.client(tokenProvider: { _ in throw APIError.tokenUnavailable }, responses: [Self.ok])
        await #expect(throws: APIError.self) { _ = try await client.execute(Ping()) }
        #expect(harness.tokens.count == 0)
        #expect(harness.sessionEnds.count == 0)
    }

    @Test func aTemporaryRefreshFailureStaysSignedIn() async {
        let harness = Harness()
        let client = harness.client(tokenProvider: { force in
            if force { throw APIError.tokenUnavailable }
            return "stale"
        }, responses: [Self.unauthorized])
        await #expect(throws: APIError.self) { _ = try await client.execute(Ping()) }
        #expect(harness.tokens.count == 1)
        #expect(harness.sessionEnds.count == 0)
    }

    @Test func aRefreshThatFindsTheSessionOverEndsIt() async {
        let harness = Harness()
        let client = harness.client(tokenProvider: { force in
            if force { throw APIError.sessionOver }
            return "stale"
        }, responses: [Self.unauthorized])
        await #expect(throws: APIError.self) { _ = try await client.execute(Ping()) }
        #expect(harness.sessionEnds.count == 1)
    }

    @Test func noSignedInUserGoesOutWithoutATokenAndEndsNothing() async {
        let harness = Harness()
        let client = harness.client(tokenProvider: { _ in nil }, responses: [Self.unauthorized])
        await #expect(throws: APIError.self) { _ = try await client.execute(Ping()) }
        #expect(harness.tokens.values == [nil])
        #expect(harness.sessionEnds.count == 0)
    }

    @Test func aServiceOutageDoesNotEndTheSession() async {
        let harness = Harness()
        let unavailable = (status: 503, body: Data.apiError(code: "AUTH_UNAVAILABLE"))
        let client = harness.client(tokenProvider: tokenProvider(), responses: [unavailable])
        await #expect(throws: APIError.self) { _ = try await client.execute(Ping()) }
        #expect(harness.tokens.count == 1)
        #expect(harness.sessionEnds.count == 0)
    }

    @Test func noConnectionDoesNotEndTheSession() async {
        let ends = Recorder<Void>()
        let client = StubURLProtocol.client(tokenProvider: tokenProvider(), onSessionEnded: { ends.append(()) }) { _ in
            throw URLError(.notConnectedToInternet)
        }
        await #expect(throws: (any Error).self) { _ = try await client.execute(Ping()) }
        #expect(ends.count == 0)
    }
}

struct FirebaseSessionErrorTests {
    private func authError(_ code: Int) -> NSError { NSError(domain: "FIRAuthErrorDomain", code: code) }

    @Test(arguments: [17021, 17017, 17005, 17011])
    func theseMeanTheSessionIsOver(code: Int) {
        #expect(FirebaseSession.isSessionOver(authError(code)))
    }

    @Test func aNetworkErrorIsTemporary() {
        #expect(!FirebaseSession.isSessionOver(authError(17020)))
    }

    @Test func tooManyRequestsIsTemporary() {
        #expect(!FirebaseSession.isSessionOver(authError(17010)))
    }

    @Test func otherErrorsAreTemporary() {
        #expect(!FirebaseSession.isSessionOver(URLError(.notConnectedToInternet)))
        #expect(!FirebaseSession.isSessionOver(NSError(domain: "SomeOtherDomain", code: 17021)))
    }
}
