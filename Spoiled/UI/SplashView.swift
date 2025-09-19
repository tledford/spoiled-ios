import SwiftUI

struct SplashView: View {
    @ObservedObject var auth: AuthViewModel

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
                    ProgressView().padding(.vertical)
                default:
                    VStack(spacing: 12) {
                        Button(action: { auth.signInWithGoogle() }) {
                            HStack { Image(systemName: "g.circle.fill"); Text("Continue with Google") }
                        }
                        .buttonStyle(.borderedProminent)
                    }
            }
            Spacer()
            Text("Sign in with your Google account")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    SplashView(auth: AuthViewModel())
}
