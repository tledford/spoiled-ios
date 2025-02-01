import SwiftUI

struct EditGiftIdeaView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var personName: String
    @State private var giftName: String
    @State private var urlString: String
    @State private var notes: String
    @State private var isPurchased: Bool
    
    let giftIdea: GiftIdea
    
    init(giftIdea: GiftIdea) {
        self.giftIdea = giftIdea
        _personName = State(initialValue: giftIdea.personName)
        _giftName = State(initialValue: giftIdea.giftName)
        _urlString = State(initialValue: giftIdea.url?.absoluteString ?? "")
        _notes = State(initialValue: giftIdea.notes)
        _isPurchased = State(initialValue: giftIdea.isPurchased)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Person's Name", text: $personName, prompt: Text("Person's Name"))
                    TextField("Gift Name", text: $giftName, prompt: Text("Gift Name"))
                    TextField("URL", text: $urlString, prompt: Text("URL"))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Notes", text: $notes, prompt: Text("Notes"), axis: .vertical)
                        .lineLimit(3...6)
                    Toggle("Purchased", isOn: $isPurchased)
                }
            }
            .navigationTitle("Edit Gift Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGiftIdea()
                    }
                    .disabled(personName.isEmpty || giftName.isEmpty)
                }
            }
        }
    }
    
    private func saveGiftIdea() {
        let updatedGiftIdea = GiftIdea(
            id: giftIdea.id,
            personName: personName,
            giftName: giftName,
            url: URL(string: urlString),
            notes: notes,
            isPurchased: isPurchased
        )
        viewModel.updateGiftIdea(updatedGiftIdea)
        dismiss()
    }
} 
