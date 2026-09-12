import Testing
import Foundation
@testable import Spoiled

struct PersonSuggestionsTests {

    private func group(members: [GroupMember]) -> Group {
        Group(id: UUID(), name: "Family", members: members)
    }

    private func member(id: String, name: String, kids: [String] = []) -> GroupMember {
        GroupMember(id: id,
                    name: name,
                    kids: kids.map { GroupMemberKid(id: UUID(), name: $0) })
    }

    @Test func includesPeopleFromExistingGiftIdeas() {
        let names = PersonSuggestions.names(
            currentUserId: "me",
            groups: [],
            giftIdeas: [GiftIdea(personName: "Dana", giftName: "Socks")]
        )
        #expect(names == ["Dana"])
    }

    @Test func excludesTheCurrentUser() {
        let names = PersonSuggestions.names(
            currentUserId: "me",
            groups: [group(members: [member(id: "me", name: "Tommy"),
                                     member(id: "other", name: "Jamie")])],
            giftIdeas: []
        )
        #expect(names == ["Jamie"])
    }

    @Test func includesKidsIncludingTheCurrentUsersOwn() {
        let names = PersonSuggestions.names(
            currentUserId: "me",
            groups: [group(members: [member(id: "me", name: "Tommy", kids: ["Rowan"]),
                                     member(id: "other", name: "Jamie", kids: ["Sam"])])],
            giftIdeas: []
        )
        #expect(names == ["Jamie", "Rowan", "Sam"])
    }

    @Test func deduplicatesAndSortsCaseInsensitively() {
        let names = PersonSuggestions.names(
            currentUserId: "me",
            groups: [group(members: [member(id: "other", name: "alice")])],
            giftIdeas: [GiftIdea(personName: "Bob", giftName: "Mug"),
                        GiftIdea(personName: "alice", giftName: "Book")]
        )
        #expect(names == ["alice", "Bob"])
    }

    @Test func skipsBlankNames() {
        let names = PersonSuggestions.names(
            currentUserId: "me",
            groups: [group(members: [member(id: "other", name: "", kids: [""])])],
            giftIdeas: [GiftIdea(personName: "", giftName: "Nothing")]
        )
        #expect(names.isEmpty)
    }

    @Test func returnsEmptyWhenThereIsNothingToSuggest() {
        #expect(PersonSuggestions.names(currentUserId: "me", groups: [], giftIdeas: []).isEmpty)
    }
}
