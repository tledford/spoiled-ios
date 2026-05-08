import SwiftUI

// MARK: - GroupsView

struct GroupsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showingAddGroupSheet = false
    @State private var showDeleteAlert = false
    @State private var groupToDelete: Group?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let groups = viewModel.groups, !groups.isEmpty {
                        ForEach(groups) { group in
                            NavigationLink(destination: GroupDetailView(group: group)) {
                                GroupRow(group: group)
                                    .spoiledCard()
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                if group.isAdmin {
                                    Button(role: .destructive) {
                                        groupToDelete = group
                                        showDeleteAlert = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } else {
                        EmptyStateView(
                            systemImage: "person.3",
                            title: "No groups yet",
                            subtitle: "Create a group to share wishlists with family or friends"
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("My Groups")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await viewModel.refreshAll() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGroupSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .navButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddGroupSheet) {
                AddGroupView()
            }
            .alert("Delete Group?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { groupToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let g = groupToDelete {
                        Task {
                            let ok = await viewModel.deleteGroup(g)
                            if ok { toastCenter.success("Group deleted") }
                            else { toastCenter.error(viewModel.errorMessage ?? "Failed to delete group") }
                        }
                        groupToDelete = nil
                    }
                }
            } message: {
                Text("This will permanently delete the group and remove memberships. This action cannot be undone.")
            }
        }
        .trackScreen("groups")
    }
}

// MARK: - GroupRow

