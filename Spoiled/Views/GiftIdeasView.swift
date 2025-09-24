import SwiftUI

struct GiftIdeasView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.openURL) private var openURL
    @State private var showingAddGiftIdeaSheet = false
    @State private var selectedGiftIdea: GiftIdea?
    @State private var showDeleteAlert = false
    @State private var giftIdeaToDelete: GiftIdea?
    @State private var hidePurchased = false
    
    var body: some View {
    NavigationStack {
            List {
                let items = viewModel.giftIdeas ?? []
                if items.isEmpty {
                    Text("You don't have any gift ideas yet. Tap the + button to add one. They’ll automatically be grouped by person name.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    let visible = hidePurchased ? items.filter { !$0.isPurchased } : items
                    let groupedGiftIdeas = Dictionary(grouping: visible, by: { $0.personName })
                    ForEach(groupedGiftIdeas.keys.sorted(), id: \.self) { personName in
                        Section(header: Text(personName)) {
                            ForEach(groupedGiftIdeas[personName] ?? []) { giftIdea in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(giftIdea.giftName)
                                            .font(.headline)
                                        if !giftIdea.notes.isEmpty {
                                            Text(giftIdea.notes)
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        if let url = giftIdea.url {
                                            Text("View Online")
                                                .font(.subheadline)
                                                .foregroundColor(.blue)
                                                .underline()
                                                .onTapGesture { openURL(url) }
                                                .accessibilityAddTraits(.isLink)
                                        }
                                    }
                                    Spacer()
                                    if viewModel.deletingGiftIdeaIds.contains(giftIdea.id) {
                                        ProgressView()
                                    }
                                    Button(action: {
                                        Task { await viewModel.toggleGiftIdeaPurchased(giftIdea) }
                                    }) {
                                        Image(systemName: giftIdea.isPurchased ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(giftIdea.isPurchased ? .green : .secondary)
                                            .imageScale(.large)
                                            .accessibilityLabel(giftIdea.isPurchased ? "Mark as not purchased" : "Mark as purchased")
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.isSavingGiftIdea || viewModel.deletingGiftIdeaIds.contains(giftIdea.id))
                                    // Visible affordance for available actions (alternative to swipe)
                                    Menu {
                                        Button {
                                            selectedGiftIdea = giftIdea
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        Button(role: .destructive) {
                                            showDeleteAlert = true
                                            giftIdeaToDelete = giftIdea
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .imageScale(.large)
                                            .foregroundColor(.secondary)
                                    }
                                    .accessibilityLabel("More actions")
                                    .disabled(viewModel.isSavingGiftIdea || viewModel.deletingGiftIdeaIds.contains(giftIdea.id))
                                }
                                .contentShape(Rectangle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button {
                                        showDeleteAlert = true
                                        giftIdeaToDelete = giftIdea
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    .disabled(viewModel.deletingGiftIdeaIds.contains(giftIdea.id))
                                    
                                    Button {
                                        selectedGiftIdea = giftIdea
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                    .disabled(viewModel.isSavingGiftIdea || viewModel.deletingGiftIdeaIds.contains(giftIdea.id))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gift Ideas")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await viewModel.refreshAll() }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { hidePurchased.toggle() }) {
                        Text(hidePurchased ? "Show purchased" : "Hide purchased")
                    }
                    .accessibilityLabel(hidePurchased ? "Show purchased" : "Hide purchased")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddGiftIdeaSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddGiftIdeaSheet) {
                AddGiftIdeaView()
                    .environmentObject(viewModel)
            }
            .sheet(item: $selectedGiftIdea) { giftIdea in
                EditGiftIdeaView(giftIdea: giftIdea)
                    .environmentObject(viewModel)
            }
            // Centralized alert prevents row-level layout changes when presenting
            .alert("Delete Gift Idea?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    giftIdeaToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let giftIdea = giftIdeaToDelete {
                        Task {
                            let ok = await viewModel.deleteGiftIdea(giftIdea)
                            if ok { toastCenter.success("Gift idea deleted") }
                            else { toastCenter.error(viewModel.errorMessage ?? "Failed to delete gift idea") }
                        }
                        giftIdeaToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this gift idea? This action cannot be undone.")
            }
    }
    .trackScreen("gift_ideas")
    }
}
