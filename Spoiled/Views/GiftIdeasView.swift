import SwiftUI

struct GiftIdeasView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.openURL) private var openURL
    @State private var showingAddGiftIdeaSheet = false
    @State private var selectedGiftIdea: GiftIdea?
    @State private var showDeleteAlert = false
    @State private var giftIdeaToDelete: GiftIdea?
    @State private var hidePurchased: Bool

    init(startHidingPurchased: Bool = false) {
        _hidePurchased = State(initialValue: startHidingPurchased)
    }

    var body: some View {
        NavigationStack {
            SwiftUI.Group {
                let items = viewModel.giftIdeas ?? []
                if items.isEmpty {
                    ScrollView {
                        EmptyStateView(
                            systemImage: "lightbulb",
                            title: "No gift ideas yet",
                            subtitle: "Tap + to add an idea. They're grouped automatically by person."
                        )
                    }
                    .background(Color.appBackground.ignoresSafeArea())
                } else {
                    let visible = hidePurchased ? items.filter { !$0.isPurchased } : items
                    let grouped = Dictionary(grouping: visible, by: { $0.personName })
                    let sortedKeys = grouped.keys.sorted()

                    List {
                        ForEach(sortedKeys, id: \.self) { personName in
                            Section {
                                ForEach(grouped[personName] ?? []) { giftIdea in
                                    GiftIdeaRow(
                                        giftIdea: giftIdea,
                                        viewModel: viewModel,
                                        onEdit: { selectedGiftIdea = giftIdea },
                                        onDelete: {
                                            giftIdeaToDelete = giftIdea
                                            showDeleteAlert = true
                                        },
                                        openURL: openURL
                                    )
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button {
                                            giftIdeaToDelete = giftIdea
                                            showDeleteAlert = true
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
                                        .tint(.brandGold)
                                        .disabled(viewModel.isSavingGiftIdea || viewModel.deletingGiftIdeaIds.contains(giftIdea.id))
                                    }
                                }
                            } header: {
                                HStack(spacing: 8) {
                                    PersonAvatar(name: personName, size: 26)
                                    Text(personName)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .textCase(nil)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.appBackground.ignoresSafeArea())
                }
            }
            .navigationTitle("Gift Ideas")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await viewModel.refreshAll() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.spring(response: 0.3)) { hidePurchased.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: hidePurchased ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text(hidePurchased ? "Show all" : "Hide bought")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(hidePurchased ? Color.brandGold.opacity(0.2) : Color.secondary.opacity(0.12))
                        .foregroundStyle(hidePurchased ? Color.brandGold : Color.secondary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(hidePurchased ? "Show purchased" : "Hide purchased")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGiftIdeaSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
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
            .alert("Delete Gift Idea?", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { giftIdeaToDelete = nil }
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

// MARK: - GiftIdeaRow

private struct GiftIdeaRow: View {
    let giftIdea: GiftIdea
    @ObservedObject var viewModel: WishlistViewModel
    let onEdit: () -> Void
    let onDelete: () -> Void
    let openURL: OpenURLAction

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var checkBounce = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(giftIdea.giftName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(giftIdea.isPurchased ? .secondary : .primary)
                    .strikethrough(giftIdea.isPurchased, color: .secondary)

                if !giftIdea.notes.isEmpty {
                    Text(giftIdea.notes)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .italic()
                }
                if let url = giftIdea.url {
                    Button {
                        openURL(url)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "link")
                                .font(.system(size: 11))
                            Text("View Online")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(Color.brandGold)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(.isLink)
                }
            }
            .opacity(giftIdea.isPurchased ? 0.6 : 1.0)

            Spacer()

            HStack(spacing: 8) {
                if viewModel.deletingGiftIdeaIds.contains(giftIdea.id) {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Button {
                        Task { await viewModel.toggleGiftIdeaPurchased(giftIdea) }
                    } label: {
                        Image(systemName: giftIdea.isPurchased ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(giftIdea.isPurchased ? .green : Color.secondary.opacity(0.5))
                            .scaleEffect(checkBounce ? 1.25 : 1.0)
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.5),
                                value: checkBounce
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isSavingGiftIdea || viewModel.deletingGiftIdeaIds.contains(giftIdea.id))
                    .accessibilityLabel(giftIdea.isPurchased ? "Mark as not purchased" : "Mark as purchased")
                    .onChange(of: giftIdea.isPurchased) { _, _ in
                        guard !reduceMotion else { return }
                        checkBounce = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { checkBounce = false }
                    }

                    Menu {
                        Button { onEdit() } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) { onDelete() } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .disabled(viewModel.isSavingGiftIdea || viewModel.deletingGiftIdeaIds.contains(giftIdea.id))
                    .accessibilityLabel("More actions")
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}
