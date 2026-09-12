import Foundation
import UniformTypeIdentifiers
import LinkPresentation

/// Everything we managed to learn about whatever the user shared.
struct SharedLink {
    var url: URL?
    var title: String?
    var pageDescription: String?
    var selectionText: String?
    var priceText: String?

    var isEmpty: Bool {
        url == nil && title == nil && pageDescription == nil && selectionText == nil
    }
}

enum SharedLinkParser {
    /// Reads the share sheet's payload. Handles three shapes:
    /// Safari's JavaScript preprocessing results, a plain URL from any other app, and
    /// plain text (which may itself contain a URL).
    static func parse(_ items: [NSExtensionItem]) async -> SharedLink {
        var link = SharedLink()

        for item in items {
            if let text = item.attributedContentText?.string, !text.isEmpty {
                apply(text: text, to: &link)
            }

            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                    if let value = await load(provider, type: UTType.propertyList.identifier) as? [String: Any],
                       let results = value[NSExtensionJavaScriptPreprocessingResultsKey] as? [String: Any] {
                        apply(javaScriptResults: results, to: &link)
                    }
                }

                if link.url == nil, provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    if let url = await load(provider, type: UTType.url.identifier) as? URL {
                        link.url = url
                    }
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    if let text = await load(provider, type: UTType.plainText.identifier) as? String {
                        apply(text: text, to: &link)
                    }
                }
            }
        }

        return link
    }

    /// Last resort for shares that carry only a URL: ask LinkPresentation for the page title.
    static func fetchTitle(for url: URL, timeout: TimeInterval = 8) async -> String? {
        let provider = LPMetadataProvider()
        provider.timeout = timeout
        let metadata: LPLinkMetadata? = await withCheckedContinuation { continuation in
            provider.startFetchingMetadata(for: url) { metadata, _ in
                continuation.resume(returning: metadata)
            }
        }
        guard let title = metadata?.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return nil
        }
        return title
    }

    // MARK: - Helpers

    private static func load(_ provider: NSItemProvider, type: String) async -> Any? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { value, _ in
                continuation.resume(returning: value)
            }
        }
    }

    private static func apply(javaScriptResults results: [String: Any], to link: inout SharedLink) {
        if link.url == nil, let raw = results["url"] as? String { link.url = URL(string: raw) }
        if let value = nonEmpty(results["title"]) { link.title = value }
        if let value = nonEmpty(results["description"]) { link.pageDescription = value }
        if let value = nonEmpty(results["selection"]) { link.selectionText = value }
        if let value = nonEmpty(results["price"]) { link.priceText = value }
    }

    /// Plain text shares are ambiguous: they can be a bare URL, a selection, or a title
    /// with a trailing URL. Pull out the first URL and keep the rest as the selection.
    private static func apply(text: String, to link: inout SharedLink) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var remainder = trimmed
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            if let match = detector.firstMatch(in: trimmed, options: [], range: range), let matched = match.url {
                if link.url == nil { link.url = matched }
                if let swiftRange = Range(match.range, in: trimmed) {
                    remainder = trimmed.replacingCharacters(in: swiftRange, with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        guard !remainder.isEmpty else { return }
        if link.selectionText == nil { link.selectionText = remainder }
        if link.title == nil, remainder.count <= 140, !remainder.contains("\n") { link.title = remainder }
    }

    private static func nonEmpty(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
