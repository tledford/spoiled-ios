import SwiftUI

// MARK: - HomeView

struct HomeView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    GreetingHeader(name: viewModel.currentUser?.name)

                    ChristmasCountdownCard(days: daysUntilChristmas)

                    QuickStatsRow(
                        purchased: giftsIHavePurchasedCount,
                        activeWishlist: myActiveWishlistCount,
                        giftIdeas: giftIdeasCount
                    )

                    if !upcomingBirthdays.isEmpty {
                        BirthdaySectionCard(entries: upcomingBirthdays)
                    }

                    StillToBuyCard(members: stillToBuy)

                    TipsCard()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await viewModel.refreshAll() }
        }
        .trackScreen("home")
    }

    // MARK: - Computed metrics

    private var currentYear: Int { Calendar.current.component(.year, from: Date()) }
    private var sixMonthsAgo: Date { Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date() }

    /// All unique group members (excluding current user), deduplicated by Firebase UID.
    private var uniqueMembers: [GroupMember] {
        var seen = Set<String>()
        var result: [GroupMember] = []
        for group in viewModel.groups ?? [] {
            for member in group.members {
                guard member.id != viewModel.currentUser?.id,
                      !seen.contains(member.id) else { continue }
                seen.insert(member.id)
                result.append(member)
            }
        }
        return result
    }

    /// Union of a member's wishlist items across all group appearances, deduplicated by item ID.
    private func uniqueItems(for memberId: String) -> [WishlistItem] {
        var seen = Set<UUID>()
        var items: [WishlistItem] = []
        for group in viewModel.groups ?? [] {
            for member in group.members where member.id == memberId {
                for item in member.wishlistItems where !seen.contains(item.id) {
                    seen.insert(item.id)
                    items.append(item)
                }
            }
        }
        return items
    }

    private var giftsIHavePurchasedCount: Int {
        guard let userId = viewModel.currentUser?.id else { return 0 }
        var count = 0
        var seen = Set<UUID>()
        for member in uniqueMembers {
            for item in uniqueItems(for: member.id) {
                guard !seen.contains(item.id),
                      item.isPurchased,
                      item.purchasedBy == userId,
                      let at = item.purchasedAt, at >= sixMonthsAgo else { continue }
                seen.insert(item.id)
                count += 1
            }
        }
        return count
    }

    private var myActiveWishlistCount: Int {
        viewModel.wishlistItems?.filter { !$0.isPurchased }.count ?? 0
    }

    private var giftIdeasCount: Int {
        viewModel.giftIdeas?.count ?? 0
    }

    // MARK: - Birthday entries

    struct BirthdayEntry: Identifiable {
        let id: String   // member.id or "kid-\(kid.id)"
        let name: String
        let birthdate: Date
        var daysUntil: Int { daysUntilNextBirthday(from: birthdate) }
    }

    private var upcomingBirthdays: [BirthdayEntry] {
        var entries: [BirthdayEntry] = []
        var seenIds = Set<String>()

        // Group members
        for member in uniqueMembers {
            if let bd = member.birthdate, !seenIds.contains(member.id) {
                seenIds.insert(member.id)
                entries.append(BirthdayEntry(id: member.id, name: member.name, birthdate: bd))
            }
        }

        // Kids of group members (deduplicated by kid UUID)
        for group in viewModel.groups ?? [] {
            for member in group.members {
                for kid in member.kids {
                    let kidKey = "kid-\(kid.id)"
                    if let bd = kid.birthdate, !seenIds.contains(kidKey) {
                        seenIds.insert(kidKey)
                        entries.append(BirthdayEntry(id: kidKey, name: kid.name, birthdate: bd))
                    }
                }
            }
        }

        // User's own kids
        for kid in viewModel.kids ?? [] {
            let kidKey = "kid-\(kid.id)"
            if !seenIds.contains(kidKey) {
                seenIds.insert(kidKey)
                entries.append(BirthdayEntry(id: kidKey, name: kid.name, birthdate: kid.birthdate))
            }
        }

        return entries.sorted { $0.daysUntil < $1.daysUntil }
    }

    // MARK: - Still to buy

    struct StillToBuyEntry: Identifiable {
        let id: String  // member.id
        let name: String
        let unpurchasedCount: Int
    }

    private var stillToBuy: [StillToBuyEntry] {
        guard let userId = viewModel.currentUser?.id else { return [] }
        let cal = Calendar.current

        return uniqueMembers.compactMap { member in
            let items = uniqueItems(for: member.id)
            let unpurchased = items.filter { !$0.isPurchased }
            guard !unpurchased.isEmpty else { return nil }

            // Has the current user purchased anything for this member this calendar year?
            let purchasedThisYear = items.contains { item in
                item.isPurchased &&
                item.purchasedBy == userId &&
                item.purchasedAt.map { cal.component(.year, from: $0) == currentYear } == true
            }
            guard !purchasedThisYear else { return nil }

            return StillToBuyEntry(id: member.id, name: member.name, unpurchasedCount: unpurchased.count)
        }
    }

    // MARK: - Christmas

    private var daysUntilChristmas: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var comps = cal.dateComponents([.year], from: today)
        comps.month = 12
        comps.day = 25
        var christmas = cal.date(from: comps)!
        if christmas < today { christmas = cal.date(byAdding: .year, value: 1, to: christmas)! }
        return cal.dateComponents([.day], from: today, to: christmas).day ?? 0
    }
}

