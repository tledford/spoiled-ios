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
            SwiftUI.Group {
                if let groups = viewModel.groups, !groups.isEmpty {
                    List {
                        Section {
                            ForEach(groups) { group in
                                NavigationLink(destination: GroupDetailView(group: group)) {
                                    GroupRow(group: group)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if group.isAdmin {
                                        Button(role: .destructive) {
                                            groupToDelete = group
                                            showDeleteAlert = true
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        .disabled(viewModel.deletingGroupIds.contains(group.id))
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground.ignoresSafeArea())
                } else {
                    ScrollView {
                        EmptyStateView(
                            systemImage: "person.3",
                            title: "No groups yet",
                            subtitle: "Create a group to share wishlists with family or friends"
                        )
                    }
                    .background(Color.appBackground.ignoresSafeArea())
                }
            }
            .navigationTitle("My Groups")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await viewModel.refreshAll() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGroupSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
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
        .padding(.vertical, 4)
        .listRowBackground(Color.appSurface)
    }
}

// MARK: - GroupDetailView

struct GroupDetailView: View {
    let group: Group
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showDeleteAlert = false
    @State private var sizesToShow: IdentSizes? = nil

    var body: some View {
        List {
            if group.members.isEmpty {
                Section {
                    EmptyStateView(
                        systemImage: "person.2",
                        title: "No members yet",
                        subtitle: "Add members in the group settings"
                    )
                }
                .listRowBackground(Color.clear)
                .listRowInsets(.init())
            } else {
                    ForEach(group.members) { member in
                        // Personal wishlist section
                        Section {
                            if !member.wishlistItems.isEmpty {
                                ForEach(member.wishlistItems) { item in
                                    WishlistItemRow(
                                        item: item,
                                        viewModel: viewModel,
                                        isInGroupView: true,
                                        kidId: nil,
                                        groupId: group.id,
                                        groupMemberId: member.id,
                                        useSheet: true
                                    )
                                }
                            } else {
                                Text("No personal wishlist items")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.vertical, 4)
                                    .listRowBackground(Color.appSurface)
                            }
                        } header: {
                            MemberSectionHeader(
                                name: member.name,
                                birthdate: member.birthdate,
                                sizes: member.sizes,
                                onSizesTap: { sizesToShow = IdentSizes(member.sizes) }
                            )
                        }

                        // Kids sections
                        ForEach(member.kids) { kid in
                            Section {
                                if !kid.wishlistItems.isEmpty {
                                    ForEach(kid.wishlistItems) { item in
                                        WishlistItemRow(
                                            item: item,
                                            viewModel: viewModel,
                                            isInGroupView: true,
                                            kidId: kid.id,
                                            groupId: group.id,
                                            groupMemberId: member.id,
                                            useSheet: true
                                        )
                                    }
                                } else {
                                    Text("No wishlist items")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 4)
                                        .listRowBackground(Color.appSurface)
                                }
                            } header: {
                                MemberSectionHeader(
                                    name: kid.name,
                                    birthdate: kid.birthdate,
                                    sizes: kid.sizes,
                                    isKid: true,
                                    onSizesTap: { sizesToShow = IdentSizes(kid.sizes) }
                                )
                            }
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.refreshAll() }
        .toolbar {
            if group.isAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
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
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
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
                            Button("Done") { sizesToShow = nil }
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
            PersonAvatar(name: name, size: 32)

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
        List {
            if !sizes.shirt.isEmpty     { sizeRow(label: "Shirt",       value: sizes.shirt) }
            if !sizes.pants.isEmpty     { sizeRow(label: "Pants",       value: sizes.pants) }
            if !sizes.shoes.isEmpty     { sizeRow(label: "Shoes",       value: sizes.shoes) }
            if !sizes.sweatshirt.isEmpty { sizeRow(label: "Sweatshirt", value: sizes.sweatshirt) }
            if !sizes.hat.isEmpty       { sizeRow(label: "Hat",         value: sizes.hat) }
            if sizes.shirt.isEmpty && sizes.pants.isEmpty && sizes.shoes.isEmpty
                && sizes.sweatshirt.isEmpty && sizes.hat.isEmpty {
                Text("No sizes provided")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func sizeRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Helpers

private func hasNonEmptySizes(_ sizes: Sizes) -> Bool {
    !sizes.shirt.isEmpty || !sizes.pants.isEmpty || !sizes.shoes.isEmpty
        || !sizes.sweatshirt.isEmpty || !sizes.hat.isEmpty
}

private func birthdayLine(from birthdate: Date) -> String {
    let days = daysUntilNextBirthday(from: birthdate)
    let next = nextBirthdayDate(from: birthdate)
    let md = DateFormatter()
    md.setLocalizedDateFormatFromTemplate("MMMMd")
    let dayWord = days == 1 ? "day" : "days"
    return "Birthday: \(md.string(from: next)) (\(days) \(dayWord))"
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
