import SwiftUI

/// Reusable labeled form fields for creating or editing a GiftIdea.
struct GiftIdeaFormFields: View {
    @Binding var personName: String
    @Binding var giftName: String
    @Binding var urlString: String
    @Binding var notes: String
    @Binding var isPurchased: Bool
    var showPurchasedToggle: Bool
    var personSuggestions: [String]

    init(personName: Binding<String>,
         giftName: Binding<String>,
         urlString: Binding<String>,
         notes: Binding<String>,
         isPurchased: Binding<Bool>,
         showPurchasedToggle: Bool = true,
         personSuggestions: [String] = []) {
        self._personName = personName
        self._giftName = giftName
        self._urlString = urlString
        self._notes = notes
        self._isPurchased = isPurchased
        self.showPurchasedToggle = showPurchasedToggle
        self.personSuggestions = personSuggestions
    }

    var body: some View {
        VStack(spacing: 0) {
            field(label: "Person's Name") {
                HStack(spacing: 8) {
                    TextField("", text: $personName)
                        .textInputAutocapitalization(.words)
                    PersonSuggestionMenu(suggestions: personSuggestions, selection: $personName)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.leading, 16)

            field(label: "Gift Name") {
                TextField("", text: $giftName)
                    .textInputAutocapitalization(.words)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.leading, 16)

            field(label: "URL") {
                TextField("https://", text: $urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.leading, 16)

            field(label: "Notes") {
                TextField("", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if showPurchasedToggle {
                Divider().padding(.leading, 16)
                Toggle("Purchased", isOn: $isPurchased)
                    .tint(.brandGold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
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
