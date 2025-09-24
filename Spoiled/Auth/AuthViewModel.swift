import Foundation
import Combine
import AuthenticationServices

@MainActor
final class AuthViewModel: ObservableObject {
    @Published private(set) var state: AuthState
    @Published var serverError: String? // Shown on Splash when backend unreachable
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
                // When we first transition to authenticated, verify backend reachability.
                if case .authenticated = newState, case .authenticated = previous {
                    // Already authenticated previously; skip.
                } else if case .authenticated = newState {
                    Task { await self.verifyBackend() }
                }
            })
            .store(in: &cancellables)
    }

    func signInWithGoogle() {
    serverError = nil
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

    func clearServerError() { serverError = nil }

    // MARK: - Backend verification
    private func verifyBackend() async {
        // Attempt a lightweight bootstrap call to ensure backend is reachable.
        let provider: (Bool) async -> String? = { force in await self.store.getValidIDToken(forceRefresh: force) }
        let client = APIClient(tokenProvider: provider)
        let bootstrap = BootstrapService(client: client)
        do {
            _ = try await bootstrap.load()
            // Success; nothing to do.
        } catch {
            await MainActor.run {
                // Map to generic message (avoid leaking internal errors)
                self.serverError = "Server not available. Please try again later."
                self.store.signOut()
            }
        }
    }
}
