import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct SplashView: View {
    @ObservedObject var auth: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var hasPerformedInitialHealth = false
    @State private var serverStatusMessage: String?
    private let healthService = HealthService()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "gift.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .foregroundStyle(.pink)
                .padding(.bottom, 8)
            Text("Welcome to Spoiled")
                .font(.largeTitle).bold()
            Text("Sign in to continue")
                .foregroundStyle(.secondary)
            Spacer()
            switch auth.state {
                case .authenticating:
                    Text("Signing in…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    ProgressView().padding(.vertical)
                default:
                    VStack(spacing: 12) {
                        if let serverError = serverStatusMessage {
                            Text(serverError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                        }
                        GoogleSignInButton(
                            scheme: colorScheme == .dark ? .dark : .light,
                            style: .wide,
                            action: { auth.signInWithGoogle() })
                        .frame(maxWidth: 375)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(8)

                        SignInWithAppleButton(.continue, onRequest: { request in
                            auth.prepareAppleRequest(request)
                        }, onCompletion: { result in
                            auth.handleAppleCompletion(result)
                        })
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(height: 40)
                        .frame(maxWidth: 375)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: hSizeClass == .regular ? 420 : .infinity)
                    .padding(.horizontal)
            }
            Spacer()
//            Text("Sign in with Google or Apple")
//                .font(.footnote)
//                .foregroundStyle(.secondary)
            Link("Privacy Policy", destination: AppConfig.api.privacyPolicyURL)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
        .padding()
        // Run health check once on first appearance. Using plain .task avoids
        // cancellation that was happening when mutating the id-bound state.
        .task {
            guard !hasPerformedInitialHealth else { return }
            let ok = await healthService.check()
            hasPerformedInitialHealth = true
            if !ok { serverStatusMessage = "Server unavailable." }
        }
    }
}

#Preview {
    SplashView(auth: AuthViewModel())
}
