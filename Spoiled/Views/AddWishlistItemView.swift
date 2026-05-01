import SwiftUI

struct AddWishlistItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var name = ""
    @State private var description = ""
    @State private var price: Double?
    @State private var linkString = ""
    @State private var selectedGroupIds: Set<UUID> = []
    @State private var selectedKid: Kid?

    var isForKid: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Item Name")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("What do you want?", text: $name)
                    }
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Optional notes…", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                    }
                }

                if isForKid, let kids = viewModel.kids {
                    if kids.count == 1 {
                        let kid = kids[0]
                        Section {
                            HStack(spacing: 10) {
                                PersonAvatar(name: kid.name, size: 28)
                                Text("For: \(kid.name)")
                                    .font(.system(size: 15, weight: .medium))
                            }
                        }
                        .onAppear { selectedKid = kid }
                    } else {
                        Section("Select Kid") {
                            Picker("For:", selection: $selectedKid) {
                                ForEach(kids) { kid in
                                    Text(kid.name).tag(kid as Kid?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }

                Section {
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

                    ForEach(viewModel.groups ?? []) { group in
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
                    }
                } header: {
                    Text("Share with Groups")
                } footer: {
                    if selectedGroupIds.isEmpty {
                        Label("Not shared — only visible to you", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(Color.brandGold.opacity(0.8))
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await addItem() } }
                        .fontWeight(.semibold)
                        .disabled(name.isEmpty || (isForKid && selectedKid == nil) || viewModel.isSavingWishlistItem)
                }
            }
        }
        .trackScreen(isForKid ? "add_kid_wishlist_item" : "add_wishlist_item")
    }

    private func addItem() async {
        let item = WishlistItem(
            name: name,
            description: description,
            price: price,
            link: URL(string: linkString),
            assignedGroupIds: Array(selectedGroupIds)
        )
        let ok = await viewModel.addWishlistItem(item, kidId: selectedKid?.id)
        if ok { toastCenter.success("Item added"); dismiss() }
        else { toastCenter.error(viewModel.errorMessage ?? "Failed to add item") }
    }
}
