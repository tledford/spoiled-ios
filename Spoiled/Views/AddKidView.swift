import SwiftUI

struct AddKidView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var kidName: String = ""
    @State private var birthdate: Date = Date()
    @State private var shirtSize: String = ""
    @State private var pantsSize: String = ""
    @State private var shoesSize: String = ""
    @State private var sweatshirtSize: String = ""
    @State private var hatSize: String = ""
    @State private var otherParentEmail: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Kid's Name")) {
                    TextField("Enter kid's name", text: $kidName)
                }
                
                Section {
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
            .navigationTitle("Add Kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await saveKid() } }
                    .disabled(kidName.isEmpty || viewModel.isSavingKid)
                }
            }
        }
    .trackScreen("add_kid")
    }
    
    private func saveKid() async {
        let newKid = Kid(
            name: kidName,
            birthdate: birthdate,
            sizes: Sizes(
                shirt: shirtSize,
                pants: pantsSize,
                shoes: shoesSize,
                sweatshirt: sweatshirtSize,
                hat: hatSize
            )
        )
        let guardianEmail = otherParentEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let ok = await viewModel.addKid(newKid, guardianEmail: guardianEmail.isEmpty ? nil : guardianEmail)
        if ok {
            toastCenter.success("Kid added")
            dismiss()
        } else {
            toastCenter.error(viewModel.errorMessage ?? "Failed to add kid")
        }
    }
}
