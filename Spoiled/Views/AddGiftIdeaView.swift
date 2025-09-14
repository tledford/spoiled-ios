import SwiftUI

struct AddGiftIdeaView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var personName = ""
    @State private var giftName = ""
    @State private var urlString = ""
    @State private var notes = ""
    @State private var isPurchased = false
    
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
                        Task { await addGiftIdea() }
                    }
                    .disabled(personName.isEmpty || giftName.isEmpty || viewModel.isSavingGiftIdea)
                }
            }
        }
    }
    
    private func addGiftIdea() async {
        let giftIdea = GiftIdea(
            personName: personName,
            giftName: giftName,
            url: URL(string: urlString),
            notes: notes,
            isPurchased: isPurchased
        )
        let ok = await viewModel.addGiftIdea(giftIdea)
        if ok {
            toastCenter.success("Gift idea added")
            dismiss()
        } else {
            toastCenter.error(viewModel.errorMessage ?? "Failed to add gift idea")
        }
    }
} 