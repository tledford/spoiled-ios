import SwiftUI

struct GiftIdeasView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var showingAddGiftIdeaSheet = false
    @State private var selectedGiftIdea: GiftIdea?
    @State private var showDeleteAlert = false
    @State private var giftIdeaToDelete: GiftIdea?
    
    var body: some View {
        NavigationStack {
            List {
                let groupedGiftIdeas = Dictionary(grouping: viewModel.giftIdeas ?? [], by: { $0.personName })
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
                                        Link("View Online", destination: url)
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                    }
                                }
                                Spacer()
                                if giftIdea.isPurchased {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .contentShape(Rectangle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    // Show confirmation alert instead of deleting immediately
                                    showDeleteAlert = true
                                    giftIdeaToDelete = giftIdea
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                                
                                Button {
                                    selectedGiftIdea = giftIdea
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .alert("Delete Gift Idea?", isPresented: $showDeleteAlert) {
                                Button("Cancel", role: .cancel) {
                                    giftIdeaToDelete = nil
                                }
                                Button("Delete", role: .destructive) {
                                    if let giftIdea = giftIdeaToDelete,
                                       let index = viewModel.giftIdeas?.firstIndex(where: { $0.id == giftIdea.id }) {
                                        viewModel.giftIdeas?.remove(at: index)
                                    }
                                    giftIdeaToDelete = nil
                                }
                            } message: {
                                Text("Are you sure you want to delete this gift idea? This action cannot be undone.")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gift Ideas")
            .toolbar {
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
        }
    }
}
