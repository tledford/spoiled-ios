import Foundation

/// One person whose birthday the app tracks.
struct BirthdayPerson: Identifiable, Hashable {
    /// A group member's Firebase UID, or `"kid-<uuid>"` for a kid.
    let id: String
    let name: String
    let birthdate: Date
}

enum BirthdayRoster {
    /// Everyone whose birthday the user should see: their group members, those members'
    /// kids, and their own kids. The current user is excluded — the app never reminds you
    /// about your own birthday.
    ///
    /// Members and member kids only appear when the server gave us a birthdate; the user's
    /// own kids always have one.
    static func people(currentUserId: String?, groups: [Group]?, kids: [Kid]?) -> [BirthdayPerson] {
        var people: [BirthdayPerson] = []
        var seenIds = Set<String>()

        // Group members, deduplicated across groups.
        for group in groups ?? [] {
            for member in group.members {
                guard member.id != currentUserId,
                      let birthdate = member.birthdate,
                      !seenIds.contains(member.id) else { continue }
                seenIds.insert(member.id)
                people.append(BirthdayPerson(id: member.id, name: member.name, birthdate: birthdate))
            }
        }

        // Kids of group members.
        for group in groups ?? [] {
            for member in group.members {
                for kid in member.kids {
                    let key = "kid-\(kid.id)"
                    guard let birthdate = kid.birthdate, !seenIds.contains(key) else { continue }
                    seenIds.insert(key)
                    people.append(BirthdayPerson(id: key, name: kid.name, birthdate: birthdate))
                }
            }
        }

        // The user's own kids.
        for kid in kids ?? [] {
            let key = "kid-\(kid.id)"
            guard !seenIds.contains(key) else { continue }
            seenIds.insert(key)
            people.append(BirthdayPerson(id: key, name: kid.name, birthdate: kid.birthdate))
        }

        return people
    }
}
