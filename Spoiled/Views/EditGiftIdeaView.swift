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
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppSectionHeader(icon: "lightbulb.fill", title: "Gift Idea Details")
                        GiftIdeaFormFields(personName: $personName,
                                           giftName: $giftName,
                                           urlString: $urlString,
                                           notes: $notes,
                                           isPurchased: $isPurchased,
                                           showPurchasedToggle: true)
                            .spoiledCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Edit Gift Idea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .navButton(color: .brandBlue, isIcon: false)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await saveGiftIdea() } } label: {
                        Text("Save")
                            .navButton(color: .brandGold, isIcon: false)
                    }
                    .disabled(personName.isEmpty || giftName.isEmpty || viewModel.isSavingGiftIdea)
                }
            }
        }
    .trackScreen("edit_gift_idea")
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
