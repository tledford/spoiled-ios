import SwiftUI

struct EditWishlistItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var name: String
    @State private var description: String
    @State private var price: Double?
    @State private var linkString: String
    @State private var selectedGroupIds: Set<UUID>

    let item: WishlistItem
    let kidId: UUID?

    init(item: WishlistItem, kidId: UUID? = nil) {
        self.kidId = kidId
        self.item = item
        _name = State(initialValue: item.name)
        _description = State(initialValue: item.description)
        _price = State(initialValue: item.price)
        _linkString = State(initialValue: item.link?.absoluteString ?? "")
        _selectedGroupIds = State(initialValue: Set(item.assignedGroupIds))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Item Details
                    VStack(alignment: .leading, spacing: 8) {
                        AppSectionHeader(icon: "info.circle.fill", title: "Item Details")
                        VStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Item Name")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("", text: $name)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            Divider().padding(.leading, 16)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Link")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("https://", text: $linkString)
                                    .keyboardType(.URL)
                                    .textInputAutocapitalization(.never)
                                    .textContentType(.URL)
                                    .autocorrectionDisabled(true)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            Divider().padding(.leading, 16)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Description")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                TextField("Optional notes…", text: $description, axis: .vertical)
                                    .lineLimit(3...6)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .spoiledCard()
                    }

                    // Share with Groups
                    VStack(alignment: .leading, spacing: 8) {
                        AppSectionHeader(icon: "person.3.fill", title: "Share with Groups")
                        VStack(spacing: 0) {
                            Toggle(isOn: Binding(
                                get: { selectedGroupIds.count == (viewModel.groups ?? []).count && !(viewModel.groups ?? []).isEmpty },
                                set: { isSelected in
                                    if isSelected { selectedGroupIds = Set((viewModel.groups ?? []).map { $0.id }) }
                                    else { selectedGroupIds.removeAll() }
                                }
                            )) {
                                Label("All Groups", systemImage: "person.3.fill")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .tint(.brandGold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)

                            ForEach(viewModel.groups ?? []) { group in
                                Divider().padding(.leading, 16)
                                Toggle(isOn: Binding(
                                    get: { selectedGroupIds.contains(group.id) },
                                    set: { isSelected in
                                        if isSelected { selectedGroupIds.insert(group.id) }
                                        else { selectedGroupIds.remove(group.id) }
                                    }
                                )) {
                                    Text(group.name)
                                }
                                .tint(.brandGold)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                        }
                        .spoiledCard()

                        if selectedGroupIds.isEmpty {
                            Label("Not shared — only visible to you", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundStyle(Color.brandGold.opacity(0.8))
                                .padding(.horizontal, 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .navButton(color: .brandBlue, isIcon: false)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveChanges() }
                    } label: {
                        Text("Save")
                            .navButton(color: .brandGold, isIcon: false)
                    }
                    .disabled(name.isEmpty || viewModel.isSavingWishlistItem)
                }
            }
        }
        .trackScreen(kidId == nil ? "edit_wishlist_item" : "edit_kid_wishlist_item")
    }

    private func saveChanges() async {
        let ok = await viewModel.updateWishlistItem(
            item: item,
            name: name,
            description: description,
            price: price,
            link: URL(string: linkString),
            assignedGroupIds: Array(selectedGroupIds),
            kidId: kidId
        )
        if ok { toastCenter.success("Item updated"); dismiss() }
        else { toastCenter.error(viewModel.errorMessage ?? "Failed to update item") }
    }
}
