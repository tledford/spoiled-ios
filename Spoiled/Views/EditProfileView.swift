import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var toastCenter: ToastCenter
    @ObservedObject var viewModel: WishlistViewModel
    
    @State private var name: String
    @State private var email: String
    @State private var birthdate: Date
    @State private var shirtSize: String
    @State private var pantsSize: String
    @State private var shoesSize: String
    @State private var sweatshirtSize: String
    @State private var hatSize: String

    @State private var isSaving = false
    @State private var errorMessage: String?
    
    init(viewModel: WishlistViewModel) {
        self.viewModel = viewModel
        _name = State(initialValue: viewModel.currentUser?.name ?? "")
        _email = State(initialValue: viewModel.currentUser?.email ?? "")
        _birthdate = State(initialValue: viewModel.currentUser?.birthdate ?? Date())
        _shirtSize = State(initialValue: viewModel.currentUser?.sizes.shirt ?? "")
        _pantsSize = State(initialValue: viewModel.currentUser?.sizes.pants ?? "")
        _shoesSize = State(initialValue: viewModel.currentUser?.sizes.shoes ?? "")
        _sweatshirtSize = State(initialValue: viewModel.currentUser?.sizes.sweatshirt ?? "")
        _hatSize = State(initialValue: viewModel.currentUser?.sizes.hat ?? "")
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if let msg = errorMessage {
                    Text(msg).foregroundStyle(.red)
                }
                Section("Personal Info") {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    DatePicker(
                        "Birthdate",
                        selection: $birthdate,
                        displayedComponents: [.date]
                    )
                }
                
                Section("Sizes") {
                    LabeledContent("Shirt") {
                        TextField("M, L, XL", text: $shirtSize)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Pants") {
                        TextField("32x32", text: $pantsSize)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Shoes") {
                        TextField("10.5", text: $shoesSize)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Sweatshirt") {
                        TextField("L", text: $sweatshirtSize)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Hat") {
                        TextField("7 1/4", text: $hatSize)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await saveProfile() } }
                        .disabled(isSaving || name.isEmpty || email.isEmpty)
                }
            }
        }
    }
    
    private func saveProfile() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        let sizes = Sizes(
            shirt: shirtSize,
            pants: pantsSize,
            shoes: shoesSize,
            sweatshirt: sweatshirtSize,
            hat: hatSize
        )
        do {
            try await viewModel.saveProfile(name: name, email: email, birthdate: birthdate, sizes: sizes)
            toastCenter.success("Profile updated")
            dismiss()
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            errorMessage = msg
            toastCenter.error(msg)
        }
    }
}