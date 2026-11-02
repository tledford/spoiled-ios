import Foundation
import SwiftUI
import OSLog
import Combine
import FirebaseAnalytics
import FirebaseCrashlytics

@MainActor
class WishlistViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var kids: [Kid]?
    @Published var groups: [Group]?
    @Published var wishlistItems: [WishlistItem]?
    @Published var giftIdeas: [GiftIdea]?
    @Published var groupInvitations: [GroupInvitation] = []
    @Published var removedPurchases: [RemovedPurchase] = []
    /// A brand-new account, which needs to finish its profile.
    @Published var needsProfileSetup = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    /// Why the most recent load failed. Cleared by the next success. Saves report through `errorMessage` instead.
    @Published private(set) var loadFailure: LoadFailure?
    /// When the data on screen came from the server, which may be from an earlier session's cache.
    @Published private(set) var lastLoadedAt: Date?
    @Published private var consecutiveLoadFailures = 0
    @Published var isSavingGiftIdea: Bool = false
    @Published var deletingGiftIdeaIds: Set<UUID> = []
    @Published var isSavingWishlistItem: Bool = false
    @Published var deletingWishlistItemIds: Set<UUID> = []
    @Published var isSavingGroup: Bool = false
    @Published var deletingGroupIds: Set<UUID> = []
    @Published var isSavingKid: Bool = false
    @Published var deletingKidIds: Set<UUID> = []

    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 5 * 60 // 5 minutes

    private var snapshotCancellable: AnyCancellable?

    private let cache: BootstrapCache
    private let connectionMonitor = ConnectionMonitor()
    /// How long to wait between automatic retries after a failed load. After the last one, the refresh timer takes over.
    private let retryDelays: [TimeInterval]
    private var retryTask: Task<Void, Never>?
    private var retryCount = 0
    /// True while the app is in front and signed in, which is the only time retrying makes sense.
    private var isAutoRefreshing = false

    /// There's data to show, but it may be out of date. One failed refresh could be a blip, so wait
    /// for a second unless the device is plainly offline.
    var showsStaleDataBanner: Bool {
        guard currentUser != nil, let loadFailure else { return false }
        return loadFailure == .offline || consecutiveLoadFailures >= 2
    }

    /// Start the auto-refresh timer. Only call when authenticated and app is active.
    func startAutoRefresh() {
        stopAutoRefresh()
        isAutoRefreshing = true
        retryCount = 0
        connectionMonitor.start { [weak self] in self?.connectionRestored() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    /// Stop the auto-refresh timer.
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        isAutoRefreshing = false
        retryTask?.cancel()
        retryTask = nil
    }

    /// The device has a connection again, so anything that failed is worth trying now.
    func connectionRestored() {
        guard isAutoRefreshing, loadFailure != nil else { return }
        retryCount = 0
        retryTask?.cancel()
        Task { await load() }
    }

    private func scheduleRetry() {
        guard isAutoRefreshing, retryCount < retryDelays.count else { return }
        let delay = retryDelays[retryCount]
        retryCount += 1
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await self?.load()
        }
    }

    /// Bumped by every load and by sign-out, so a response that's been overtaken can be ignored.
    private var loadGeneration = 0

    private let bootstrapService: BootstrapService
    private let usersService: UsersService
    private let giftIdeasService: GiftIdeasService
    private let groupsService: GroupsService
    private let kidsService: KidsService
    private let wishlistService: WishlistService

    private static let logger = Logger(subsystem: "Spoiled", category: "WishlistViewModel")

    private func dlog(_ message: String) {
        #if DEBUG
        WishlistViewModel.logger.debug("\(message)")
        #endif
    }

    private func elog(_ message: String) {
        #if DEBUG
        WishlistViewModel.logger.error("\(message)")
        #endif
    }

    init(bootstrapService: BootstrapService = BootstrapService(), usersService: UsersService = UsersService(), giftIdeasService: GiftIdeasService = GiftIdeasService(), wishlistService: WishlistService = WishlistService(), groupsService: GroupsService = GroupsService(), kidsService: KidsService = KidsService(), cache: BootstrapCache = .shared, retryDelays: [TimeInterval] = [5, 15, 30, 60]) {
        self.cache = cache
        self.retryDelays = retryDelays
        self.bootstrapService = bootstrapService
        self.usersService = usersService
        self.giftIdeasService = giftIdeasService
        self.wishlistService = wishlistService
        self.groupsService = groupsService
        self.kidsService = kidsService

        // Mirror the pieces of app state the share extension needs into the App Group so it
        // can render its form without a network round trip.
        snapshotCancellable = Publishers.CombineLatest4($currentUser, $kids, $groups, $giftIdeas)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { user, kids, groups, giftIdeas in
                guard let user else { return }
                ShareSnapshotStore.save(ShareSnapshot(user: user,
                                                      kids: kids ?? [],
                                                      groups: groups ?? [],
                                                      giftIdeas: giftIdeas ?? []))
            }
    }

    /// Names offered when picking who a gift idea is for. Mirrors what the share extension shows.
    var personSuggestions: [String] {
        guard let currentUser else { return [] }
        return PersonSuggestions.names(currentUserId: currentUser.id,
                                       groups: groups ?? [],
                                       giftIdeas: giftIdeas ?? [])
    }

    // MARK: - Reset Actions

    /// Stands in for "no cutoff" when writing the reset date back to the API, which cannot store a null.
    /// Far enough in the past that every purchase stays visible.
    private static let noPurchaseCutoff = Date(timeIntervalSince1970: 0)

    /// The cutoff in force: purchases made before it are hidden from this user's report and home
    /// screen. `nil` means the whole purchase history is showing.
    var purchaseCutoff: Date? {
        guard let cutoff = currentUser?.wishlistPurchasesResetDate, cutoff > Self.noPurchaseCutoff else { return nil }
        return cutoff
    }

    /// Whether any purchases are currently hidden by an earlier clear.
    var hasPurchaseCutoff: Bool { purchaseCutoff != nil }

    /// The oldest purchase date the report can show.
    var purchaseVisibilityStartDate: Date {
        purchaseCutoff ?? Self.noPurchaseCutoff
    }

    /// How many currently visible purchases a clear with this cutoff would hide.
    func purchasedWishlistItemCount(before cutoff: Date) -> Int {
        purchasedWishlistItems.filter { ($0.purchasedAt ?? .distantPast) < cutoff }.count
    }

    /// Hides wishlist purchases made before `cutoff` from this user's report. Defaults to hiding everything
    /// purchased so far. Does not mark anything unpurchased for other people.
    @discardableResult
    func clearWishlistPurchases(before cutoff: Date = Date()) async -> Bool {
        guard let user = currentUser else { return false }
        let hiddenCount = purchasedWishlistItemCount(before: cutoff)
        do {
            try await effectiveUsers.updateUser(
                userId: user.id,
                name: user.name,
                email: user.email,
                birthdate: user.birthdate,
                sizes: user.sizes,
                wishlistPurchasesResetDate: cutoff
            )
            // Update local state immediately
            currentUser?.wishlistPurchasesResetDate = cutoff
            AnalyticsEvents.purchasedWishlistItemsCleared(count: hiddenCount,
                                                          usedCustomCutoff: !Calendar.current.isDateInToday(cutoff))
            // Then refresh everything to be sure
            await load()
            return true
        } catch {
            elog("Failed to clear wishlist purchases: \(error)")
            AnalyticsEvents.error(code: "wishlist_purchases_clear_failed", message: error.localizedDescription, context: "clear_wishlist_purchases")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    /// Removes the cutoff entirely, bringing back every purchase ever cleared.
    @discardableResult
    func showAllPurchases() async -> Bool {
        guard let user = currentUser, hasPurchaseCutoff else { return false }
        do {
            try await effectiveUsers.updateUser(
                userId: user.id,
                name: user.name,
                email: user.email,
                birthdate: user.birthdate,
                sizes: user.sizes,
                wishlistPurchasesResetDate: Self.noPurchaseCutoff
            )
            currentUser?.wishlistPurchasesResetDate = Self.noPurchaseCutoff
            AnalyticsEvents.purchasedWishlistItemsRestored()
            await load()
            return true
        } catch {
            elog("Failed to restore hidden purchases: \(error)")
            AnalyticsEvents.error(code: "wishlist_purchases_restore_failed", message: error.localizedDescription, context: "show_all_purchases")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    // Convenience to rebuild services with an auth-backed APIClient token provider
    func configureAuth(using auth: AuthViewModel) {
        if case let .authenticated(userId) = auth.state { restoreFromCache(userId: userId) }
        configure(client: APIClient(tokenProvider: { force in try await auth.getValidIDToken(forceRefresh: force) }))
    }

    func configure(client: APIClient, startLoading: Bool = true) {
        let bs = BootstrapService(client: client)
        let us = UsersService(client: client)
        let gis = GiftIdeasService(client: client)
        let ws = WishlistService(client: client)
        let gs = GroupsService(client: client)
        let ks = KidsService(client: client)
        // Assign
        // Note: properties are let; create a new VM when wiring auth or refactor to var. We'll instead refresh via new local services usage in methods.
        // For minimal impact, we keep stored services but prefer local overrides via a small indirection helper.
        _authClientOverride = client
        _bootstrapServiceOverride = bs
        _usersServiceOverride = us
        _giftIdeasServiceOverride = gis
        _wishlistServiceOverride = ws
        _groupsServiceOverride = gs
        _kidsServiceOverride = ks

        // Now that auth is configured, kick off a fresh load
        if startLoading { Task { await self.load() } }
    }

    /// Shows the last good data straight away, if there is any for this user.
    func restoreFromCache(userId: String) {
        guard currentUser == nil, let entry = cache.load(userId: userId) else { return }
        apply(entry.data)
        lastLoadedAt = entry.savedAt
    }

    private func apply(_ data: BootstrapData) {
        currentUser = data.user
        groups = data.groups
        kids = data.kids
        wishlistItems = data.wishlistItems
        giftIdeas = data.giftIdeas
        groupInvitations = data.invitations
        removedPurchases = data.removedPurchases
    }

    /// Forgets the signed-in user, so the next account can't see any of their data. A load
    /// still in flight is abandoned rather than allowed to write it back.
    func resetForSignOut() {
        loadGeneration += 1
        retryTask?.cancel()
        retryTask = nil
        retryCount = 0
        cache.clear()
        loadFailure = nil
        lastLoadedAt = nil
        consecutiveLoadFailures = 0
        currentUser = nil
        groups = nil
        kids = nil
        wishlistItems = nil
        giftIdeas = nil
        groupInvitations = []
        removedPurchases = []
        needsProfileSetup = false
        isLoading = false
        errorMessage = nil

        _authClientOverride = nil
        _bootstrapServiceOverride = nil
        _usersServiceOverride = nil
        _giftIdeasServiceOverride = nil
        _wishlistServiceOverride = nil
        _groupsServiceOverride = nil
        _kidsServiceOverride = nil
    }

    // MARK: - Service overrides when auth is configured
    private var _authClientOverride: APIClient?
    private var _bootstrapServiceOverride: BootstrapService?
    private var _usersServiceOverride: UsersService?
    private var _giftIdeasServiceOverride: GiftIdeasService?
    private var _wishlistServiceOverride: WishlistService?
    private var _groupsServiceOverride: GroupsService?
    private var _kidsServiceOverride: KidsService?

    private var effectiveBootstrap: BootstrapService { _bootstrapServiceOverride ?? bootstrapService }
    private var effectiveUsers: UsersService { _usersServiceOverride ?? usersService }
    private var effectiveGiftIdeas: GiftIdeasService { _giftIdeasServiceOverride ?? giftIdeasService }
    private var effectiveWishlist: WishlistService { _wishlistServiceOverride ?? wishlistService }
    private var effectiveGroups: GroupsService { _groupsServiceOverride ?? groupsService }
    private var effectiveKids: KidsService { _kidsServiceOverride ?? kidsService }

    func load() async {
        // Avoid making network calls before auth/token is configured
        guard _authClientOverride != nil else { return }
//        #if DEBUG
//        dlog("Starting bootstrap request: baseURL=\(AppConfig.api.baseURL.absoluteString) path=/bootstrap userId=\(AppConfig.devUserId.uuidString)")
//        #endif
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        do {
//            #if DEBUG
//            let mockData = MockDataService.createMockData()
//            self.currentUser = mockData.currentUser
//            self.kids = mockData.kids
//            self.groups = mockData.groups
//            self.wishlistItems = mockData.wishlistItems
//            self.giftIdeas = mockData.giftIdeas
//            #else
            let (data, isNewUser) = try await effectiveBootstrap.load()
            // Before the check below: a newer load won't find the account new, because this one just created it.
            if isNewUser, !needsProfileSetup, _authClientOverride != nil {
                needsProfileSetup = true
                AnalyticsEvents.signUp(method: AnalyticsAuthProvider.last())
            }
            guard generation == loadGeneration else { return }
//            #endif
            dlog("Bootstrap success: user=\(data.user.id) groups=\(data.groups.count) kids=\(data.kids.count) myItems=\(data.wishlistItems.count) giftIdeas=\(data.giftIdeas.count)")
            apply(data)
            lastLoadedAt = Date()
            loadFailure = nil
            consecutiveLoadFailures = 0
            retryCount = 0
            cache.save(data)
        } catch {
            guard generation == loadGeneration else { return }
            if !error.isCancellation {
                elog("Bootstrap failed: \(String(describing: error))")
                recordLoadFailure(error)
                scheduleRetry()
            }
        }
        isLoading = false
        dlog("Bootstrap finished. isLoading=false")
    }

    private func recordLoadFailure(_ error: Error) {
        let failure = error.loadFailure
        loadFailure = failure
        consecutiveLoadFailures += 1
        // A long outage would otherwise report every retry.
        guard consecutiveLoadFailures == 1 else { return }
        var status = 0
        if case let APIError.http(httpStatus, _, _, _, _) = error { status = httpStatus }
        AnalyticsEvents.error(code: "bootstrap_load_failed", message: failure.rawValue, context: "load:\(status)")
        // Being offline isn't a bug in the app.
        if failure != .offline {
            Crashlytics.crashlytics().record(error: NSError(domain: "BootstrapLoadFailure", code: status, userInfo: ["category": failure.rawValue]))
        }
    }

    /// Sets how many of a group member's or kid's item the current user has bought. 0 clears their purchase.
    /// On failure the item is rolled back and `errorMessage` says why.
    func setItemPurchaseQuantity(_ item: WishlistItem, quantity: Int, groupId: UUID?, groupMemberId: String?, kidId: UUID? = nil) async -> Bool {
        guard let groupId, let currentUserId = currentUser?.id else { return false }

        let wasPurchased = item.isPurchased
        updateGroupItem(item.id, groupId: groupId, groupMemberId: groupMemberId, kidId: kidId) {
            $0.setPurchase(quantity: quantity, by: currentUserId)
        }

        do {
            let isPurchased: Bool
            let context: String
            if let kidId {
                isPurchased = try await effectiveWishlist.setGroupKidItemPurchase(groupId: groupId, kidId: kidId, itemId: item.id, quantity: quantity)
                context = "group_kid"
            } else if let groupMemberId {
                isPurchased = try await effectiveWishlist.setGroupMemberItemPurchase(groupId: groupId, memberUserId: groupMemberId, itemId: item.id, quantity: quantity)
                context = "group_member"
            } else {
                updateGroupItem(item.id, groupId: groupId, groupMemberId: groupMemberId, kidId: kidId) { $0 = item }
                return false
            }

            AnalyticsEvents.wishlistItemPurchaseQuantitySet(itemId: item.id, quantity: quantity, quantityDesired: item.quantityDesired, context: context)
            if isPurchased && !wasPurchased {
                AnalyticsEvents.wishlistItemPurchased(itemId: item.id, context: context)
            } else if !isPurchased && wasPurchased {
                AnalyticsEvents.wishlistItemUnpurchased(itemId: item.id, context: context)
            }
            await refreshAll()
            return true
        } catch {
            elog("Failed to set purchase quantity: \(String(describing: error))")
            updateGroupItem(item.id, groupId: groupId, groupMemberId: groupMemberId, kidId: kidId) { $0 = item }
            if let apiError = error as? APIError, case let .http(_, code, message, _, _) = apiError, code == "QUANTITY_EXCEEDED" {
                // Someone else got there first, so the screen is out of date.
                self.errorMessage = message
                await refreshAll()
            } else {
                self.errorMessage = error.userFacingMessage
            }
            return false
        }
    }

    /// Changes the group's copy of an item, whether it's on a member's list or one of their kids'.
    private func updateGroupItem(_ itemId: UUID, groupId: UUID, groupMemberId: String?, kidId: UUID?, change: (inout WishlistItem) -> Void) {
        guard let gi = groups?.firstIndex(where: { $0.id == groupId }) else { return }
        if let kidId {
            for mi in groups![gi].members.indices {
                if let ki = groups![gi].members[mi].kids.firstIndex(where: { $0.id == kidId }),
                   let ii = groups![gi].members[mi].kids[ki].wishlistItems.firstIndex(where: { $0.id == itemId }) {
                    change(&groups![gi].members[mi].kids[ki].wishlistItems[ii])
                    return
                }
            }
        } else if let groupMemberId,
                  let mi = groups![gi].members.firstIndex(where: { $0.id == groupMemberId }),
                  let ii = groups![gi].members[mi].wishlistItems.firstIndex(where: { $0.id == itemId }) {
            change(&groups![gi].members[mi].wishlistItems[ii])
        }
    }

    // Unified refresh entry point (can show loading spinner)
    func refreshAll() async {
        await load()
    }
    
    func addWishlistItem(_ item: WishlistItem, kidId: UUID?) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        do {
            isSavingWishlistItem = true
            defer { isSavingWishlistItem = false }
            var newItem = item
            if let kidId = kidId {
                let serverId = try await effectiveWishlist.createKidItem(userId: userId, kidId: kidId, item: item)
                if serverId != item.id {
                    newItem = WishlistItem(id: serverId, name: item.name, description: item.description, price: item.price, link: item.link, quantityDesired: item.quantityDesired, assignedGroupIds: item.assignedGroupIds)
                }
                if let kidIndex = kids?.firstIndex(where: { $0.id == kidId }) {
                    kids?[kidIndex].wishlistItems.append(newItem)
                }
                AnalyticsEvents.wishlistItemCreated(itemId: newItem.id, ownerType: "kid", hasPrice: newItem.price != nil, hasLink: newItem.link != nil, isKid: true)
            } else {
                let serverId = try await effectiveWishlist.createUserItem(userId: userId, item: item)
                if serverId != item.id {
                    newItem = WishlistItem(id: serverId, name: item.name, description: item.description, price: item.price, link: item.link, quantityDesired: item.quantityDesired, assignedGroupIds: item.assignedGroupIds)
                }
                if wishlistItems == nil { wishlistItems = [] }
                wishlistItems?.append(newItem)
                AnalyticsEvents.wishlistItemCreated(itemId: newItem.id, ownerType: "user", hasPrice: newItem.price != nil, hasLink: newItem.link != nil, isKid: false)
            }
            return true
        } catch {
            #if DEBUG
            if let apiError = error as? APIError, case let .http(status, code, message, requestId, raw) = apiError {
                WishlistViewModel.logger.error("Wishlist create failed. status=\(status) code=\(code) reqId=\(requestId ?? "") msg=\(message) raw=\(raw ?? "")")
            } else {
                WishlistViewModel.logger.error("Wishlist create failed: \(String(describing: error))")
            }
            #endif
            self.errorMessage = error.userFacingMessage
            return false
        }
    }
    
    func addGroup(_ group: Group) {
        Task { @MainActor in
            isSavingGroup = true
            defer { isSavingGroup = false }
            do {
                let newId = try await effectiveGroups.create(name: group.name)
                var created = group
                if newId != group.id {
                    created = Group(id: newId, name: group.name, isAdmin: true, members: [])
                }
                if groups == nil { groups = [] }
                groups?.append(created)
                AnalyticsEvents.groupCreated(groupId: created.id)
            } catch {
                self.errorMessage = error.userFacingMessage
            }
        }
    }
    
    func updateWishlistItem(item: WishlistItem, name: String, description: String, link: URL?, quantityDesired: Int, assignedGroupIds: [UUID], kidId: UUID?) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        var updated = item
        updated.name = name
        updated.description = description
        updated.link = link
        updated.quantityDesired = quantityDesired
        updated.assignedGroupIds = assignedGroupIds
        do {
            isSavingWishlistItem = true
            defer { isSavingWishlistItem = false }
            if let kidId = kidId {
                try await effectiveWishlist.updateKidItem(userId: userId, kidId: kidId, item: updated)
                if let kidIndex = kids?.firstIndex(where: { $0.id == kidId }),
                   let index = kids?[kidIndex].wishlistItems.firstIndex(where: { $0.id == item.id }) {
                    kids?[kidIndex].wishlistItems[index] = updated
                }
                AnalyticsEvents.wishlistItemUpdated(itemId: updated.id, ownerType: "kid", hasPrice: updated.price != nil, hasLink: updated.link != nil, isKid: true)
            } else {
                try await effectiveWishlist.updateUserItem(userId: userId, item: updated)
                if let index = wishlistItems?.firstIndex(where: { $0.id == item.id }) {
                    wishlistItems?[index] = updated
                }
                AnalyticsEvents.wishlistItemUpdated(itemId: updated.id, ownerType: "user", hasPrice: updated.price != nil, hasLink: updated.link != nil, isKid: false)
            }
            return true
        } catch {
            AnalyticsEvents.error(code: "wishlist_update_failed", message: error.localizedDescription, context: "update_wishlist_item")
            #if DEBUG
            if let apiError = error as? APIError, case let .http(status, code, message, requestId, raw) = apiError {
                WishlistViewModel.logger.error("Wishlist update failed. status=\(status) code=\(code) reqId=\(requestId ?? "") msg=\(message) raw=\(raw ?? "")")
            } else {
                WishlistViewModel.logger.error("Wishlist update failed: \(String(describing: error))")
            }
            #endif
            self.errorMessage = error.userFacingMessage
            return false
        }
    }
    
    func addGiftIdea(_ giftIdea: GiftIdea) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        do {
            isSavingGiftIdea = true
            defer { isSavingGiftIdea = false }
            // Ensure local array exists
            if giftIdeas == nil { giftIdeas = [] }
            let serverId = try await effectiveGiftIdeas.create(userId: userId, idea: giftIdea)
            var ideaToInsert = giftIdea
            if serverId != giftIdea.id {
                // Rebuild with server id to keep in sync
                ideaToInsert = GiftIdea(id: serverId,
                                        personName: giftIdea.personName,
                                        giftName: giftIdea.giftName,
                                        url: giftIdea.url,
                                        notes: giftIdea.notes,
                                        isPurchased: giftIdea.isPurchased)
            }
            giftIdeas?.append(ideaToInsert)
            AnalyticsEvents.giftIdeaCreated(ideaId: ideaToInsert.id, hasUrl: ideaToInsert.url != nil)
            return true
        } catch {
            #if DEBUG
            if let apiError = error as? APIError, case let .http(status, code, message, requestId, raw) = apiError {
                WishlistViewModel.logger.error("Gift idea create failed. status=\(status) code=\(code) reqId=\(requestId ?? "") msg=\(message) raw=\(raw ?? "")")
            } else {
                WishlistViewModel.logger.error("Gift idea create failed: \(String(describing: error))")
            }
            #endif
            self.errorMessage = error.userFacingMessage
            return false
        }
    }
    
    func updateGiftIdea(_ giftIdea: GiftIdea) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        do {
            isSavingGiftIdea = true
            defer { isSavingGiftIdea = false }
            try await effectiveGiftIdeas.update(userId: userId, idea: giftIdea)
            if let index = giftIdeas?.firstIndex(where: { $0.id == giftIdea.id }) {
                giftIdeas?[index] = giftIdea
            }
            AnalyticsEvents.giftIdeaUpdated(ideaId: giftIdea.id, hasUrl: giftIdea.url != nil)
        return true
        } catch {
            AnalyticsEvents.error(code: "gift_idea_update_failed", message: error.localizedDescription, context: "update_gift_idea")
            self.errorMessage = error.userFacingMessage
        return false
        }
    }

    func toggleGiftIdeaPurchased(_ idea: GiftIdea) async {
        guard let userId = currentUser?.id else { return }
        guard let idx = giftIdeas?.firstIndex(where: { $0.id == idea.id }) else { return }
        var updated = idea
        updated.isPurchased.toggle()
        // Optimistic update
        giftIdeas?[idx] = updated
        do {
            try await effectiveGiftIdeas.update(userId: userId, idea: updated)
        } catch {
            // Roll back on failure
            giftIdeas?[idx] = idea
            await MainActor.run { self.errorMessage = error.userFacingMessage }
            return
        }
        if updated.isPurchased {
            AnalyticsEvents.wishlistItemPurchased(itemId: updated.id, context: "gift_idea")
        } else {
            AnalyticsEvents.wishlistItemUnpurchased(itemId: updated.id, context: "gift_idea")
        }
    }

    func deleteGiftIdea(_ giftIdea: GiftIdea) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        do {
            deletingGiftIdeaIds.insert(giftIdea.id)
            defer { deletingGiftIdeaIds.remove(giftIdea.id) }
            try await effectiveGiftIdeas.delete(userId: userId, ideaId: giftIdea.id)
            giftIdeas?.removeAll(where: { $0.id == giftIdea.id })
            AnalyticsEvents.giftIdeaDeleted(ideaId: giftIdea.id)
        return true
        } catch {
            AnalyticsEvents.error(code: "gift_idea_delete_failed", message: error.localizedDescription, context: "delete_gift_idea")
            self.errorMessage = error.userFacingMessage
        return false
        }
    }

    /// Deletes all purchased gift ideas for the current user.
    /// Returns a tuple of (deleted count, failed count).
    func deletePurchasedGiftIdeas() async -> (deleted: Int, failed: Int) {
        guard let userId = currentUser?.id else { return (0, 0) }
        let purchased = (giftIdeas ?? []).filter { $0.isPurchased }
        guard !purchased.isEmpty else { return (0, 0) }

        var deletedCount = 0
        var failedCount = 0

        for idea in purchased {
            do {
                try await effectiveGiftIdeas.delete(userId: userId, ideaId: idea.id)
                giftIdeas?.removeAll(where: { $0.id == idea.id })
                AnalyticsEvents.giftIdeaDeleted(ideaId: idea.id)
                deletedCount += 1
            } catch {
                elog("Failed to delete purchased gift idea \(idea.id): \(error)")
                failedCount += 1
            }
        }

        if deletedCount > 0 {
            AnalyticsEvents.purchasedGiftIdeasCleared(count: deletedCount)
        }

        return (deletedCount, failedCount)
    }
    
    func deleteWishlistItem(_ item: WishlistItem, kidId: UUID?) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        do {
            deletingWishlistItemIds.insert(item.id)
            defer { deletingWishlistItemIds.remove(item.id) }
            if let kidId = kidId {
                try await effectiveWishlist.deleteKidItem(userId: userId, kidId: kidId, itemId: item.id)
                if let kidIndex = kids?.firstIndex(where: { $0.id == kidId }) {
                    kids?[kidIndex].wishlistItems.removeAll(where: { $0.id == item.id })
                }
                AnalyticsEvents.wishlistItemDeleted(itemId: item.id, ownerType: "kid", isKid: true)
            } else {
                try await effectiveWishlist.deleteUserItem(userId: userId, itemId: item.id)
                wishlistItems?.removeAll(where: { $0.id == item.id })
                AnalyticsEvents.wishlistItemDeleted(itemId: item.id, ownerType: "user", isKid: false)
            }
            return true
        } catch {
            AnalyticsEvents.error(code: "wishlist_delete_failed", message: error.localizedDescription, context: "delete_wishlist_item")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    func saveProfile(name: String, email: String, birthdate: Date, sizes: Sizes) async throws {
        guard let userId = currentUser?.id else { return }
        try await effectiveUsers.updateUser(
            userId: userId,
            name: name,
            email: email,
            birthdate: birthdate,
            sizes: sizes,
            wishlistPurchasesResetDate: currentUser?.wishlistPurchasesResetDate
        )
        // Update local state after successful save
        var updated = currentUser
        updated?.name = name
        updated?.email = email
        updated?.birthdate = birthdate
        updated?.sizes = sizes
        currentUser = updated
        AnalyticsEvents.profileUpdated()
    }
    
    func updateGroup(_ group: Group, newName: String) async -> Bool {
        isSavingGroup = true
        defer { isSavingGroup = false }
        do {
            try await effectiveGroups.rename(groupId: group.id, name: newName)
            if let index = groups?.firstIndex(where: { $0.id == group.id }) {
                groups?[index].name = newName
            }
            AnalyticsEvents.groupUpdated(groupId: group.id)
            return true
        } catch {
            AnalyticsEvents.error(code: "group_update_failed", message: error.localizedDescription, context: "rename_group")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }
    
    func removeMemberFromGroup(_ member: GroupMember, from group: Group) async -> Bool {
        do {
            try await effectiveGroups.removeMember(groupId: group.id, userId: member.id)
            if let groupIndex = groups?.firstIndex(where: { $0.id == group.id }) {
                groups?[groupIndex].members.removeAll(where: { $0.id == member.id })
            }
            return true
        } catch {
            AnalyticsEvents.error(code: "group_remove_member_failed", message: error.localizedDescription, context: "remove_member")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }
    
    /// Accepts or declines an invitation, then reloads so a joined group shows up.
    func respondToInvitation(_ invitation: GroupInvitation, accept: Bool) async -> Bool {
        do {
            try await effectiveGroups.respondToInvitation(id: invitation.id, accept: accept)
            AnalyticsEvents.groupInvitationAnswered(groupId: invitation.groupId, accepted: accept)
            await load()
            return true
        } catch {
            AnalyticsEvents.error(code: "group_invitation_answer_failed", message: error.localizedDescription, context: "respond_to_invitation")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    /// What a code leads to, or nil with `errorMessage` set. Nobody joins anything yet.
    func previewInviteCode(_ code: String) async -> InviteCodePreview? {
        do {
            return try await effectiveGroups.previewInviteCode(Self.tidied(code: code))
        } catch {
            self.errorMessage = error.userFacingMessage
            return nil
        }
    }

    func joinGroup(code: String) async -> Bool {
        do {
            try await effectiveGroups.acceptInviteCode(Self.tidied(code: code))
            AnalyticsEvents.groupJoinedWithCode()
            await load()
            return true
        } catch {
            AnalyticsEvents.error(code: "group_join_with_code_failed", message: error.localizedDescription, context: "join_group")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    /// The group's invite code. Pass `replacing` to make the current one stop working.
    func inviteCode(for group: Group, replacing: Bool = false) async -> GroupInviteCode? {
        do {
            return try await effectiveGroups.inviteCode(groupId: group.id, replacing: replacing)
        } catch {
            AnalyticsEvents.error(code: "group_invite_code_failed", message: error.localizedDescription, context: "invite_code")
            self.errorMessage = error.userFacingMessage
            return nil
        }
    }

    func leaveGroup(_ group: Group) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        do {
            try await effectiveGroups.removeMember(groupId: group.id, userId: userId)
            groups?.removeAll(where: { $0.id == group.id })
            AnalyticsEvents.groupLeft(groupId: group.id)
            return true
        } catch {
            AnalyticsEvents.error(code: "group_leave_failed", message: error.localizedDescription, context: "leave_group")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    /// A typed code goes into a URL path, so nothing in it can be allowed to change that path.
    private static func tidied(code: String) -> String {
        code.filter { $0.isLetter || $0.isNumber }
    }

    func addMemberToGroup(email: String, to group: Group) async -> Bool {
        do {
            try await effectiveGroups.addMember(groupId: group.id, email: email)
            // Note: The API will return { ok: true, pending: true/false } to indicate if user exists
            // For now, we'll refresh to get the accurate state rather than guess
            // Future enhancement: parse the response to determine if it should go to members or pending
            AnalyticsEvents.groupMemberInvited(groupId: group.id)
            return true
        } catch {
            AnalyticsEvents.error(code: "group_invite_failed", message: error.localizedDescription, context: "invite_member")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    func removePendingInvitation(email: String, from group: Group) async -> Bool {
        do {
            try await effectiveGroups.removePendingInvitation(groupId: group.id, email: email)
            // Optimistic UI: remove from pending invitations list
            if let groupIndex = groups?.firstIndex(where: { $0.id == group.id }) {
                groups?[groupIndex].pendingInvitations.removeAll { $0.email == email }
            }
            return true
        } catch {
            AnalyticsEvents.error(code: "group_remove_pending_invitation_failed", message: error.localizedDescription, context: "remove_pending_invitation")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    func deleteGroup(_ group: Group) async -> Bool {
        do {
            deletingGroupIds.insert(group.id)
            defer { deletingGroupIds.remove(group.id) }
            try await effectiveGroups.delete(groupId: group.id)
            groups?.removeAll(where: { $0.id == group.id })
            AnalyticsEvents.groupDeleted(groupId: group.id)
            return true
        } catch {
            AnalyticsEvents.error(code: "group_delete_failed", message: error.localizedDescription, context: "delete_group")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    func addKid(_ kid: Kid, guardianEmail: String? = nil) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        do {
            isSavingKid = true
            defer { isSavingKid = false }
            let newId = try await effectiveKids.create(userId: userId, kid: kid, guardianEmail: guardianEmail)
            var created = kid
            if newId != kid.id {
                created = Kid(id: newId, name: kid.name, birthdate: kid.birthdate, wishlistItems: kid.wishlistItems, sizes: kid.sizes, guardianEmails: kid.guardianEmails)
            }
            if kids == nil { kids = [] }
            kids?.append(created)
            AnalyticsEvents.kidCreated(kidId: created.id)
            return true
        } catch {
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    func updateKid(_ kid: Kid, guardianEmail: String? = nil) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        do {
            isSavingKid = true
            defer { isSavingKid = false }
            try await effectiveKids.update(userId: userId, kid: kid, guardianEmail: guardianEmail)
            if let index = kids?.firstIndex(where: { $0.id == kid.id }) {
                kids?[index] = kid
            }
            AnalyticsEvents.kidUpdated(kidId: kid.id)
            return true
        } catch {
            AnalyticsEvents.error(code: "kid_update_failed", message: error.localizedDescription, context: "update_kid")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    func deleteKid(_ kid: Kid) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        do {
            deletingKidIds.insert(kid.id)
            defer { deletingKidIds.remove(kid.id) }
            try await effectiveKids.delete(userId: userId, kidId: kid.id)
            kids?.removeAll(where: { $0.id == kid.id })
            AnalyticsEvents.kidDeleted(kidId: kid.id)
            return true
        } catch {
            AnalyticsEvents.error(code: "kid_delete_failed", message: error.localizedDescription, context: "delete_kid")
            self.errorMessage = error.userFacingMessage
            return false
        }
    }

    // MARK: - Purchased Items for Others
    
    struct PurchasedItem: Identifiable {
        let id: UUID
        let item: WishlistItem
        let recipientName: String
        /// How many of the item the current user bought, which may be only part of what's wanted.
        let quantity: Int
        /// When the current user last added to that count.
        let purchasedAt: Date?
        /// The owner has deleted this item since the user bought it.
        var isRemoved = false
    }

    /// Whether a purchase survives the cutoff the user set with their last clear.
    /// With no clear on record the whole purchase history is shown. Items with no purchase date
    /// predate the clear as far as we can tell, so a cutoff hides them.
    private func isPurchaseVisible(_ purchase: WishlistItemPurchase) -> Bool {
        guard let cutoff = purchaseCutoff else { return true }
        guard let purchasedAt = purchase.purchasedAt else { return false }
        return purchasedAt >= cutoff
    }

    var purchasedWishlistItems: [PurchasedItem] {
        guard let userId = currentUser?.id else { return [] }
        var result: [PurchasedItem] = []
        var seen = Set<UUID>()

        func collect(_ items: [WishlistItem], recipientName: String) {
            for item in items {
                if let purchase = item.purchase(by: userId), isPurchaseVisible(purchase), !seen.contains(item.id) {
                    seen.insert(item.id)
                    result.append(PurchasedItem(id: item.id, item: item, recipientName: recipientName, quantity: purchase.quantity, purchasedAt: purchase.purchasedAt))
                }
            }
        }

        // Items from group members
        for group in groups ?? [] {
            for member in group.members where member.id != userId {
                collect(member.wishlistItems, recipientName: member.name)

                // Items from members' kids
                for kid in member.kids {
                    collect(kid.wishlistItems, recipientName: kid.name)
                }
            }
        }

        for removed in removedPurchases where !seen.contains(removed.itemId) {
            let purchase = WishlistItemPurchase(userId: userId, quantity: removed.quantity, purchasedAt: removed.purchasedAt)
            guard isPurchaseVisible(purchase) else { continue }
            result.append(PurchasedItem(id: removed.itemId,
                                        item: WishlistItem(id: removed.itemId, name: removed.itemName, price: removed.itemPrice),
                                        recipientName: removed.recipientName,
                                        quantity: removed.quantity,
                                        purchasedAt: removed.purchasedAt,
                                        isRemoved: true))
        }

        return result.sorted { ($0.purchasedAt ?? Date.distantPast) > ($1.purchasedAt ?? Date.distantPast) }
    }
}
