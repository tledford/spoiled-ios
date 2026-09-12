import Foundation
import UserNotifications
import os

// MARK: - PlannedNotification
/// One reminder the scheduler intends to post. Built purely from data so it can be
/// unit-tested without touching `UNUserNotificationCenter`.
struct PlannedNotification: Equatable {
    let identifier: String
    let title: String
    let body: String?
    /// When the reminder should fire, local time.
    let fireDate: Date
}

// MARK: - BirthdayNotificationScheduler
enum BirthdayNotificationScheduler {
    /// Reminders fire at this local time on the day they are due.
    static let fireHour = 9
    static let fireMinute = 17

    /// Birthdays further out than this are not scheduled yet; a reschedule happens on
    /// every foreground, so they get picked up well before they matter.
    static let horizonDays = 150

    /// iOS keeps at most 64 pending requests per app and silently drops the rest.
    /// Stay under it with headroom, keeping the soonest reminders.
    static let maxScheduled = 60

    /// Identifier prefix, so a reschedule only clears reminders this feature owns.
    static let identifierPrefix = "birthday."

    private static let logger = Logger(subsystem: "Spoiled", category: "BirthdayNotifications")

    private static func elog(_ message: String) {
        #if DEBUG
        logger.error("\(message)")
        #endif
    }

    // MARK: Planning (pure)

    /// Build every reminder that should be pending right now, soonest first.
    static func plannedNotifications(
        for people: [BirthdayPerson],
        leadTimes: Set<BirthdayLeadTime>,
        now: Date = Date()
    ) -> [PlannedNotification] {
        guard !leadTimes.isEmpty else { return [] }

        let cal = Calendar.current
        var planned: [PlannedNotification] = []

        for person in people {
            let birthday = nextBirthdayDate(from: person.birthdate, relativeTo: now)
            let daysAway = cal.dateComponents([.day], from: cal.startOfDay(for: now), to: birthday).day ?? 0
            guard daysAway <= horizonDays else { continue }

            for leadTime in leadTimes {
                guard let day = cal.date(byAdding: .day, value: -leadTime.rawValue, to: birthday),
                      let fireDate = cal.date(
                          bySettingHour: fireHour, minute: fireMinute, second: 0, of: day
                      ) else { continue }
                // A lead time that has already gone by this year is simply skipped.
                guard fireDate > now else { continue }

                planned.append(
                    PlannedNotification(
                        identifier: "\(identifierPrefix)\(person.id).\(leadTime.rawValue)",
                        title: leadTime.title(for: person.name),
                        body: leadTime.body,
                        fireDate: fireDate
                    )
                )
            }
        }

        // Soonest first, so the cap only ever drops the most distant reminders.
        // Identifier breaks ties to keep the output stable for equal fire dates.
        planned.sort {
            $0.fireDate == $1.fireDate ? $0.identifier < $1.identifier : $0.fireDate < $1.fireDate
        }
        return Array(planned.prefix(maxScheduled))
    }

    // MARK: Scheduling (side-effecting)

    /// Current system authorization status.
    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Ask iOS for permission. Returns whether it was granted.
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            elog("Notification authorization failed: \(error)")
            return false
        }
    }

    /// Replace all pending birthday reminders with a freshly computed set.
    /// No-op unless the user has actually authorized notifications.
    static func reschedule(people: [BirthdayPerson], leadTimes: Set<BirthdayLeadTime>) async {
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else {
            await cancelAll()
            return
        }

        await cancelAll()

        let center = UNUserNotificationCenter.current()
        let cal = Calendar.current
        for plan in plannedNotifications(for: people, leadTimes: leadTimes) {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            if let body = plan.body { content.body = body }
            content.sound = .default

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: plan.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: plan.identifier, content: content, trigger: trigger)
            do {
                try await center.add(request)
            } catch {
                elog("Failed to schedule \(plan.identifier): \(error)")
            }
        }
    }

    /// Remove every pending reminder this feature owns, leaving anything else alone.
    static func cancelAll() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        guard !ours.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: ours)
    }
}
