import SwiftUI

// MARK: - ConnectionErrorView

/// Shown instead of the app when there's no data at all, so a failed load never looks like an empty account.
struct ConnectionErrorView: View {
    /// Nil while the first load is still going, just taking a while.
    let failure: LoadFailure?
    let onRetry: () -> Void
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            if let failure {
                Image(systemName: failure == .offline ? "wifi.slash" : "exclamationmark.icloud")
                    .font(.largeTitle)
                    .imageScale(.large)
                    .foregroundStyle(Color.brandGold)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(failure.title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(failure.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.brandGold)
            } else {
                ProgressView()
                Text("Taking longer than usual…")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Sign Out", action: onSignOut)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground.ignoresSafeArea())
        .trackScreen("connection_error")
    }
}

// MARK: - StaleDataBanner

/// Says the data on screen may be out of date. Tapping it tries again.
struct StaleDataBanner: View {
    let failure: LoadFailure
    let lastLoadedAt: Date?
    let onRetry: () -> Void

    private static let formatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()

    private var text: String {
        let lead = failure == .offline ? "You're offline" : "Couldn't refresh"
        guard let lastLoadedAt else { return lead }
        // Under a minute reads oddly as "in 0 sec.", and nothing's really changed by then anyway.
        guard Date().timeIntervalSince(lastLoadedAt) >= 60 else { return "\(lead) · Updated just now" }
        return "\(lead) · Updated \(Self.formatter.localizedString(for: lastLoadedAt, relativeTo: Date()))"
    }

    var body: some View {
        Button(action: onRetry) {
            HStack(spacing: 8) {
                Image(systemName: failure == .offline ? "wifi.slash" : "exclamationmark.arrow.circlepath")
                    .accessibilityHidden(true)
                Text(text)
                    .multilineTextAlignment(.leading)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.brandGold.opacity(0.18))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Tries to refresh")
    }
}
