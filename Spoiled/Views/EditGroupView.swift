import SwiftUI

struct EditGroupView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var name: String
    @State private var showingDeleteMemberAlert = false
    @State private var memberToDelete: GroupMember?
    @State private var showingDeletePendingInvitationAlert = false
    @State private var pendingInvitationToDelete: PendingInvitation?
    @State private var showingAddMemberSheet = false
    
    let group: Group
    
    init(group: Group) {
        self.group = group
        _name = State(initialValue: group.name)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Group Info
                VStack(alignment: .leading, spacing: 8) {
                    AppSectionHeader(icon: "info.circle.fill", title: "Group Info")
                    VStack(spacing: 0) {
                        TextField("Group Name", text: $name)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                    }
                    .spoiledCard()
                }

                // Members
                VStack(alignment: .leading, spacing: 8) {
                    AppSectionHeader(icon: "person.2.fill", title: "Members")
                    VStack(spacing: 0) {
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
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            Divider().padding(.leading, 16)
                        }

                        Button {
                            showingAddMemberSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Add Member")
                            }
                            .foregroundStyle(Color.brandGold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                    .spoiledCard()
                }

                if !group.pendingInvitations.isEmpty {
                    // Pending Invitations
                    VStack(alignment: .leading, spacing: 8) {
                        AppSectionHeader(icon: "envelope.fill", title: "Pending Invitations")
                        VStack(spacing: 0) {
                            ForEach(Array(group.pendingInvitations.enumerated()), id: \.element.id) { index, pendingInvitation in
                                HStack {
                                    Text(pendingInvitation.email)
                                        .font(.body)
                                    Spacer()
                                    Button(role: .destructive) {
                                        pendingInvitationToDelete = pendingInvitation
                                        showingDeletePendingInvitationAlert = true
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)

                                if index < group.pendingInvitations.count - 1 {
                                    Divider().padding(.leading, 16)
                                }
                            }
                        }
                        .spoiledCard()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("Edit Group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        let ok = await viewModel.updateGroup(group, newName: name)
                        if ok {
                            await viewModel.refreshAll()
                            toastCenter.success("Group updated")
                            dismiss()
                        } else {
                            toastCenter.error(viewModel.errorMessage ?? "Failed to update group")
                        }
                    }
                } label: {
                    Text("Save")
                        .navButton(isIcon: false)
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
                    Task {
                        let ok = await viewModel.removeMemberFromGroup(member, from: group)
                        if ok {
                            await viewModel.refreshAll()
                            toastCenter.success("Member removed")
                        } else {
                            toastCenter.error(viewModel.errorMessage ?? "Failed to remove member")
                        }
                    }
                }
                memberToDelete = nil
            }
        } message: {
            if let member = memberToDelete {
                Text("Are you sure you want to remove \(member.name) from this group?")
            }
        }
        .alert("Cancel Invitation?", isPresented: $showingDeletePendingInvitationAlert) {
            Button("No", role: .cancel) {
                pendingInvitationToDelete = nil
            }
            Button("Yes", role: .destructive) {
                if let invitation = pendingInvitationToDelete {
                    Task {
                        let ok = await viewModel.removePendingInvitation(email: invitation.email, from: group)
                        if ok {
                            await viewModel.refreshAll()
                            toastCenter.success("Invitation cancelled")
                        } else {
                            toastCenter.error(viewModel.errorMessage ?? "Failed to cancel invitation")
                        }
                    }
                }
                pendingInvitationToDelete = nil
            }
        } message: {
            if let invitation = pendingInvitationToDelete {
                Text("Are you sure you want to cancel the invitation for \(invitation.email)?")
            }
        }
        .sheet(isPresented: $showingAddMemberSheet) {
            AddGroupMemberView(group: group)
                .environmentObject(viewModel)
                .environmentObject(toastCenter)
        }
    .trackScreen("edit_group")
    }
}

struct AddGroupMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
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
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppSectionHeader(icon: "envelope.fill", title: "Invite Member")
                        VStack(spacing: 0) {
                            TextField("Email Address", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)
                                .autocorrectionDisabled()
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                        }
                        .spoiledCard()
                        
                        Text("Enter the email address of the person you want to add to this group.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .navButton(isIcon: false)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        if isValidEmail {
                            Task {
                                let ok = await viewModel.addMemberToGroup(email: email, to: group)
                                if ok {
                                    await viewModel.refreshAll()
                                    toastCenter.success("Member added")
                                    dismiss()
                                } else {
                                    toastCenter.error(viewModel.errorMessage ?? "Failed to add member")
                                }
                            }
                        } else {
                            showingInvalidEmailAlert = true
                        }
                    } label: {
                        Text("Add")
                            .navButton(isIcon: false)
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
    .trackScreen("add_group_member")
    }
}
