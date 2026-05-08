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
            .navigationTitle("Add Gift Idea")
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
                        Task { await addGiftIdea() }
                    } label: {
                        Text("Add")
                            .navButton(isIcon: false)
                    }
                    .disabled(personName.isEmpty || giftName.isEmpty || viewModel.isSavingGiftIdea)
                }
            }
        }
    .trackScreen("add_gift_idea")
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