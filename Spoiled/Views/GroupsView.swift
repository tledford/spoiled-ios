import SwiftUI

struct GroupsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var showingAddGroupSheet = false
    
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
                    }
                }
            }
            .navigationTitle("My Groups")
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
    
    var body: some View {
        List {
            if group.members.isEmpty {
                Text("No other members in this group")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(group.members) { member in
                    DisclosureGroup(member.name) {
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
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            if group.isAdmin {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        EditGroupView(group: group)
                    } label: {
                        Text("Edit")
                    }
                }
            }
        }
    }
} 