// MARK: - Greeting Header

private struct GreetingHeader: View {
    let name: String?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:     return "Good evening"
        }
    }

    private var firstName: String {
        name?.components(separatedBy: " ").first ?? "there"
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(greeting), \(firstName)! 🎁")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)
            Text(Self.dateFormatter.string(from: Date()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

// MARK: - Christmas Countdown

private struct ChristmasCountdownCard: View {
    let days: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.18, green: 0.12, blue: 0.04), Color(red: 0.56, green: 0.34, blue: 0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    if days == 0 {
                        Text("🎄 Merry Christmas!")
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(days)")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(Color.brandGold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("days until Christmas")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer()
                Image(systemName: days == 0 ? "star.fill" : "gift.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.brandGold.opacity(0.35))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .shadow(color: Color.brandGold.opacity(0.2), radius: 16, x: 0, y: 6)
    }
}

// MARK: - Quick Stats Row

private struct QuickStatsRow: View {
    let purchased: Int
    let activeWishlist: Int
    let giftIdeas: Int

    var body: some View {
        HStack(spacing: 10) {
            NavigationLink(destination: PurchasedGiftsReportView()) {
                StatCard(icon: "gift.fill", value: "\(purchased)", label: "Purchased", tint: Color.brandGold)
            }
            .buttonStyle(.plain)

            StatCard(icon: "list.bullet", value: "\(activeWishlist)", label: "My Wishlist", tint: .blue)
            StatCard(icon: "lightbulb.fill", value: "\(giftIdeas)", label: "Gift Ideas", tint: Color.brandRose)
        }
    }
}

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Birthday Section

private struct BirthdaySectionCard: View {
    let entries: [HomeView.BirthdayEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(icon: "birthday.cake.fill", title: "Upcoming Birthdays")
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    BirthdayRow(entry: entry)
                    if index < entries.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

private struct BirthdayRow: View {
    let entry: HomeView.BirthdayEntry

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private var birthdateThisYear: Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.month, .day], from: entry.birthdate)
        comps.year = cal.component(.year, from: Date())
        let d = cal.date(from: comps) ?? entry.birthdate
        // If already past, use next year
        let today = cal.startOfDay(for: Date())
        if d < today {
            return cal.date(byAdding: .year, value: 1, to: d) ?? d
        }
        return d
    }

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(name: entry.name, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(.system(size: 15, weight: .semibold))
                Text(Self.dateFormatter.string(from: birthdateThisYear))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            BirthdayBadge(daysUntil: entry.daysUntil)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Still to Buy

private struct StillToBuyCard: View {
    let members: [HomeView.StillToBuyEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(icon: "cart.fill", title: "Still to Buy")
                .padding(.bottom, 12)

            if members.isEmpty {
                HStack(spacing: 12) {
                    Text("🎉")
                        .font(.system(size: 28))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Everyone is taken care of!")
                            .font(.system(size: 15, weight: .semibold))
                        Text("You've purchased a gift for all group members this year.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { index, entry in
                        StillToBuyRow(entry: entry)
                        if index < members.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

private struct StillToBuyRow: View {
    let entry: HomeView.StillToBuyEntry

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(name: entry.name, size: 36)
            Text(entry.name)
                .font(.system(size: 15, weight: .semibold))
            Spacer()
            Text("\(entry.unpurchasedCount) item\(entry.unpurchasedCount == 1 ? "" : "s")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.brandGold)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.brandGold.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// MARK: - Tips Card

private struct TipsCard: View {
    @State private var isExpanded = false

    private let tips: [(icon: String, text: String)] = [
        ("gift.fill",          "Add items to your wishlist so your group knows what you want."),
        ("magnifyingglass",    "Browse group members' wishlists to find the perfect gift."),
        ("lightbulb.fill",     "Save gift ideas privately — they're only visible to you."),
        ("figure.and.child.holdinghands", "Add your kids so the group can see their wishlists too."),
        ("envelope.fill",      "Invite people to a group using their email address."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    SectionHeader(icon: "questionmark.circle.fill", title: "How to Use Spoiled")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: tip.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.brandGold)
                                .frame(width: 20)
                                .padding(.top, 1)
                            Text(tip.text)
                                .font(.system(size: 14))
                                .foregroundStyle(.primary.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        if index < tips.count - 1 {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.top, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandGold)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
    }
}
