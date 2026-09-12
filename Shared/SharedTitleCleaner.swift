import Foundation

/// Turns a raw page title into something that reads like a wishlist item.
///
/// Product pages routinely ship titles like
/// `Amazon.com: LEGO Botanical Collection, 10281 : Toys & Games` — the user should not have
/// to delete all of that by hand before saving.
enum SharedTitleCleaner {
    private static let separators = [" | ", " – ", " — ", " · ", " :: ", " » ", " > ", " - "]
    private static let maxLength = 120

    static func clean(_ raw: String, url: URL?) -> String {
        var title = decodeEntities(raw)
        title = title.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "" }

        let hadStorePrefix: Bool
        (title, hadStorePrefix) = stripStorePrefix(title)
        // Store-prefixed titles ("Amazon.com: <product> : <category>") also carry a trailing
        // category that is noise on a wishlist.
        if hadStorePrefix, let (head, _) = splitOnSeparator(title, " : "), !head.isEmpty {
            title = head
        }
        title = stripTrailingSiteName(title, url: url)
        title = title.trimmingCharacters(in: CharacterSet(charactersIn: " -–—|:·"))
        return truncate(title)
    }

    /// Site tokens worth matching against, e.g. `www.bestbuy.com` -> ["bestbuy"].
    static func siteTokens(for url: URL?) -> [String] {
        guard let host = url?.host?.lowercased() else { return [] }
        let labels = host.replacingOccurrences(of: "www.", with: "").split(separator: ".")
        guard let first = labels.first else { return [] }
        return [String(first), host]
    }

    /// Returns the title without a leading store name, and whether one was removed.
    private static func stripStorePrefix(_ title: String) -> (String, Bool) {
        // Amazon prefixes the store name; a few others use the same shape.
        guard let range = title.range(of: "^[A-Za-z0-9.]{3,20}\\s*:\\s*", options: .regularExpression) else {
            return (title, false)
        }
        let prefix = String(title[range]).lowercased()
        guard prefix.contains(".com") || prefix.contains(".co") else { return (title, false) }
        return (String(title[range.upperBound...]), true)
    }

    private static func stripTrailingSiteName(_ title: String, url: URL?) -> String {
        let tokens = siteTokens(for: url)
        guard !tokens.isEmpty else { return title }

        var result = title
        // Titles can carry more than one trailing segment ("… | Target | Toys").
        for _ in 0..<2 {
            guard let (head, tail) = splitOnLastSeparator(result) else { break }
            let normalizedTail = tail.lowercased().replacingOccurrences(of: " ", with: "")
            let matchesSite = tokens.contains { normalizedTail.contains($0.replacingOccurrences(of: " ", with: "")) }
            guard matchesSite, !head.trimmingCharacters(in: .whitespaces).isEmpty else { break }
            result = head
        }
        return result
    }

    private static func splitOnSeparator(_ title: String, _ separator: String) -> (String, String)? {
        guard let range = title.range(of: separator, options: .backwards) else { return nil }
        return (String(title[title.startIndex..<range.lowerBound]),
                String(title[range.upperBound...]))
    }

    private static func splitOnLastSeparator(_ title: String) -> (String, String)? {
        var best: (range: Range<String.Index>, separator: String)?
        for separator in separators {
            guard let range = title.range(of: separator, options: .backwards) else { continue }
            if best == nil || range.lowerBound > best!.range.lowerBound {
                best = (range, separator)
            }
        }
        guard let best else { return nil }
        let head = String(title[title.startIndex..<best.range.lowerBound])
        let tail = String(title[best.range.upperBound...])
        return (head, tail)
    }

    private static func truncate(_ title: String) -> String {
        guard title.count > maxLength else { return title }
        let cutoff = title.index(title.startIndex, offsetBy: maxLength)
        let head = title[title.startIndex..<cutoff]
        if let lastSpace = head.lastIndex(of: " ") {
            return String(head[head.startIndex..<lastSpace]).trimmingCharacters(in: .whitespaces)
        }
        return String(head)
    }

    private static func decodeEntities(_ string: String) -> String {
        guard string.contains("&") else { return string }
        var result = string
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                        "&#39;": "'", "&apos;": "'", "&nbsp;": " ", "&#x27;": "'"]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        return result
    }
}
