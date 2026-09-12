import Foundation

// Shared birthday date math. Used by the Home screen, the groups list, the kid list,
// and the local-notification scheduler — they must all agree on when a birthday lands.

/// The next occurrence of `birthdate`'s month/day, at local midnight.
/// Returns today when the birthday is today.
func nextBirthdayDate(from birthdate: Date, relativeTo now: Date = Date()) -> Date {
    let cal = Calendar.current
    var comps = cal.dateComponents([.month, .day], from: birthdate)
    let currentYear = cal.component(.year, from: now)
    comps.year = currentYear
    let thisYear = cal.date(from: comps) ?? now
    if thisYear >= cal.startOfDay(for: now) { return thisYear }
    comps.year = currentYear + 1
    return cal.date(from: comps) ?? thisYear
}

/// Whole days from today until the next occurrence of `birthdate`. 0 when it is today.
func daysUntilNextBirthday(from birthdate: Date, relativeTo now: Date = Date()) -> Int {
    let cal = Calendar.current
    let start = cal.startOfDay(for: now)
    let next = nextBirthdayDate(from: birthdate, relativeTo: start)
    let days = cal.dateComponents([.day], from: start, to: next).day ?? 0
    return max(0, days)
}
