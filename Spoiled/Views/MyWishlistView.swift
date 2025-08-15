import SwiftUI

struct MyWishlistView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var showingAddItemSheet = false
    @State private var selectedTab = "My Items"
    
    var body: some View {
        NavigationStack {
            VStack {
                if viewModel.kids?.isEmpty == false {
                    Picker("Select List", selection: $selectedTab) {
                        Text("My Items").tag("My Items")
                        Text("Kids' Items").tag("Kids Items")
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }
                
                if selectedTab == "My Items" || viewModel.kids?.isEmpty == true {
                    MyItemsListView(viewModel: viewModel)
                } else {
                    KidsItemsListView(viewModel: viewModel)
                }
            }
            .navigationTitle("My Wishlist")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddItemSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddItemSheet) {
                AddWishlistItemView(isForKid: selectedTab == "Kids Items")
            }
            .refreshable { await viewModel.load() }
        }
    }
}

struct MyItemsListView: View {
    @ObservedObject var viewModel: WishlistViewModel
    
    var body: some View {
        List {
            if let items = viewModel.wishlistItems, !items.isEmpty {
                ForEach(items) { item in
                    WishlistItemRow(item: item, viewModel: viewModel, isInGroupView: false, kidId: nil, groupId: nil, groupMemberId: nil)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.deleteWishlistItem(item, kidId: nil)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } else {
                Text("Your wishlist is empty. Tap the + button to add items!")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
    }
}

struct KidsItemsListView: View {
    @ObservedObject var viewModel: WishlistViewModel
    
    var body: some View {
        List {
            if let currentUserKids = viewModel.kids {
                ForEach(currentUserKids) { kid in
                    Section(kid.name) {
                        ForEach(kid.wishlistItems) { item in
                            WishlistItemRow(item: item, viewModel: viewModel, isInGroupView: false, kidId: kid.id, groupId: nil, groupMemberId: nil)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        viewModel.deleteWishlistItem(item, kidId: kid.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }
            }
        }
    }
}

struct WishlistItemRow: View {
    let item: WishlistItem
    @ObservedObject var viewModel: WishlistViewModel
    var isInGroupView: Bool
    let kidId: UUID?
    let groupId: UUID?
    let groupMemberId: UUID?
    
    init(item: WishlistItem, 
         viewModel: WishlistViewModel, 
         isInGroupView: Bool, 
         kidId: UUID? = nil, 
         groupId: UUID? = nil, 
         groupMemberId: UUID? = nil) {
        self.item = item
        self.viewModel = viewModel
        self.isInGroupView = isInGroupView
        self.kidId = kidId
        self.groupId = groupId
        self.groupMemberId = groupMemberId
    }
    
    var body: some View {
        NavigationLink(destination: WishlistItemDetailView(
            item: item,
            isInGroupView: isInGroupView,
            kidId: kidId,
            groupId: groupId,
            groupMemberId: groupMemberId
        )) {
            HStack {
                VStack(alignment: .leading) {
                    Text(item.name)
                        .font(.headline)
                    if let price = item.price {
                        Text("$\(price, specifier: "%.2f")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if isInGroupView && item.isPurchased {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
        }
    }
}
