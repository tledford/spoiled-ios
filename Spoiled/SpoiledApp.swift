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
    @StateObject private var toastCenter = ToastCenter()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(wishlistViewModel)
                .environmentObject(toastCenter)
        }
    }
}
