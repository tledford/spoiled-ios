import Foundation
import FirebaseAnalytics

// Centralized helpers for Firebase Analytics event logging.
// Custom event naming: lowercase_with_underscores.
enum AnalyticsEvents {
    static func login(method: String) {
        Analytics.logEvent(AnalyticsEventLogin, parameters: [AnalyticsParameterMethod: method])
    }
    static func signUp(method: String?) {
        var params: [String: Any] = [:]
        if let method { params[AnalyticsParameterMethod] = method }
        Analytics.logEvent(AnalyticsEventSignUp, parameters: params)
    }
    static func logout() { Analytics.logEvent("logout", parameters: nil) }

    static func groupCreated(groupId: UUID) {
        Analytics.logEvent("group_created", parameters: ["group_id": groupId.uuidString])
    }
    static func groupUpdated(groupId: UUID) {
        Analytics.logEvent("group_updated", parameters: ["group_id": groupId.uuidString])
    }
    static func groupDeleted(groupId: UUID) {
        Analytics.logEvent("group_deleted", parameters: ["group_id": groupId.uuidString])
    }
    static func groupMemberInvited(groupId: UUID) {
        Analytics.logEvent("group_member_invited", parameters: ["group_id": groupId.uuidString])
    }
    static func kidCreated(kidId: UUID) {
        Analytics.logEvent("kid_created", parameters: ["kid_id": kidId.uuidString])
    }
    static func kidUpdated(kidId: UUID) {
        Analytics.logEvent("kid_updated", parameters: ["kid_id": kidId.uuidString])
    }
    static func kidDeleted(kidId: UUID) {
        Analytics.logEvent("kid_deleted", parameters: ["kid_id": kidId.uuidString])
    }
    static func wishlistItemCreated(itemId: UUID, ownerType: String, hasPrice: Bool, hasLink: Bool, isKid: Bool) {
        Analytics.logEvent("wishlist_item_created", parameters: [
            "item_id": itemId.uuidString,
            "owner_type": ownerType,
            "has_price": hasPrice ? 1 : 0,
            "has_link": hasLink ? 1 : 0,
            "is_kid": isKid ? 1 : 0
        ])
    }
    static func wishlistItemUpdated(itemId: UUID, ownerType: String, hasPrice: Bool, hasLink: Bool, isKid: Bool) {
        Analytics.logEvent("wishlist_item_updated", parameters: [
            "item_id": itemId.uuidString,
            "owner_type": ownerType,
            "has_price": hasPrice ? 1 : 0,
            "has_link": hasLink ? 1 : 0,
            "is_kid": isKid ? 1 : 0
        ])
    }
    static func wishlistItemDeleted(itemId: UUID, ownerType: String, isKid: Bool) {
        Analytics.logEvent("wishlist_item_deleted", parameters: [
            "item_id": itemId.uuidString,
            "owner_type": ownerType,
            "is_kid": isKid ? 1 : 0
        ])
    }
    static func giftIdeaCreated(ideaId: UUID, hasUrl: Bool) {
        Analytics.logEvent("gift_idea_created", parameters: [
            "idea_id": ideaId.uuidString,
            "has_url": hasUrl ? 1 : 0
        ])
    }
    static func giftIdeaUpdated(ideaId: UUID, hasUrl: Bool) {
        Analytics.logEvent("gift_idea_updated", parameters: [
            "idea_id": ideaId.uuidString,
            "has_url": hasUrl ? 1 : 0
        ])
    }
    static func giftIdeaDeleted(ideaId: UUID) {
        Analytics.logEvent("gift_idea_deleted", parameters: ["idea_id": ideaId.uuidString])
    }
    static func wishlistItemPurchased(itemId: UUID, context: String) {
        Analytics.logEvent("wishlist_item_purchased", parameters: [
            "item_id": itemId.uuidString,
            "context": context
        ])
    }
    static func wishlistItemUnpurchased(itemId: UUID, context: String) {
        Analytics.logEvent("wishlist_item_unpurchased", parameters: [
            "item_id": itemId.uuidString,
            "context": context
        ])
    }
    static func profileUpdated() { Analytics.logEvent("profile_updated", parameters: nil) }
    static func error(code: String, message: String?, context: String) {
        var params: [String: Any] = ["context": context, "code": code]
        if let message { params["message"] = String(message.prefix(100)) }
        Analytics.logEvent("app_error", parameters: params)
    }
}

enum AnalyticsAuthProvider {
    private static let key = "last_auth_provider"
    static func record(_ provider: String) { UserDefaults.standard.set(provider, forKey: key) }
    static func last() -> String? { UserDefaults.standard.string(forKey: key) }
}
