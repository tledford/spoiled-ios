import SwiftUI

// MARK: - MyWishlistView

struct MyWishlistView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var showingAddItemSheet = false
    @State private var selectedTab = "My Items"

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                if viewModel.kids?.isEmpty == false {
                    segmentedContent
                } else {
                    MyItemsListView(viewModel: viewModel)
                }
            }
            .navigationTitle("My Wishlist")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddItemSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
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

    private var segmentedContent: some View {
        VStack(spacing: 0) {
            GlassSegmentedPicker(
                options: ["My Items", "Kids Items"],
                selection: $selectedTab
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)

            if selectedTab == "My Items" {
                MyItemsListView(viewModel: viewModel)
            } else {
                KidsItemsListView(viewModel: viewModel)
            }
        }
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
        .background(.ultraThinMaterial, in: Capsule())
    }
}

// MARK: - MyItemsListView

struct MyItemsListView: View {
    @ObservedObject var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter

    var body: some View {
        if let items = viewModel.wishlistItems, !items.isEmpty {
            List {
                ForEach(items) { item in
                    WishlistItemRow(item: item, viewModel: viewModel, isInGroupView: false, kidId: nil, groupId: nil, groupMemberId: nil)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                Task {
                                    let ok = await viewModel.deleteWishlistItem(item, kidId: nil)
                                    if ok { toastCenter.success("Item deleted") }
                                    else { toastCenter.error(viewModel.errorMessage ?? "Failed to delete item") }
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(viewModel.deletingWishlistItemIds.contains(item.id))
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        } else {
            ScrollView {
                EmptyStateView(
                    systemImage: "gift",
                    title: "Your wishlist is empty",
                    subtitle: "Tap + to add your first wish"
                )
            }
        }
    }
}

// MARK: - KidsItemsListView

struct KidsItemsListView: View {
    @ObservedObject var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter

    var body: some View {
        if let kids = viewModel.kids, !kids.isEmpty {
            List {
                ForEach(kids) { kid in
                    Section {
                        ForEach(kid.wishlistItems) { item in
                            WishlistItemRow(item: item, viewModel: viewModel, isInGroupView: false, kidId: kid.id, groupId: nil, groupMemberId: nil)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        Task {
                                            let ok = await viewModel.deleteWishlistItem(item, kidId: kid.id)
                                            if ok { toastCenter.success("Item deleted") }
                                            else { toastCenter.error(viewModel.errorMessage ?? "Failed to delete item") }
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .disabled(viewModel.deletingWishlistItemIds.contains(item.id))
                                }
                        }
                        if kid.wishlistItems.isEmpty {
                            Text("No items yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                        }
                    } header: {
                        Text(kid.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.brandGold)
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        } else {
            ScrollView {
                EmptyStateView(
                    systemImage: "figure.and.child.holdinghands",
                    title: "No kids added",
                    subtitle: "Add kids in Settings to manage their wishlists"
                )
            }
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
        if useSheet {
            Button {
                showDetailSheet = true
            } label: {
                rowContent
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
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
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isInGroupView && item.isPurchased ? .secondary : .primary)
                    .strikethrough(isInGroupView && item.isPurchased, color: .secondary)

                HStack(spacing: 6) {
                    if let price = item.price {
                        Text("$\(price, specifier: "%.2f")")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    if !isInGroupView && item.assignedGroupIds.isEmpty {
                        PrivateBadge()
                    }
                }
            }
            Spacer()
            if isInGroupView && item.isPurchased {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 20))
            }
        }
        .padding(.vertical, 4)
    }
}
