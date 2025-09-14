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
            // Since we no longer have member references, we can't show member count here
        }
    }
}

struct GroupDetailView: View {
    let group: Group
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showDeleteAlert = false
    
    var body: some View {
        List {
            if group.members.isEmpty {
                Text("No other members in this group")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(group.members) { member in
                    Section(member.name) {
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

                        let kidsWithItems = member.kids.filter { !$0.wishlistItems.isEmpty }
                        if !kidsWithItems.isEmpty {
                            ForEach(kidsWithItems) { kid in
                                DisclosureGroup("\(kid.name) (Kid)") {
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
    }
} 
