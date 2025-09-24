import Foundation
import Combine
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var state: AuthState
    private var cancellables = Set<AnyCancellable>()
    private let store: AuthStore

    init(store: AuthStore = DefaultAuthStore()) {
        self.store = store
        self.state = store.currentState
        store.authStatePublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveValue: { [weak self] newState in
                guard let self else { return }
                let previous = self.state
                self.state = newState
            })
            .store(in: &cancellables)
    }

    func signInWithGoogle() {
        Task { await store.signInWithGoogle() }
    }

    // Apple Sign-In passthroughs
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        store.prepareAppleRequest(request)
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        store.handleAppleCompletion(result)
    }

    // Account deletion
    func beginAppleAccountDeletion(_ request: ASAuthorizationAppleIDRequest) {
        store.beginAppleAccountDeletion(request)
    }

    func handleAppleAccountDeletionCompletion(_ result: Result<ASAuthorization, Error>) {
        store.handleAppleAccountDeletionCompletion(result)
    }

    func deleteCurrentUserWithoutApple() {
        Task { await store.deleteCurrentUserWithoutApple() }
    }

    func isCurrentUserApple() -> Bool { store.isCurrentUserApple() }

    func signOut() { store.signOut() }

    // Expose token retrieval to consumers that need to attach Bearer tokens
    func getValidIDToken(forceRefresh: Bool) async -> String? {
        await store.getValidIDToken(forceRefresh: forceRefresh)
    }

}
