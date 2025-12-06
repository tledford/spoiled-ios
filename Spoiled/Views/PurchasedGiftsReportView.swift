import SwiftUI

struct PurchasedGiftsReportView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                if allPurchasedGiftsInLastSixMonths.isEmpty && purchasedGiftIdeas.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "gift")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("No Purchased Gifts")
                            .font(.headline)
                        Text("No gifts have been marked as purchased.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    List {
                        // Beautiful summary header that scrolls
                        Section {
                            VStack(spacing: 16) {
                                Text("Purchased Gifts Summary")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                HStack(spacing: 20) {
                                    SummaryCard(
                                        icon: "list.bullet.clipboard",
                                        title: "Wishlist Items",
                                        count: allPurchasedGiftsInLastSixMonths.count
                                    )
                                    
                                    SummaryCard(
                                        icon: "lightbulb.fill",
                                        title: "Gift Ideas",
                                        count: purchasedGiftIdeas.count
                                    )
                                }
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        
                        
                        // Purchased gifts grouped by group member
                        ForEach(groupedByGroupMember.keys.sorted { member1, member2 in
                            member1.name < member2.name
                        }, id: \.id) { member in
                            Section(header: Text("Purchased for \(member.name)")) {
                                ForEach(groupedByGroupMember[member] ?? [], id: \.id) { item in
                                    PurchasedGiftRow(item: item)
                                }
                            }
                        }
                        
                        // Purchased gifts grouped by kid (from own kids)
                        ForEach(groupedByKid.keys.sorted { kid1, kid2 in
                            kid1.name < kid2.name
                        }, id: \.id) { kid in
                            Section(header: Text("Purchased for \(kid.name)")) {
                                ForEach(groupedByKid[kid] ?? [], id: \.id) { item in
                                    PurchasedGiftRow(item: item)
                                }
                            }
                        }
                        
                        // Purchased gift ideas grouped by person
                        ForEach(groupedGiftIdeasByPerson.keys.sorted(), id: \.self) { personName in
                            Section(header: Text("Gift Ideas for \(personName)")) {
                                ForEach(groupedGiftIdeasByPerson[personName] ?? [], id: \.id) { idea in
                                    PurchasedGiftIdeaRow(idea: idea)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Purchased Gifts")
            .navigationBarTitleDisplayMode(.inline)
        }
        .trackScreen("purchased_gifts_report")
    }
    
    // MARK: - Computed Properties
    
    private var allPurchasedGiftsInLastSixMonths: [WishlistItem] {
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        var seenIds = Set<UUID>()
        var purchasedGifts: [WishlistItem] = []
        
        guard let currentUserId = viewModel.currentUser?.id else { return [] }
        
        // Collect from all group members' wishlist items
        if let groups = viewModel.groups {
            for group in groups {
                for member in group.members {
                    for item in member.wishlistItems {
                        if item.isPurchased &&
                           item.purchasedAt != nil &&
                           item.purchasedAt! >= sixMonthsAgo &&
                           !seenIds.contains(item.id) &&
                           item.purchasedBy == currentUserId {
                            purchasedGifts.append(item)
                            seenIds.insert(item.id)
                        }
                    }

                    for kidItem in member.kids.flatMap({ $0.wishlistItems }) {
                        if kidItem.isPurchased &&
                           kidItem.purchasedAt != nil &&
                           kidItem.purchasedAt! >= sixMonthsAgo &&
                           !seenIds.contains(kidItem.id) &&
                           kidItem.purchasedBy == currentUserId {
                            purchasedGifts.append(kidItem)
                            seenIds.insert(kidItem.id)
                        }
                    }
                }
            }
        }
        
        return purchasedGifts
    }
    
    private var purchasedGiftIdeas: [GiftIdea] {
        guard let ideas = viewModel.giftIdeas else { return [] }
        return ideas.filter { $0.isPurchased }
    }
    
    private var groupedByGroupMember: [GroupMember: [WishlistItem]] {
        var grouped: [GroupMember: [WishlistItem]] = [:]
        var seenMemberIds = Set<String>()
        
        guard let groups = viewModel.groups else { return [:] }
        
        for group in groups {
            for member in group.members {
                // Skip if we've already processed this member
                if seenMemberIds.contains(member.id) {
                    continue
                }
                seenMemberIds.insert(member.id)
                
                // Collect only from member's own wishlist items (exclude kids)
                let memberGifts = allPurchasedGiftsInLastSixMonths.filter { item in
                    member.wishlistItems.contains(where: { $0.id == item.id })
                }
                
                if !memberGifts.isEmpty {
                    grouped[member] = memberGifts
                }
            }
        }
        
        return grouped
    }
    
    private var groupedByKid: [GroupMemberKid: [WishlistItem]] {
        var grouped: [GroupMemberKid: [WishlistItem]] = [:]
        var seenKidIds = Set<UUID>()
        
        guard let groups = viewModel.groups else { return [:] }
        
        for group in groups {
            for member in group.members {
                // Collect from member's kids' wishlist items
                for kid in member.kids {
                    // Skip if we've already processed this kid
                    if seenKidIds.contains(kid.id) {
                        continue
                    }
                    seenKidIds.insert(kid.id)
                    
                    let kidGifts = allPurchasedGiftsInLastSixMonths.filter { item in
                        kid.wishlistItems.contains(where: { $0.id == item.id })
                    }
                    
                    if !kidGifts.isEmpty {
                        grouped[kid] = kidGifts
                    }
                }
            }
        }
        
        return grouped
    }
    
    private var groupedGiftIdeasByPerson: [String: [GiftIdea]] {
        var grouped: [String: [GiftIdea]] = [:]
        
        for idea in purchasedGiftIdeas {
            if grouped[idea.personName] != nil {
                grouped[idea.personName]?.append(idea)
            } else {
                grouped[idea.personName] = [idea]
            }
        }
        
        return grouped
    }
}

private struct PurchasedGiftRow: View {
    let item: WishlistItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                }
                Spacer()
            }
            
            HStack(spacing: 16) {
                if let purchasedAt = item.purchasedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text(formatDate(purchasedAt))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

private struct PurchasedGiftIdeaRow: View {
    let idea: GiftIdea
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(idea.giftName)
                        .font(.headline)
                }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SummaryCard: View {
    let icon: String
    let title: String
    let count: Int
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

#Preview {
    PurchasedGiftsReportView()
        .environmentObject(WishlistViewModel())
}
