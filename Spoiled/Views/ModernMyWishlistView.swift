//
//  ModernMyWishlistView.swift
//  Spoiled
//
//  Created by Assistant on 1/15/25.
//

import SwiftUI

struct ModernMyWishlistView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var showingAddItemSheet = false
    @State private var selectedTab = "My Items"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerView
                contentView
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddItemSheet) {
                AddWishlistItemView(isForKid: selectedTab == "Kids Items")
            }
            .refreshable { await viewModel.load() }
        }
        .trackScreen("my_wishlist")
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            headerTopSection
                // .padding(.top, 20)
            
            if viewModel.kids?.isEmpty == false {
                segmentedPicker
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(
            headerGradient
                .ignoresSafeArea(edges: .top)
        )
    }
    
    private var headerTopSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("My Wishlist")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundColor(.white)
                
                if let itemCount = viewModel.wishlistItems?.count {
                    Text("\(itemCount) item\(itemCount != 1 ? "s" : "")")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            addButton
        }
    }
    
    private var addButton: some View {
        Button(action: { showingAddItemSheet = true }) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                
                Image(systemName: "plus")
                    .font(.system(.title3, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private var segmentedPicker: some View {
        HStack(spacing: 0) {
            ForEach(["My Items", "Kids Items"], id: \.self) { option in
                Button(action: { selectedTab = option }) {
                    Text(option)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(selectedTab == option ? .primary : .white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedTab == option ? Color.white : Color.clear)
                        )
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private var headerGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemPurple),
                Color(.systemBlue),
                Color(.systemTeal)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var contentView: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            if selectedTab == "My Items" || viewModel.kids?.isEmpty == true {
                ModernMyItemsListView(viewModel: viewModel)
            } else {
                ModernKidsItemsListView(viewModel: viewModel)
            }
        }
    }
}

struct ModernMyItemsListView: View {
    @ObservedObject var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let items = viewModel.wishlistItems, !items.isEmpty {
                    ForEach(items) { item in
                        ModernWishlistItemRow(
                            item: item,
                            viewModel: viewModel,
                            isInGroupView: false,
                            kidId: nil,
                            groupId: nil,
                            groupMemberId: nil
                        )
                        .contextMenu {
                            Button(action: {
                                // Edit action
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive, action: {
                                Task {
                                    let ok = await viewModel.deleteWishlistItem(item, kidId: nil)
                                    if ok {
                                        toastCenter.success("Item deleted")
                                    } else {
                                        toastCenter.error(viewModel.errorMessage ?? "Failed to delete item")
                                    }
                                }
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } else {
                    ModernEmptyStateView(
                        icon: "gift",
                        title: "No Items Yet",
                        message: "Your wishlist is empty. Add your first item to get started!",
                        buttonText: "Add Item",
                        buttonAction: { /* Add item action */ }
                    )
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
}

struct ModernKidsItemsListView: View {
    @ObservedObject var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if let currentUserKids = viewModel.kids, !currentUserKids.isEmpty {
                    ForEach(currentUserKids) { kid in
                        VStack(alignment: .leading, spacing: 12) {
                            // Kid section header
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.orange.opacity(0.3), Color.pink.opacity(0.3)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 36, height: 36)
                                    
                                    Text(String(kid.name.first?.uppercased() ?? "?"))
                                        .font(.system(.headline, weight: .bold))
                                        .foregroundColor(.primary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kid.name)
                                        .font(.system(.headline, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    Text("\(kid.wishlistItems.count) item\(kid.wishlistItems.count != 1 ? "s" : "")")
                                        .font(.system(.caption, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            // Kid's items
                            LazyVStack(spacing: 8) {
                                ForEach(kid.wishlistItems) { item in
                                    ModernWishlistItemRow(
                                        item: item,
                                        viewModel: viewModel,
                                        isInGroupView: false,
                                        kidId: kid.id,
                                        groupId: nil,
                                        groupMemberId: nil
                                    )
                                    .contextMenu {
                                        Button(role: .destructive, action: {
                                            Task {
                                                let ok = await viewModel.deleteWishlistItem(item, kidId: kid.id)
                                                if ok {
                                                    toastCenter.success("Item deleted")
                                                } else {
                                                    toastCenter.error(viewModel.errorMessage ?? "Failed to delete item")
                                                }
                                            }
                                        }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 2)
                        )
                    }
                } else {
                    ModernEmptyStateView(
                        icon: "person.2",
                        title: "No Kids Added",
                        message: "Add kids to manage their wishlists separately",
                        buttonText: "Manage Kids",
                        buttonAction: { /* Navigate to manage kids */ }
                    )
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
}

// Custom button style for modern interactions
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
