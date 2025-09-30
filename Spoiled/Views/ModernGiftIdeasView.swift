//
//  ModernGiftIdeasView.swift
//  Spoiled
//
//  Created by Assistant on 1/15/25.
//

import SwiftUI

struct ModernGiftIdeasView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var showingAddIdeaSheet = false
    @State private var selectedGiftIdea: GiftIdea?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Modern header with search
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Gift Ideas")
                                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Inspiration for everyone")
                                .font(.system(.subheadline, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Button(action: { showingAddIdeaSheet = true }) {
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
                            Color(.systemOrange),
                            Color(.systemRed),
                            Color(.systemPink)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                
                // Content
                ScrollView {
                    LazyVStack(spacing: 20) {
                        if let giftIdeas = viewModel.giftIdeas, !giftIdeas.isEmpty {
                            let groupedGiftIdeas = Dictionary(grouping: giftIdeas, by: { $0.personName })
                            ForEach(groupedGiftIdeas.keys.sorted(), id: \.self) { personName in
                                VStack(alignment: .leading, spacing: 12) {
                                    // Person section header
                                    HStack {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 40, height: 40)
                                            
                                            Text(String(personName.prefix(1)).uppercased())
                                                .font(.system(.title3, weight: .bold))
                                                .foregroundColor(.primary)
                                        }
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(personName)
                                                .font(.system(.title2, weight: .bold))
                                                .foregroundColor(.primary)
                                            
                                            let ideaCount = groupedGiftIdeas[personName]?.count ?? 0
                                            Text("\(ideaCount) idea\(ideaCount != 1 ? "s" : "")")
                                                .font(.system(.subheadline, weight: .medium))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                    
                                    // Person's gift ideas
                                    LazyVStack(spacing: 12) {
                                        ForEach(groupedGiftIdeas[personName] ?? []) { idea in
                                            ModernGiftIdeaCard(idea: idea, selectedGiftIdea: $selectedGiftIdea)
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        } else {
                            ModernEmptyStateView(
                                icon: "lightbulb",
                                title: "No Gift Ideas Yet",
                                message: "Start building your collection of gift ideas for friends and family",
                                buttonText: "Add Idea",
                                buttonAction: { showingAddIdeaSheet = true }
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
            .sheet(isPresented: $showingAddIdeaSheet) {
                AddGiftIdeaView()
            }
            .sheet(item: $selectedGiftIdea) { giftIdea in
                EditGiftIdeaView(giftIdea: giftIdea)
            }
        }
        .trackScreen("gift_ideas")
    }
}

struct ModernGiftIdeaCard: View {
    let idea: GiftIdea
    @Binding var selectedGiftIdea: GiftIdea?
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var isPressed = false
    @State private var isPurchased = false
    @State private var showDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with purchase status
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(idea.giftName)
                        .font(.system(.title3, design: .default, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if !idea.notes.isEmpty {
                        Text(idea.notes)
                            .font(.system(.subheadline))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                // Purchase status toggle
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isPurchased.toggle()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(isPurchased ? Color.green : Color(.systemGray5))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: isPurchased ? "checkmark" : "cart")
                            .font(.system(.subheadline, weight: .bold))
                            .foregroundColor(isPurchased ? .white : .secondary)
                    }
                }
                .buttonStyle(ScaleButtonStyle())
            }
            
            // Action buttons
            HStack(spacing: 12) {
                if let url = idea.url {
                    Link(destination: url) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.caption)
                            Text("View Online")
                                .font(.system(.subheadline, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                }
                
                Spacer()
                
                Menu {
                    Button {
                        selectedGiftIdea = idea
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Circle().fill(Color(.systemGray6)))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(.systemGray6), lineWidth: 0.5)
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .alert("Delete Gift Idea?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    let ok = await viewModel.deleteGiftIdea(idea)
                    if ok {
                        toastCenter.success("Gift idea deleted")
                    } else {
                        toastCenter.error(viewModel.errorMessage ?? "Failed to delete gift idea")
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this gift idea? This action cannot be undone.")
        }
    }
}
