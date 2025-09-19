import SwiftUI

struct GroupsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showingAddGroupSheet = false
    @State private var showDeleteAlert = false
    @State private var groupToDelete: Group?
    
    var body: some View {
        NavigationStack {
            List {
                if let currentUserGroups = viewModel.groups, currentUserGroups.isEmpty {
                    Text("No groups yet. Create one by tapping the + button!")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    ForEach(viewModel.groups ?? []) { group in
//                        if viewModel.currentUser?.groups.contains(where: { $0.id == group.id }) == true {
                            NavigationLink(destination: GroupDetailView(group: group)) {
                                GroupRow(group: group)
                            }
//                        }
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
            .navigationTitle("My Groups")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await viewModel.refreshAll() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddGroupSheet = true }) {
                        Image(systemName: "plus")
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
    }
}

struct GroupRow: View {
    let group: Group
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(group.name)
                .font(.headline)
        }
    }
}

struct GroupDetailView: View {
    let group: Group
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showDeleteAlert = false
    @State private var sizesToShow: IdentSizes? = nil
    
    var body: some View {
        List {
            if group.members.isEmpty {
                Text("No other members in this group")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(group.members) { member in
                    Section {
                        if !member.wishlistItems.isEmpty {
                            ForEach(member.wishlistItems) { item in
                                WishlistItemRow(
                                    item: item,
                                    viewModel: viewModel,
                                    isInGroupView: true,
                                    kidId: nil,
                                    groupId: group.id,
                                    groupMemberId: member.id
                                )
                            }
                        } else {
                            Text("No personal wishlist items")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    } header: {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(member.name)
                                    if hasNonEmptySizes(member.sizes) {
                                        Button {
                                            sizesToShow = IdentSizes(member.sizes)
                                        } label: {
                                            Image(systemName: "exclamationmark.circle")
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundColor(.blue)
                                        .accessibilityLabel("View sizes for \(member.name)")
                                    }
                                }
                                if let b = member.birthdate {
                                    Text(birthdayLine(from: b))
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

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
                                        groupMemberId: member.id
                                    )
                                }
                            } else {
                                Text("No wishlist items")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                        } header: {
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(kid.name)
                                        if hasNonEmptySizes(kid.sizes) {
                                            Button {
                                                sizesToShow = IdentSizes(kid.sizes)
                                            } label: {
                                                Image(systemName: "exclamationmark.circle")
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundColor(.blue)
                                            .accessibilityLabel("View sizes for \(kid.name)")
                                        }
                                    }
                                    if let b = kid.birthdate {
                                        Text(birthdayLine(from: b))
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    .navigationTitle(group.name)
    .navigationBarTitleDisplayMode(.inline)
    .refreshable { await viewModel.refreshAll() }
        .toolbar {
            if group.isAdmin {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        NavigationLink {
                            EditGroupView(group: group)
                        } label: {
                            Label("Edit", systemImage: "pencil")
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

private func hasNonEmptySizes(_ sizes: Sizes) -> Bool {
    return !sizes.shirt.isEmpty || !sizes.pants.isEmpty || !sizes.shoes.isEmpty || !sizes.sweatshirt.isEmpty || !sizes.hat.isEmpty
}

private func birthdayLine(from birthdate: Date) -> String {
    let days = daysUntilNextBirthday(from: birthdate)
    // Show upcoming date (month/day) and days remaining
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

private func daysUntilNextBirthday(from birthdate: Date, relativeTo now: Date = Date()) -> Int {
    let cal = Calendar.current
    let start = cal.startOfDay(for: now)
    let next = nextBirthdayDate(from: birthdate, relativeTo: start)
    let days = cal.dateComponents([.day], from: start, to: next).day ?? 0
    return max(0, days)
}

// Identifiable wrapper so we can use .sheet(item:) and always pass the selected sizes
struct IdentSizes: Identifiable, Equatable {
    let id = UUID()
    let value: Sizes
    init(_ value: Sizes) { self.value = value }
}

struct ListSizesView: View {
    let sizes: Sizes
    var body: some View {
        List {
            if !sizes.shirt.isEmpty { row(label: "Shirt", value: sizes.shirt) }
            if !sizes.pants.isEmpty { row(label: "Pants", value: sizes.pants) }
            if !sizes.shoes.isEmpty { row(label: "Shoes", value: sizes.shoes) }
            if !sizes.sweatshirt.isEmpty { row(label: "Sweatshirt", value: sizes.sweatshirt) }
            if !sizes.hat.isEmpty { row(label: "Hat", value: sizes.hat) }
            if sizes.shirt.isEmpty && sizes.pants.isEmpty && sizes.shoes.isEmpty && sizes.sweatshirt.isEmpty && sizes.hat.isEmpty {
                Text("No sizes provided")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            }
        }
    }

    @ViewBuilder
    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}
