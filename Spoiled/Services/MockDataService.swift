import Foundation

struct MockDataService {
    static func createMockData() -> (currentUser: User, groups: [Group], kids: [Kid], wishlistItems: [WishlistItem], giftIdeas: [GiftIdea]) {
        
        // Create 3 groups
        var groups = [
            Group(name: "Family Group", isAdmin: true),
            Group(name: "Friends Group", isAdmin: false),
            Group(name: "Holiday Group", isAdmin: true)
        ]
        
        // Create group members
        let groupMembers = [
            GroupMember(name: "Emma Wilson", wishlistItems: createWishlistItems(for: "Emma Wilson", groupIds: [groups[0].id, groups[2].id])),
            GroupMember(name: "Michael Brown", wishlistItems: createWishlistItems(for: "Michael Brown", groupIds: [groups[0].id, groups[2].id])),
            GroupMember(name: "Sarah Davis", wishlistItems: createWishlistItems(for: "Sarah Davis", groupIds: [groups[1].id, groups[2].id])),
            GroupMember(name: "James Miller", wishlistItems: createWishlistItems(for: "James Miller", groupIds: [groups[1].id, groups[2].id]))
        ]

        // Add group members to groups
        groups[0].members = [groupMembers[0], groupMembers[1]]
        groups[1].members = [groupMembers[2], groupMembers[3]]
        groups[2].members = [groupMembers[0], groupMembers[1], groupMembers[2], groupMembers[3]]
        
        // Create current user
        let currentUser = User(
            name: "John Smith",
            email: "john@email.com",
            birthdate: Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date(),
            sizes: Sizes(
                shirt: "L",
                pants: "34x32",
                shoes: "10.5",
                sweatshirt: "XL",
                hat: "7 1/4"
            )
        )
        
        let kids = [
            Kid(
                name: "Johnny Jr",
                birthdate: Date(),
                wishlistItems: createKidsWishlistItems(kidName: "Johnny Jr", groupIds: [groups[0].id, groups[2].id]),
                sizes: Sizes(
                    shirt: "M",
                    pants: "8",
                    shoes: "4Y",
                    sweatshirt: "L",
                    hat: "S/M"
                )
            ),
            Kid(
                name: "Jane",
                birthdate: Date(),
                wishlistItems: createKidsWishlistItems(kidName: "Jane", groupIds: [groups[1].id, groups[2].id]),
                sizes: Sizes(
                    shirt: "S",
                    pants: "6",
                    shoes: "2Y",
                    sweatshirt: "M",
                    hat: "S"
                )
            )
        ]
        
        let wishlistItems = createWishlistItems(for: "John Smith", groupIds: [groups[0].id, groups[1].id, groups[2].id])
        
        let giftIdeas = [
            GiftIdea(personName: "Alice", giftName: "Book", url: URL(string: "https://example.com/book"), notes: "Loves mystery novels", isPurchased: false),
            GiftIdea(personName: "Bob", giftName: "Headphones", url: URL(string: "https://example.com/headphones"), notes: "Prefers over-ear", isPurchased: true),
            GiftIdea(personName: "Alice", giftName: "Guitar", url: URL(string: "https://example.com/guitar"), notes: "Wants to learn", isPurchased: true)
        ]
        
        return (currentUser, groups, kids, wishlistItems, giftIdeas)
    }
    
    private static func createWishlistItems(for userName: String, groupIds: [UUID]) -> [WishlistItem] {
        [
            WishlistItem(name: "Item 1 for \(userName)", description: "Description 1", price: 29.99, link: URL(string: "https://www.amazon.com/dp/B08VCK1M1X"), isPurchased: true, assignedGroupIds: groupIds),
            WishlistItem(name: "Item 2 for \(userName)", description: "Description 2", price: 49.99, link: URL(string: "https://www.amazon.com/dp/B08VCK1M1X"), isPurchased: true, assignedGroupIds: groupIds),
            WishlistItem(name: "Item 3 for \(userName)", description: "Description 3", price: 19.99, link: URL(string: "https://www.amazon.com/dp/B08VCK1M1X"), assignedGroupIds: groupIds),
            WishlistItem(name: "Item 4 for \(userName)", description: "Description 4", price: 39.99, link: URL(string: "https://www.amazon.com/dp/B08VCK1M1X"), assignedGroupIds: groupIds),
            WishlistItem(name: "Item 5 for \(userName)", description: "Description 5", price: 59.99, link: URL(string: "https://www.amazon.com/dp/B08VCK1M1X"), assignedGroupIds: groupIds)
        ]
    }
    
    private static func createKidsWishlistItems(kidName: String, groupIds: [UUID]) -> [WishlistItem] {
        [
            WishlistItem(name: "Toy 1 for \(kidName)", description: "Fun toy 1", price: 19.99, link: URL(string: "https://www.amazon.com/dp/B08VCK1M1X"), isPurchased: true, assignedGroupIds: groupIds),
            WishlistItem(name: "Toy 2 for \(kidName)", description: "Fun toy 2", price: 24.99, link: URL(string: "https://www.amazon.com/dp/B08VCK1M1X"), isPurchased: true, assignedGroupIds: groupIds),
            WishlistItem(name: "Toy 3 for \(kidName)", description: "Fun toy 3", price: 14.99, link: URL(string: "https://www.amazon.com/dp/B08VCK1M1X"), assignedGroupIds: groupIds),
            WishlistItem(name: "Toy 4 for \(kidName)", description: "Fun toy 4", price: 29.99, link: URL(string: "https://www.amazon.com/dp/B08VCK1M1X"), assignedGroupIds: groupIds),
            WishlistItem(name: "Toy 5 for \(kidName)", description: "Fun toy 5", price: 9.99, link: URL(string: "https://www.amazon.com/dp/B08VCK1M1X"), assignedGroupIds: groupIds)
        ]
    }
} 
