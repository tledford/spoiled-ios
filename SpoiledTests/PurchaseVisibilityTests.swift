import Testing
import Foundation
@testable import Spoiled

@MainActor
struct PurchaseVisibilityTests {

    private let cal = Calendar.current
    private let meId = "me"

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// A view model owned by `me`, whose only group member has one purchase per supplied date.
    private func makeViewModel(purchaseDates: [Date?], resetDate: Date?) -> WishlistViewModel {
        let items = purchaseDates.enumerated().map { index, purchasedAt in
            WishlistItem(name: "Gift \(index)",
                         isPurchased: true,
                         purchasedAt: purchasedAt,
                         purchasedBy: meId)
        }
        let viewModel = WishlistViewModel()
        viewModel.currentUser = User(id: meId,
                                     name: "Me",
                                     email: "me@example.com",
                                     wishlistPurchasesResetDate: resetDate)
        viewModel.groups = [Group(name: "Family",
                                  members: [GroupMember(id: "them", name: "Them", wishlistItems: items)])]
        return viewModel
    }

    @Test func purchasesOlderThanSixMonthsStayVisibleWithoutAClear() {
        let lastYear = cal.date(byAdding: .month, value: -11, to: Date())!
        let viewModel = makeViewModel(purchaseDates: [lastYear], resetDate: nil)
        #expect(viewModel.purchasedWishlistItems.count == 1)
    }

    @Test func cutoffKeepsPurchasesMadeOnTheCutoffDay() {
        let cutoff = date(2025, 12, 6)
        let viewModel = makeViewModel(
            purchaseDates: [date(2025, 12, 5),
                            cutoff,
                            cal.date(byAdding: .hour, value: 9, to: cutoff)!,
                            date(2025, 12, 20)],
            resetDate: cutoff
        )
        let names = viewModel.purchasedWishlistItems.map(\.item.name)
        #expect(names.sorted() == ["Gift 1", "Gift 2", "Gift 3"])
    }

    @Test func countReportsWhatAClearWouldHide() {
        let viewModel = makeViewModel(
            purchaseDates: [date(2025, 12, 5), date(2025, 12, 6), date(2025, 12, 20)],
            resetDate: nil
        )
        #expect(viewModel.purchasedWishlistItemCount(before: date(2025, 12, 6)) == 1)
        #expect(viewModel.purchasedWishlistItemCount(before: date(2025, 12, 21)) == 3)
    }

    @Test func theEpochSentinelCountsAsNoCutoff() {
        let viewModel = makeViewModel(purchaseDates: [date(2025, 12, 5), nil],
                                      resetDate: Date(timeIntervalSince1970: 0))
        #expect(viewModel.purchaseCutoff == nil)
        #expect(viewModel.hasPurchaseCutoff == false)
        #expect(viewModel.purchasedWishlistItems.count == 2)
    }

    @Test func purchasesWithoutADateHideOnlyOnceACutoffExists() {
        #expect(makeViewModel(purchaseDates: [nil], resetDate: nil).purchasedWishlistItems.count == 1)
        #expect(makeViewModel(purchaseDates: [nil], resetDate: date(2025, 12, 6)).purchasedWishlistItems.isEmpty)
    }
}