struct GroupRow: View {
    let group: Group

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brandGold.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.3.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.brandGold)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(group.name)
                        .font(.system(size: 16, weight: .semibold))
                    if group.isAdmin {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.brandGold)
                    }
                }
                let count = group.members.count
                Text(count == 1 ? "1 member" : "\(count) members")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            GoldBadge(text: "\(group.members.count)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// MARK: - GroupDetailView

struct GroupDetailView: View {
    let group: Group
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showDeleteAlert = false
    @State private var sizesToShow: IdentSizes? = nil
    @State private var hidePurchased: Bool = false

    private func filteredSorted(_ items: [WishlistItem]) -> [WishlistItem] {
        let visible = hidePurchased ? items.filter { !$0.isPurchased } : items
        return visible.sorted { !$0.isPurchased && $1.isPurchased }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if group.members.isEmpty {
                    EmptyStateView(
                        systemImage: "person.2",
                        title: "No members yet",
                        subtitle: "Add members in the group settings"
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(group.members) { member in
                        VStack(alignment: .leading, spacing: 12) {
                            MemberSectionHeader(
                                name: member.name,
                                birthdate: member.birthdate,
                                sizes: member.sizes,
                                onSizesTap: { sizesToShow = IdentSizes(member.sizes) }
                            )
                            .padding(.horizontal, 4)

                            // Personal wishlist
                            let memberItems = filteredSorted(member.wishlistItems)
                            VStack(spacing: 0) {
                                if memberItems.isEmpty {
                                    Text(hidePurchased && !member.wishlistItems.isEmpty ? "No unpurchased items" : "No personal wishlist items")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    ForEach(Array(memberItems.enumerated()), id: \.element.id) { index, item in
                                        WishlistItemRow(
                                            item: item,
                                            viewModel: viewModel,
                                            isInGroupView: true,
                                            kidId: nil,
                                            groupId: group.id,
                                            groupMemberId: member.id,
                                            useSheet: true
                                        )

                                        if index < memberItems.count - 1 {
                                            Divider().padding(.leading, 16)
                                        }
                                    }
                                }
                            }
                            .spoiledCard()

                            // Kids wishlists
                            ForEach(member.kids) { kid in
                                VStack(alignment: .leading, spacing: 12) {
                                    MemberSectionHeader(
                                        name: kid.name,
                                        birthdate: kid.birthdate,
                                        sizes: kid.sizes,
                                        isKid: true,
                                        onSizesTap: { sizesToShow = IdentSizes(kid.sizes) }
                                    )
                                    .padding(.horizontal, 4)
                                    .padding(.top, 4)

                                    let kidItems = filteredSorted(kid.wishlistItems)
                                    VStack(spacing: 0) {
                                        if kidItems.isEmpty {
                                            Text(hidePurchased && !kid.wishlistItems.isEmpty ? "No unpurchased items" : "No wishlist items")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .padding(16)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        } else {
                                            ForEach(Array(kidItems.enumerated()), id: \.element.id) { index, item in
                                                WishlistItemRow(
                                                    item: item,
                                                    viewModel: viewModel,
                                                    isInGroupView: true,
                                                    kidId: kid.id,
                                                    groupId: group.id,
                                                    groupMemberId: member.id,
                                                    useSheet: true
                                                )

                                                if index < kidItems.count - 1 {
                                                    Divider().padding(.leading, 16)
                                                }
                                            }
                                        }
                                    }
                                    .spoiledCard()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.refreshAll() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        withAnimation(.spring(response: 0.3)) { hidePurchased.toggle() }
                    } label: {
                        Label(
                            hidePurchased ? "Show Purchased Items" : "Hide Purchased Items",
                            systemImage: hidePurchased ? "eye" : "eye.slash"
                        )
                    }

                    if group.isAdmin {
                        NavigationLink {
                            EditGroupView(group: group)
                        } label: {
                            Label("Edit Group", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            showDeleteAlert = true
                        } label: {
                            Label("Delete Group", systemImage: "trash")
                        }
                        .disabled(viewModel.deletingGroupIds.contains(group.id))
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .navButton()
                }
            }
        }
        .alert("Delete Group?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    let ok = await viewModel.deleteGroup(group)
                    if ok { toastCenter.success("Group deleted") }
                    else { toastCenter.error(viewModel.errorMessage ?? "Failed to delete group") }
                }
            }
        } message: {
            Text("This will permanently delete the group and remove memberships. This action cannot be undone.")
        }
        .sheet(item: $sizesToShow) { sizes in
            NavigationStack {
                ListSizesView(sizes: sizes.value)
                    .navigationTitle("Sizes")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                sizesToShow = nil
                            } label: {
                                Text("Done")
                                    .navButton(isIcon: false)
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - MemberSectionHeader

private struct MemberSectionHeader: View {
    let name: String
    let birthdate: Date?
    let sizes: Sizes
    var isKid: Bool = false
    let onSizesTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if isKid {
                ZStack {
                    Circle()
                        .fill(Color.brandGold.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "figure.and.child.holdinghands")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.brandGold)
                }
            } else {
                PersonAvatar(name: name, size: 32)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .textCase(nil)

                if let b = birthdate {
                    let days = daysUntilNextBirthday(from: b)
                    BirthdayBadge(daysUntil: days)
                }
            }

            Spacer()

            if hasNonEmptySizes(sizes) {
                SizesPillButton(action: onSizesTap)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - ListSizesView

struct ListSizesView: View {
    let sizes: Sizes

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 0) {
                    if !sizes.shirt.isEmpty     { sizeRow(label: "Shirt",       value: sizes.shirt) }
                    if !sizes.shirt.isEmpty && (!sizes.pants.isEmpty || !sizes.shoes.isEmpty || !sizes.sweatshirt.isEmpty || !sizes.hat.isEmpty) { Divider().padding(.leading, 16) }
                    
                    if !sizes.pants.isEmpty     { sizeRow(label: "Pants",       value: sizes.pants) }
                    if !sizes.pants.isEmpty && (!sizes.shoes.isEmpty || !sizes.sweatshirt.isEmpty || !sizes.hat.isEmpty) { Divider().padding(.leading, 16) }
                    
                    if !sizes.shoes.isEmpty     { sizeRow(label: "Shoes",       value: sizes.shoes) }
                    if !sizes.shoes.isEmpty && (!sizes.sweatshirt.isEmpty || !sizes.hat.isEmpty) { Divider().padding(.leading, 16) }
                    
                    if !sizes.sweatshirt.isEmpty { sizeRow(label: "Sweatshirt", value: sizes.sweatshirt) }
                    if !sizes.sweatshirt.isEmpty && !sizes.hat.isEmpty { Divider().padding(.leading, 16) }
                    
                    if !sizes.hat.isEmpty       { sizeRow(label: "Hat",         value: sizes.hat) }
                    
                    if sizes.shirt.isEmpty && sizes.pants.isEmpty && sizes.shoes.isEmpty
                        && sizes.sweatshirt.isEmpty && sizes.hat.isEmpty {
                        Text("No sizes provided")
                            .foregroundStyle(.secondary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .spoiledCard()
            }
            .padding(16)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }

    @ViewBuilder
    private func sizeRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

// MARK: - Helpers

private func hasNonEmptySizes(_ sizes: Sizes) -> Bool {
    !sizes.shirt.isEmpty || !sizes.pants.isEmpty || !sizes.shoes.isEmpty
        || !sizes.sweatshirt.isEmpty || !sizes.hat.isEmpty
}

private func nextBirthdayDate(from birthdate: Date, relativeTo now: Date = Date()) -> Date {
    let cal = Calendar.current
    var comps = cal.dateComponents([.month, .day], from: birthdate)
    let currentYear = cal.component(.year, from: now)
    comps.year = currentYear
    let thisYear = cal.date(from: comps) ?? now
    if thisYear >= cal.startOfDay(for: now) { return thisYear }
    comps.year = currentYear + 1
    return cal.date(from: comps) ?? thisYear
}

func daysUntilNextBirthday(from birthdate: Date, relativeTo now: Date = Date()) -> Int {
    let cal = Calendar.current
    let start = cal.startOfDay(for: now)
    let next = nextBirthdayDate(from: birthdate, relativeTo: start)
    let days = cal.dateComponents([.day], from: start, to: next).day ?? 0
    return max(0, days)
}

// MARK: - IdentSizes

struct IdentSizes: Identifiable, Equatable {
    let id = UUID()
    let value: Sizes
    init(_ value: Sizes) { self.value = value }
}
