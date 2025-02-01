import SwiftUI

struct WishlistItemDetailView: View {
    let item: WishlistItem
    var isInGroupView: Bool
    let kidId: UUID?
    let groupId: UUID?
    let groupMemberId: UUID?
    @EnvironmentObject private var viewModel: WishlistViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var assignedGroups: [Group] {
        viewModel.groups?.filter { item.assignedGroupIds.contains($0.id) } ?? []
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Price Card
                    if let price = item.price {
                        PriceCard(price: price)
                    }
                    
                    // Description Card
                    if !item.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(item.description)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    
                    // Link Card
                    if let link = item.link {
                        Link(destination: link) {
                            HStack {
                                Image(systemName: "link")
                                    .imageScale(.large)
                                Text("View Item Online")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "arrow.up.right")
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    
                    // Groups Card
                    if !isInGroupView && !assignedGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shared With")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            ForEach(assignedGroups) { group in
                                HStack {
                                    Image(systemName: "person.3.fill")
                                        .foregroundStyle(.secondary)
                                    Text(group.name)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    
                    // Purchase Button
                    if isInGroupView {
                        Button {
                            viewModel.toggleItemPurchased(item, groupId: groupId, groupMemberId: groupMemberId)
                        } label: {
                            HStack {
                                Text(item.isPurchased ? "Mark as Not Purchased" : "Mark as Purchased")
                                    .font(.headline)
                                Spacer()
                                if item.isPurchased {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(item.isPurchased ? Color.green : Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Delete button section
                    if !isInGroupView {
                        Section {
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Delete Item")
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !isInGroupView {
                        Button("Edit") {
                            showingEditSheet = true
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
                    viewModel.deleteWishlistItem(item, kidId: kidId)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this item? This action cannot be undone.")
            }
        }
    }
}

struct PriceCard: View {
    let price: Double
    
    var body: some View {
        HStack {
            Text("Price")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "$%.2f", price))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
} 
