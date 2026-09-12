import Foundation

enum PersonSuggestions {
    /// Names worth offering when the user types who a gift idea is for: everyone they have
    /// already saved an idea for, plus their group members and those members' kids.
    static func names(currentUserId: String, groups: [Group], giftIdeas: [GiftIdea]) -> [String] {
        var people = Set<String>()
        for idea in giftIdeas where !idea.personName.isEmpty {
            people.insert(idea.personName)
        }
        for group in groups {
            for member in group.members {
                if !member.name.isEmpty, member.id != currentUserId {
                    people.insert(member.name)
                }
                for kid in member.kids where !kid.name.isEmpty {
                    people.insert(kid.name)
                }
            }
        }
        return people.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
