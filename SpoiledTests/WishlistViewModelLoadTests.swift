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
