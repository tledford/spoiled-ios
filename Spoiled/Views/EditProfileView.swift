import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: WishlistViewModel
    
    @State private var name: String
    @State private var email: String
    @State private var birthdate: Date
    @State private var shirtSize: String
    @State private var pantsSize: String
    @State private var shoesSize: String
    @State private var sweatshirtSize: String
    @State private var hatSize: String
    
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
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(name.isEmpty || email.isEmpty)
                }
            }
        }
    }
    
    private func saveProfile() {
        let sizes = Sizes(
            shirt: shirtSize,
            pants: pantsSize,
            shoes: shoesSize,
            sweatshirt: sweatshirtSize,
            hat: hatSize
        )
        
        // In a real app, you'd update the user profile in your backend
        viewModel.updateProfile(
            name: name,
            email: email,
            birthdate: birthdate,
            sizes: sizes
        )
        dismiss()
    }
} 