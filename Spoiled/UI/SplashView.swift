import SwiftUI
import AuthenticationServices
import GoogleSignInSwift

struct SplashView: View {
    @ObservedObject var auth: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var hSizeClass

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
                        if let serverError = auth.serverError {
                            Text(serverError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                auth.clearServerError()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        GoogleSignInButton(
                            scheme: colorScheme == .dark ? .dark : .light,
                            style: .wide,
                            action: { auth.signInWithGoogle() })
                        .frame(maxWidth: .infinity)
                        .cornerRadius(8)

                        SignInWithAppleButton(.continue, onRequest: { request in
                            auth.prepareAppleRequest(request)
                        }, onCompletion: { result in
                            auth.handleAppleCompletion(result)
                        })
                        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                        .frame(maxWidth: .infinity, maxHeight: 40)
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: hSizeClass == .regular ? 420 : .infinity)
                    .padding(.horizontal)
            }
            Spacer()
//            Text("Sign in with Google or Apple")
//                .font(.footnote)
//                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    SplashView(auth: AuthViewModel())
}
