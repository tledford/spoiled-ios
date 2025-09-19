import Foundation
import Combine
import FirebaseAuth
import GoogleSignIn
import FirebaseAnalytics
import FirebaseCrashlytics
import UIKit

// Phase 1: Implement Google sign-in with Firebase only

enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(userId: String)
}

protocol AuthStore: AnyObject {
    var authStatePublisher: AnyPublisher<AuthState, Never> { get }
    var currentState: AuthState { get }

    func signInWithGoogle() async
    func getValidIDToken(forceRefresh: Bool) async -> String?
    func signOut()
}

final class DefaultAuthStore: AuthStore {
    private let stateSubject: CurrentValueSubject<AuthState, Never>
    var authStatePublisher: AnyPublisher<AuthState, Never> { stateSubject.eraseToAnyPublisher() }
    var currentState: AuthState { stateSubject.value }

    init(initial: AuthState = .unauthenticated) {
        self.stateSubject = CurrentValueSubject(initial)
        // If FirebaseAuth is present and user is already signed in, reflect that
        if let user = Auth.auth().currentUser {
            stateSubject.send(.authenticated(userId: user.uid))
        }
    }

    func signInWithGoogle() async { await signInWithGoogleFirebase() }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        try? Auth.auth().signOut()
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
            // Google sign-in
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
}
