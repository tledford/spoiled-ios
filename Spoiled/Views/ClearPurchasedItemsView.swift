import SwiftUI

/// Sheet for hiding purchased wishlist items from the purchases report, either all of them
/// or only those bought before a chosen date.
struct ClearPurchasedItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter

    private enum Scope: Hashable {
        case all
        case before
    }

    @State private var scope: Scope = .all
    @State private var cutoffDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var isClearing = false

    // The picker bounds are frozen when the sheet opens. Recomputing them from the view model
    // would move the range out from under the current selection while the list refreshes,
    // which crashes the graphical date picker.
    @State private var rangeStart: Date = Calendar.current.startOfDay(for: Date())
    @State private var rangeEnd: Date = Date()

    private var selectableRange: ClosedRange<Date> {
        rangeStart...max(rangeStart, rangeEnd)
    }

    /// The cutoff that will actually be sent: purchases before it get hidden, purchases on the
    /// day itself or later are kept.
    private var effectiveCutoff: Date {
        switch scope {
        case .all:
            return Date()
        case .before:
            return Calendar.current.startOfDay(for: cutoffDate)
        }
    }

    private var affectedCount: Int {
        viewModel.purchasedWishlistItemCount(before: effectiveCutoff)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppSectionHeader(icon: "eraser", title: "What to Clear")

                        VStack(alignment: .leading, spacing: 0) {
                            Picker("What to clear", selection: $scope) {
                                Text("Everything").tag(Scope.all)
                                Text("Before a date").tag(Scope.before)
                            }
                            .pickerStyle(.segmented)
                            .padding(16)

                            if scope == .before {
                                Divider()
                                DatePicker("Keep purchases from this day on",
                                           selection: $cutoffDate,
                                           in: selectableRange,
                                           displayedComponents: .date)
                                    .datePickerStyle(.wheel)
                                    .labelsHidden()
                                    .tint(Color.brandGold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                            }
                        }
                        .spoiledCard()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        AppSectionHeader(icon: "info.circle", title: "Summary")

                        VStack(alignment: .leading, spacing: 10) {
                            Text(summaryText)
                                .font(.system(size: 15, weight: .semibold))
                            if scope == .before {
                                Text("Purchases made on \(cutoffDate.formatted(date: .abbreviated, time: .omitted)) or later stay in the report.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            Text("Cleared purchases are only hidden from your report and home screen. They stay marked as purchased for everyone else. Show All Purchases brings them back.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .spoiledCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Clear Purchases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .navButton(isIcon: false)
                    }
                    .disabled(isClearing)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .destructive) {
                        clear()
                    } label: {
                        Text("Clear")
                            .navButton(isIcon: false)
                    }
                    .disabled(isClearing || affectedCount == 0)
                }
            }
        }
        .onAppear(perform: freezePickerBounds)
        .trackScreen("clear_purchased_items")
    }

    private var summaryText: String {
        switch affectedCount {
        case 0 where scope == .before:
            return "No purchases were made before this date."
        case 0:
            return "There are no purchases to clear."
        case 1:
            return "1 purchase will be hidden."
        default:
            return "\(affectedCount) purchases will be hidden."
        }
    }

    /// Pins the picker to the span the report actually covers: the oldest purchase still showing
    /// through today.
    private func freezePickerBounds() {
        let calendar = Calendar.current
        let now = Date()
        let oldestPurchase = viewModel.purchasedWishlistItems.compactMap { $0.item.purchasedAt }.min()
        let start = calendar.startOfDay(for: min(oldestPurchase ?? now, now))
        rangeStart = start
        rangeEnd = now
        cutoffDate = min(max(cutoffDate, start), now)
    }

    /// Closes the sheet first: the clear refreshes the whole view model, and re-rendering the
    /// date picker against that new data while it is still on screen is what crashed the app.
    private func clear() {
        guard !isClearing else { return }
        isClearing = true
        let cutoff = effectiveCutoff
        let count = affectedCount
        dismiss()
        Task { @MainActor in
            let ok = await viewModel.clearWishlistPurchases(before: cutoff)
            if ok {
                toastCenter.success(count == 1 ? "1 purchase hidden" : "\(count) purchases hidden")
            } else {
                toastCenter.error("Couldn't clear purchases")
            }
        }
    }
}
