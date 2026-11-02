import Foundation

/// How many of an item one person has bought.
struct WishlistItemPurchase: Codable, Hashable {
    /// Nil once the purchaser has deleted their account. Their purchase still counts.
    let userId: String?
    var quantity: Int
    var purchasedAt: Date?
}

/// Something the user bought from an item its owner has since deleted.
struct RemovedPurchase: Identifiable, Codable, Hashable {
    var id: UUID { itemId }
    let itemId: UUID
    let itemName: String
    let itemPrice: Double?
    let recipientName: String
    let quantity: Int
    let purchasedAt: Date?
}

struct WishlistItem: Identifiable, Codable, Hashable {
    static let maxQuantityDesired = 99

    let id: UUID
    var name: String
    var description: String
    var price: Double?
    var link: URL?
    var quantityDesired: Int
    /// Only populated on group copies of an item. The owner's own copy is always empty, so its
    /// purchase state means nothing outside of group views.
    var purchases: [WishlistItemPurchase]
    var assignedGroupIds: [UUID]

    init(id: UUID = UUID(), name: String, description: String = "", price: Double? = nil, link: URL? = nil, quantityDesired: Int = 1, purchases: [WishlistItemPurchase] = [], assignedGroupIds: [UUID] = []) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.link = link
        self.quantityDesired = quantityDesired
        self.purchases = purchases
        self.assignedGroupIds = assignedGroupIds
    }

    var purchasedQuantity: Int { purchases.reduce(0) { $0 + $1.quantity } }

    /// Purchased count for display. The owner can lower the desired quantity below what's been bought.
    var coveredQuantity: Int { min(purchasedQuantity, quantityDesired) }

    var remainingQuantity: Int { max(0, quantityDesired - purchasedQuantity) }

    var isPurchased: Bool { purchasedQuantity >= quantityDesired }

    func purchase(by userId: String) -> WishlistItemPurchase? {
        purchases.first { $0.userId == userId }
    }

    func quantityPurchased(by userId: String) -> Int {
        purchase(by: userId)?.quantity ?? 0
    }

    /// Sets one person's count the way the server does: the date only moves when the count rises,
    /// and a count of 0 removes the purchase.
    mutating func setPurchase(quantity: Int, by userId: String, at date: Date = Date()) {
        guard quantity > 0 else {
            purchases.removeAll { $0.userId == userId }
            return
        }
        if let index = purchases.firstIndex(where: { $0.userId == userId }) {
            if quantity > purchases[index].quantity { purchases[index].purchasedAt = date }
            purchases[index].quantity = quantity
        } else {
            purchases.append(WishlistItemPurchase(userId: userId, quantity: quantity, purchasedAt: date))
        }
    }
}
