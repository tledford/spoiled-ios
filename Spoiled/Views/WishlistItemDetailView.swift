import SwiftUI
import LinkPresentation
import UIKit

struct WishlistItemDetailView: View {
    let item: WishlistItem
    var isInGroupView: Bool
    let kidId: UUID?
    let groupId: UUID?
    let groupMemberId: String?
    var presentedAsSheet: Bool = false
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var purchaseBounce = false
    @State private var isSavingPurchase = false
    /// What the stepper shows until its change has saved. Nil when it matches the saved count.
    @State private var draftPurchaseQuantity: Int?
    @State private var purchaseSaveDelay: Task<Void, Never>?
    @State private var lastPurchaseSave: Task<Void, Never>?

    private var currentItem: WishlistItem {
        if isInGroupView, let groupId, let gi = viewModel.groups?.firstIndex(where: { $0.id == groupId }) {
            if let kidId,
               let memberIndex = viewModel.groups?[gi].members.firstIndex(where: { member in member.kids.contains(where: { $0.id == kidId && $0.wishlistItems.contains(where: { $0.id == item.id }) }) }),
               let kidx = viewModel.groups?[gi].members[memberIndex].kids.firstIndex(where: { $0.id == kidId }),
               let ii = viewModel.groups?[gi].members[memberIndex].kids[kidx].wishlistItems.firstIndex(where: { $0.id == item.id }) {
                return viewModel.groups![gi].members[memberIndex].kids[kidx].wishlistItems[ii]
            }
            if let memberUserId = groupMemberId,
               let memberIndex = viewModel.groups?[gi].members.firstIndex(where: { $0.id == memberUserId }),
               let ii = viewModel.groups?[gi].members[memberIndex].wishlistItems.firstIndex(where: { $0.id == item.id }) {
                return viewModel.groups![gi].members[memberIndex].wishlistItems[ii]
            }
        }
        return item
    }

    var assignedGroups: [Group] {
        viewModel.groups?.filter { currentItem.assignedGroupIds.contains($0.id) } ?? []
    }

    private var myPurchasedQuantity: Int {
        viewModel.currentUser.map { currentItem.quantityPurchased(by: $0.id) } ?? 0
    }

    /// Everything's been bought and none of it by this user, so they have nothing to change.
    private var purchasedByOthers: Bool {
        currentItem.isPurchased && myPurchasedQuantity == 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Here rather than in the navigation bar, which would cut a long name off.
                    Text(currentItem.name)
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)

                    // Link preview hero
                    if let link = currentItem.link {
                        LinkPreviewView(url: link)
                    }

