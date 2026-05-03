import SwiftUI

struct PurchasedGiftsReportView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    let items = viewModel.purchasedWishlistItems
                    if items.isEmpty {
                        EmptyStateView(
                            systemImage: "gift.fill",
                            title: "No purchases yet",
                            subtitle: "Gifts you've bought for others will appear here."
                        )
                        .padding(.top, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, purchased in
                                GiftReportRow(purchased: purchased)
                                if index < items.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .spoiledCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Purchased Gifts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("Done")
                            .navButton(color: .brandBlue, isIcon: false)
                    }
                }
            }
        }
        .trackScreen("purchased_gifts_report")
    }
}

private struct GiftReportRow: View {
    let purchased: WishlistViewModel.PurchasedItem

    var body: some View {
        HStack(spacing: 12) {
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
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(date, style: .date)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text("For \(purchased.recipientName)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.brandGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.brandGold.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
