import SwiftUI

struct AddGiftIdeaView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var personName = ""
    @State private var giftName = ""
    @State private var urlString = ""
    @State private var notes = ""
    @State private var isPurchased = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Person's Name", text: $personName)
                    TextField("Gift Name", text: $giftName)
                    TextField("URL", text: $urlString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Purchased", isOn: $isPurchased)
                }
            }
            .navigationTitle("Add Gift Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addGiftIdea()
                    }
                    .disabled(personName.isEmpty || giftName.isEmpty)
                }
            }
        }
    }
    
    private func addGiftIdea() {
        let giftIdea = GiftIdea(
            personName: personName,
            giftName: giftName,
            url: URL(string: urlString),
            notes: notes,
            isPurchased: isPurchased
        )
        viewModel.addGiftIdea(giftIdea)
        dismiss()
    }
} 