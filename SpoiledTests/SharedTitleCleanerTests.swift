import Testing
import Foundation
@testable import Spoiled

struct SharedTitleCleanerTests {

    @Test func stripsTrailingSiteName() {
        let cleaned = SharedTitleCleaner.clean("LEGO Botanical Orchid | Target",
                                               url: URL(string: "https://www.target.com/p/lego-orchid/-/A-12345"))
        #expect(cleaned == "LEGO Botanical Orchid")
    }

    @Test func stripsStorePrefixAndTrailingCategory() {
        let cleaned = SharedTitleCleaner.clean("Amazon.com: LEGO Icons Orchid 10311 : Toys & Games",
                                               url: URL(string: "https://www.amazon.com/dp/B09XYZ"))
        #expect(cleaned == "LEGO Icons Orchid 10311")
    }

    @Test func keepsTitlesThatDoNotMentionTheSite() {
        let cleaned = SharedTitleCleaner.clean("Hario V60 Ceramic Dripper - Size 02",
                                               url: URL(string: "https://example.com/v60"))
        #expect(cleaned == "Hario V60 Ceramic Dripper - Size 02")
    }

    @Test func collapsesWhitespaceAndDecodesEntities() {
        let cleaned = SharedTitleCleaner.clean("Salt &amp;\n   Pepper   Grinder", url: nil)
        #expect(cleaned == "Salt & Pepper Grinder")
    }

    @Test func truncatesOnAWordBoundary() {
        let long = String(repeating: "word ", count: 60).trimmingCharacters(in: .whitespaces)
        let cleaned = SharedTitleCleaner.clean(long, url: nil)
        #expect(cleaned.count <= 120)
        #expect(!cleaned.hasSuffix(" "))
        #expect(cleaned.hasPrefix("word word"))
    }

    @Test func handlesTitleThatIsOnlyTheSiteName() {
        let cleaned = SharedTitleCleaner.clean("Best Buy", url: URL(string: "https://www.bestbuy.com"))
        #expect(cleaned == "Best Buy")
    }
}
