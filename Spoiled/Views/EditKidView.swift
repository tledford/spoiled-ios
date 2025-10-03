import SwiftUI

struct EditKidView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    let kidIndex: Int
    
    @State private var kidName: String
    @State private var birthdate: Date
    @State private var shirtSize: String
    @State private var pantsSize: String
    @State private var shoesSize: String
    @State private var sweatshirtSize: String
    @State private var hatSize: String
    @State private var otherParentEmail: String

    init(kidIndex: Int) {
        self.kidIndex = kidIndex
        _kidName = State(initialValue: "")
        _birthdate = State(initialValue: Date())
        _shirtSize = State(initialValue: "")
        _pantsSize = State(initialValue: "")
        _shoesSize = State(initialValue: "")
        _sweatshirtSize = State(initialValue: "")
        _hatSize = State(initialValue: "")
        _otherParentEmail = State(initialValue: "")
    }
    
    var body: some View {
        Form {
            Section("Info") {
                TextField("Name", text: $kidName)
                DatePicker(
                    "Birthdate",
                    selection: $birthdate,
                    displayedComponents: [.date]
                )
            }
            
            Section(header: Text("Other Parent (Optional)")) {
                TextField("Enter email address", text: $otherParentEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
            
            Section("Sizes") {
                LabeledContent("Shirt") {
                    TextField("M, L, XL", text: $shirtSize)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Pants") {
                    TextField("6, 7, 8", text: $pantsSize)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Shoes") {
                    TextField("3Y, 4Y", text: $shoesSize)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Sweatshirt") {
                    TextField("M", text: $sweatshirtSize)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Hat") {
                    TextField("S/M", text: $hatSize)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .onAppear {
            loadKidData()
        }
        .navigationTitle("Edit Kid")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { Task { await saveKid() } }
                .disabled(kidName.isEmpty || viewModel.isSavingKid)
            }
        }
    .trackScreen("edit_kid")
    }
    
    private func loadKidData() {
        if let kid = viewModel.kids?[kidIndex] {
            kidName = kid.name
            birthdate = kid.birthdate
            shirtSize = kid.sizes.shirt
            pantsSize = kid.sizes.pants
            shoesSize = kid.sizes.shoes
            sweatshirtSize = kid.sizes.sweatshirt
            hatSize = kid.sizes.hat
            
            // Find the other parent's email (not the current user)
            if let currentUserEmail = viewModel.currentUser?.email {
                otherParentEmail = kid.guardianEmails.first(where: { $0 != currentUserEmail }) ?? ""
            }
        }
    }
    
    private func saveKid() async {
        let currentKid = viewModel.kids![kidIndex]
        let updatedKid = Kid(
            id: currentKid.id,
            name: kidName,
            birthdate: birthdate,
            wishlistItems: currentKid.wishlistItems,
            sizes: Sizes(
                shirt: shirtSize,
                pants: pantsSize,
                shoes: shoesSize,
                sweatshirt: sweatshirtSize,
                hat: hatSize
            ),
            guardianEmails: currentKid.guardianEmails
        )
        let guardianEmail = otherParentEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = await viewModel.updateKid(updatedKid, guardianEmail: guardianEmail.isEmpty ? nil : guardianEmail)
        if ok {
            toastCenter.success("Kid updated")
            dismiss()
        } else {
            toastCenter.error(viewModel.errorMessage ?? "Failed to update kid")
        }
    }
} 
