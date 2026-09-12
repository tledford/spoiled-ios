import Testing
import Foundation
@testable import Spoiled

struct BirthdayRosterTests {

    private let cal = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func group(_ name: String = "Family", members: [GroupMember]) -> Group {
        Group(id: UUID(), name: name, members: members)
    }

    private func member(
        id: String,
        name: String,
        birthdate: Date?,
        kids: [GroupMemberKid] = []
    ) -> GroupMember {
        GroupMember(id: id, name: name, kids: kids, birthdate: birthdate)
    }

    @Test func excludesTheCurrentUser() {
        let people = BirthdayRoster.people(
            currentUserId: "me",
            groups: [group(members: [
                member(id: "me", name: "Tommy", birthdate: date(1985, 4, 2)),
                member(id: "other", name: "Jamie", birthdate: date(1987, 9, 9))
            ])],
            kids: nil
        )
        #expect(people.map(\.name) == ["Jamie"])
    }

    @Test func skipsMembersWithNoBirthdate() {
        let people = BirthdayRoster.people(
            currentUserId: "me",
            groups: [group(members: [
                member(id: "a", name: "Ada", birthdate: nil),
                member(id: "b", name: "Ben", birthdate: date(1990, 1, 1))
            ])],
            kids: nil
        )
        #expect(people.map(\.name) == ["Ben"])
    }

    @Test func deduplicatesAMemberWhoIsInTwoGroups() {
        let jamie = member(id: "jamie", name: "Jamie", birthdate: date(1987, 9, 9))
        let people = BirthdayRoster.people(
            currentUserId: "me",
            groups: [group("Family", members: [jamie]), group("Friends", members: [jamie])],
            kids: nil
        )
        #expect(people.count == 1)
        #expect(people[0].id == "jamie")
    }

    @Test func includesGroupMemberKidsThatHaveABirthdate() {
        let kidWithBirthdate = GroupMemberKid(id: UUID(), name: "Rowan", birthdate: date(2015, 3, 4))
        let kidWithout = GroupMemberKid(id: UUID(), name: "Sky", birthdate: nil)
        let people = BirthdayRoster.people(
            currentUserId: "me",
            groups: [group(members: [
                member(id: "jamie", name: "Jamie", birthdate: nil, kids: [kidWithBirthdate, kidWithout])
            ])],
            kids: nil
        )
        #expect(people.map(\.name) == ["Rowan"])
        #expect(people[0].id == "kid-\(kidWithBirthdate.id)")
    }

    @Test func includesTheUsersOwnKids() {
        let kid = Kid(name: "Quinn", birthdate: date(2018, 7, 12))
        let people = BirthdayRoster.people(currentUserId: "me", groups: nil, kids: [kid])
        #expect(people.map(\.name) == ["Quinn"])
        #expect(people[0].birthdate == date(2018, 7, 12))
    }

    @Test func doesNotListAKidTwiceWhenItAppearsAsBothOwnAndGroupKid() {
        let kidId = UUID()
        let ownKid = Kid(id: kidId, name: "Quinn", birthdate: date(2018, 7, 12))
        let sameKidViaGroup = GroupMemberKid(id: kidId, name: "Quinn", birthdate: date(2018, 7, 12))
        let people = BirthdayRoster.people(
            currentUserId: "me",
            groups: [group(members: [
                member(id: "jamie", name: "Jamie", birthdate: nil, kids: [sameKidViaGroup])
            ])],
            kids: [ownKid]
        )
        #expect(people.count == 1)
    }

    @Test func emptyInputProducesNoPeople() {
        #expect(BirthdayRoster.people(currentUserId: nil, groups: nil, kids: nil).isEmpty)
    }
}
