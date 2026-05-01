import SwiftUI

struct ManageKidsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showingAddKidSheet = false
    @State private var showDeleteAlert = false
    @State private var kidToDelete: Kid?

    var body: some View {
        SwiftUI.Group {
            if let kids = viewModel.kids, !kids.isEmpty {
                List {
                    ForEach(Array(kids.enumerated()), id: \.element.id) { index, kid in                        NavigationLink(destination: EditKidView(kidIndex: index)) {
                            HStack(spacing: 12) {
                                PersonAvatar(name: kid.name, size: 36)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(kid.name)
                                        .font(.system(size: 16, weight: .semibold))
                                    let days = daysUntilNextBirthday(from: kid.birthdate)
                                    BirthdayBadge(daysUntil: days)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.appBackground.ignoresSafeArea())
            } else {
                ScrollView {
                    EmptyStateView(
                        systemImage: "figure.and.child.holdinghands",
                        title: "No kids yet",
                        subtitle: "Tap + to add a kid and manage their wishlist"
                    )
                }
                .background(Color.appBackground.ignoresSafeArea())
            }
        }
        .navigationTitle("Manage Kids")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await viewModel.refreshAll() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddKidSheet = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
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
        .trackScreen("manage_kids")
    }
}
