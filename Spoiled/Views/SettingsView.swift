import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var toast: ToastCenter
    @State private var showingEditProfile = false
    @State private var showDeleteConfirm = false
    @State private var showAppleDeletionSheet = false

    var body: some View {
        NavigationStack {
            List {
                // Profile card
                Section {
                    if let user = viewModel.currentUser {
                        HStack(spacing: 14) {
                            PersonAvatar(name: user.name, size: 56)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(user.name)
                                    .font(.system(size: 18, weight: .semibold))
                                Text(user.email)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                showingEditProfile = true
                            } label: {
                                Text("Edit")
                                    .navButton(color: .brandBlue, isIcon: false)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.appSurface)
                    }
                }

                Section("Family") {
                    NavigationLink {
                        ManageKidsView()
                    } label: {
                        Label("Manage Kids", systemImage: "figure.and.child.holdinghands")
                    }
                    .listRowBackground(Color.appSurface)
                }

                Section("Reports") {
                    NavigationLink {
                        PurchasedGiftsReportView()
                    } label: {
                        Label("Purchased Gifts", systemImage: "checklist")
                    }
                    .listRowBackground(Color.appSurface)
                }

                // Account actions
                Section {
                    Button(role: .destructive) {
                        auth.signOut()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.appSurface)
                }

                // Danger zone
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Account")
                                .font(.footnote)
                            Spacer()
                        }
                    }
                    .listRowBackground(Color.appSurface)
                } footer: {
                    HStack {
                        Spacer()
                        Link("Privacy Policy", destination: AppConfig.api.privacyPolicyURL)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
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

// MARK: - AppleAccountDeletionSheet

private struct AppleAccountDeletionSheet: View {
    @EnvironmentObject var auth: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)

                Text("Confirm Deletion")
                    .font(.title2).bold()
                Text("To delete your account, Apple requires you to re-authorize. This action is immediate and irreversible.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                SignInWithAppleButton(.continue, onRequest: { req in
                    auth.beginAppleAccountDeletion(req)
                }, onCompletion: { result in
                    if case .failure(let error) = result {
                        print("Apple deletion reauth failed: \(error.localizedDescription)")
                    }
                    auth.handleAppleAccountDeletionCompletion(result)
                    dismiss()
                })
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 50)
                .padding(.horizontal)

                Button("Cancel", role: .cancel) { dismiss() }
                    .padding(.top, 4)
            }
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Delete Account")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
