import Testing
import Foundation
@testable import Spoiled

struct WishlistItemQuantityTests {

    private let meId = "me"
    private let themId = "them"
    private let earlier = Date(timeIntervalSince1970: 1_000)
    private let later = Date(timeIntervalSince1970: 2_000)

    @Test func newItemsWantOneAndAreUnpurchased() {
        let item = WishlistItem(name: "Gift")
        #expect(item.quantityDesired == 1)
        #expect(item.remainingQuantity == 1)
        #expect(item.isPurchased == false)
    }

    @Test func purchasedOnlyOnceTheTotalReachesWhatsWanted() {
        var item = WishlistItem(name: "Gift", quantityDesired: 3)

        item.setPurchase(quantity: 2, by: meId)
        #expect(item.purchasedQuantity == 2)
        #expect(item.remainingQuantity == 1)
        #expect(item.isPurchased == false)

        item.setPurchase(quantity: 1, by: themId)
        #expect(item.remainingQuantity == 0)
        #expect(item.isPurchased == true)
    }

    @Test func countsAreKeptPerPerson() {
        var item = WishlistItem(name: "Gift", quantityDesired: 3)
        item.setPurchase(quantity: 2, by: meId)
        item.setPurchase(quantity: 1, by: themId)
        #expect(item.quantityPurchased(by: meId) == 2)
        #expect(item.quantityPurchased(by: themId) == 1)
        #expect(item.quantityPurchased(by: "nobody") == 0)
    }

    @Test func aDeletedPurchasersCountStillAppliesButBelongsToNobody() {
        let item = WishlistItem(name: "Gift",
                                purchases: [WishlistItemPurchase(userId: nil, quantity: 1, purchasedAt: earlier)])
        #expect(item.isPurchased == true)
        #expect(item.quantityPurchased(by: meId) == 0)
    }

    @Test func loweringWhatsWantedBelowWhatsBoughtStaysInRange() {
        let item = WishlistItem(name: "Gift",
                                quantityDesired: 1,
                                purchases: [WishlistItemPurchase(userId: themId, quantity: 3, purchasedAt: earlier)])
        #expect(item.isPurchased == true)
        #expect(item.coveredQuantity == 1)
        #expect(item.remainingQuantity == 0)
    }

    @Test func settingAPurchaseToZeroRemovesOnlyThatPersonsPurchase() {
        var item = WishlistItem(name: "Gift", quantityDesired: 3)
        item.setPurchase(quantity: 1, by: meId)
        item.setPurchase(quantity: 1, by: themId)

        item.setPurchase(quantity: 0, by: meId)

        #expect(item.purchase(by: meId) == nil)
        #expect(item.quantityPurchased(by: themId) == 1)
    }

    @Test func thePurchaseDateMovesOnlyWhenTheCountRises() {
        var item = WishlistItem(name: "Gift", quantityDesired: 3)
        item.setPurchase(quantity: 2, by: meId, at: earlier)

        item.setPurchase(quantity: 1, by: meId, at: later)
        #expect(item.purchase(by: meId)?.purchasedAt == earlier)

        item.setPurchase(quantity: 2, by: meId, at: later)
        #expect(item.purchase(by: meId)?.purchasedAt == later)
    }

    // MARK: - Purchases report

    @MainActor
    private func makeViewModel(items: [WishlistItem], resetDate: Date? = nil) -> WishlistViewModel {
        let viewModel = WishlistViewModel()
        viewModel.currentUser = User(id: meId,
                                     name: "Me",
                                     email: "me@example.com",
                                     wishlistPurchasesResetDate: resetDate)
        viewModel.groups = [Group(name: "Family",
                                  members: [GroupMember(id: themId, name: "Them", wishlistItems: items)])]
        return viewModel
    }

    @MainActor
    @Test func theReportListsPartialPurchasesWithMyCountAndDate() throws {
        let item = WishlistItem(name: "Pajamas",
                                quantityDesired: 3,
                                purchases: [WishlistItemPurchase(userId: meId, quantity: 2, purchasedAt: earlier)])

        let purchased = makeViewModel(items: [item]).purchasedWishlistItems

        let entry = try #require(purchased.first)
        #expect(purchased.count == 1)
        #expect(entry.quantity == 2)
        #expect(entry.purchasedAt == earlier)
        #expect(entry.item.isPurchased == false)
    }

    @MainActor
    @Test func theReportSkipsItemsOnlyOtherPeopleBought() {
        let item = WishlistItem(name: "Pajamas",
                                purchases: [WishlistItemPurchase(userId: "someone", quantity: 1, purchasedAt: earlier)])
        #expect(makeViewModel(items: [item]).purchasedWishlistItems.isEmpty)
    }

    @MainActor
    @Test func theCutoffGoesByMyPurchaseDateNotAnyoneElses() {
        let item = WishlistItem(name: "Pajamas",
                                quantityDesired: 2,
                                purchases: [WishlistItemPurchase(userId: meId, quantity: 1, purchasedAt: earlier),
                                            WishlistItemPurchase(userId: "someone", quantity: 1, purchasedAt: later)])
        let viewModel = makeViewModel(items: [item], resetDate: Date(timeIntervalSince1970: 1_500))
        #expect(viewModel.purchasedWishlistItems.isEmpty)
    }
}
