import SwiftUI

/// Reusable labeled form fields for creating or editing a GiftIdea.
/// Caller owns state & validation; this view only renders bindings.
struct GiftIdeaFormFields: View {
    @Binding var personName: String
    @Binding var giftName: String
    @Binding var urlString: String
    @Binding var notes: String
    @Binding var isPurchased: Bool
    var showPurchasedToggle: Bool

    init(personName: Binding<String>,
         giftName: Binding<String>,
         urlString: Binding<String>,
         notes: Binding<String>,
         isPurchased: Binding<Bool>,
         showPurchasedToggle: Bool = true) {
        self._personName = personName
        self._giftName = giftName
        self._urlString = urlString
        self._notes = notes
        self._isPurchased = isPurchased
        self.showPurchasedToggle = showPurchasedToggle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            field(label: "Person's Name") {
                TextField("", text: $personName)
                    .textInputAutocapitalization(.words)
            }
            field(label: "Gift Name") {
                TextField("", text: $giftName)
                    .textInputAutocapitalization(.words)
            }
            field(label: "URL") {
                TextField("", text: $urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            field(label: "Notes") {
                TextField("", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            if showPurchasedToggle {
                field(label: "Purchased") {
                    Toggle("", isOn: $isPurchased)
                        .labelsHidden()
                }
            }
        }
    }

    @ViewBuilder
    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
