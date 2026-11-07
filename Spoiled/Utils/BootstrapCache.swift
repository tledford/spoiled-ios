import Foundation

/// The last good bootstrap, so the app can open with data when the server can't be reached.
/// Deleted on sign-out. Never shared with the share extension, which has its own smaller snapshot.
final class BootstrapCache: @unchecked Sendable {
    struct Entry: Codable {
        let userId: String
        let savedAt: Date
        let data: BootstrapData
    }

    static let shared = BootstrapCache(directory: URL.applicationSupportDirectory.appending(path: "BootstrapCache"))

    private let directory: URL
    private var fileURL: URL { directory.appending(path: "bootstrap-v1.json") }
    /// Keeps a save and the sign-out that follows it in order.
    private let queue = DispatchQueue(label: "dev.tomled.Spoiled.BootstrapCache")

    init(directory: URL) {
        self.directory = directory
    }

    /// What's saved for this user, if anything. A file that can't be read is thrown away.
    func load(userId: String) -> Entry? {
        queue.sync {
            guard let stored = try? Data(contentsOf: fileURL) else { return nil }
            guard let entry = try? JSONDecoder().decode(Entry.self, from: stored) else {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
            return entry.userId == userId ? entry : nil
        }
    }

    func save(_ data: BootstrapData, savedAt: Date = Date()) {
        let entry = Entry(userId: data.user.id, savedAt: savedAt, data: data)
        queue.async { [self] in
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try JSONEncoder().encode(entry).write(to: fileURL, options: [.atomic, .completeFileProtection])
                var url = fileURL
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try url.setResourceValues(values)
            } catch {
                // The cache only ever helps. Without it the app just needs the network.
            }
        }
    }

    func clear() {
        queue.async { [self] in
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// Waits for pending saves and clears to finish.
    func flush() {
        queue.sync {}
    }
}
