import SwiftUI

struct EditGiftIdeaView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
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
                    GiftIdeaFormFields(personName: $personName,
                                       giftName: $giftName,
                                       urlString: $urlString,
                                       notes: $notes,
                                       isPurchased: $isPurchased,
                                       showPurchasedToggle: true)
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
                        Task { await saveGiftIdea() }
                    }
                    .disabled(personName.isEmpty || giftName.isEmpty || viewModel.isSavingGiftIdea)
                }
            }
        }
    }
    
    private func saveGiftIdea() async {
        let updatedGiftIdea = GiftIdea(
            id: giftIdea.id,
            personName: personName,
            giftName: giftName,
            url: URL(string: urlString),
            notes: notes,
            isPurchased: isPurchased
        )
        let ok = await viewModel.updateGiftIdea(updatedGiftIdea)
        if ok {
            toastCenter.success("Gift idea updated")
            dismiss()
        } else {
            toastCenter.error(viewModel.errorMessage ?? "Failed to update gift idea")
        }
    }
} 
