//
//  SpoiledApp.swift
//  Spoiled
//
//  Created by Tommy Ledford on 1/1/25.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn
import UIKit
import Combine

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            assertionFailure("Missing Firebase clientID. Ensure GoogleService-Info.plist is included or set GIDClientID in Info.plist.")
        }
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct SpoiledApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var wishlistViewModel = WishlistViewModel()
    @StateObject private var toastCenter = ToastCenter()
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var themeStore = ThemeStore()
    @StateObject private var notificationSettings = BirthdayNotificationSettings()
    @StateObject private var notifications = BirthdayNotificationCoordinator()
    @State private var cancellables = Set<AnyCancellable>()
    /// An invite link can arrive before sign-in, so it waits here until `ContentView` can show it.
    @AppStorage("pendingInviteCode") private var pendingInviteCode = ""

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            rootView
            .environmentObject(wishlistViewModel)
            .environmentObject(toastCenter)
            .environmentObject(authViewModel)
            .environmentObject(themeStore)
            .environmentObject(notificationSettings)
            .environmentObject(notifications)
            .preferredColorScheme(themeStore.colorScheme)
            .onOpenURL { url in
                if let code = InviteLink.code(from: url) {
                    pendingInviteCode = code
                } else {
                    // Having this modifier can stop URLs reaching the app delegate.
                    _ = GIDSignIn.sharedInstance.handle(url)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .authUnauthorized)) { _ in
                authViewModel.signOut()
                toastCenter.info("Session expired. Please sign in again.")
            }
            .onAppear {
                notifications.attach(viewModel: wishlistViewModel, settings: notificationSettings)
                if case .authenticated = authViewModel.state {
                    wishlistViewModel.configureAuth(using: authViewModel)
                    wishlistViewModel.startAutoRefresh()
                }
            }
            .onChange(of: authViewModel.state) { _, newState in
                if case .authenticated = newState {
                    wishlistViewModel.configureAuth(using: authViewModel)
                    wishlistViewModel.startAutoRefresh()
                } else {
                    wishlistViewModel.stopAutoRefresh()
                    wishlistViewModel.resetForSignOut()
                    ShareSnapshotStore.clear()
                    // The previous user's reminders would keep firing unless we drop them here.
                    Task { await notifications.cancelAll() }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, case .authenticated = authViewModel.state {
                    Task { await wishlistViewModel.load() }
                    wishlistViewModel.startAutoRefresh()
                    // Picks up a permission change made in iOS Settings while we were away.
                    Task { await notifications.refreshAuthorizationStatus() }
                } else if newPhase == .background || newPhase == .inactive {
                    wishlistViewModel.stopAutoRefresh()
                }
            }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch authViewModel.state {
        case .unauthenticated, .authenticating:
            SplashView(auth: authViewModel)
        case .authenticated:
            ContentView()
        }
    }
}
