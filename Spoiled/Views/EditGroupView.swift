import SwiftUI

struct EditGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var name: String
    @State private var showingDeleteMemberAlert = false
    @State private var memberToDelete: GroupMember?
    @State private var showingAddMemberSheet = false
    
    let group: Group
    
    init(group: Group) {
        self.group = group
        _name = State(initialValue: group.name)
    }
    
    var body: some View {
        Form {
            Section("Group Info") {
                TextField("Group Name", text: $name)
            }
            
            Section("Members") {
                ForEach(group.members) { member in
                    HStack {
                        Text(member.name)
                        Spacer()
                        Button(role: .destructive) {
                            memberToDelete = member
                            showingDeleteMemberAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Button {
                    showingAddMemberSheet = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                        Text("Add Member")
                    }
                }
            }
        }
        .navigationTitle("Edit Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveGroup()
                }
                .disabled(name.isEmpty)
            }
        }
        .alert("Remove Member?", isPresented: $showingDeleteMemberAlert) {
            Button("Cancel", role: .cancel) {
                memberToDelete = nil
            }
            Button("Remove", role: .destructive) {
                if let member = memberToDelete {
                    viewModel.removeMemberFromGroup(member, from: group)
                }
                memberToDelete = nil
            }
        } message: {
            if let member = memberToDelete {
                Text("Are you sure you want to remove \(member.name) from this group?")
            }
        }
        .sheet(isPresented: $showingAddMemberSheet) {
            AddGroupMemberView(group: group)
        }
    }
    
    private func saveGroup() {
        viewModel.updateGroup(group, newName: name)
        dismiss()
    }
}

struct AddGroupMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var email = ""
    @State private var showingInvalidEmailAlert = false
    
    let group: Group
    
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email Address", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Text("Enter the email address of the person you want to add to this group.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if isValidEmail {
                            viewModel.addMemberToGroup(email: email, to: group)
                            dismiss()
                        } else {
                            showingInvalidEmailAlert = true
                        }
                    }
                    .disabled(email.isEmpty)
                }
            }
            .alert("Invalid Email", isPresented: $showingInvalidEmailAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter a valid email address.")
            }
        }
    }
} 