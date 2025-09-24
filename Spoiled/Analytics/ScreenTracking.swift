import SwiftUI
import FirebaseAnalytics

// Simple screen tracking modifier. Apply to root content of a screen.
struct TrackScreen: ViewModifier {
    let name: String
    func body(content: Content) -> some View {
        content
            .onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: name]) }
    }
}

extension View {
    func trackScreen(_ name: String) -> some View { self.modifier(TrackScreen(name: name)) }
}