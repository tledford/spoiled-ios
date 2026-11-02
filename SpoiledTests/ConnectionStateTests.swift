import Foundation
import Testing
@testable import Spoiled

struct UserFacingErrorTests {
    @Test func noConnectionIsOffline() {
        #expect(URLError(.notConnectedToInternet).loadFailure == .offline)
        #expect(URLError(.networkConnectionLost).loadFailure == .offline)
    }

    @Test func aServerThatWontAnswerIsUnreachable() {
        #expect(URLError(.timedOut).loadFailure == .serverUnreachable)
        #expect(URLError(.cannotConnectToHost).loadFailure == .serverUnreachable)
        #expect(URLError(.cannotFindHost).loadFailure == .serverUnreachable)
        #expect(APIError.tokenUnavailable.loadFailure == .serverUnreachable)
    }

    @Test func aServerThatAnswersWithAFailureIsAServerError() {
        #expect(APIError.http(status: 500, code: "INTERNAL_ERROR", message: "Boom", requestId: "abc", rawBody: nil).loadFailure == .serverError)
    }

    @Test func clientErrorsShowTheServersMessage() {
        let error = APIError.http(status: 409, code: "QUANTITY_EXCEEDED", message: "Only 2 left to purchase.", requestId: "abc", rawBody: nil)
        #expect(error.userFacingMessage == "Only 2 left to purchase.")
    }

    @Test func serverErrorsHideTheDetails() {
        let error = APIError.http(status: 500, code: "INTERNAL_ERROR", message: "D1_ERROR: no such table", requestId: "abc", rawBody: nil)
        #expect(!error.userFacingMessage.contains("D1_ERROR"))
        #expect(!error.userFacingMessage.contains("abc"))
        #expect(!error.userFacingMessage.contains("500"))
    }

    @Test func aRawErrorBodyIsNeverShown() {
        let error = APIError.http(status: 404, code: "HTTP_404", message: "<html>Not found</html>", requestId: nil, rawBody: "<html>Not found</html>")
        #expect(!error.userFacingMessage.contains("<html>"))
    }

    @Test func connectionErrorsUsePlainLanguage() {
        #expect(URLError(.notConnectedToInternet).userFacingMessage == LoadFailure.offline.message)
        #expect(URLError(.timedOut).userFacingMessage == LoadFailure.serverUnreachable.message)
    }

    @Test func cancellationsAreNotFailures() {
        #expect(URLError(.cancelled).isCancellation)
        #expect(CancellationError().isCancellation)
        #expect(!URLError(.timedOut).isCancellation)
    }
}

struct BootstrapCacheTests {
    private func makeCache() -> BootstrapCache {
        BootstrapCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
    }

    private func data(userId: String = "me") -> BootstrapData {
        BootstrapData(user: User(id: userId, name: "Me", email: "me@example.com"),
                      groups: [Group(name: "Family", members: [GroupMember(id: "them", name: "Them", wishlistItems: [WishlistItem(name: "Pajamas", quantityDesired: 4, purchases: [WishlistItemPurchase(userId: "me", quantity: 2, purchasedAt: Date(timeIntervalSince1970: 1000))])])])],
                      kids: [Kid(name: "Kid", birthdate: Date(timeIntervalSince1970: 0))],
                      wishlistItems: [WishlistItem(name: "Socks")],
                      giftIdeas: [],
                      invitations: [GroupInvitation(id: "i", groupId: UUID(), groupName: "Friends", invitedByName: nil, invitedAt: "2026")])
    }

    @Test func savesAndRestoresEverything() {
        let cache = makeCache()
        let saved = data()
        let when = Date(timeIntervalSince1970: 5000)
        cache.save(saved, savedAt: when)

        let entry = cache.load(userId: "me")

        #expect(entry?.savedAt == when)
        #expect(entry?.data.user.name == "Me")
        #expect(entry?.data.groups == saved.groups)
        #expect(entry?.data.kids == saved.kids)
        #expect(entry?.data.wishlistItems == saved.wishlistItems)
        #expect(entry?.data.invitations == saved.invitations)
        #expect(entry?.data.groups[0].members[0].wishlistItems[0].purchasedQuantity == 2)
    }

    @Test func anotherUserGetsNothing() {
        let cache = makeCache()
        cache.save(data(userId: "someone-else"))
        #expect(cache.load(userId: "me") == nil)
    }

    @Test func clearingRemovesIt() {
        let cache = makeCache()
        cache.save(data())
        cache.clear()
        #expect(cache.load(userId: "me") == nil)
    }

    @Test func aClearRightAfterASaveWins() {
        let cache = makeCache()
        for _ in 0..<5 { cache.save(data()) }
        cache.clear()
        cache.flush()
        #expect(cache.load(userId: "me") == nil)
    }

