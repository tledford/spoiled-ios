import SwiftUI

struct PurchasedGiftsReportView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss
    @State private var showingClearSheet = false
    @State private var isRestoring = false

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
        content
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Purchased Gifts")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingClearSheet = true
                    } label: {
                        Label("Clear Purchased Wishlist Items…", systemImage: "eraser")
                    }
                    .disabled(viewModel.purchasedWishlistItems.isEmpty)

                    if viewModel.hasPurchaseCutoff {
                        Button {
                            Task { await showAll() }
                        } label: {
                            Label("Show All Purchases", systemImage: "eye")
                        }
                        .disabled(isRestoring)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .navButton(isIcon: true)
                }
            }
        }
        .sheet(isPresented: $showingClearSheet) {
            ClearPurchasedItemsView()
        }
        .trackScreen("purchased_gifts_report")
    }

    @MainActor
    private func showAll() async {
        isRestoring = true
        defer { isRestoring = false }
        let ok = await viewModel.showAllPurchases()
        toastCenter.show(ok ? Toast(message: "Showing all purchases", style: .success, duration: 5.0)
                            : Toast(message: "Couldn't restore purchases", style: .error, duration: 5.0))
    }

    @ViewBuilder
    private var cutoffBanner: some View {
        if let cutoff = viewModel.purchaseCutoff {
            PurchaseCutoffBanner(cutoff: cutoff)
        }
    }

    @ViewBuilder
    private var content: some View {
        SwiftUI.Group {
            if !hasAnyPurchases {
                ScrollView {
                    VStack(spacing: 0) {
                        cutoffBanner
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                        EmptyStateView(
                            systemImage: "gift.fill",
                            title: "No purchases yet",
                            subtitle: "Gifts you've bought for others will appear here."
                        )
                        .padding(.top, 40)
                    }
                }
                .background(Color.appBackground.ignoresSafeArea())
            } else {
                List {
                    if viewModel.hasPurchaseCutoff {
                        Section {
                            cutoffBanner
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        .listSectionSpacing(4)
                    }

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
    }
}

// MARK: - Supporting Views

private struct PurchaseCutoffBanner: View {
    let cutoff: Date

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "eye.slash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.brandGold)

            VStack(alignment: .leading, spacing: 2) {
                Text("Hiding purchases before \(cutoff.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 14, weight: .semibold))
                Text("Hidden from your report only. Show All Purchases brings them back.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.brandGold.opacity(0.35), lineWidth: 1)
        }
    }
}

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
