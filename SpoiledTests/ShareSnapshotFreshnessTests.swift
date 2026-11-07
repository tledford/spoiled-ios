import Testing
import Foundation
@testable import Spoiled

/// The share extension reads its kids/groups/people list out of the App Group, so the app has
/// to keep that copy current. These cover the write path, not the extension's read path.
///
/// Each case writes to a store of its own. Every view model writes a snapshot, so in the shared
/// App Group copy, other suites' view models running at the same time overwrite these.
@MainActor
struct ShareSnapshotFreshnessTests {

    private func makeStore() -> ShareSnapshotStore {
        ShareSnapshotStore(suiteName: "ShareSnapshotFreshnessTests.\(UUID().uuidString)")
    }

    private func removeStore(_ store: ShareSnapshotStore) {
        UserDefaults().removePersistentDomain(forName: store.suiteName)
    }

    /// Waits for the view model's debounced write to produce a snapshot matching `condition`.
    /// It waits on the main queue, which other suites keep busy, so a fixed delay isn't enough.
    private func snapshot(
        in store: ShareSnapshotStore,
        where condition: (ShareSnapshot) -> Bool
    ) async throws -> ShareSnapshot? {
        let deadline = ContinuousClock.now + .seconds(10)
        while ContinuousClock.now < deadline {
            if let snapshot = store.load(), condition(snapshot) { return snapshot }
            try await Task.sleep(for: .milliseconds(50))
        }
        return store.load()
    }

    @Test func localEditsReachTheSnapshotWithoutABootstrap() async throws {
        let store = makeStore()
        defer { removeStore(store) }
        let viewModel = WishlistViewModel(snapshotStore: store)
        viewModel.currentUser = User(id: "me", name: "Tommy", email: "t@example.com")
        viewModel.groups = []
        viewModel.kids = []
        viewModel.giftIdeas = []
        let first = try await snapshot(in: store) { $0.userId == "me" }
        #expect(first?.peopleSuggestions == [])

        // Mirrors what addGiftIdea does on success: append to the published array.
        viewModel.giftIdeas?.append(GiftIdea(personName: "Dana", giftName: "Socks"))

        let updated = try await snapshot(in: store) { $0.peopleSuggestions == ["Dana"] }
        #expect(updated?.peopleSuggestions == ["Dana"])
    }

    @Test func addingAKidReachesTheSnapshot() async throws {
        let store = makeStore()
        defer { removeStore(store) }
        let viewModel = WishlistViewModel(snapshotStore: store)
        viewModel.currentUser = User(id: "me", name: "Tommy", email: "t@example.com")
        viewModel.kids = []
        let first = try await snapshot(in: store) { $0.userId == "me" }
        #expect(first?.kids == [])

        viewModel.kids?.append(Kid(name: "Rowan", birthdate: Date()))

        let updated = try await snapshot(in: store) { !$0.kids.isEmpty }
        #expect(updated?.kids.map(\.name) == ["Rowan"])
    }

    @Test func nothingIsWrittenBeforeThereIsAUser() async throws {
        let store = makeStore()
        defer { removeStore(store) }
        let viewModel = WishlistViewModel(snapshotStore: store)
        viewModel.groups = [Group(name: "Family")]
        // Waiting for something not to happen: give the 300 ms debounce well over its time.
        try await Task.sleep(for: .seconds(1))

        #expect(store.load() == nil)
    }
}
