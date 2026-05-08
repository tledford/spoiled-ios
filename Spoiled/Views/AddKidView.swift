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
            ScrollView {
                VStack(spacing: 24) {
                    // Kid's Name & Birthdate
                    VStack(alignment: .leading, spacing: 12) {
                        AppSectionHeader(icon: "figure.and.child.holdinghands", title: "Kid's Info")
                        
                        VStack(spacing: 0) {
                            fieldRow(label: "Name") {
                                TextField("Enter kid's name", text: $kidName)
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
                    
                    // Other Parent
                    VStack(alignment: .leading, spacing: 12) {
                        AppSectionHeader(icon: "envelope.fill", title: "Other Parent (Optional)")
                        
                        VStack(spacing: 0) {
                            fieldRow(label: "Email") {
                                TextField("Enter email address", text: $otherParentEmail)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .spoiledCard()
                        
                        Text("This person will also be able to manage this kid's wishlist.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    
                    // Sizes
                    VStack(alignment: .leading, spacing: 12) {
                        AppSectionHeader(icon: "tshirt.fill", title: "Sizes")
                        
                        VStack(spacing: 0) {
                            sizeField(label: "Shirt", placeholder: "M, L, XL", text: $shirtSize)
                            Divider().padding(.leading, 16)
                            sizeField(label: "Pants", placeholder: "6, 7, 8", text: $pantsSize)
                            Divider().padding(.leading, 16)
                            sizeField(label: "Shoes", placeholder: "3Y, 4Y", text: $shoesSize)
                            Divider().padding(.leading, 16)
                            sizeField(label: "Sweatshirt", placeholder: "M", text: $sweatshirtSize)
                            Divider().padding(.leading, 16)
                            sizeField(label: "Hat", placeholder: "S/M", text: $hatSize)
                        }
                        .spoiledCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Add Kid")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Text("Cancel")
                            .navButton(isIcon: false)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { Task { await saveKid() } } label: {
                        Text("Save")
                            .navButton(isIcon: false)
                    }
                    .disabled(kidName.isEmpty || viewModel.isSavingKid)
                }
            }
            .trackScreen("add_kid")
        }
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
