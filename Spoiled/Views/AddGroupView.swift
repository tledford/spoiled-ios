import SwiftUI

struct AddGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    
    @State private var name = ""
    @State private var selectedMemberIds: Set<UUID> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Group Name", text: $name)
                }
                
//                Section("Add Members") {
//                    ForEach(viewModel.currentUser?.groups.groupMembers) { member in
//                        if member.id != viewModel.currentUser?.id {
//                            Toggle(member.name, isOn: Binding(
//                                get: { selectedMemberIds.contains(member.id) },
//                                set: { isSelected in
//                                    if isSelected {
//                                        selectedMemberIds.insert(member.id)
//                                    } else {
//                                        selectedMemberIds.remove(member.id)
//                                    }
//                                }
//                            ))
//                        }
//                    }
//                }
            }
            .navigationTitle("New Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createGroup() {
        let group = Group(name: name)
        viewModel.addGroup(group)
        dismiss()
    }
} 
