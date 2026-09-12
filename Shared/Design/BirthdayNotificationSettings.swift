import Foundation
import Combine

// MARK: - BirthdayLeadTime
/// How far ahead of a birthday a reminder fires. The raw value is the number of days.
enum BirthdayLeadTime: Int, CaseIterable, Identifiable, Hashable {
    case dayOf = 0
    case dayBefore = 1
    case week = 7
    case month = 30

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .dayOf:     return "On the day"
        case .dayBefore: return "1 day before"
        case .week:      return "1 week before"
        case .month:     return "30 days before"
        }
    }

    /// Notification title for a given person.
    func title(for name: String) -> String {
        switch self {
        case .dayOf:     return "🎂 It's \(name)'s birthday today!"
        case .dayBefore: return "\(name)'s birthday is tomorrow"
        case .week:      return "\(name)'s birthday is in a week"
        case .month:     return "\(name)'s birthday is in 30 days"
        }
    }

    /// Notification body, or nil when the title says enough.
    var body: String? {
        switch self {
        case .dayOf:     return nil
        case .dayBefore: return "Last chance to grab something."
        case .week:      return "Time to pick a gift."
        case .month:     return "Enough time to order and ship."
        }
    }
}

// MARK: - BirthdayNotificationSettings
/// Which birthday reminders the user wants, persisted to the App Group.
///
/// All four lead times are on until the user says otherwise. An absent key means
/// "never configured" and defaults to all; an empty stored array means the user turned
/// every reminder off, which must survive a relaunch.
@MainActor
final class BirthdayNotificationSettings: ObservableObject {
    private static let leadTimesKey = "birthdayLeadTimes"
    private static let primedKey = "birthdayNotificationsPrimed"

    @Published var enabledLeadTimes: Set<BirthdayLeadTime> {
        didSet {
            guard enabledLeadTimes != oldValue else { return }
            Self.store.set(enabledLeadTimes.map(\.rawValue).sorted(), forKey: Self.leadTimesKey)
        }
    }

    /// Whether the explanatory sheet has been shown. Set once, either button.
    @Published var hasPrimed: Bool {
        didSet {
            guard hasPrimed != oldValue else { return }
            Self.store.set(hasPrimed, forKey: Self.primedKey)
        }
    }

    init() {
        enabledLeadTimes = Self.loadLeadTimes()
        hasPrimed = Self.store.bool(forKey: Self.primedKey)
    }

    func isEnabled(_ leadTime: BirthdayLeadTime) -> Bool {
        enabledLeadTimes.contains(leadTime)
    }

    func setEnabled(_ enabled: Bool, for leadTime: BirthdayLeadTime) {
        if enabled {
            enabledLeadTimes.insert(leadTime)
        } else {
            enabledLeadTimes.remove(leadTime)
        }
    }

    /// App Group defaults when available, falling back to the process's own defaults.
    private nonisolated static var store: UserDefaults { SharedContainer.defaults ?? .standard }

    private nonisolated static func loadLeadTimes() -> Set<BirthdayLeadTime> {
        // No key at all means the user has never configured this — default to every reminder.
        // A stored empty array means they deliberately turned them all off.
        guard store.object(forKey: leadTimesKey) != nil,
              let raw = store.array(forKey: leadTimesKey) as? [Int] else {
            return Set(BirthdayLeadTime.allCases)
        }
        return Set(raw.compactMap(BirthdayLeadTime.init(rawValue:)))
    }
}
