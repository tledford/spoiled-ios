import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var wishlistViewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @EnvironmentObject private var notificationSettings: BirthdayNotificationSettings
    @EnvironmentObject private var notifications: BirthdayNotificationCoordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showEditProfile = false
    @State private var showNotificationPrimer = false
    @Namespace private var giftNamespace

    /// Held for a beat so the cover cannot flash by on a fast connection.
    @State private var minimumCoverElapsed = false
    /// Backstop so a stalled request can never pin the cover open.
    @State private var coverTimedOut = false

    private static let minimumCoverSeconds: UInt64 = 2
    private static let coverTimeoutSeconds: UInt64 = 15

    /// The cover stays up until the first bootstrap lands, and never for less than
    /// `minimumCoverSeconds`. An error or the timeout releases it too, so a failed load
    /// shows the real (empty) app and its toast rather than an endless gift.
    private var isInitialLoading: Bool {
        if coverTimedOut { return false }
        let dataSettled = wishlistViewModel.currentUser != nil || wishlistViewModel.errorMessage != nil
        return !(minimumCoverElapsed && dataSettled)
    }

    var body: some View {
        ZStack {
            tabs
            if isInitialLoading {
                AppLoadingView(namespace: giftNamespace)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.72),
            value: isInitialLoading
        )
        .task {
            try? await Task.sleep(for: .seconds(Self.minimumCoverSeconds))
            minimumCoverElapsed = true
        }
        .task {
            try? await Task.sleep(for: .seconds(Self.coverTimeoutSeconds))
            coverTimedOut = true
        }
    }

    private var tabs: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView(giftNamespace: giftNamespace, showsGift: !isInitialLoading)
            }
            Tab("Wishlist", systemImage: "gift.fill") {
                MyWishlistView()
            }
            Tab("Groups", systemImage: "person.3.fill") {
                GroupsView()
            }
            Tab("Gift Ideas", systemImage: "lightbulb.fill") {
                GiftIdeasView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .overlay(alignment: .top) {
            if wishlistViewModel.isLoading {
                ProgressView().padding(.top, 8)
            }
        }
        .toast(toastCenter)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: wishlistViewModel)
                .environmentObject(toastCenter)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NewUserCreated"))) { _ in
            toastCenter.info("Welcome! Let's finish setting up your profile.")
            showEditProfile = true
        }
        .sheet(isPresented: $showNotificationPrimer) {
            BirthdayNotificationPrimerSheet()
                .environmentObject(notificationSettings)
                .environmentObject(notifications)
        }
        // Wait for the first bootstrap to land before asking — there is nothing to remind
        // anyone about until the roster exists, and the ask reads better with the app filled in.
        .onChange(of: wishlistViewModel.currentUser?.id) { _, _ in
            Task { await maybePrimeNotifications() }
        }
        .task { await maybePrimeNotifications() }
    }

    private func maybePrimeNotifications() async {
        guard wishlistViewModel.currentUser != nil, !notificationSettings.hasPrimed else { return }
        await notifications.refreshAuthorizationStatus()
        if notifications.shouldPrime(hasLoadedUser: true, hasPrimed: notificationSettings.hasPrimed) {
            showNotificationPrimer = true
        }
    }
}

// MARK: - BirthdayNotificationPrimerSheet
/// Explains why the app wants to send notifications before the system prompt appears.
/// Shown once; either button marks it done.
private struct BirthdayNotificationPrimerSheet: View {
    @EnvironmentObject private var notificationSettings: BirthdayNotificationSettings
    @EnvironmentObject private var notifications: BirthdayNotificationCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            content
        }
        .background(Color.appBackground.ignoresSafeArea())
        .presentationDetents([.medium, .large])
    }

    // Scrolls so the copy is never clipped at the medium detent or at large text sizes.
    private var content: some View {
        VStack(spacing: 20) {
            Image(systemName: "birthday.cake.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.brandGold)

            Text("Never Miss a Birthday")
                .font(.title2).bold()
                .multilineTextAlignment(.center)

            Text("We'll nudge you before every birthday in your groups: 30 days out, a week before, the day before, and that morning. Enough warning to pick a gift and get it shipped.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                notificationSettings.hasPrimed = true
                Task {
                    _ = await notifications.requestAuthorizationAndSchedule()
                    dismiss()
                }
            } label: {
                Text("Turn On Reminders")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandGold)
            .padding(.horizontal)

            Button("Not Now") {
                notificationSettings.hasPrimed = true
                dismiss()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ContentView()
        .environmentObject(WishlistViewModel())
        .environmentObject(ToastCenter())
        .environmentObject(BirthdayNotificationSettings())
        .environmentObject(BirthdayNotificationCoordinator())
}
