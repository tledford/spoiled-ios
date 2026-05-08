import SwiftUI

struct AddWishlistItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter

    @State private var name = ""
    @State private var description = ""
    @State private var linkString = ""
    @State private var selectedGroupIds: Set<UUID> = []
    @State private var selectedKid: Kid?

    var isForKid: Bool

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
                                TextField("What do you want?", text: $name)
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

                    if isForKid, let kids = viewModel.kids {
                        if kids.count == 1 {
                            let kid = kids[0]
                            VStack(spacing: 0) {
                                HStack(spacing: 10) {
                                    PersonAvatar(name: kid.name, size: 28)
                                    Text("For: \(kid.name)")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .spoiledCard()
                            .onAppear { selectedKid = kid }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                AppSectionHeader(icon: "person.fill", title: "Select Kid")
                                VStack(spacing: 0) {
                                    HStack {
                                        Text("For:")
                                            .font(.system(size: 15, weight: .medium))
                                        Spacer()
                                        Picker("", selection: $selectedKid) {
                                            Text("Select...").tag(nil as Kid?)
                                            ForEach(kids) { kid in
                                                Text(kid.name).tag(kid as Kid?)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                }
                                .spoiledCard()
                            }
                        }
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
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .navButton(isIcon: false)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await addItem() }
                    } label: {
                        Text("Add")
                            .navButton(isIcon: false)
                    }
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
            link: URL(string: linkString),
            assignedGroupIds: Array(selectedGroupIds)
        )
        let ok = await viewModel.addWishlistItem(item, kidId: selectedKid?.id)
        if ok { toastCenter.success("Item added"); dismiss() }
        else { toastCenter.error(viewModel.errorMessage ?? "Failed to add item") }
    }
}
