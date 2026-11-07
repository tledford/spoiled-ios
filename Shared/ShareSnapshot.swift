import Foundation

/// The slice of app state the share extension needs in order to build its form.
///
/// The app writes this after every successful bootstrap so the extension can render
/// instantly without a network round trip. If it is missing the extension falls back
/// to calling `/bootstrap` itself.
struct ShareSnapshot: Codable, Equatable {
    struct NamedRef: Codable, Equatable, Hashable, Identifiable {
        let id: UUID
        let name: String
    }

    var userId: String
    var kids: [NamedRef]
    var groups: [NamedRef]
    /// People the user has previously saved gift ideas for, plus everyone in their groups.
    var peopleSuggestions: [String]
    var updatedAt: Date

    init(userId: String,
         kids: [NamedRef] = [],
         groups: [NamedRef] = [],
         peopleSuggestions: [String] = [],
         updatedAt: Date = Date()) {
        self.userId = userId
        self.kids = kids
        self.groups = groups
        self.peopleSuggestions = peopleSuggestions
        self.updatedAt = updatedAt
    }
}

struct ShareSnapshotStore: Sendable {
    /// The App Group copy the share extension reads.
    static let shared = ShareSnapshotStore(suiteName: SharedContainer.appGroupId)

    private static let key = "share.snapshot.v1"

    /// Tests pass a suite of their own. Every view model writes its snapshot here, so tests
    /// sharing the App Group copy overwrite each other's.
    let suiteName: String

    private var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    func save(_ snapshot: ShareSnapshot) {
        guard let defaults,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func load() -> ShareSnapshot? {
        guard let defaults,
              let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(ShareSnapshot.self, from: data)
    }

    func clear() {
        defaults?.removeObject(forKey: Self.key)
    }
}

extension ShareSnapshot {
    /// Builds a snapshot from the models the app already holds after a bootstrap.
    init(user: User, kids: [Kid], groups: [Group], giftIdeas: [GiftIdea]) {
        self.init(userId: user.id,
                  kids: kids.map { NamedRef(id: $0.id, name: $0.name) },
                  groups: groups.map { NamedRef(id: $0.id, name: $0.name) },
                  peopleSuggestions: PersonSuggestions.names(currentUserId: user.id,
                                                             groups: groups,
                                                             giftIdeas: giftIdeas))
    }
}
