import SwiftUI

/// Item form row for how many of an item the owner wants.
struct QuantityStepperRow: View {
    @Binding var quantity: Int

    var body: some View {
        Stepper(value: $quantity, in: 1...WishlistItem.maxQuantityDesired) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Quantity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(quantity)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
