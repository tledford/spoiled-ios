import Foundation
import Testing
@testable import Spoiled

@MainActor
struct WishlistViewModelLoadTests {
    private func waitUntil(_ condition: @Sendable () -> Bool) async throws {
        for _ in 0..<500 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(condition())
    }

    @Test func aSuccessfulLoadFillsInTheUser() async {
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { _ in (200, .bootstrap()) }, startLoading: false)
        await viewModel.load()
        #expect(viewModel.currentUser?.id == "me")
    }

    @Test func signingOutClearsEverything() async {
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { _ in (200, .bootstrap()) }, startLoading: false)
        await viewModel.load()
        viewModel.errorMessage = "Something from before"

        viewModel.resetForSignOut()

        #expect(viewModel.currentUser == nil)
        #expect(viewModel.groups == nil)
        #expect(viewModel.kids == nil)
        #expect(viewModel.wishlistItems == nil)
        #expect(viewModel.giftIdeas == nil)
        #expect(viewModel.errorMessage == nil)
        #expect(!viewModel.isLoading)
    }

    @Test func aLoadStillRunningAtSignOutCannotWriteBack() async throws {
        let started = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { _ in
            started.signal()
            release.wait()
            return (200, .bootstrap(userId: "previous-account"))
        }, startLoading: false)

        let load = Task { await viewModel.load() }
        await Task.detached { started.wait() }.value

        viewModel.resetForSignOut()
        release.signal()
        await load.value

        #expect(viewModel.currentUser == nil)
    }

    @Test func nothingLoadsAfterSignOut() async {
        let requests = Recorder<Void>()
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { _ in
            requests.append(())
            return (200, .bootstrap())
        }, startLoading: false)

        viewModel.resetForSignOut()
        await viewModel.load()

        #expect(requests.count == 0)
        #expect(viewModel.currentUser == nil)
    }

    @Test func aBrandNewAccountIsAskedToFinishItsProfile() async {
        let bootstraps = Recorder<Void>()
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { request in
            if request.url?.path().hasSuffix("/users") == true { return (200, Data(#"{"id":"me"}"#.utf8)) }
            bootstraps.append(())
            return bootstraps.count == 1 ? (404, .apiError(code: "NOT_FOUND")) : (200, .bootstrap())
        }, startLoading: false)

        await viewModel.load()

        #expect(viewModel.currentUser?.id == "me")
        #expect(viewModel.needsProfileSetup)
    }

    @Test func anExistingAccountIsNotAsked() async {
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { _ in (200, .bootstrap()) }, startLoading: false)
        await viewModel.load()
        #expect(!viewModel.needsProfileSetup)
    }

    /// At launch two loads can overlap. The one that creates the account may lose to the newer one, which finds it existing.
    @Test func aNewAccountIsStillAskedWhenALoadOvertakesTheOneThatCreatedIt() async {
        let creating = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let bootstraps = Recorder<Void>()
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { request in
            if request.url?.path().hasSuffix("/users") == true {
                creating.signal()
                release.wait()
                return (200, Data(#"{"id":"me"}"#.utf8))
            }
            bootstraps.append(())
            return bootstraps.count == 1 ? (404, .apiError(code: "NOT_FOUND")) : (200, .bootstrap())
        }, startLoading: false)

        let creatingLoad = Task { await viewModel.load() }
        await Task.detached { creating.wait() }.value
        await viewModel.load()
        #expect(!viewModel.needsProfileSetup)

        release.signal()
        await creatingLoad.value
        #expect(viewModel.needsProfileSetup)
    }

    @Test func signingOutForgetsThePrompt() {
        let viewModel = WishlistViewModel()
        viewModel.needsProfileSetup = true
        viewModel.resetForSignOut()
        #expect(!viewModel.needsProfileSetup)
    }

    @Test func anOlderLoadCannotOverwriteANewerOne() async throws {
        let firstStarted = DispatchSemaphore(value: 0)
        let releaseFirst = DispatchSemaphore(value: 0)
        let calls = Recorder<Void>()
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { _ in
            calls.append(())
            if calls.count == 1 {
                firstStarted.signal()
                releaseFirst.wait()
                return (200, .bootstrap(userId: "me", name: "Old"))
            }
            return (200, .bootstrap(userId: "me", name: "New"))
        }, startLoading: false)

        let older = Task { await viewModel.load() }
        await Task.detached { firstStarted.wait() }.value
        await viewModel.load()
        #expect(viewModel.currentUser?.name == "New")
        #expect(!viewModel.isLoading)

        releaseFirst.signal()
        await older.value
        #expect(viewModel.currentUser?.name == "New")
    }
}
