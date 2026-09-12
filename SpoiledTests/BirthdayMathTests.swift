import Testing
import Foundation
@testable import Spoiled

struct BirthdayMathTests {

    private let cal = Calendar.current

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        cal.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func birthdayTodayIsZeroDaysAway() {
        let now = date(2026, 6, 15)
        #expect(daysUntilNextBirthday(from: date(1990, 6, 15), relativeTo: now) == 0)
    }

    @Test func birthdayTomorrowIsOneDayAway() {
        let now = date(2026, 6, 15)
        #expect(daysUntilNextBirthday(from: date(1990, 6, 16), relativeTo: now) == 1)
    }

    @Test func birthdayYesterdayRollsToNextYear() {
        let now = date(2026, 6, 15)
        let days = daysUntilNextBirthday(from: date(1990, 6, 14), relativeTo: now)
        #expect(days == 364)  // 2027 is not a leap year
        #expect(nextBirthdayDate(from: date(1990, 6, 14), relativeTo: now) == date(2027, 6, 14))
    }

    @Test func timeOfDayInTheBirthdateIsIgnored() {
        let now = date(2026, 6, 15)
        let birthdateLate = cal.date(from: DateComponents(
            year: 1990, month: 6, day: 20, hour: 23, minute: 59
        ))!
        #expect(daysUntilNextBirthday(from: birthdateLate, relativeTo: now) == 5)
    }

    @Test func nextBirthdayIsLocalMidnight() {
        let now = date(2026, 6, 15)
        let next = nextBirthdayDate(from: date(1990, 8, 3), relativeTo: now)
        #expect(next == cal.startOfDay(for: next))
        #expect(next == date(2026, 8, 3))
    }

    /// Feb 29 has no counterpart in a common year. `Calendar.date(from:)` normalizes the
    /// out-of-range day forward, so the birthday lands on March 1 rather than Feb 28.
    /// Pinned here so the choice is deliberate rather than incidental.
    @Test func leapDayBirthdayRollsForwardToMarchFirstInCommonYears() {
        let now = date(2027, 1, 10)   // 2027 is not a leap year
        #expect(nextBirthdayDate(from: date(2000, 2, 29), relativeTo: now) == date(2027, 3, 1))
    }

    @Test func leapDayBirthdayLandsOnFebruary29InLeapYears() {
        let now = date(2028, 1, 10)   // 2028 is a leap year
        #expect(nextBirthdayDate(from: date(2000, 2, 29), relativeTo: now) == date(2028, 2, 29))
    }

    @Test func dayCountIsNeverNegative() {
        let now = date(2026, 12, 31)
        #expect(daysUntilNextBirthday(from: date(1990, 1, 1), relativeTo: now) == 1)
    }
}
