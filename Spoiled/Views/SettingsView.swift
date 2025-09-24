import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var toast: ToastCenter
    @State private var showingEditProfile = false
    @State private var showDebug = false
    @State private var showDeleteConfirm = false
    @State private var showAppleDeletionSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    if let user = viewModel.currentUser {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Edit") {
                                showingEditProfile = true
                            }
                        }
                    }
                }
                
                Section("Kids") {
                    NavigationLink("Manage Kids") {
                        ManageKidsView()
                    }
                }
                
                Section("Account") {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("Delete Account")
                    }
                    .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                        if auth.isCurrentUserApple() {
                            Button("Delete Now", role: .destructive) {
                                showAppleDeletionSheet = true
                            }
                        } else {
                            Button("Delete Now", role: .destructive) {
                                Task { await auth.deleteCurrentUserWithoutApple() }
                                toast.info("Account deleted")
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This action is immediate and irreversible. Your account and all associated data will be permanently deleted.")
                    }

                    Button(role: .destructive) {
                        auth.signOut()
                    } label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
            .sheet(isPresented: $showAppleDeletionSheet) {
                AppleAccountDeletionSheet()
                    .environmentObject(auth)
            }
        }
    .trackScreen("settings")
    }
}

private struct AppleAccountDeletionSheet: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Confirm Deletion")
                    .font(.title2).bold()
                Text("To delete your account, Apple requires you to re-authorize. This action is immediate and irreversible.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                SignInWithAppleButton(.continue, onRequest: { req in
                    auth.beginAppleAccountDeletion(req)
                }, onCompletion: { result in
                    if case .failure(let error) = result {
                        print("Apple deletion reauth failed: \(error.localizedDescription)")
                    }
                    auth.handleAppleAccountDeletionCompletion(result)
                    // After completion, dismiss; app will transition to unauthenticated on success
                    dismiss()
                })
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 44)

                Button("Cancel", role: .cancel) { dismiss() }
                    .padding(.top, 8)
            }
            .padding()
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
