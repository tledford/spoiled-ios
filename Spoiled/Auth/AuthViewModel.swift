import Foundation
import Combine

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
                self?.state = newState
            })
            .store(in: &cancellables)
    }

    func signInWithGoogle() {
        Task { await store.signInWithGoogle() }
    }

    func signOut() { store.signOut() }

    // Expose token retrieval to consumers that need to attach Bearer tokens
    func getValidIDToken(forceRefresh: Bool) async -> String? {
        await store.getValidIDToken(forceRefresh: forceRefresh)
    }
}
