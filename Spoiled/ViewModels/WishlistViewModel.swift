import Foundation
import SwiftUI
import OSLog

@MainActor
class WishlistViewModel: ObservableObject {
    @Published var currentUser: User?
    @Published var kids: [Kid]?
    @Published var groups: [Group]?
    @Published var wishlistItems: [WishlistItem]?
    @Published var giftIdeas: [GiftIdea]?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let bootstrapService: BootstrapService
    private let usersService: UsersService

    #if DEBUG
    private static let logger = Logger(subsystem: "Spoiled", category: "WishlistViewModel")
    private func dlog(_ message: String) { WishlistViewModel.logger.debug("\(message)") }
    private func elog(_ message: String) { WishlistViewModel.logger.error("\(message)") }
    #endif

    init(bootstrapService: BootstrapService = BootstrapService(), usersService: UsersService = UsersService()) {
        self.bootstrapService = bootstrapService
        self.usersService = usersService
        Task { await load() }
    }

    func load() async {
        #if DEBUG
        dlog("Starting bootstrap request: baseURL=\(AppConfig.api.baseURL.absoluteString) path=/bootstrap userId=\(AppConfig.devUserId.uuidString)")
        #endif
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
            let data = try await bootstrapService.load()
//            #endif
            #if DEBUG
            dlog("Bootstrap success: user=\(data.0.id.uuidString) groups=\(data.1.count) kids=\(data.2.count) myItems=\(data.3.count) giftIdeas=\(data.4.count)")
            #endif
            self.currentUser = data.0
            self.groups = data.1
            self.kids = data.2
            self.wishlistItems = data.3
            self.giftIdeas = data.4
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

    func toggleItemPurchased(_ item: WishlistItem, groupId: UUID?, groupMemberId: UUID?) {
        if let groupId = groupId,
           let groupIndex = groups?.firstIndex(where: { $0.id == groupId }),
           let memberIndex = groups?[groupIndex].members.firstIndex(where: { $0.id == groupMemberId }),
           let itemIndex = groups?[groupIndex].members[memberIndex].wishlistItems.firstIndex(where: { $0.id == item.id }) {
            
            // Toggle the purchased status
            groups?[groupIndex].members[memberIndex].wishlistItems[itemIndex].isPurchased.toggle()
            
            //TODO: send update to API with groupId, groupMemberId, and itemId
        }
    }
    
    func addWishlistItem(_ item: WishlistItem, kidId: UUID?) {
        if let kidId = kidId {
            if let kidIndex = kids?.firstIndex(where: { $0.id == kidId }) {
                kids?[kidIndex].wishlistItems.append(item)

                //TODO: send item with kidId to API
            }
        } else {
            wishlistItems?.append(item)

            //TODO: send item with currentUser?.id to API
        }
    }
    
    func addGroup(_ group: Group) {
        groups?.append(group)
        
        //TODO: send group to API
    }
    
    func updateWishlistItem(item: WishlistItem, name: String, description: String, price: Double?, link: URL?, assignedGroupIds: [UUID], kidId: UUID?) {
        if let kidId = kidId {
            if let kidIndex = kids?.firstIndex(where: { $0.id == kidId }) {
                // Create a new copy of the kid
                var updatedKid = kids?[kidIndex]
                if let index = updatedKid?.wishlistItems.firstIndex(where: { $0.id == item.id }) {
                    updatedKid?.wishlistItems[index].name = name
                    updatedKid?.wishlistItems[index].description = description
                    updatedKid?.wishlistItems[index].price = price
                    updatedKid?.wishlistItems[index].link = link
                    updatedKid?.wishlistItems[index].assignedGroupIds = assignedGroupIds
                    
                    // Reassign the entire kid object to trigger UI update
                    if let updatedKid = updatedKid {
                        kids?[kidIndex] = updatedKid
                    }
                    //TODO: send updatedKid?.wishlistItems[index] to API
                }
            }
        }
        if let index = wishlistItems?.firstIndex(where: { $0.id == item.id }) {
            wishlistItems?[index].name = name
            wishlistItems?[index].description = description
            wishlistItems?[index].price = price
            wishlistItems?[index].link = link
            wishlistItems?[index].assignedGroupIds = assignedGroupIds

            //TODO: send wishlistItems?[index] to API
        }
    }
    
    func addGiftIdea(_ giftIdea: GiftIdea) {
        giftIdeas?.append(giftIdea)

        //TODO: send giftIdea to API
    }
    
    func updateGiftIdea(_ giftIdea: GiftIdea) {
        if let index = giftIdeas?.firstIndex(where: { $0.id == giftIdea.id }) {
            giftIdeas?[index] = giftIdea
        }

        //TODO: send update to API with giftIdea
    }
    
    func deleteWishlistItem(_ item: WishlistItem, kidId: UUID?) {
        if let kidId = kidId {
            if let kidIndex = kids?.firstIndex(where: { $0.id == kidId }) {
                kids?[kidIndex].wishlistItems.removeAll(where: { $0.id == item.id })
                //TODO: send delete request to API with kidId and itemId
            }
        } else {
            wishlistItems?.removeAll(where: { $0.id == item.id })
            //TODO: send delete request to API with itemId
        }
    }

    func saveProfile(name: String, email: String, birthdate: Date, sizes: Sizes) async throws {
        guard let userId = currentUser?.id else { return }
        try await usersService.updateUser(userId: userId, name: name, email: email, birthdate: birthdate, sizes: sizes)
        // Update local state after successful save
        var updated = currentUser
        updated?.name = name
        updated?.email = email
        updated?.birthdate = birthdate
        updated?.sizes = sizes
        currentUser = updated
    }
    
    func updateGroup(_ group: Group, newName: String) {
        if let index = groups?.firstIndex(where: { $0.id == group.id }) {
            groups?[index].name = newName
            
            //TODO: send update to API
        }
    }
    
    func removeMemberFromGroup(_ member: GroupMember, from group: Group) {
        if let groupIndex = groups?.firstIndex(where: { $0.id == group.id }) {
            groups?[groupIndex].members.removeAll(where: { $0.id == member.id })
            
            //TODO: send delete request to API
        }
    }
    
    func addMemberToGroup(email: String, to group: Group) {
        //TODO: In a real app, you would:
        // 1. Check if user exists in the system
        // 2. If yes, add them to the group
        // 3. If no, send them an invitation email
        // 4. Update the UI accordingly
        
        // if let groupIndex = groups?.firstIndex(where: { $0.id == group.id }) {
        //     let newMember = GroupMember(name: email, wishlistItems: [])
        //     groups?[groupIndex].members.append(newMember)
            
            
        // }

        //TODO: send add request to API
    }
}
