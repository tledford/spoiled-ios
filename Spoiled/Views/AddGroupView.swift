import SwiftUI

struct AddGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    
    @State private var name = ""
    @State private var selectedMemberIds: Set<UUID> = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppSectionHeader(icon: "person.2.fill", title: "Group Details")
                        VStack(spacing: 0) {
                            TextField("Group Name", text: $name)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                        .spoiledCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .navButton(color: .brandBlue, isIcon: false)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { createGroup() } label: {
                        Text("Create")
                            .navButton(color: .brandGold, isIcon: false)
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    .trackScreen("add_group")
    }
    
    private func createGroup() {
        let group = Group(name: name)
        viewModel.addGroup(group)
        dismiss()
    }
} 
