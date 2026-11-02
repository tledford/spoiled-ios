import Foundation
import Testing
@testable import Spoiled

@MainActor
struct RemovedPurchaseTests {
    private let meId = "me"

    private func removed(_ name: String = "Mug", quantity: Int = 2, purchasedAt: Date? = Date(timeIntervalSince1970: 2_000_000_000)) -> RemovedPurchase {
        RemovedPurchase(itemId: UUID(), itemName: name, itemPrice: 12.5, recipientName: "Alex", quantity: quantity, purchasedAt: purchasedAt)
    }

    private func makeViewModel(removed: [RemovedPurchase], resetDate: Date? = nil) -> WishlistViewModel {
        let viewModel = WishlistViewModel()
        viewModel.currentUser = User(id: meId, name: "Me", email: "me@example.com", wishlistPurchasesResetDate: resetDate)
        viewModel.removedPurchases = removed
        return viewModel
    }

    @Test func theyAppearInTheReportMarkedAsRemoved() {
        let viewModel = makeViewModel(removed: [removed("Mug", quantity: 2)])
        let item = viewModel.purchasedWishlistItems.first
        #expect(item?.isRemoved == true)
        #expect(item?.item.name == "Mug")
        #expect(item?.item.price == 12.5)
        #expect(item?.recipientName == "Alex")
        #expect(item?.quantity == 2)
    }

    @Test func purchasesOfItemsStillThereAreNotMarked() {
        let viewModel = makeViewModel(removed: [])
        let bought = WishlistItem(name: "Socks", purchases: [WishlistItemPurchase(userId: meId, quantity: 1, purchasedAt: Date())])
        viewModel.groups = [Group(name: "Family", members: [GroupMember(id: "them", name: "Them", wishlistItems: [bought])])]
        #expect(viewModel.purchasedWishlistItems.map(\.isRemoved) == [false])
    }

    @Test func theCutoffAppliesToThem() {
        let cutoff = Date(timeIntervalSince1970: 1_500_000_000)
        let before = removed("Old", purchasedAt: Date(timeIntervalSince1970: 1_000_000_000))
        let after = removed("New", purchasedAt: Date(timeIntervalSince1970: 1_600_000_000))
        let viewModel = makeViewModel(removed: [before, after], resetDate: cutoff)
        #expect(viewModel.purchasedWishlistItems.map(\.item.name) == ["New"])
    }

    @Test func theyCountTowardWhatAClearWouldHide() {
        let viewModel = makeViewModel(removed: [removed(purchasedAt: Date(timeIntervalSince1970: 1_000_000_000))])
        #expect(viewModel.purchasedWishlistItemCount(before: Date(timeIntervalSince1970: 1_500_000_000)) == 1)
    }

    @Test func aLoadPicksThemUp() async {
        let viewModel = WishlistViewModel()
        let id = "10000000-0000-0000-0000-000000000009"
        viewModel.configure(client: StubURLProtocol.client { _ in
            (200, .bootstrap(removedPurchases: #"[{"itemId":"\#(id)","itemName":"Mug","itemPrice":12.5,"recipientName":"Alex","quantity":2,"purchasedAt":"2026-01-01T00:00:00.000Z","removedAt":"2026-02-01T00:00:00.000Z"}]"#))
        }, startLoading: false)
        await viewModel.load()
        #expect(viewModel.removedPurchases.map(\.itemName) == ["Mug"])
        #expect(viewModel.removedPurchases.first?.purchasedAt != nil)
    }

    @Test func aServerWithoutThemStillLoads() async {
        let viewModel = WishlistViewModel()
        viewModel.configure(client: StubURLProtocol.client { _ in (200, .bootstrap()) }, startLoading: false)
        await viewModel.load()
        #expect(viewModel.currentUser != nil)
        #expect(viewModel.removedPurchases.isEmpty)
    }

    @Test func signingOutForgetsThem() {
        let viewModel = makeViewModel(removed: [removed()])
        viewModel.resetForSignOut()
        #expect(viewModel.removedPurchases.isEmpty)
    }
}
