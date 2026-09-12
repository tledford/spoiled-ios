import Testing
import Foundation
@testable import Spoiled

struct BirthdayNotificationSchedulerTests {

    private let cal = Calendar.current
    private let allLeadTimes = Set(BirthdayLeadTime.allCases)

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// A birthday `days` from `now`, expressed as a birthdate in a past year.
    private func person(_ name: String, daysFromNow days: Int, now: Date) -> BirthdayPerson {
        let target = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: now))!
        var comps = cal.dateComponents([.month, .day], from: target)
        comps.year = 1990
        return BirthdayPerson(id: name, name: name, birthdate: cal.date(from: comps)!)
    }

    @Test func schedulesEveryEnabledLeadTimeForADistantBirthday() {
        let now = date(2026, 1, 1)
        let plans = BirthdayNotificationScheduler.plannedNotifications(
            for: [person("Ada", daysFromNow: 100, now: now)],
            leadTimes: allLeadTimes,
            now: now
        )
        #expect(plans.count == 4)
    }

    @Test func dropsLeadTimesThatHaveAlreadyPassed() {
        let now = date(2026, 1, 1)
        // Birthday in 3 days: the 7- and 30-day reminders are already behind us.
        let plans = BirthdayNotificationScheduler.plannedNotifications(
            for: [person("Ada", daysFromNow: 3, now: now)],
            leadTimes: allLeadTimes,
            now: now
        )
        #expect(plans.count == 2)
        #expect(plans.allSatisfy { $0.fireDate > now })
    }

    @Test func skipsBirthdaysBeyondTheHorizon() {
        let now = date(2026, 1, 1)
        let far = BirthdayNotificationScheduler.horizonDays + 10
        let plans = BirthdayNotificationScheduler.plannedNotifications(
            for: [person("Ada", daysFromNow: far, now: now)],
            leadTimes: allLeadTimes,
            now: now
        )
        #expect(plans.isEmpty)
    }

    @Test func firesAtNineSeventeenLocal() {
        let now = date(2026, 1, 1)
        let plans = BirthdayNotificationScheduler.plannedNotifications(
            for: [person("Ada", daysFromNow: 100, now: now)],
            leadTimes: [.dayOf],
            now: now
        )
        let comps = cal.dateComponents([.hour, .minute], from: plans[0].fireDate)
        #expect(comps.hour == BirthdayNotificationScheduler.fireHour)
        #expect(comps.minute == BirthdayNotificationScheduler.fireMinute)
    }

    @Test func outputIsSortedSoonestFirst() {
        let now = date(2026, 1, 1)
        let people = [
            person("Far", daysFromNow: 120, now: now),
            person("Near", daysFromNow: 10, now: now),
            person("Middle", daysFromNow: 60, now: now)
        ]
        let plans = BirthdayNotificationScheduler.plannedNotifications(
            for: people, leadTimes: allLeadTimes, now: now
        )
        #expect(plans == plans.sorted { $0.fireDate < $1.fireDate })
    }

    @Test func capsAtTheScheduleLimitKeepingTheSoonest() {
        let now = date(2026, 1, 1)
        // 40 people x 4 lead times = 160 candidates, well past the cap.
        let people = (0..<40).map { person("P\($0)", daysFromNow: 40 + $0, now: now) }
        let plans = BirthdayNotificationScheduler.plannedNotifications(
            for: people, leadTimes: allLeadTimes, now: now
        )
        #expect(plans.count == BirthdayNotificationScheduler.maxScheduled)

        // Nothing kept may fire later than something that was dropped. Compared as an
        // inequality rather than an exact set, because many candidates share a fire date
        // and which member of a tied group survives the cap is not meaningful.
        let kept = Set(plans.map(\.identifier))
        let allCandidates = people.flatMap { p in
            BirthdayNotificationScheduler.plannedNotifications(
                for: [p], leadTimes: allLeadTimes, now: now
            )
        }
        let dropped = allCandidates.filter { !kept.contains($0.identifier) }
        #expect(!dropped.isEmpty)
        #expect(plans.map(\.fireDate).max()! <= dropped.map(\.fireDate).min()!)
    }

    @Test func identifiersAreStableAcrossCalls() {
        let now = date(2026, 1, 1)
        let people = [person("Ada", daysFromNow: 50, now: now)]
        let first = BirthdayNotificationScheduler.plannedNotifications(
            for: people, leadTimes: allLeadTimes, now: now
        )
        let second = BirthdayNotificationScheduler.plannedNotifications(
            for: people, leadTimes: allLeadTimes, now: now
        )
        #expect(first.map(\.identifier) == second.map(\.identifier))
        #expect(first.allSatisfy {
            $0.identifier.hasPrefix(BirthdayNotificationScheduler.identifierPrefix)
        })
    }

    @Test func noLeadTimesMeansNothingScheduled() {
        let now = date(2026, 1, 1)
        let plans = BirthdayNotificationScheduler.plannedNotifications(
            for: [person("Ada", daysFromNow: 10, now: now)],
            leadTimes: [],
            now: now
        )
        #expect(plans.isEmpty)
    }

    @Test func titlesNameThePerson() {
        let now = date(2026, 1, 1)
        let plans = BirthdayNotificationScheduler.plannedNotifications(
            for: [person("Ada", daysFromNow: 100, now: now)],
            leadTimes: [.dayOf],
            now: now
        )
        #expect(plans[0].title.contains("Ada"))
    }
}
