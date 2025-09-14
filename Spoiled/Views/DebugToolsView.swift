import SwiftUI
import Foundation

// Simple developer utilities for early development/testing
struct DebugToolsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var selectedUserId: UUID = AppConfig.devUserId

    struct DevUser: Identifiable, Hashable { let id: UUID; let name: String }

    // Hardcoded IDs from the API dev seed (for local testing only)
    private let devUsers: [DevUser] = [
        DevUser(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "John Smith"),
        DevUser(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, name: "Emma Wilson"),
        DevUser(id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!, name: "Michael Brown"),
        DevUser(id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!, name: "Sarah Davis"),
        DevUser(id: UUID(uuidString: "20000000-0000-0000-0000-000000000004")!, name: "James Miller")
    ]

    var body: some View {
        List {
            Section(footer: Text("Toggles the X-User-Id header and reloads Bootstrap. Dev use only.")) {
                ForEach(devUsers) { user in
                    Button(action: { switchUser(to: user) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.name)
                                Text(user.id.uuidString)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedUserId == user.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.blue)
                            }
                        }
                    }
                    .disabled(selectedUserId == user.id || viewModel.isLoading)
                }
            }
        }
        .navigationTitle("Debug Tools")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func switchUser(to user: DevUser) {
        guard selectedUserId != user.id else { return }
        selectedUserId = user.id
        AppConfig.devUserId = user.id
        toastCenter.info("Switching to \(user.name)…")
        Task { @MainActor in
            await viewModel.refreshAll()
            if let error = viewModel.errorMessage, !error.isEmpty {
                toastCenter.error("Failed: \(error)")
            } else {
                toastCenter.success("Now acting as \(user.name)")
            }
        }
    }
}

#Preview {
    NavigationStack {
        DebugToolsView()
            .environmentObject(WishlistViewModel())
            .environmentObject(ToastCenter())
    }
}
