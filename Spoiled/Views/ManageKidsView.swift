import SwiftUI

struct ManageKidsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showingAddKidSheet = false
    @State private var showDeleteAlert = false
    @State private var kidToBeDeleted: Kid?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Manage Kids")
                .navigationBarTitleDisplayMode(.large)
                .refreshable { await viewModel.refreshAll() }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingAddKidSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .navButton()
                        }
                    }
                }
                .sheet(isPresented: $showingAddKidSheet) {
                    AddKidView()
                        .environmentObject(viewModel)
                }
                .alert("Delete Kid?", isPresented: $showDeleteAlert) {
                    Button("Cancel", role: .cancel) { kidToBeDeleted = nil }
                    Button("Delete", role: .destructive) {
                        if let kid = kidToBeDeleted {
                            Task {
                                let ok = await viewModel.deleteKid(kid)
                                if ok { toastCenter.success("Kid deleted") }
                                else { toastCenter.error(viewModel.errorMessage ?? "Failed to delete kid") }
                            }
                            kidToBeDeleted = nil
                        }
                    }
                } message: {
                    Text("This will permanently delete the kid and their wishlist items (unless shared). This action cannot be undone.")
                }
                .trackScreen("manage_kids")
        }
    }

    @ViewBuilder
    private var content: some View {
        if let kids = viewModel.kids, !kids.isEmpty {
            List {
                Section {
                    ForEach(Array(kids.enumerated()), id: \.element.id) { index, kid in
                        KidRow(kid: kid, index: index, kidToBeDeleted: $kidToBeDeleted, showDeleteAlert: $showDeleteAlert)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
        } else {
            ScrollView {
                EmptyStateView(
                    systemImage: "figure.and.child.holdinghands",
                    title: "No kids yet",
                    subtitle: "Tap + to add a kid and manage their wishlist"
                )
                .padding(.top, 40)
            }
            .background(Color.appBackground.ignoresSafeArea())
        }
    }
}

private struct KidRow: View {
    let kid: Kid
    let index: Int
    @Binding var kidToBeDeleted: Kid?
    @Binding var showDeleteAlert: Bool
    @EnvironmentObject var viewModel: WishlistViewModel

    var body: some View {
        NavigationLink(destination: EditKidView(kidIndex: index)) {
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
        .listRowBackground(Color.appSurface)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                kidToBeDeleted = kid
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .disabled(viewModel.deletingKidIds.contains(kid.id))
        }
    }
}
