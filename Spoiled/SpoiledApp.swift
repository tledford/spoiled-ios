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

@main
struct SpoiledApp: App {
    @StateObject private var wishlistViewModel = WishlistViewModel()
    @StateObject private var toastCenter = ToastCenter()
    @StateObject private var authViewModel = AuthViewModel()
    @State private var cancellables = Set<AnyCancellable>()

    init() {
        FirebaseApp.configure()
        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        } else {
            // Fallback: ensure GIDClientID is set in Info.plist if Firebase options are unavailable
            assertionFailure("Missing Firebase clientID. Ensure GoogleService-Info.plist is included or set GIDClientID in Info.plist.")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            rootView
            .environmentObject(wishlistViewModel)
            .environmentObject(toastCenter)
            .environmentObject(authViewModel)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
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
