import SwiftUI

struct ManageKidsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showingAddKidSheet = false
    @State private var showDeleteAlert = false
    @State private var kidToDelete: Kid?
    
    var body: some View {
    List {
            if let currentUserKids = viewModel.kids, !currentUserKids.isEmpty {
                ForEach(Array(currentUserKids.enumerated()), id: \.element.id) { index, kid in
                    NavigationLink(destination: EditKidView(kidIndex: index)) {
                        Text(kid.name)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            kidToDelete = kid
                            showDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(viewModel.deletingKidIds.contains(kid.id))
                    }
                }
            }
            else {
                Text("Click the plus (+) button to add a kid, then you can add items to their wishlist.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
        }
    .navigationTitle("Manage Kids")
    .navigationBarTitleDisplayMode(.inline)
    .refreshable { await viewModel.refreshAll() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddKidSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddKidSheet) {
            AddKidView()
                .environmentObject(viewModel)
        }
        .alert("Delete Kid?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { kidToDelete = nil }
            Button("Delete", role: .destructive) {
                if let k = kidToDelete {
                    Task {
                        let ok = await viewModel.deleteKid(k)
                        if ok { toastCenter.success("Kid deleted") }
                        else { toastCenter.error(viewModel.errorMessage ?? "Failed to delete kid") }
                    }
                    kidToDelete = nil
                }
            }
        } message: {
            Text("This will permanently delete the kid and their wishlist items (unless shared). This action cannot be undone.")
        }
    }
} 
