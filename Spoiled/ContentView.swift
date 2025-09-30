//
//  ContentView.swift
//  Spoiled
//
//  Created by Tommy Ledford on 1/1/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var wishlistViewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var selectedTab = 0
    @State private var showEditProfile = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ModernMyWishlistView()
                // .environmentObject(wishlistViewModel)
                .tabItem { Label("Wishlist", systemImage: "gift") }
                .tag(0)
            
            ModernGroupsView()
                // .environmentObject(wishlistViewModel)
                .tabItem { Label("Groups", systemImage: "person.3") }
                .tag(1)
            
            ModernGiftIdeasView()
                // .environmentObject(wishlistViewModel)
                .tabItem { Label("Gift Ideas", systemImage: "lightbulb") }
                .tag(2)
            
            ModernSettingsView()
                // .environmentObject(wishlistViewModel)
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(3)
        }
        .overlay(alignment: .top) {
            if wishlistViewModel.isLoading {
                ProgressView().padding(.top, 8)
            }
            // } else if let error = wishlistViewModel.errorMessage {
            //     Text(error).foregroundStyle(.red).padding(.top, 8)
            // }
        }
        .toast(toastCenter)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: wishlistViewModel)
                .environmentObject(toastCenter)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NewUserCreated"))) { _ in
            toastCenter.info("Welcome! Let’s finish setting up your profile.")
            showEditProfile = true
        }
    }
}
