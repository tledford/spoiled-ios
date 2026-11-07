import Foundation
import FirebaseAuth

enum FirebaseSession {
    /// Token provider for `APIClient`, backed directly by the Firebase user.
    ///
    /// The app and the share extension see the same signed-in user without any extra setup:
    /// Firebase's user keychain item is keyed by `firebase_auth_<googleAppID>` (taken from
    /// `GoogleService-Info.plist`, which both targets bundle) and is stored with no explicit
    /// access group, so it lands in each process's *default* access group — the first entry of
    /// `keychain-access-groups`. Both targets declare exactly one entry,
    /// `$(AppIdentifierPrefix)dev.tomled.Spoiled`, so both resolve to the same item.
    ///
    /// Do not call `Auth.auth().useUserAccessGroup(_:)` here. It reads from a *different*
    /// keychain item (`AuthStoredUserManager`, keyed by project id and an explicit access
    /// group), does not carry the existing user over to it, and deletes the legacy item — which
    /// signs every existing user out on first launch after the update.
    static var tokenProvider: (Bool) async throws -> String? {
        { forceRefresh in
            guard let user = Auth.auth().currentUser else { return nil }
            do {
                if forceRefresh {
                    return try await user.getIDTokenResult(forcingRefresh: true).token
                }
                return try await user.getIDToken()
            } catch {
                throw isSessionOver(error) ? APIError.sessionOver : APIError.tokenUnavailable
            }
        }
    }

    /// Whether a failed token request means the session has really ended. Anything else, like
    /// having no connection, is temporary and must not sign the user out.
    static func isSessionOver(_ error: Error) -> Bool {
        let error = error as NSError
        guard error.domain == AuthErrors.domain, let code = AuthErrorCode(rawValue: error.code) else { return false }
        switch code {
        case .userTokenExpired, .invalidUserToken, .userDisabled, .userNotFound:
            return true
        default:
            return false
        }
    }
}
