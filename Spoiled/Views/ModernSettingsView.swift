//
//  ModernSettingsView.swift
//  Spoiled
//
//  Created by Assistant on 1/15/25.
//

import SwiftUI

struct ModernSettingsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var showEditProfile = false
    @State private var showManageKids = false
    @State private var showDeleteAccountAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    ModernProfileHeader(
                        user: viewModel.currentUser,
                        onEditTapped: { showEditProfile = true }
                    )
                    
                    // Settings Sections
                    VStack(spacing: 20) {
                        ModernSettingsSection(title: "Family") {
                            ModernSettingsRow(
                                icon: "person.2.fill",
                                iconColor: .orange,
                                title: "Manage Kids",
                                subtitle: "Add and manage children's wishlists",
                                action: { showManageKids = true }
                            )
                        }
                        
                        ModernSettingsSection(title: "Account") {
                            ModernSettingsRow(
                                icon: "bell.fill",
                                iconColor: .blue,
                                title: "Notifications",
                                subtitle: "Manage notification preferences"
                            ) {
                                // Notification settings
                            }
                            
                            ModernSettingsRow(
                                icon: "lock.fill",
                                iconColor: .green,
                                title: "Privacy",
                                subtitle: "Control your data and privacy settings"
                            ) {
                                // Privacy settings
                            }
                            
                            ModernSettingsRow(
                                icon: "icloud.fill",
                                iconColor: .cyan,
                                title: "Data & Sync",
                                subtitle: "Manage your data synchronization"
                            ) {
                                // Data sync settings
                            }
                        }
                        
                        ModernSettingsSection(title: "Support") {
                            ModernSettingsRow(
                                icon: "questionmark.circle.fill",
                                iconColor: .purple,
                                title: "Help & Support",
                                subtitle: "Get help and contact support"
                            ) {
                                // Help action
                            }
                            
                            ModernSettingsRow(
                                icon: "star.fill",
                                iconColor: .yellow,
                                title: "Rate Spoiled",
                                subtitle: "Leave a review on the App Store"
                            ) {
                                // App Store rating
                            }
                            
                            ModernSettingsRow(
                                icon: "doc.text.fill",
                                iconColor: .gray,
                                title: "Privacy Policy",
                                subtitle: "Read our privacy policy"
                            ) {
                                // Privacy policy action
                            }
                        }
                        
                        ModernSettingsSection(title: "Account Actions") {
                            ModernSettingsRow(
                                icon: "rectangle.portrait.and.arrow.right.fill",
                                iconColor: .orange,
                                title: "Sign Out",
                                subtitle: "Sign out of your account",
                                isDestructive: false
                            ) {
                                // Sign out action
                            }
                            
                            ModernSettingsRow(
                                icon: "trash.fill",
                                iconColor: .red,
                                title: "Delete Account",
                                subtitle: "Permanently delete your account",
                                isDestructive: true
                            ) {
                                showDeleteAccountAlert = true
                            }
                        }
                    }
                    
                    // App Version Footer
                    VStack(spacing: 8) {
                        Text("Spoiled")
                            .font(.system(.headline, design: .rounded, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("Version 1.0.0")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: viewModel)
        }
        .sheet(isPresented: $showManageKids) {
            ManageKidsView()
        }
        .alert("Delete Account?", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                // Delete account action
            }
        } message: {
            Text("This will permanently delete your account and all associated data. This action cannot be undone.")
        }
        .trackScreen("settings")
    }
}

struct ModernProfileHeader: View {
    let user: User?
    let onEditTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(.systemPurple),
                                Color(.systemBlue),
                                Color(.systemTeal)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                
                if let user = user {
                    Text(String(user.name.prefix(2)).uppercased())
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(.title, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 8) {
                if let user = user {
                    Text(user.name)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(user.email)
                        .font(.system(.subheadline))
                        .foregroundColor(.secondary)
                } else {
                    Text("Loading...")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: onEditTapped) {
                HStack(spacing: 8) {
                    Image(systemName: "pencil")
                        .font(.system(.subheadline, weight: .medium))
                    
                    Text("Edit Profile")
                        .font(.system(.subheadline, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
        )
    }
}

struct ModernSettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .foregroundColor(.primary)
                .padding(.horizontal, 20)
            
            VStack(spacing: 1) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            )
        }
    }
}

struct ModernSettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?
    let isDestructive: Bool
    let action: () -> Void
    @State private var isPressed = false
    
    init(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isDestructive ? Color.red.opacity(0.2) : iconColor.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundColor(isDestructive ? .red : iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.body, weight: .medium))
                        .foregroundColor(isDestructive ? .red : .primary)
                        .multilineTextAlignment(.leading)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(.caption))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

#Preview {
    ModernSettingsView()
        .environmentObject(WishlistViewModel())
}
