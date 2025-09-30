//
//  ModernGroupsView.swift
//  Spoiled
//
//  Created by Assistant on 1/15/25.
//

import SwiftUI

struct ModernGroupsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showingAddGroupSheet = false
    @State private var showDeleteAlert = false
    @State private var groupToDelete: Group?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Modern header
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("My Groups")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                            
                            if let groupCount = viewModel.groups?.count {
                                Text("\(groupCount) group\(groupCount != 1 ? "s" : "")")
                                    .font(.system(.subheadline, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { showingAddGroupSheet = true }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                
                                Image(systemName: "plus")
                                    .font(.system(.title3, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        colors: [
                            Color(.systemIndigo),
                            Color(.systemBlue),
                            Color(.systemCyan)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if let currentUserGroups = viewModel.groups, !currentUserGroups.isEmpty {
                            ForEach(viewModel.groups ?? []) { group in
                                ModernGroupRow(group: group)
                                    .contextMenu {
                                        Button(action: {
                                            // Edit group action
                                        }) {
                                            Label("Edit Group", systemImage: "pencil")
                                        }
                                        
                                        if group.isAdmin {
                                            Divider()
                                            
                                            Button(role: .destructive, action: {
                                                groupToDelete = group
                                                showDeleteAlert = true
                                            }) {
                                                Label("Delete Group", systemImage: "trash")
                                            }
                                        }
                                    }
                            }
                        } else {
                            ModernEmptyStateView(
                                icon: "person.3",
                                title: "No Groups Yet",
                                message: "Create a group to share wishlists with family and friends",
                                buttonText: "Create Group",
                                buttonAction: { showingAddGroupSheet = true }
                            )
                            .padding(.top, 60)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .background(Color(.systemGroupedBackground))
            }
            .navigationBarHidden(true)
            .refreshable { await viewModel.refreshAll() }
            .sheet(isPresented: $showingAddGroupSheet) {
                AddGroupView()
            }
            .alert("Delete Group?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { groupToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let g = groupToDelete {
                        Task {
                            let ok = await viewModel.deleteGroup(g)
                            if ok { toastCenter.success("Group deleted") }
                            else { toastCenter.error(viewModel.errorMessage ?? "Failed to delete group") }
                        }
                        groupToDelete = nil
                    }
                }
            } message: {
                Text("This will permanently delete the group and remove memberships. This action cannot be undone.")
            }
        }
        .trackScreen("groups")
    }
}

struct ModernGroupRow: View {
    let group: Group
    @State private var isPressed = false
    
    var body: some View {
        NavigationLink(destination: GroupDetailView(group: group)) {
            groupRowContent
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private var groupRowContent: some View {
        HStack(spacing: 16) {
            groupAvatar
            groupInfo
            Spacer()
            chevronIcon
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(groupCardBackground)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
    }
    
    private var groupAvatar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.3),
                            Color.pink.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
            
            VStack(spacing: 2) {
                Image(systemName: "person.3.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                
                if group.members.count > 0 {
                    Text("\(group.members.count)")
                        .font(.system(.caption2, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var groupInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeaderRow
            memberCountRow
            memberAvatars
        }
    }
    
    private var groupHeaderRow: some View {
        HStack {
            Text(group.name)
                .font(.system(.headline, design: .default, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
            
            if group.isAdmin {
                adminBadge
            }
        }
    }
    
    private var adminBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "crown.fill")
                .font(.caption)
            Text("Admin")
                .font(.system(.caption, weight: .medium))
        }
        .foregroundColor(.yellow)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.yellow.opacity(0.1))
        )
    }
    
    @ViewBuilder
    private var memberCountRow: some View {
        if !group.members.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(group.members.count) member\(group.members.count != 1 ? "s" : "")")
                    .font(.system(.subheadline, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var memberAvatars: some View {
        if !group.members.isEmpty {
            let membersToShow = Array(group.members.prefix(4))
            
            HStack(spacing: -8) {
                ForEach(Array(membersToShow.enumerated()), id: \.offset) { index, member in
                    memberAvatar(member: member, index: index)
                }
                
                if group.members.count > 4 {
                    overflowAvatar(count: group.members.count - 4)
                }
            }
        }
    }
    
    private func memberAvatar(member: GroupMember, index: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 28, height: 28)
            
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 24, height: 24)
            
            Text(String(member.name.prefix(1)).uppercased())
                .font(.system(.caption2, weight: .bold))
                .foregroundColor(.white)
        }
        .overlay(
            Circle()
                .stroke(Color(.systemBackground), lineWidth: 2)
        )
        .zIndex(Double(4 - index))
    }
    
    private func overflowAvatar(count: Int) -> some View {
        ZStack {
            Circle()
                .fill(Color(.systemBackground))
                .frame(width: 28, height: 28)
            
            Circle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 24, height: 24)
            
            Text("+\(count)")
                .font(.system(.caption2, weight: .bold))
                .foregroundColor(.secondary)
        }
        .overlay(
            Circle()
                .stroke(Color(.systemBackground), lineWidth: 2)
        )
    }
    
    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var groupCardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(.systemBackground))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color(.systemGray6), lineWidth: 0.5)
            )
    }
}
