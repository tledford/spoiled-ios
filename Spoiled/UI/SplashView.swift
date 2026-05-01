import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct SplashView: View {
    @ObservedObject var auth: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasPerformedInitialHealth = false
    @State private var serverStatusMessage: String?
    @State private var iconAppeared = false
    @State private var contentAppeared = false
    private let healthService = HealthService()

    var body: some View {
        ZStack {
            splashBackground
            VStack(spacing: 0) {
                Spacer()
                heroSection
                Spacer()
                authSection
                Spacer(minLength: 32)
                footerSection
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
        .ignoresSafeArea()
        .task {
            guard !hasPerformedInitialHealth else { return }
            let ok = await healthService.check()
            hasPerformedInitialHealth = true
            if !ok { serverStatusMessage = "Server unavailable." }
        }
    }

    // MARK: - Background
    @ViewBuilder private var splashBackground: some View {
        if #available(iOS 18, *) {
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    Color(red: 0.06, green: 0.05, blue: 0.14),
                    Color(red: 0.10, green: 0.07, blue: 0.22),
                    Color(red: 0.06, green: 0.05, blue: 0.14),
                    Color(red: 0.12, green: 0.08, blue: 0.24),
                    Color(red: 0.18, green: 0.10, blue: 0.32),
                    Color(red: 0.10, green: 0.06, blue: 0.20),
                    Color(red: 0.05, green: 0.05, blue: 0.10),
                    Color(red: 0.08, green: 0.06, blue: 0.16),
                    Color(red: 0.05, green: 0.04, blue: 0.10),
                ]
            )
            .ignoresSafeArea()
        } else {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.05, blue: 0.14),
                    Color(red: 0.14, green: 0.09, blue: 0.26),
                    Color(red: 0.05, green: 0.05, blue: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Hero
    private var heroSection: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.brandRose.opacity(0.12))
                    .frame(width: 140, height: 140)
                Circle()
                    .fill(Color.brandRose.opacity(0.07))
                    .frame(width: 170, height: 170)
                Image(systemName: "gift.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 68, height: 68)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.brandRose, Color(red: 0.94, green: 0.55, blue: 0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .scaleEffect(iconAppeared ? 1.0 : 0.6)
            .opacity(iconAppeared ? 1.0 : 0)
            .animation(
                reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.65).delay(0.1),
                value: iconAppeared
            )

            VStack(spacing: 8) {
                Text("Spoiled")
                    .font(.system(size: 52, weight: .black, design: .default))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.white.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .tracking(-1)

                Text("Wishlists for people who love giving")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }
            .opacity(contentAppeared ? 1 : 0)
            .offset(y: contentAppeared ? 0 : 12)
            .animation(
                reduceMotion ? .none : .easeOut(duration: 0.5).delay(0.3),
                value: contentAppeared
            )
        }
        .onAppear {
            iconAppeared = true
            contentAppeared = true
        }
    }

    // MARK: - Auth
    @ViewBuilder private var authSection: some View {
        switch auth.state {
        case .authenticating:
            VStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                Text("Signing in…")
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .frame(height: 108)

        default:
            VStack(spacing: 14) {
                if let serverError = serverStatusMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(serverError)
                    }
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                SignInWithAppleButton(.continue, onRequest: { request in
                    auth.prepareAppleRequest(request)
                }, onCompletion: { result in
                    auth.handleAppleCompletion(result)
                })
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
                .frame(maxWidth: hSizeClass == .regular ? 400 : .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                GoogleSignInButton(
                    scheme: .dark,
                    style: .wide,
                    action: { auth.signInWithGoogle() }
                )
                .frame(height: 50)
                .frame(maxWidth: hSizeClass == .regular ? 400 : .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .opacity(contentAppeared ? 1 : 0)
            .animation(
                reduceMotion ? .none : .easeOut(duration: 0.5).delay(0.45),
                value: contentAppeared
            )
        }
    }

    // MARK: - Footer
    private var footerSection: some View {
        Link("Privacy Policy", destination: AppConfig.api.privacyPolicyURL)
            .font(.footnote)
            .foregroundStyle(Color.white.opacity(0.35))
    }
}

#Preview {
    SplashView(auth: AuthViewModel())
}
