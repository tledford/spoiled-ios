import SwiftUI
import AuthenticationServices
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @EnvironmentObject private var toast: ToastCenter
    @EnvironmentObject private var themeStore: ThemeStore
    @EnvironmentObject private var notificationSettings: BirthdayNotificationSettings
    @EnvironmentObject private var notifications: BirthdayNotificationCoordinator
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
                                    .navButton(isIcon: false)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(Color.appSurface)
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $themeStore.theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Label(theme.label, systemImage: theme.systemImage)
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .listRowBackground(Color.appSurface)
                }

                Section {
                    ForEach(BirthdayLeadTime.allCases) { leadTime in
                        Toggle(leadTime.label, isOn: Binding(
                            get: { notificationSettings.isEnabled(leadTime) },
                            set: { isOn in
                                notificationSettings.setEnabled(isOn, for: leadTime)
                                AnalyticsEvents.birthdayReminderChanged(
                                    leadTime: leadTime.rawValue, enabled: isOn
                                )
                            }
                        ))
                        .tint(Color.brandGold)
                        .disabled(notificationsBlocked)
                        .listRowBackground(Color.appSurface)
                    }
                } header: {
                    Text("Birthday Reminders")
                } footer: {
                    if notificationsBlocked {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifications are turned off for Spoiled in iOS Settings.")
                            Button("Open iOS Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.footnote)
                        }
                        .padding(.top, 4)
                    } else {
                        Text("Reminders arrive at 9:17 AM. Your own birthday is never included.")
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
        .task { await notifications.refreshAuthorizationStatus() }
    }

    /// The toggles are inert while iOS is blocking notifications, so say so instead of
    /// letting the user flip switches that do nothing.
    private var notificationsBlocked: Bool {
        notifications.authorizationStatus == .denied
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
