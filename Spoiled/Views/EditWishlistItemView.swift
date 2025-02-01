import SwiftUI

struct EditWishlistItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
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
            Form {
                Section {
                    TextField("Item Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Price", value: $price, format: .currency(code: "USD"), prompt: Text("Price"))
                        .keyboardType(.decimalPad)
                    TextField("Link", text: $linkString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }
                
                Section("Share with Groups") {
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
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        // Update the item in the view model
        viewModel.updateWishlistItem(
            item: item,
            name: name,
            description: description,
            price: price,
            link: URL(string: linkString),
            assignedGroupIds: Array(selectedGroupIds),
            kidId: kidId
        )
        dismiss()
    }
} 