                    // Description
                    if !currentItem.description.isEmpty {
                        detailCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Description", systemImage: "text.alignleft")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.brandGold)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                Text(currentItem.description)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    // Quantity (own wishlist)
                    if !isInGroupView && currentItem.quantityDesired > 1 {
                        detailCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Quantity", systemImage: "number")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.brandGold)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                Text("\(currentItem.quantityDesired)")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    // Groups card
                    if !isInGroupView {
                        detailCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Shared With", systemImage: "person.3.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.brandGold)
                                    .textCase(.uppercase)
                                    .tracking(0.5)

                                if assignedGroups.isEmpty {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lock.fill")
                                            .foregroundStyle(Color.brandGold.opacity(0.6))
                                        Text("Not shared with any groups")
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline)
                                } else {
                                    ForEach(assignedGroups) { group in
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                            Text(group.name)
                                                .foregroundStyle(.primary)
                                        }
                                        .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }

                    // Purchase controls (group view)
                    if isInGroupView {
                        if currentItem.quantityDesired > 1 {
                            multipleQuantityPurchaseControls
                        } else {
                            singleQuantityPurchaseButton
                        }
                    }

                    // Delete button (own wishlist)
                    if !isInGroupView {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Item", systemImage: "trash")
                                    .font(.system(size: 15, weight: .medium))
                                Spacer()
                            }
                            .padding(.vertical, 14)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(16)
            }
            .background(Color.appBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if presentedAsSheet {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { dismiss() } label: {
                            Text("Done")
                                .navButton(isIcon: false)
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !isInGroupView {
                        Button { showingEditSheet = true } label: {
                            Text("Edit")
                                .navButton(isIcon: false)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditWishlistItemView(item: item, kidId: kidId)
                    .environmentObject(viewModel)
            }
            .alert("Delete Item", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        let ok = await viewModel.deleteWishlistItem(item, kidId: kidId)
                        if ok { toastCenter.success("Item deleted"); dismiss() }
                        else { toastCenter.error(viewModel.errorMessage ?? "Failed to delete item") }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this item? This action cannot be undone.")
            }
        }
        .trackScreen(isInGroupView
                     ? "group_wishlist_item_detail"
                     : (kidId == nil ? "wishlist_item_detail" : "kid_wishlist_item_detail"))
    }

    /// Progress plus a stepper for this user's own count. Stepping saves by itself.
    @ViewBuilder
    private var multipleQuantityPurchaseControls: some View {
        let mine = myPurchasedQuantity
        let maximum = mine + currentItem.remainingQuantity
        let selected = min(draftPurchaseQuantity ?? mine, maximum)
        let bought = currentItem.purchasedQuantity - mine + selected

        detailCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Purchases", systemImage: "gift.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.brandGold)
                    .textCase(.uppercase)
                    .tracking(0.5)
                HStack {
                    Text("\(min(bought, currentItem.quantityDesired)) of \(currentItem.quantityDesired) purchased")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    if bought >= currentItem.quantityDesired {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if maximum > 0 {
                    Divider()
                    Stepper(value: Binding(get: { selected }, set: { choosePurchaseQuantity($0) }), in: 0...maximum) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How many did you purchase?")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("\(selected)")
                                .font(.title3.weight(.semibold))
                        }
                    }
                } else {
                    Text("Purchased by other group members")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var singleQuantityPurchaseButton: some View {
        Button {
            savePurchase(quantity: currentItem.isPurchased ? 0 : 1)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(currentItem.isPurchased
                         ? (purchasedByOthers ? "Already Purchased" : "Mark as Not Purchased")
                         : "Mark as Purchased")
                        .font(.system(size: 16, weight: .semibold))
                    if purchasedByOthers {
                        Text("Purchased by another group member")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                Image(systemName: currentItem.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .scaleEffect(purchaseBounce ? 1.35 : 1.0)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.45),
                        value: purchaseBounce
                    )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(currentItem.isPurchased ? Color.green : Color.accentColor)
                    .opacity(purchasedByOthers ? 0.55 : 1.0)
            )
        }
        .disabled(purchasedByOthers || isSavingPurchase)
        .onChange(of: currentItem.isPurchased) { _, _ in
            guard !reduceMotion else { return }
            purchaseBounce = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { purchaseBounce = false }
        }
    }

    /// Shows the new count right away and saves once the tapping stops, so a run of taps sends one request.
    private func choosePurchaseQuantity(_ quantity: Int) {
        draftPurchaseQuantity = quantity
        purchaseSaveDelay?.cancel()
        purchaseSaveDelay = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            savePurchase(quantity: quantity)
        }
    }

    private func savePurchase(quantity: Int) {
        isSavingPurchase = true
        let previousSave = lastPurchaseSave
        lastPurchaseSave = Task {
            // One at a time, so the last count chosen is the one that sticks.
            await previousSave?.value
            let ok = await viewModel.setItemPurchaseQuantity(currentItem, quantity: quantity, groupId: groupId, groupMemberId: groupMemberId, kidId: kidId)
            if !ok { toastCenter.error(viewModel.errorMessage ?? "Couldn't update your purchase") }
            if draftPurchaseQuantity == quantity { draftPurchaseQuantity = nil }
            isSavingPurchase = false
        }
    }

    @ViewBuilder
    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.appSurface)
            )
    }
}

// MARK: - Link Preview

private struct LinkPreviewView: View {
    let url: URL
    var cornerRadius: CGFloat = 14

    @StateObject private var loader = LinkMetadataLoader()
    @State private var showShareSheet = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        SwiftUI.Group {
            if let metadata = loader.metadata {
                Link(destination: url) {
                    LPLinkViewRepresentable(metadata: metadata)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 80)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .shadow(color: adaptiveShadow(scheme), radius: 5, x: 0, y: 2)
                }
            } else if loader.failed {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "link").imageScale(.large)
                        Text("View Item Online").font(.headline)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .padding()
                    .foregroundStyle(.white)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .shadow(color: adaptiveShadow(scheme), radius: 5, x: 0, y: 2)
                }
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 80)
                    .overlay {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading preview…").foregroundStyle(.secondary)
                        }
                    }
                    .shadow(color: adaptiveShadow(scheme), radius: 5, x: 0, y: 2)
                    .task { loader.fetch(url: url) }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            Button {
                UIPasteboard.general.url = url
            } label: {
                Label("Copy Link", systemImage: "doc.on.doc")
            }
            Button {
                showShareSheet = true
            } label: {
                Label("Share…", systemImage: "square.and.arrow.up")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [url])
        }
        .onAppear { loader.fetch(url: url) }
    }

    private func adaptiveShadow(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.1)
    }
}

private final class LinkMetadataLoader: ObservableObject {
    @Published var metadata: LPLinkMetadata?
    @Published var failed: Bool = false
    private var isLoading = false
    private static let cache = NSCache<NSURL, LPLinkMetadata>()

    func fetch(url: URL) {
        if metadata != nil || failed || isLoading { return }
        if let cached = Self.cache.object(forKey: url as NSURL) { self.metadata = cached; return }
        isLoading = true
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { [weak self] meta, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let meta = meta { Self.cache.setObject(meta, forKey: url as NSURL); self.metadata = meta }
                else { self.failed = true }
            }
        }
    }
}

private struct LPLinkViewRepresentable: UIViewRepresentable {
    let metadata: LPLinkMetadata
    func makeUIView(context: Context) -> LPLinkView {
        let view = LPLinkView(metadata: metadata)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    func updateUIView(_ uiView: LPLinkView, context: Context) { uiView.metadata = metadata }
}

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
