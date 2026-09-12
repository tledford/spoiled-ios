import Foundation
import Combine
import UserNotifications

/// Owns the birthday-reminder side effect in one place.
///
/// The roster and the user's lead-time choices both live elsewhere; this watches both and
/// reschedules when either moves. The debounce matters: `WishlistViewModel.load()` runs on
/// sign-in, on every foreground, on a five-minute timer, and after every mutation, so the
/// published collections churn constantly.
@MainActor
final class BirthdayNotificationCoordinator: ObservableObject {
    /// Mirrors the system authorization status so Settings can explain itself.
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private var cancellables = Set<AnyCancellable>()
    private weak var viewModel: WishlistViewModel?
    private weak var settings: BirthdayNotificationSettings?

    /// Begin watching the roster and the user's preferences. Safe to call more than once.
    func attach(viewModel: WishlistViewModel, settings: BirthdayNotificationSettings) {
        guard cancellables.isEmpty else { return }
        self.viewModel = viewModel
        self.settings = settings

        let roster = Publishers.CombineLatest3(
            viewModel.$currentUser,
            viewModel.$groups,
            viewModel.$kids
        )
        .map { _, _, _ in () }

        Publishers.CombineLatest(roster, settings.$enabledLeadTimes)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                Task { await self?.rescheduleNow() }
            }
            .store(in: &cancellables)

        Task { await refreshAuthorizationStatus() }
    }

    /// Re-read the system status — call after returning from iOS Settings.
    func refreshAuthorizationStatus() async {
        authorizationStatus = await BirthdayNotificationScheduler.authorizationStatus()
    }

    /// Whether the explanatory sheet should be presented right now.
    func shouldPrime(hasLoadedUser: Bool, hasPrimed: Bool) -> Bool {
        hasLoadedUser && !hasPrimed && authorizationStatus == .notDetermined
    }

    /// Raise the system prompt, then schedule if the user said yes.
    func requestAuthorizationAndSchedule() async -> Bool {
        AnalyticsEvents.notificationPermissionPrompted()
        let granted = await BirthdayNotificationScheduler.requestAuthorization()
        AnalyticsEvents.notificationPermissionResult(granted: granted)
        await refreshAuthorizationStatus()
        if granted { await rescheduleNow() }
        return granted
    }

    /// Rebuild the pending reminders from current state.
    func rescheduleNow() async {
        guard let viewModel, let settings else { return }
        let people = BirthdayRoster.people(
            currentUserId: viewModel.currentUser?.id,
            groups: viewModel.groups,
            kids: viewModel.kids
        )
        await BirthdayNotificationScheduler.reschedule(
            people: people,
            leadTimes: settings.enabledLeadTimes
        )
    }

    /// Drop every pending reminder. Called on sign-out — the view model keeps the previous
    /// user's roster in memory, so without this their reminders would keep firing.
    func cancelAll() async {
        await BirthdayNotificationScheduler.cancelAll()
    }
}
