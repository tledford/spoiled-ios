//
//  SpoiledApp.swift
//  Spoiled
//
//  Created by Tommy Ledford on 1/1/25.
//

import SwiftUI

@main
struct SpoiledApp: App {
    @StateObject private var wishlistViewModel = WishlistViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(wishlistViewModel)
        }
    }
}
    