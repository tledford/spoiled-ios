import Foundation
import SwiftUI
import OSLog
import FirebaseAnalytics

@MainActor
class WishlistViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var kids: [Kid]?
    @Published var groups: [Group]?
    @Published var wishlistItems: [WishlistItem]?
    @Published var giftIdeas: [GiftIdea]?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var isSavingGiftIdea: Bool = false
    @Published var deletingGiftIdeaIds: Set<UUID> = []
    @Published var isSavingWishlistItem: Bool = false
    @Published var deletingWishlistItemIds: Set<UUID> = []
    @Published var isSavingGroup: Bool = false
    @Published var deletingGroupIds: Set<UUID> = []
    @Published var isSavingKid: Bool = false
    @Published var deletingKidIds: Set<UUID> = []

    private let bootstrapService: BootstrapService
    private let usersService: UsersService
    private let giftIdeasService: GiftIdeasService
    private let groupsService: GroupsService
    private let kidsService: KidsService
    private let wishlistService: WishlistService

    #if DEBUG
    private static let logger = Logger(subsystem: "Spoiled", category: "WishlistViewModel")
    private func dlog(_ message: String) { WishlistViewModel.logger.debug("\(message)") }
    private func elog(_ message: String) { WishlistViewModel.logger.error("\(message)") }
    #endif

    init(bootstrapService: BootstrapService = BootstrapService(), usersService: UsersService = UsersService(), giftIdeasService: GiftIdeasService = GiftIdeasService(), wishlistService: WishlistService = WishlistService(), groupsService: GroupsService = GroupsService(), kidsService: KidsService = KidsService()) {
        self.bootstrapService = bootstrapService
        self.usersService = usersService
        self.giftIdeasService = giftIdeasService
        self.wishlistService = wishlistService
        self.groupsService = groupsService
        self.kidsService = kidsService
    }

    // Convenience to rebuild services with an auth-backed APIClient token provider
    func configureAuth(using auth: AuthViewModel) {
        let provider: (Bool) async -> String? = { force in await auth.getValidIDToken(forceRefresh: force) }
        let client = APIClient(tokenProvider: provider)
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
        Task { await self.load() }
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
        isLoading = true
        errorMessage = nil
        do {
//            #if DEBUG
//            let mockData = MockDataService.createMockData()
//            self.currentUser = mockData.currentUser
//            self.kids = mockData.kids
//            self.groups = mockData.groups
//            self.wishlistItems = mockData.wishlistItems
//            self.giftIdeas = mockData.giftIdeas
//            #else
            let data = try await effectiveBootstrap.load()
//            #endif
            #if DEBUG
            dlog("Bootstrap success: user=\(data.0.id) groups=\(data.1.count) kids=\(data.2.count) myItems=\(data.3.count) giftIdeas=\(data.4.count)")
            #endif
            self.currentUser = data.0
            self.groups = data.1
            self.kids = data.2
            self.wishlistItems = data.3
            self.giftIdeas = data.4
            if data.5 {
                // newly created account; surface a flag so UI can navigate to EditProfileView
                NotificationCenter.default.post(name: Notification.Name("NewUserCreated"), object: nil)
                AnalyticsEvents.signUp(method: AnalyticsAuthProvider.last())
            }
        } catch {
            #if DEBUG
            elog("Bootstrap failed: \(String(describing: error))")
            #endif
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
        isLoading = false
        #if DEBUG
        dlog("Bootstrap finished. isLoading=false")
        #endif
    }

    func toggleItemPurchased(_ item: WishlistItem, groupId: UUID?, groupMemberId: String?, kidId: UUID? = nil) {
        guard let groupId, let currentUserId = currentUser?.id else { return }

        // Determine context: member's own item vs kid item
    if let memberUserId = groupMemberId,
           let groupIndex = groups?.firstIndex(where: { $0.id == groupId }),
       let memberIndex = groups?[groupIndex].members.firstIndex(where: { $0.id == memberUserId }),
           let itemIndex = groups?[groupIndex].members[memberIndex].wishlistItems.firstIndex(where: { $0.id == item.id }) {

            var target = groups![groupIndex].members[memberIndex].wishlistItems[itemIndex]
            if target.isPurchased, let purchaser = target.purchasedBy, purchaser != currentUserId { return }

            target.isPurchased.toggle()
            if target.isPurchased {
                target.purchasedAt = Date()
                target.purchasedBy = currentUserId
            } else {
                target.purchasedAt = nil
                target.purchasedBy = nil
            }
            groups?[groupIndex].members[memberIndex].wishlistItems[itemIndex] = target

            Task { [weak self] in
                guard let self else { return }
                do {
                    let res = try await effectiveWishlist.toggleGroupMemberItem(groupId: groupId, memberUserId: memberUserId, itemId: item.id)
                    if res.isPurchased {
                        AnalyticsEvents.wishlistItemPurchased(itemId: item.id, context: "group_member")
                    } else {
                        AnalyticsEvents.wishlistItemUnpurchased(itemId: item.id, context: "group_member")
                    }
                    await self.refreshAll()
                } catch {
                    // Roll back
                    if let gi = self.groups?.firstIndex(where: { $0.id == groupId }),
                       let mi = self.groups?[gi].members.firstIndex(where: { $0.id == memberUserId }),
                       let ii = self.groups?[gi].members[mi].wishlistItems.firstIndex(where: { $0.id == item.id }) {
                        self.groups?[gi].members[mi].wishlistItems[ii] = item
                    }
                    await MainActor.run { self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error) }
                }
            }
            return
        }

        // Kid item in group view
        if let kidId,
           let groupIndex = groups?.firstIndex(where: { $0.id == groupId }) {
            // Find kid within member sections
            if let km = groups?[groupIndex].members.firstIndex(where: { member in member.kids.contains(where: { $0.id == kidId && $0.wishlistItems.contains(where: { $0.id == item.id }) }) }) {
                // Find indices
                let kids = groups![groupIndex].members[km].kids
                guard let kidIdx = kids.firstIndex(where: { $0.id == kidId }),
                      let itemIdx = kids[kidIdx].wishlistItems.firstIndex(where: { $0.id == item.id }) else { return }
                var target = groups![groupIndex].members[km].kids[kidIdx].wishlistItems[itemIdx]
                if target.isPurchased, let purchaser = target.purchasedBy, purchaser != currentUserId { return }
                target.isPurchased.toggle()
                if target.isPurchased {
                    target.purchasedAt = Date()
                    target.purchasedBy = currentUserId
                } else {
                    target.purchasedAt = nil
                    target.purchasedBy = nil
                }
                groups![groupIndex].members[km].kids[kidIdx].wishlistItems[itemIdx] = target

                Task { [weak self] in
                    guard let self else { return }
                    do {
                        let res = try await effectiveWishlist.toggleGroupKidItem(groupId: groupId, kidId: kidId, itemId: item.id)
                        if res.isPurchased {
                            AnalyticsEvents.wishlistItemPurchased(itemId: item.id, context: "group_kid")
                        } else {
                            AnalyticsEvents.wishlistItemUnpurchased(itemId: item.id, context: "group_kid")
                        }
                        await self.refreshAll()
                    } catch {
                        // Roll back
                        if let gi = self.groups?.firstIndex(where: { $0.id == groupId }),
                           let kmi = self.groups?[gi].members.firstIndex(where: { member in member.kids.contains(where: { $0.id == kidId && $0.wishlistItems.contains(where: { $0.id == item.id }) }) }),
                           let kidIdx2 = self.groups?[gi].members[kmi].kids.firstIndex(where: { $0.id == kidId }),
                           let ii = self.groups?[gi].members[kmi].kids[kidIdx2].wishlistItems.firstIndex(where: { $0.id == item.id }) {
                            self.groups?[gi].members[kmi].kids[kidIdx2].wishlistItems[ii] = item
                        }
                        await MainActor.run { self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error) }
                    }
                }
            }
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
                    newItem = WishlistItem(id: serverId, name: item.name, description: item.description, price: item.price, link: item.link, isPurchased: item.isPurchased, assignedGroupIds: item.assignedGroupIds)
                }
                if let kidIndex = kids?.firstIndex(where: { $0.id == kidId }) {
                    kids?[kidIndex].wishlistItems.append(newItem)
                }
                AnalyticsEvents.wishlistItemCreated(itemId: newItem.id, ownerType: "kid", hasPrice: newItem.price != nil, hasLink: newItem.link != nil, isKid: true)
            } else {
                let serverId = try await effectiveWishlist.createUserItem(userId: userId, item: item)
                if serverId != item.id {
                    newItem = WishlistItem(id: serverId, name: item.name, description: item.description, price: item.price, link: item.link, isPurchased: item.isPurchased, assignedGroupIds: item.assignedGroupIds)
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
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
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            }
        }
    }
    
    func updateWishlistItem(item: WishlistItem, name: String, description: String, price: Double?, link: URL?, assignedGroupIds: [UUID], kidId: UUID?) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        var updated = item
        updated.name = name
        updated.description = description
        updated.price = price
        updated.link = link
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
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
            await MainActor.run { self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error) }
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        return false
        }
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            return false
        }
    }

    func saveProfile(name: String, email: String, birthdate: Date, sizes: Sizes) async throws {
        guard let userId = currentUser?.id else { return }
    try await effectiveUsers.updateUser(userId: userId, name: name, email: email, birthdate: birthdate, sizes: sizes)
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            return false
        }
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            return false
        }
    }

    func addKid(_ kid: Kid) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        do {
            isSavingKid = true
            defer { isSavingKid = false }
            let newId = try await effectiveKids.create(userId: userId, kid: kid)
            var created = kid
            if newId != kid.id {
                created = Kid(id: newId, name: kid.name, birthdate: kid.birthdate, wishlistItems: kid.wishlistItems, sizes: kid.sizes)
            }
            if kids == nil { kids = [] }
            kids?.append(created)
            AnalyticsEvents.kidCreated(kidId: created.id)
            return true
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            return false
        }
    }

    func updateKid(_ kid: Kid) async -> Bool {
        guard let userId = currentUser?.id else { return false }
        do {
            isSavingKid = true
            defer { isSavingKid = false }
            try await effectiveKids.update(userId: userId, kid: kid)
            if let index = kids?.firstIndex(where: { $0.id == kid.id }) {
                kids?[index] = kid
            }
            AnalyticsEvents.kidUpdated(kidId: kid.id)
            return true
        } catch {
            AnalyticsEvents.error(code: "kid_update_failed", message: error.localizedDescription, context: "update_kid")
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
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
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            return false
        }
    }
}
