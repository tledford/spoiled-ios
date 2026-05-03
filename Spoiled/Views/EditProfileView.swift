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
            ScrollView {
                VStack(spacing: 24) {
                    if let msg = errorMessage {
                        Text(msg)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                    
                    // Personal Info
                    VStack(alignment: .leading, spacing: 12) {
                        AppSectionHeader(icon: "person.fill", title: "Personal Info")
                        
                        VStack(spacing: 0) {
                            fieldRow(label: "Name") {
                                TextField("Enter your name", text: $name)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            Divider().padding(.leading, 16)
                            
                            fieldRow(label: "Email") {
                                TextField("Enter email", text: $email)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            Divider().padding(.leading, 16)
                            
                            fieldRow(label: "Birthdate") {
                                DatePicker(
                                    "",
                                    selection: $birthdate,
                                    displayedComponents: [.date]
                                )
                                .labelsHidden()
                            }
                        }
                        .spoiledCard()
                    }
                    
                    // Sizes
                    VStack(alignment: .leading, spacing: 12) {
                        AppSectionHeader(icon: "tshirt.fill", title: "Sizes")
                        
                        VStack(spacing: 0) {
                            sizeField(label: "Shirt", placeholder: "M, L, XL", text: $shirtSize)
                            Divider().padding(.leading, 16)
                            sizeField(label: "Pants", placeholder: "32x32", text: $pantsSize)
                            Divider().padding(.leading, 16)
                            sizeField(label: "Shoes", placeholder: "10.5", text: $shoesSize)
                            Divider().padding(.leading, 16)
                            sizeField(label: "Sweatshirt", placeholder: "L", text: $sweatshirtSize)
                            Divider().padding(.leading, 16)
                            sizeField(label: "Hat", placeholder: "7 1/4", text: $hatSize)
                        }
                        .spoiledCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .navButton(color: .brandBlue, isIcon: false)
                    }
                    .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await saveProfile() } } label: {
                        Text(isSaving ? "Saving…" : "Save")
                            .navButton(color: .brandGold, isIcon: false)
                    }
                    .disabled(isSaving || name.isEmpty || email.isEmpty)
                }
            }
        }
        .trackScreen("edit_profile")
    }
    
    @ViewBuilder
    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
            Spacer()
            content()
                .font(.system(size: 15))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
    
    @ViewBuilder
    private func sizeField(label: String, placeholder: String, text: Binding<String>) -> some View {
        fieldRow(label: label) {
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
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
