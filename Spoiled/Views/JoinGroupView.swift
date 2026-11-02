import SwiftUI

// MARK: - GroupSharingNotice

/// Says what joining a group shares, so nobody finds out afterwards.
struct GroupSharingNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("If you join, people in this group can see:")
                .font(.subheadline.weight(.semibold))
            Label("Your name, birthdate and sizes", systemImage: "person.fill")
            Label("Wishlist items you share with the group", systemImage: "gift.fill")
            Label("Your kids' names, birthdates and sizes, and items you share for them", systemImage: "figure.and.child.holdinghands")
            Text("You can leave a group at any time.")
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .font(.subheadline)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .spoiledCard()
    }
}

// MARK: - JoinGroupConfirmation

/// The decision itself: which group, who's asking, and what joining shares.
private struct JoinGroupConfirmation: View {
    let groupName: String
    let invitedByName: String?
    let joinTitle: String
    let declineTitle: String
    let isWorking: Bool
    let errorMessage: String?
    let onJoin: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Join \(groupName)?")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                if let invitedByName {
                    Text("\(invitedByName) invited you")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            GroupSharingNotice()

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Button(action: onJoin) {
                Text(isWorking ? "Joining…" : joinTitle)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandGold)
            .disabled(isWorking)

            Button(declineTitle, action: onDecline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .disabled(isWorking)
        }
    }
}

// MARK: - InvitationReviewView

/// Accept or decline an invitation sent to the user's email address.
struct InvitationReviewView: View {
    let invitation: GroupInvitation
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            JoinGroupConfirmation(
                groupName: invitation.groupName,
                invitedByName: invitation.invitedByName,
                joinTitle: "Join Group",
                declineTitle: "Decline",
                isWorking: isWorking,
                errorMessage: errorMessage,
                onJoin: { respond(accept: true) },
                onDecline: { respond(accept: false) }
            )
            .padding(24)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .trackScreen("group_invitation")
    }

    private func respond(accept: Bool) {
        isWorking = true
        errorMessage = nil
        Task {
            let ok = await viewModel.respondToInvitation(invitation, accept: accept)
            isWorking = false
            if ok {
                toastCenter.success(accept ? "You joined \(invitation.groupName)" : "Invitation declined")
                dismiss()
            } else {
                errorMessage = viewModel.errorMessage ?? "Something went wrong. Please try again."
            }
        }
    }
}

// MARK: - JoinGroupView

/// Join with an invite code, typed in or from a link.
struct JoinGroupView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss

    @State private var code: String
    @State private var preview: InviteCodePreview?
    @State private var isWorking = false
    @State private var errorMessage: String?
    private let openedFromLink: Bool

    init(code: String = "") {
        _code = State(initialValue: code)
        openedFromLink = !code.isEmpty
    }

    private var trimmedCode: String { code.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                SwiftUI.Group {
                    if let preview, preview.alreadyMember {
                        EmptyStateView(
                            systemImage: "person.3.fill",
                            title: "You're already in \(preview.groupName)",
                            subtitle: "Find it in your groups."
                        )
                    } else if let preview {
                        JoinGroupConfirmation(
                            groupName: preview.groupName,
                            invitedByName: preview.invitedByName,
                            joinTitle: "Join Group",
                            declineTitle: "Not Now",
                            isWorking: isWorking,
                            errorMessage: errorMessage,
                            onJoin: join,
                            onDecline: { dismiss() }
                        )
                    } else {
                        codeEntry
                    }
                }
                .padding(24)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Join a Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text(preview?.alreadyMember == true ? "Done" : "Cancel")
                            .navButton(isIcon: false)
                    }
                }
            }
            .task {
                if openedFromLink { await lookUp() }
            }
        }
        .trackScreen("join_group")
    }

    private var codeEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(icon: "ticket.fill", title: "Invite Code")
            TextField("Enter code", text: $code)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .spoiledCard()
                .onSubmit { Task { await lookUp() } }

            Text("Ask someone in the group for their invite link or code.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await lookUp() }
            } label: {
                Text(isWorking ? "Checking…" : "Continue")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandGold)
            .disabled(trimmedCode.isEmpty || isWorking)
            .padding(.top, 4)
        }
    }

    private func lookUp() async {
        isWorking = true
        errorMessage = nil
        preview = await viewModel.previewInviteCode(trimmedCode)
        if preview == nil {
            errorMessage = viewModel.errorMessage ?? "Something went wrong. Please try again."
        }
        isWorking = false
    }

    private func join() {
        guard let preview else { return }
        isWorking = true
        errorMessage = nil
        Task {
            let ok = await viewModel.joinGroup(code: trimmedCode)
            isWorking = false
            if ok {
                toastCenter.success("You joined \(preview.groupName)")
                dismiss()
            } else {
                errorMessage = viewModel.errorMessage ?? "Something went wrong. Please try again."
            }
        }
    }
}

// MARK: - InvitationRow

struct GroupInvitationRow: View {
    let invitation: GroupInvitation

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(invitation.groupName)
                    .font(.body.weight(.semibold))
                if let invitedByName = invitation.invitedByName {
                    Text("\(invitedByName) invited you")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("Review")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.brandGold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

// MARK: - InviteLinkSection

/// The group's invite link, for admins to send however they like. Spoiled doesn't send email.
struct InviteLinkSection: View {
    let group: Group
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var invite: GroupInviteCode?
    @State private var isLoading = false
    @State private var showingReplaceAlert = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionHeader(icon: "link", title: "Invite Link")
            VStack(alignment: .leading, spacing: 12) {
                if let invite, let url = URL(string: invite.url) {
                    HStack {
                        Text("Code")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(invite.code)
                            .font(.body.monospaced().weight(.semibold))
                            .textSelection(.enabled)
                    }
                    ShareLink(item: url, message: Text("Join my group “\(group.name)” on Spoiled. If you need the app first, your code is \(invite.code).")) {
                        Label("Share Invite Link", systemImage: "square.and.arrow.up")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brandGold)
                    Button("Get a New Link") { showingReplaceAlert = true }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Button("Try Again") { Task { await load() } }
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .spoiledCard()

            Text(footnote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .task { await load() }
        .alert("Get a New Link?", isPresented: $showingReplaceAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Get New Link", role: .destructive) { Task { await replace() } }
        } message: {
            Text("The current link and code will stop working.")
        }
    }

    private var footnote: String {
        guard let invite, let expires = parseAPIDate(invite.expiresAt) else {
            return "Anyone with the link can ask to join this group."
        }
        return "Anyone with the link can join this group until \(Self.dateFormatter.string(from: expires))."
    }

    private func load() async {
        isLoading = true
        invite = await viewModel.inviteCode(for: group)
        isLoading = false
    }

    private func replace() async {
        isLoading = true
        if let replaced = await viewModel.inviteCode(for: group, replacing: true) {
            invite = replaced
            toastCenter.success("New link ready")
        } else {
            toastCenter.error(viewModel.errorMessage ?? "Couldn't get a new link")
        }
        isLoading = false
    }
}
