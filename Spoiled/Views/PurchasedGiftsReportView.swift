import SwiftUI

struct PurchasedGiftsReportView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearConfirmation = false

    // Wishlist items grouped by recipient name, sorted by purchasedAt asc within each group.
    private var wishlistItemsByPerson: [(name: String, items: [WishlistViewModel.PurchasedItem])] {
        let grouped = Dictionary(grouping: viewModel.purchasedWishlistItems, by: \.recipientName)
        return grouped.keys.sorted().map { name in
            let sorted = (grouped[name] ?? []).sorted {
                ($0.item.purchasedAt ?? .distantPast) < ($1.item.purchasedAt ?? .distantPast)
            }
            return (name: name, items: sorted)
        }
    }

    // Purchased gift ideas grouped by person name, sorted by gift name asc within each group.
    private var purchasedGiftIdeasByPerson: [(name: String, ideas: [GiftIdea])] {
        let purchased = (viewModel.giftIdeas ?? []).filter { $0.isPurchased }
        let grouped = Dictionary(grouping: purchased, by: \.personName)
        return grouped.keys.sorted().map { name in
            let sorted = (grouped[name] ?? []).sorted { $0.giftName < $1.giftName }
            return (name: name, ideas: sorted)
        }
    }

    private var hasAnyPurchases: Bool {
        !viewModel.purchasedWishlistItems.isEmpty || (viewModel.giftIdeas ?? []).contains { $0.isPurchased }
    }

    var body: some View {
        SwiftUI.Group {
            if !hasAnyPurchases {
                ScrollView {
                    EmptyStateView(
                        systemImage: "gift.fill",
                        title: "No purchases yet",
                        subtitle: "Gifts you've bought for others will appear here."
                    )
                    .padding(.top, 40)
                }
                .background(Color.appBackground.ignoresSafeArea())
            } else {
                List {
                    // MARK: Wishlist Items
                    Section(header: PurchaseCategoryHeader(title: "Wishlist Items")) {
                        EmptyView()
                    }
                    .listSectionSpacing(4)

                    if wishlistItemsByPerson.isEmpty {
                        Section {
                            Text("No wishlist items purchased yet")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.appSurface)
                        }
                    } else {
                        ForEach(wishlistItemsByPerson, id: \.name) { group in
                            Section {
                                ForEach(group.items) { purchased in
                                    WishlistPurchaseRow(purchased: purchased)
                                }
                            } header: {
                                PurchasePersonHeader(name: group.name)
                            }
                        }
                    }

                    // MARK: Gift Ideas
                    Section(header: PurchaseCategoryHeader(title: "Gift Ideas")) {
                        EmptyView()
                    }
                    .listSectionSpacing(4)

                    if purchasedGiftIdeasByPerson.isEmpty {
                        Section {
                            Text("No gift ideas purchased yet")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .listRowBackground(Color.appSurface)
                        }
                    } else {
                        ForEach(purchasedGiftIdeasByPerson, id: \.name) { group in
                            Section {
                                ForEach(group.ideas) { idea in
                                    GiftIdeaPurchaseRow(idea: idea)
                                }
                            } header: {
                                PurchasePersonHeader(name: group.name)
                                    .padding(.top, 8)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground.ignoresSafeArea())
            }
        }
        .navigationTitle("Purchased Gifts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        Label("Clear Purchased Wishlist Items", systemImage: "eraser")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .navButton(isIcon: true)
                }
            }
        }
        .alert("Clear Wishlist Items?", isPresented: $showingClearConfirmation) {
            Button("Clear", role: .destructive) {
                Task {
                    await viewModel.resetWishlistPurchases()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
 message: {
            Text("This will hide all current wishlist purchases from this report and the home screen. It will NOT mark the items as unpurchased for others.")
        }
        .trackScreen("purchased_gifts_report")
    }
}

// MARK: - Supporting Views

private struct PurchaseCategoryHeader: View {
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.brandGold.opacity(0.35))
                .frame(height: 1)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.brandGold)
                .textCase(nil)
                .fixedSize()
            Rectangle()
                .fill(Color.brandGold.opacity(0.35))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
    }
}

private struct PurchasePersonHeader: View {
    let name: String

    var body: some View {
        HStack(spacing: 8) {
            PersonAvatar(name: name, size: 30)
            Text(name)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .textCase(nil)
        }
    }
}

private struct WishlistPurchaseRow: View {
    let purchased: WishlistViewModel.PurchasedItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(purchased.item.name)
                .font(.system(size: 15, weight: .semibold))

            HStack(spacing: 6) {
                if let price = purchased.item.price {
                    Text("$\(price, specifier: "%.2f")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                if let date = purchased.item.purchasedAt {
                    if purchased.item.price != nil {
                        Text("•").foregroundStyle(.secondary)
                    }
                    Text(date, style: .date)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.appSurface)
    }
}

private struct GiftIdeaPurchaseRow: View {
    let idea: GiftIdea

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(idea.giftName)
                .font(.system(size: 15, weight: .semibold))

            if !idea.notes.isEmpty {
                Text(idea.notes)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.appSurface)
    }
}
