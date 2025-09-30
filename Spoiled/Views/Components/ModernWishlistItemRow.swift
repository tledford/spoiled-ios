//
//  ModernWishlistItemRow.swift
//  Spoiled
//
//  Created by Assistant on 1/15/25.
//

import SwiftUI

struct ModernWishlistItemRow: View {
    let item: WishlistItem
    @ObservedObject var viewModel: WishlistViewModel
    var isInGroupView: Bool
    let kidId: UUID?
    let groupId: UUID?
    let groupMemberId: String?
    @State private var isPressed = false
    
    init(item: WishlistItem, 
         viewModel: WishlistViewModel, 
         isInGroupView: Bool, 
         kidId: UUID? = nil, 
         groupId: UUID? = nil, 
         groupMemberId: String? = nil) {
        self.item = item
        self.viewModel = viewModel
        self.isInGroupView = isInGroupView
        self.kidId = kidId
        self.groupId = groupId
        self.groupMemberId = groupMemberId
    }
    
    private var destinationView: some View {
        WishlistItemDetailView(
            item: item,
            isInGroupView: isInGroupView,
            kidId: kidId,
            groupId: groupId,
            groupMemberId: groupMemberId
        )
    }
    
    var body: some View {
        NavigationLink(destination: destinationView) {
            rowContent
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var rowContent: some View {
        HStack(spacing: 16) {
            productImage
            itemInfo
            rightSection
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(cardBackground)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    private var productImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
            
            Image(systemName: "gift.fill")
                .font(.title2)
                .foregroundStyle(.white)
        }
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var itemInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.name)
                .font(.system(.headline, design: .default, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            if !item.description.isEmpty {
                Text(item.description)
                    .font(.system(.caption, design: .default))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            itemMetadata
        }
    }
    
    private var itemMetadata: some View {
        HStack(spacing: 12) {
            // Price with modern styling
            if let price = item.price {
                priceTag(price: price)
            }
            
            // Privacy indicator with modern design
            if !isInGroupView && item.assignedGroupIds.isEmpty {
                privacyIndicator
            }
            
            Spacer()
        }
    }
    
    private func priceTag(price: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            Text("\(price, specifier: "%.2f")")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.green.opacity(0.1))
        .clipShape(Capsule())
    }
    
    private var privacyIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "eye.slash.fill")
                .font(.caption)
            Text("Private")
                .font(.system(.caption, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.secondary.opacity(0.8))
        )
        .accessibilityLabel("Not shared with any groups")
    }
    
    private var rightSection: some View {
        VStack {
            if isInGroupView && item.isPurchased {
                purchasedIndicator
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var purchasedIndicator: some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 28, height: 28)
            
            Image(systemName: "checkmark")
                .font(.system(.caption, weight: .bold))
                .foregroundColor(.white)
        }
        .shadow(color: Color.green.opacity(0.3), radius: 2, x: 0, y: 1)
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5), lineWidth: 0.5)
            )
    }
}
