//
//  ContentView.swift
//  Spoiled
//
//  Created by Tommy Ledford on 1/1/25.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @StateObject private var wishlistViewModel = WishlistViewModel()
    
    var body: some View {
        TabView(selection: $selectedTab) {
            MyWishlistView()
                .environmentObject(wishlistViewModel)
                .tabItem {
                    Label("Wishlist", systemImage: "gift")
                }
                .tag(0)
            
            GroupsView()
                .environmentObject(wishlistViewModel)
                .tabItem {
                    Label("Groups", systemImage: "person.3")
                }
                .tag(1)
            
            GiftIdeasView()
                .environmentObject(wishlistViewModel)
                .tabItem {
                    Label("Gift Ideas", systemImage: "lightbulb")
                }
                .tag(2)
            
            SettingsView()
                .environmentObject(wishlistViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
    }
}

#Preview {
    ContentView()
}
