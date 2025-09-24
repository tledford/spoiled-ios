import Foundation
import Combine
import FirebaseAuth
import GoogleSignIn
import FirebaseAnalytics
import FirebaseCrashlytics
// Analytics helpers (see Analytics/AnalyticsEvents.swift)
import UIKit
import AuthenticationServices
import CryptoKit

enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(userId: String)
}

protocol AuthStore: AnyObject {
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }
    var currentState: AuthState { get }

    func signInWithGoogle() async
    // Apple Sign-In via SwiftUI's SignInWithAppleButton hooks
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest)
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>)
    // Account deletion (Apple requires re-auth and token revocation)
    func beginAppleAccountDeletion(_ request: ASAuthorizationAppleIDRequest)
    func handleAppleAccountDeletionCompletion(_ result: Result<ASAuthorization, Error>)
    func deleteCurrentUserWithoutApple() async
    func isCurrentUserApple() -> Bool
    func getValidIDToken(forceRefresh: Bool) async -> String?
    func signOut()
}

final class DefaultAuthStore: AuthStore {
    private let stateSubject: CurrentValueSubject<AuthState, Never>
    var authStatePublisher: AnyPublisher<AuthState, Never> { stateSubject.eraseToAnyPublisher() }
    var currentState: AuthState { stateSubject.value }
    private var currentNonce: String?
    private let usersService = UsersService()

    init(initial: AuthState = .unauthenticated) {
        self.stateSubject = CurrentValueSubject(initial)
        // If FirebaseAuth is present and user is already signed in, reflect that
        if let user = Auth.auth().currentUser {
            stateSubject.send(.authenticated(userId: user.uid))
        }
    }

    func signInWithGoogle() async { await signInWithGoogleFirebase() }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
    case .failure:
            stateSubject.send(.unauthenticated)
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce,
                  let appleIDToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                stateSubject.send(.unauthenticated)
                return
            }

            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )

            Task { @MainActor in
                do {
                    stateSubject.send(.authenticating)
                    let authResult = try await Auth.auth().signIn(with: credential)
                    _ = try? await authResult.user.getIDTokenResult(forcingRefresh: true)
                    let uid = authResult.user.uid
                    Analytics.setUserID(uid)
                    AnalyticsEvents.login(method: "apple")
                    AnalyticsAuthProvider.record("apple")
                    Crashlytics.crashlytics().setUserID(uid)
                    stateSubject.send(.authenticated(userId: uid))
                } catch {
                    stateSubject.send(.unauthenticated)
                }
            }
        }
    }

    func beginAppleAccountDeletion(_ request: ASAuthorizationAppleIDRequest) {
        // Apple requires the user to re-authorize; we reuse nonce pattern
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
    }

    func handleAppleAccountDeletionCompletion(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure:
            // User canceled or failed; do nothing to state
            return
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let codeData = appleIDCredential.authorizationCode,
                  let authCodeString = String(data: codeData, encoding: .utf8) else { return }

            Task { @MainActor in
                do {
                    // Delete user data in API first
                    do { try await self.usersService.deleteMe() } catch { /* ignore and continue to revoke */ }
                    try await Auth.auth().revokeToken(withAuthorizationCode: authCodeString)
                    if let user = Auth.auth().currentUser {
                        try await user.delete()
                    }
                    // Also clear local session
                    try? Auth.auth().signOut()
                    GIDSignIn.sharedInstance.signOut()
                    stateSubject.send(.unauthenticated)
                } catch {
                    // Keep user signed in; caller may show error UI
                }
            }
        }
    }

    func deleteCurrentUserWithoutApple() async {
        // Always attempt to delete server data first; don't block on API errors.
        do { try await usersService.deleteMe() } catch { /* ignore */ }

        if let user = Auth.auth().currentUser {
            do {
                try await user.delete()
            } catch {
                // If deletion requires recent login, re-auth with Google then retry.
                let nsErr = error as NSError
                let requiresRecent = nsErr.code == AuthErrorCode.requiresRecentLogin.rawValue
//                let credTooOld = nsErr.code == AuthErrorCode.credentialTooOld.rawValue
                if requiresRecent {//} || credTooOld {
                    do {
                        try await reauthenticateWithGoogle()
                        try await user.delete()
                    } catch {
                        // Still failed; proceed to sign-out so the user returns to splash.
                    }
                } else {
                    // Other delete error; proceed to sign-out.
                }
            }
        }

        // Clear local session regardless so UI returns to SplashView.
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        stateSubject.send(.unauthenticated)
    }

    func isCurrentUserApple() -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        return user.providerData.contains(where: { $0.providerID == "apple.com" })
    }

    func signOut() {
        // Sign out of Firebase and any provider SDKs we control.
    GIDSignIn.sharedInstance.signOut()
    try? Auth.auth().signOut()
    AnalyticsEvents.logout()
        stateSubject.send(.unauthenticated)
    }

    func getValidIDToken(forceRefresh: Bool) async -> String? {
        guard let user = Auth.auth().currentUser else { return nil }
        if forceRefresh {
            if let result = try? await user.getIDTokenResult(forcingRefresh: true) {
                return result.token
            } else {
                return try? await user.getIDToken()
            }
        } else {
            return try? await user.getIDToken()
        }
    }

    
    @MainActor
    private func signInWithGoogleFirebase() async {
        stateSubject.send(.authenticating)
        do {
            guard let presenting = topViewController() else {
                stateSubject.send(.unauthenticated)
                return
            }
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard
                let idToken = result.user.idToken?.tokenString
            else {
                stateSubject.send(.unauthenticated)
                return
            }
            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            // Sign in to Firebase
            let authResult = try await Auth.auth().signIn(with: credential)
            // Prime ID token to avoid race where first API call lacks Authorization
            _ = try? await authResult.user.getIDTokenResult(forcingRefresh: true)
            let uid = authResult.user.uid
            // Tag Analytics/Crashlytics
            Analytics.setUserID(uid)
            AnalyticsEvents.login(method: "google")
            AnalyticsAuthProvider.record("google")
            Crashlytics.crashlytics().setUserID(uid)
            stateSubject.send(.authenticated(userId: uid))
        } catch {
            stateSubject.send(.unauthenticated)
        }
    }

    // Utility to find the top-most view controller for presenting Google Sign-In
    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC = base ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        if let nav = baseVC as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = baseVC as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = baseVC?.presentedViewController {
            return topViewController(base: presented)
        }
        return baseVC
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap { String(format: "%02x", $0) }.joined()
        return hashString
    }

    // Re-authenticate the current Firebase user with Google to satisfy recent-login requirement.
    @MainActor
    private func reauthenticateWithGoogle() async throws {
        guard let presenting = topViewController() else { throw URLError(.userAuthenticationRequired) }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
        guard let idToken = result.user.idToken?.tokenString else { throw URLError(.userAuthenticationRequired) }
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        guard let user = Auth.auth().currentUser else { throw URLError(.userAuthenticationRequired) }
        _ = try await user.reauthenticate(with: credential)
    }
}
