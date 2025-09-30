//
//  ModernContentView.swift
//  Spoiled
//
//  Created by Assistant on 1/15/25.
//

import SwiftUI

struct ModernContentView: View {
    @EnvironmentObject private var wishlistViewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var selectedTab = 0
    @State private var showEditProfile = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                ModernMyWishlistView()
                    .tag(0)
                
                ModernGroupsView()
                    .tag(1)
                
                ModernGiftIdeasView()
                    .tag(2)
                
                ModernSettingsView()
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Custom Tab Bar
            ModernTabBar(selectedTab: $selectedTab)
        }
        .overlay(alignment: .top) {
            if wishlistViewModel.isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Loading...")
                        .font(.system(.caption, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                )
                .padding(.top, 60)
            }
        }
        .toast(toastCenter)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: wishlistViewModel)
                .environmentObject(toastCenter)
        }
    }
}

struct ModernTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var tabIndicator
    
    private let tabs = [
        (title: "Wishlist", icon: "gift", activeIcon: "gift.fill"),
        (title: "Groups", icon: "person.3", activeIcon: "person.3.fill"),
        (title: "Gift Ideas", icon: "lightbulb", activeIcon: "lightbulb.fill"),
        (title: "Settings", icon: "gear", activeIcon: "gear")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    VStack(spacing: 6) {
                        ZStack {
                            if selectedTab == index {
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: 64, height: 32)
                                    .matchedGeometryEffect(id: "tabIndicator", in: tabIndicator)
                            }
                            
                            Image(systemName: selectedTab == index ? tab.activeIcon : tab.icon)
                                .font(.system(.body, weight: selectedTab == index ? .semibold : .medium))
                                .foregroundColor(selectedTab == index ? .blue : .secondary)
                                .animation(.easeInOut(duration: 0.2), value: selectedTab)
                        }
                        
                        Text(tab.title)
                            .font(.system(.caption2, weight: selectedTab == index ? .semibold : .medium))
                            .foregroundColor(selectedTab == index ? .blue : .secondary)
                            .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: -5)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(.systemGray6), lineWidth: 0.5)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}

#Preview {
    ModernContentView()
        .environmentObject(WishlistViewModel())
        .environmentObject(ToastCenter())
}
