import Foundation
import Network

/// Reports when the device gets a connection back after losing it.
final class ConnectionMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "dev.tomled.Spoiled.ConnectionMonitor")
    private var wasConnected = true
    private var isStarted = false

    func start(onReconnect: @escaping @MainActor () -> Void) {
        guard !isStarted else { return }
        isStarted = true
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let isConnected = path.status == .satisfied
            if isConnected && !wasConnected {
                Task { @MainActor in onReconnect() }
            }
            wasConnected = isConnected
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