    @Test func nothingSavedYetIsFine() {
        #expect(makeCache().load(userId: "me") == nil)
    }

    @Test func aDamagedFileIsThrownAway() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: "bootstrap-v1.json")
        try Data("not json".utf8).write(to: file)

        #expect(BootstrapCache(directory: directory).load(userId: "me") == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path()))
    }
}

@MainActor
struct ConnectionStateTests {
    private func makeViewModel(_ handler: @escaping StubURLProtocol.Handler, retryDelays: [TimeInterval] = []) -> (WishlistViewModel, BootstrapCache) {
        let cache = BootstrapCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        let viewModel = WishlistViewModel(cache: cache, retryDelays: retryDelays)
        viewModel.configure(client: StubURLProtocol.client(handler: handler), startLoading: false)
        return (viewModel, cache)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<500 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    @Test func aFailedFirstLoadLeavesNoUserAndSaysWhy() async {
        let (viewModel, _) = makeViewModel { _ in throw URLError(.notConnectedToInternet) }
        await viewModel.load()
        #expect(viewModel.currentUser == nil)
        #expect(viewModel.loadFailure == .offline)
        #expect(viewModel.lastLoadedAt == nil)
        #expect(!viewModel.isLoading)
        #expect(!viewModel.showsStaleDataBanner)
    }

    @Test func anEmptyAccountIsNotAFailure() async {
        let (viewModel, _) = makeViewModel { _ in (200, .bootstrap()) }
        await viewModel.load()
        #expect(viewModel.currentUser != nil)
        #expect(viewModel.loadFailure == nil)
        #expect(viewModel.wishlistItems == [])
        #expect(viewModel.groups == [])
        #expect(viewModel.lastLoadedAt != nil)
    }

    @Test func aFailedRefreshKeepsTheDataOnScreen() async {
        let calls = Recorder<Void>()
        let (viewModel, _) = makeViewModel { _ in
            calls.append(())
            if calls.count == 1 { return (200, .bootstrap(name: "Loaded")) }
            throw URLError(.timedOut)
        }
        await viewModel.load()
        await viewModel.load()
        #expect(viewModel.currentUser?.name == "Loaded")
        #expect(viewModel.loadFailure == .serverUnreachable)
    }

    @Test func oneBlipDoesNotShowTheBannerButTwoDo() async {
        let calls = Recorder<Void>()
        let (viewModel, _) = makeViewModel { _ in
            calls.append(())
            if calls.count == 1 { return (200, .bootstrap()) }
            throw URLError(.timedOut)
        }
        await viewModel.load()
        await viewModel.load()
        #expect(!viewModel.showsStaleDataBanner)
        await viewModel.load()
        #expect(viewModel.showsStaleDataBanner)
    }

    @Test func beingOfflineShowsTheBannerRightAway() async {
        let calls = Recorder<Void>()
        let (viewModel, _) = makeViewModel { _ in
            calls.append(())
            if calls.count == 1 { return (200, .bootstrap()) }
            throw URLError(.notConnectedToInternet)
        }
        await viewModel.load()
        await viewModel.load()
        #expect(viewModel.showsStaleDataBanner)
    }

    @Test func aSuccessClearsTheFailure() async {
        let calls = Recorder<Void>()
        let (viewModel, _) = makeViewModel { _ in
            calls.append(())
            if calls.count == 1 { throw URLError(.timedOut) }
            return (200, .bootstrap())
        }
        await viewModel.load()
        #expect(viewModel.loadFailure != nil)
        await viewModel.load()
        #expect(viewModel.loadFailure == nil)
        #expect(!viewModel.showsStaleDataBanner)
    }

    @Test func aCancelledLoadIsNotAFailure() async {
        let (viewModel, _) = makeViewModel { _ in throw URLError(.cancelled) }
        await viewModel.load()
        #expect(viewModel.loadFailure == nil)
        #expect(!viewModel.isLoading)
    }

    @Test func aLoadFailureDoesNotTouchErrorMessage() async {
        let (viewModel, _) = makeViewModel { _ in throw URLError(.timedOut) }
        viewModel.errorMessage = "From a save"
        await viewModel.load()
        #expect(viewModel.errorMessage == "From a save")
    }

    @Test func retriesByItselfAndRecovers() async throws {
        let calls = Recorder<Void>()
        let (viewModel, _) = makeViewModel({ _ in
            calls.append(())
            if calls.count < 3 { throw URLError(.timedOut) }
            return (200, .bootstrap())
        }, retryDelays: [0.01, 0.01, 0.01])
        viewModel.startAutoRefresh()
        defer { viewModel.stopAutoRefresh() }

        await viewModel.load()

        try await waitUntil { viewModel.currentUser != nil }
        #expect(viewModel.loadFailure == nil)
        #expect(calls.count == 3)
    }

    @Test func stopsRetryingWhenTheDelaysRunOut() async throws {
        let calls = Recorder<Void>()
        let (viewModel, _) = makeViewModel({ _ in
            calls.append(())
            throw URLError(.timedOut)
        }, retryDelays: [0.01, 0.01])
        viewModel.startAutoRefresh()
        defer { viewModel.stopAutoRefresh() }

        await viewModel.load()

        try await waitUntil { calls.count >= 3 }
        try await Task.sleep(for: .milliseconds(100))
        #expect(calls.count == 3)
    }

    @Test func doesNotRetryInTheBackground() async throws {
        let calls = Recorder<Void>()
        let (viewModel, _) = makeViewModel({ _ in
            calls.append(())
            throw URLError(.timedOut)
        }, retryDelays: [0.01, 0.01])

        await viewModel.load()

        try await Task.sleep(for: .milliseconds(100))
        #expect(calls.count == 1)
    }

    @Test func gettingAConnectionBackRetriesStraightAway() async throws {
        let calls = Recorder<Void>()
        let (viewModel, _) = makeViewModel { _ in
            calls.append(())
            if calls.count == 1 { throw URLError(.notConnectedToInternet) }
            return (200, .bootstrap())
        }
        viewModel.startAutoRefresh()
        defer { viewModel.stopAutoRefresh() }
        await viewModel.load()

        viewModel.connectionRestored()

        try await waitUntil { viewModel.currentUser != nil }
    }

    @Test func gettingAConnectionBackDoesNothingIfNothingFailed() async throws {
        let calls = Recorder<Void>()
        let (viewModel, _) = makeViewModel { _ in
            calls.append(())
            return (200, .bootstrap())
        }
        viewModel.startAutoRefresh()
        defer { viewModel.stopAutoRefresh() }
        await viewModel.load()

        viewModel.connectionRestored()

        try await Task.sleep(for: .milliseconds(50))
        #expect(calls.count == 1)
    }

    @Test func aColdStartWithACacheShowsTheSavedData() async {
        let cache = BootstrapCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        let online = WishlistViewModel(cache: cache)
        online.configure(client: StubURLProtocol.client { _ in (200, .bootstrap(userId: "me", name: "Saved")) }, startLoading: false)
        await online.load()
        cache.flush()

        let offline = WishlistViewModel(cache: cache)
        offline.configure(client: StubURLProtocol.client { _ in throw URLError(.notConnectedToInternet) }, startLoading: false)
        offline.restoreFromCache(userId: "me")
        #expect(offline.currentUser?.name == "Saved")
        #expect(offline.lastLoadedAt != nil)

        await offline.load()
        #expect(offline.currentUser?.name == "Saved")
        #expect(offline.loadFailure == .offline)
    }

    @Test func anotherAccountCantSeeACachedAccount() async {
        let cache = BootstrapCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        let first = WishlistViewModel(cache: cache)
        first.configure(client: StubURLProtocol.client { _ in (200, .bootstrap(userId: "first")) }, startLoading: false)
        await first.load()
        cache.flush()

        let second = WishlistViewModel(cache: cache)
        second.restoreFromCache(userId: "second")
        #expect(second.currentUser == nil)
    }

    @Test func aFailedLoadDoesNotOverwriteTheCache() async {
        let calls = Recorder<Void>()
        let (viewModel, cache) = makeViewModel { _ in
            calls.append(())
            if calls.count == 1 { return (200, .bootstrap(name: "Good")) }
            throw URLError(.timedOut)
        }
        await viewModel.load()
        await viewModel.load()
        cache.flush()
        #expect(cache.load(userId: "me")?.data.user.name == "Good")
    }

    @Test func signingOutDeletesTheCache() async {
        let (viewModel, cache) = makeViewModel { _ in (200, .bootstrap()) }
        await viewModel.load()
        viewModel.resetForSignOut()
        cache.flush()
        #expect(cache.load(userId: "me") == nil)
        #expect(viewModel.lastLoadedAt == nil)
        #expect(viewModel.loadFailure == nil)
    }

    @Test func signingOutStopsRetries() async throws {
        let calls = Recorder<Void>()
        let (viewModel, _) = makeViewModel({ _ in
            calls.append(())
            throw URLError(.timedOut)
        }, retryDelays: [0.05, 0.05])
        viewModel.startAutoRefresh()
        await viewModel.load()

        viewModel.stopAutoRefresh()
        viewModel.resetForSignOut()

        try await Task.sleep(for: .milliseconds(150))
        #expect(calls.count == 1)
    }
}
