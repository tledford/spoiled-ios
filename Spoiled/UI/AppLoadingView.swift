import SwiftUI

/// Full-screen cover shown while the first bootstrap is in flight.
///
/// The gift carries a `matchedGeometryEffect` so that when loading finishes it flies up
/// and settles into the slot beside the user's name in `GreetingHeader`, rather than the
/// app cutting from a placeholder straight to real content.
struct AppLoadingView: View {
    /// Shared with `GreetingHeader` so the gift can travel between the two.
    static let giftID = "app-gift"

    let namespace: Namespace.ID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bouncing = false

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 28) {
                Text("🎁")
                    .font(.system(size: 72))
                    .offset(y: bouncing ? -20 : 0)
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: bouncing
                    )
                    .matchedGeometryEffect(id: Self.giftID, in: namespace)

                Text("Wrapping things up")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { bouncing = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading your lists")
    }
}
