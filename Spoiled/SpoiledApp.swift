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
    @State private var cancellables = Set<AnyCancellable>()

    var body: some Scene {
        WindowGroup {
            rootView
            .environmentObject(wishlistViewModel)
            .environmentObject(toastCenter)
            .environmentObject(authViewModel)
            .onReceive(NotificationCenter.default.publisher(for: .authUnauthorized)) { _ in
                authViewModel.signOut()
                toastCenter.info("Session expired. Please sign in again.")
            }
            .onAppear {
                if case .authenticated = authViewModel.state {
                    wishlistViewModel.configureAuth(using: authViewModel)
                }
            }
            .onChange(of: authViewModel.state) { _, newState in
                if case .authenticated = newState {
                    wishlistViewModel.configureAuth(using: authViewModel)
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
