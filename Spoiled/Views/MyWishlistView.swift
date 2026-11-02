import SwiftUI

// MARK: - MyWishlistView

struct MyWishlistView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var showingAddItemSheet = false
    @State private var selectedTab = "My Items"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if viewModel.kids?.isEmpty == false {
                        GlassSegmentedPicker(
                            options: ["My Items", "Kids Items"],
                            selection: $selectedTab
                        )
                        .padding(.horizontal, 0)

                        if selectedTab == "My Items" {
                            MyItemsListView(viewModel: viewModel)
                        } else {
                            KidsItemsListView(viewModel: viewModel)
                        }
                    } else {
                        MyItemsListView(viewModel: viewModel)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("My Wishlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddItemSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .navButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddItemSheet) {
                AddWishlistItemView(isForKid: selectedTab == "Kids Items")
            }
            .refreshable { await viewModel.load() }
        }
        .trackScreen("my_wishlist")
    }
}

// MARK: - GlassSegmentedPicker

struct GlassSegmentedPicker: View {
    let options: [String]
    @Binding var selection: String
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selection = option
                    }
                } label: {
                    Text(option)
                        .font(.system(size: 14, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selection == option ? .white : .secondary)
                }
                .background {
                    if selection == option {
                        Capsule()
                            .fill(Color.brandGold)
                            .matchedGeometryEffect(id: "pill", in: ns)
                    }
                }
            }
        }
        .padding(4)
        .background(Color.appSurface, in: Capsule())
    }
}

// MARK: - MyItemsListView

struct MyItemsListView: View {
    @ObservedObject var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var itemToDelete: WishlistItem?

    var body: some View {
        content
            .deleteItemConfirmation(item: $itemToDelete, viewModel: viewModel, kidId: nil, toastCenter: toastCenter)
    }

    @ViewBuilder
    private var content: some View {
        if let items = viewModel.wishlistItems, !items.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    WishlistItemRow(item: item, viewModel: viewModel, isInGroupView: false, kidId: nil, groupId: nil, groupMemberId: nil)
                        .contextMenu {
                            Button(role: .destructive) {
                                itemToDelete = item
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    
                    if index < items.count - 1 {
                        Divider().padding(.leading, 16)
                    }
                }
            }
            .spoiledCard()
        } else {
            EmptyStateView(
                systemImage: "gift",
                title: "Your wishlist is empty",
                subtitle: "Tap + to add your first wish"
            )
            .padding(.top, 40)
        }
    }
}

// MARK: - KidsItemsListView

struct KidsItemsListView: View {
    @ObservedObject var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var itemToDelete: (item: WishlistItem, kidId: UUID)?

    var body: some View {
        content
            .deleteItemConfirmation(
                item: Binding(get: { itemToDelete?.item }, set: { if $0 == nil { itemToDelete = nil } }),
                viewModel: viewModel,
                kidId: itemToDelete?.kidId,
                toastCenter: toastCenter
            )
    }

    @ViewBuilder
    private var content: some View {
        if let kids = viewModel.kids, !kids.isEmpty {
            VStack(spacing: 24) {
                ForEach(kids) { kid in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(kid.name.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            if kid.wishlistItems.isEmpty {
                                Text("No items yet")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                ForEach(Array(kid.wishlistItems.enumerated()), id: \.element.id) { index, item in
                                    WishlistItemRow(item: item, viewModel: viewModel, isInGroupView: false, kidId: kid.id, groupId: nil, groupMemberId: nil)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                itemToDelete = (item, kid.id)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    
                                    if index < kid.wishlistItems.count - 1 {
                                        Divider().padding(.leading, 16)
                                    }
                                }
                            }
                        }
                        .spoiledCard()
                    }
                }
            }
        } else {
            EmptyStateView(
                systemImage: "figure.and.child.holdinghands",
                title: "No kids added",
                subtitle: "Add kids in Settings to manage their wishlists"
            )
            .padding(.top, 40)
        }
    }
}

// MARK: - Delete confirmation

private extension View {
    /// Long-press deletes are easy to hit by accident, so they ask first.
    func deleteItemConfirmation(item: Binding<WishlistItem?>, viewModel: WishlistViewModel, kidId: UUID?, toastCenter: ToastCenter) -> some View {
        alert("Delete Item", isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } }), presenting: item.wrappedValue) { itemToDelete in
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    let ok = await viewModel.deleteWishlistItem(itemToDelete, kidId: kidId)
                    if ok { toastCenter.success("Item deleted") }
                    else { toastCenter.error(viewModel.errorMessage ?? "Failed to delete item") }
                }
            }
        } message: { itemToDelete in
            Text("Are you sure you want to delete \(itemToDelete.name)? This action cannot be undone.")
        }
    }
}

// MARK: - WishlistItemRow

struct WishlistItemRow: View {
    let item: WishlistItem
    @ObservedObject var viewModel: WishlistViewModel
    var isInGroupView: Bool
    let kidId: UUID?
    let groupId: UUID?
    let groupMemberId: String?
    var useSheet: Bool = false

    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showDetailSheet = false

    init(item: WishlistItem,
         viewModel: WishlistViewModel,
         isInGroupView: Bool,
         kidId: UUID? = nil,
         groupId: UUID? = nil,
         groupMemberId: String? = nil,
         useSheet: Bool = false) {
        self.item = item
        self.viewModel = viewModel
        self.isInGroupView = isInGroupView
        self.kidId = kidId
        self.groupId = groupId
        self.groupMemberId = groupMemberId
        self.useSheet = useSheet
    }

    var body: some View {
        rowView
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
    }

    @ViewBuilder
    private var rowView: some View {
        if useSheet {
            Button {
                showDetailSheet = true
            } label: {
                rowContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showDetailSheet) {
                WishlistItemDetailView(
                    item: item,
                    isInGroupView: isInGroupView,
                    kidId: kidId,
                    groupId: groupId,
                    groupMemberId: groupMemberId,
                    presentedAsSheet: true
                )
                .environmentObject(viewModel)
                .toast(toastCenter) // The root view's toasts would be hidden behind this sheet.
            }
        } else {
            NavigationLink(destination: WishlistItemDetailView(
                item: item,
                isInGroupView: isInGroupView,
                kidId: kidId,
                groupId: groupId,
                groupMemberId: groupMemberId
            )) {
                rowContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// Owners only ever see how many they asked for, never how many have been bought.
    private var quantityLabel: String? {
        guard item.quantityDesired > 1 else { return nil }
        guard isInGroupView else { return "Qty \(item.quantityDesired)" }
        return item.isPurchased ? nil : "\(item.coveredQuantity) of \(item.quantityDesired) purchased"
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isInGroupView && item.isPurchased ? .secondary : .primary)
                    .strikethrough(isInGroupView && item.isPurchased, color: .secondary)

                if let quantityLabel {
                    Text(quantityLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                if !isInGroupView && item.assignedGroupIds.isEmpty {
                    PrivateBadge()
                }
            }
            Spacer()
            if isInGroupView && item.isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 18))
            }
        }
    }
}
