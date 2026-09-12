import Testing
import Foundation
@testable import Spoiled

/// The share extension reads its kids/groups/people list out of the App Group, so the app has
/// to keep that copy current. These cover the write path, not the extension's read path.
/// Serialized: every case reads and writes the one real App Group defaults suite, so running
/// them in parallel makes them clobber each other.
@MainActor
@Suite(.serialized)
struct ShareSnapshotFreshnessTests {

    /// The view model debounces snapshot writes; give it room to land.
    private func waitForSnapshotWrite() async throws {
        try await Task.sleep(for: .milliseconds(600))
    }

    @Test func localEditsReachTheSnapshotWithoutABootstrap() async throws {
        ShareSnapshotStore.clear()
        let viewModel = WishlistViewModel()
        viewModel.currentUser = User(id: "me", name: "Tommy", email: "t@example.com")
        viewModel.groups = []
        viewModel.kids = []
        viewModel.giftIdeas = []
        try await waitForSnapshotWrite()

        // Mirrors what addGiftIdea does on success: append to the published array.
        viewModel.giftIdeas?.append(GiftIdea(personName: "Dana", giftName: "Socks"))
        try await waitForSnapshotWrite()

        let snapshot = ShareSnapshotStore.load()
        #expect(snapshot?.peopleSuggestions == ["Dana"])
        ShareSnapshotStore.clear()
    }

    @Test func addingAKidReachesTheSnapshot() async throws {
        ShareSnapshotStore.clear()
        let viewModel = WishlistViewModel()
        viewModel.currentUser = User(id: "me", name: "Tommy", email: "t@example.com")
        viewModel.kids = []
        try await waitForSnapshotWrite()

        viewModel.kids?.append(Kid(name: "Rowan", birthdate: Date()))
        try await waitForSnapshotWrite()

        #expect(ShareSnapshotStore.load()?.kids.map(\.name) == ["Rowan"])
        ShareSnapshotStore.clear()
    }

    @Test func nothingIsWrittenBeforeThereIsAUser() async throws {
        ShareSnapshotStore.clear()
        let viewModel = WishlistViewModel()
        viewModel.groups = [Group(name: "Family")]
        try await waitForSnapshotWrite()

        #expect(ShareSnapshotStore.load() == nil)
    }
}
