import SwiftUI

struct AddWishlistItemView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    
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
                    TextField("Item Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Price", value: $price, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    TextField("Link", text: $linkString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
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
                    Button("Add") {
                        addItem()
                    }
                    .disabled(name.isEmpty || (isForKid && selectedKid == nil))
                }
            }
        }
    }
    
    private func addItem() {
        let item = WishlistItem(
            name: name,
            description: description,
            price: price,
            link: URL(string: linkString),
            assignedGroupIds: Array(selectedGroupIds)
        )
        
        viewModel.addWishlistItem(item, kidId: selectedKid?.id)
        
        dismiss()
    }
} 
