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
            // Opaque, so rows scrolling under it don't show through.
            .background {
                let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                shape.fill(Color.appBackground)
                    .overlay(shape.fill(Color.brandGold.opacity(0.18)))
                    .overlay(shape.strokeBorder(Color.brandGold.opacity(0.35)))
            }
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Tries to refresh")
    }
}

extension View {
    /// Shows `StaleDataBanner` above the tab bar when it's needed. Apply it to a tab's root content.
    ///
    /// It isn't at the top: outside the `NavigationStack` the navigation bar drew over it, and inside
    /// it the large title went missing on any tab first opened while the banner showed.
    func staleDataBanner() -> some View {
        modifier(StaleDataBannerPlacement())
    }
}

private struct StaleDataBannerPlacement: ViewModifier {
    @EnvironmentObject private var viewModel: WishlistViewModel

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if viewModel.showsStaleDataBanner, let failure = viewModel.loadFailure {
                StaleDataBanner(
                    failure: failure,
                    lastLoadedAt: viewModel.lastLoadedAt,
                    onRetry: { Task { await viewModel.load() } }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
}
