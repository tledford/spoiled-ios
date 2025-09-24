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
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Item Name").font(.caption).foregroundStyle(.secondary)
                        TextField("", text: $name)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Link").font(.caption).foregroundStyle(.secondary)
                        TextField("", text: $linkString)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .textContentType(.URL)
                            .autocorrectionDisabled(true)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description").font(.caption).foregroundStyle(.secondary)
                        TextField("", text: $description, axis: .vertical)
                            .lineLimit(3...6)
                    }
//                    VStack(alignment: .leading, spacing: 6) {
//                        Text("Price").font(.caption).foregroundStyle(.secondary)
//                        TextField("", value: $price, format: .currency(code: "USD"))
//                            .keyboardType(.decimalPad)
//                    }
                }
                
                if isForKid, let currentUserKids = viewModel.kids {
                    if currentUserKids.count == 1 {
                        let kid = currentUserKids[0]
                        Text("For: \(kid.name)")
                            .onAppear { selectedKid = kid }
                    } else {
                        Section(header: Text("Select Kid")) {
                            Picker("For:", selection: $selectedKid) {
                                ForEach(currentUserKids) { kid in
                                    Text(kid.name).tag(kid as Kid?)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }
                }
                
                Section("Share with Groups") {
                    HStack {
                        Toggle("All Groups", isOn: Binding(
                            get: { selectedGroupIds.count == (viewModel.groups ?? []).count },
                            set: { isSelected in
                                if isSelected {
                                    selectedGroupIds = Set((viewModel.groups ?? []).map { $0.id })
                                } else {
                                    selectedGroupIds.removeAll()
                                }
                            }
                        ))
                    }
                    .listRowBackground(Color.secondary.opacity(0.2))
                    .font(.headline)
                    
                    ForEach(viewModel.groups ?? []) { group in
                        Toggle(group.name, isOn: Binding(
                            get: { selectedGroupIds.contains(group.id) },
                            set: { isSelected in
                                if isSelected {
                                    selectedGroupIds.insert(group.id)
                                } else {
                                    selectedGroupIds.remove(group.id)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await addItem() } }
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
        if ok {
            toastCenter.success("Item added")
            dismiss()
        } else {
            toastCenter.error(viewModel.errorMessage ?? "Failed to add item")
        }
    }
} 
