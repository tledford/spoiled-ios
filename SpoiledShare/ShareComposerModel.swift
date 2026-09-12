import Foundation
import SwiftUI
import FirebaseAuth

@MainActor
final class ShareComposerModel: ObservableObject {
    enum Destination: Hashable, Identifiable {
        case myWishlist
        case kid(UUID)
        case giftIdea

        var id: String {
            switch self {
            case .myWishlist: return "me"
            case .kid(let id): return "kid-\(id.uuidString)"
            case .giftIdea: return "idea"
            }
        }

        var isWishlist: Bool {
            if case .giftIdea = self { return false }
            return true
        }
    }

    enum Phase: Equatable {
        case loading
        case ready
        case signedOut
        case failed(String)
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var snapshot: ShareSnapshot?
    @Published private(set) var isEnrichingTitle = false
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    @Published var destination: Destination = .myWishlist
    @Published var name = ""
    @Published var linkString = ""
    @Published var details = ""
    @Published var personName = ""
    @Published var selectedGroupIds: Set<UUID> = []

    private let onFinish: (Bool) -> Void

    init(onFinish: @escaping (Bool) -> Void) {
        self.onFinish = onFinish
    }

    var kids: [ShareSnapshot.NamedRef] { snapshot?.kids ?? [] }
    var groups: [ShareSnapshot.NamedRef] { snapshot?.groups ?? [] }
    var peopleSuggestions: [String] { snapshot?.peopleSuggestions ?? [] }

    var canSave: Bool {
        guard !isSaving, phase == .ready else { return false }
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if case .giftIdea = destination {
            return !personName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    // MARK: - Loading

    func start(items: [NSExtensionItem]) async {
        guard Auth.auth().currentUser != nil else {
            phase = .signedOut
            return
        }

        async let parsed = SharedLinkParser.parse(items)
        async let loaded = resolveSnapshot()

        let link = await parsed
        let snapshot = await loaded

        self.snapshot = snapshot
        prefill(from: link)

        guard snapshot != nil else {
            phase = .failed("Couldn't reach Spoiled. Open the app once, then try sharing again.")
            return
        }
        phase = .ready

        // Nothing usable came through — most often a bare URL from an app that shares no
        // metadata. Ask LinkPresentation for the page title in the background.
        if name.isEmpty, let url = link.url {
            isEnrichingTitle = true
            let fetched = await SharedLinkParser.fetchTitle(for: url)
            isEnrichingTitle = false
            if name.isEmpty, let fetched {
                name = SharedTitleCleaner.clean(fetched, url: url)
            }
            if name.isEmpty { name = fallbackName(for: url) }
        }
    }

    private func resolveSnapshot() async -> ShareSnapshot? {
        if let cached = ShareSnapshotStore.load() { return cached }

        // No cache yet (first run after installing this version). Bootstrap directly.
        let client = APIClient(tokenProvider: FirebaseSession.tokenProvider)
        do {
            let data = try await BootstrapService(client: client).load()
            let snapshot = ShareSnapshot(user: data.0, kids: data.2, groups: data.1, giftIdeas: data.4)
            ShareSnapshotStore.save(snapshot)
            return snapshot
        } catch {
            return nil
        }
    }

    private func prefill(from link: SharedLink) {
        if let url = link.url { linkString = url.absoluteString }

        if let title = link.title {
            name = SharedTitleCleaner.clean(title, url: link.url)
        }

        var detailParts: [String] = []
        if let selection = link.selectionText, selection != link.title {
            detailParts.append(clip(selection, to: 500))
        } else if let description = link.pageDescription {
            detailParts.append(clip(description, to: 500))
        }
        if let price = link.priceText { detailParts.append("Price: \(price)") }
        details = detailParts.joined(separator: "\n\n")
    }

    private func fallbackName(for url: URL) -> String {
        // Better than an empty field: the last meaningful path component, or the host.
        let slug = url.pathComponents
            .filter { $0 != "/" && !$0.isEmpty }
            .last?
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        if let slug, slug.count > 3, !slug.contains(".") {
            return slug.capitalized
        }
        return url.host?.replacingOccurrences(of: "www.", with: "") ?? ""
    }

    private func clip(_ string: String, to limit: Int) -> String {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let cutoff = trimmed.index(trimmed.startIndex, offsetBy: limit)
        return String(trimmed[trimmed.startIndex..<cutoff]).trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: - Saving

    func save() async {
        guard let snapshot, canSave else { return }
        isSaving = true
        errorMessage = nil

        let client = APIClient(tokenProvider: FirebaseSession.tokenProvider)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = normalizedLink()

        do {
            switch destination {
            case .myWishlist:
                let item = WishlistItem(name: trimmedName,
                                        description: trimmedDetails,
                                        link: link,
                                        assignedGroupIds: Array(selectedGroupIds))
                _ = try await WishlistService(client: client).createUserItem(userId: snapshot.userId, item: item)
            case .kid(let kidId):
                let item = WishlistItem(name: trimmedName,
                                        description: trimmedDetails,
                                        link: link,
                                        assignedGroupIds: Array(selectedGroupIds))
                _ = try await WishlistService(client: client).createKidItem(userId: snapshot.userId,
                                                                           kidId: kidId,
                                                                           item: item)
            case .giftIdea:
                let idea = GiftIdea(personName: personName.trimmingCharacters(in: .whitespacesAndNewlines),
                                    giftName: trimmedName,
                                    url: link,
                                    notes: trimmedDetails)
                _ = try await GiftIdeasService(client: client).create(userId: snapshot.userId, idea: idea)
            }
            isSaving = false
            onFinish(true)
        } catch {
            isSaving = false
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn't save. Please try again."
        }
    }

    func cancel() {
        onFinish(false)
    }

    private func normalizedLink() -> URL? {
        let trimmed = linkString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let url = URL(string: trimmed), url.scheme != nil { return url }
        return URL(string: "https://" + trimmed)
    }
}
