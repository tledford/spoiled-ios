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

                    HStack(spacing: 12) {
                        ChristmasCountdownCard(days: daysUntilChristmas)
                        UpcomingBirthdayCountCard(count: birthdaysWithinTwoMonthsCount)
                    }

                    QuickStatsRow(
                        purchased: giftsIHavePurchasedCount,
                        activeWishlist: myActiveWishlistCount,
                        giftIdeas: giftIdeasCount
                    )

                    if !upcomingBirthdays.isEmpty {
                        BirthdaySectionCard(entries: upcomingBirthdays)
                    }

                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Spoiled")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await viewModel.refreshAll() }
        }
        .trackScreen("home")
    }

    // MARK: - Computed metrics

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

    private var giftsIHavePurchasedCount: Int {
        let wishlistCount = viewModel.purchasedWishlistItems.count
        let giftIdeasCount = (viewModel.giftIdeas ?? []).filter { $0.isPurchased }.count
        return wishlistCount + giftIdeasCount
    }

    private var myActiveWishlistCount: Int {
        viewModel.wishlistItems?.count ?? 0
    }

    private var giftIdeasCount: Int {
        viewModel.giftIdeas?.filter { !$0.isPurchased }.count ?? 0
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

    // MARK: - Birthdays within 2 months

    private var birthdaysWithinTwoMonthsCount: Int {
        upcomingBirthdays.filter { $0.daysUntil <= 60 }.count
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

            VStack(alignment: .leading, spacing: 4) {
                if days == 0 {
                    Text("🎄")
                        .font(.system(size: 30))
                    Text("Merry\nChristmas!")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                } else {
                    Text("\(days)")
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(Color.brandGold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    HStack(alignment: .center, spacing: 6) {
                        Text("days until\nChristmas")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(2)
                        Spacer()
                        Image(systemName: "gift.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.brandGold.opacity(0.35))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .shadow(color: Color.brandGold.opacity(0.2), radius: 16, x: 0, y: 6)
    }
}

// MARK: - Upcoming Birthday Count Card

private struct UpcomingBirthdayCountCard: View {
    let count: Int

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.02, green: 0.22, blue: 0.26), Color(red: 0.08, green: 0.50, blue: 0.52)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.65, green: 0.96, blue: 0.96))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                HStack(alignment: .center, spacing: 6) {
                    Text(count == 1 ? "birthday in\n2 months" : "birthdays in\n2 months")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "birthday.cake.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(red: 0.65, green: 0.96, blue: 0.96).opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .shadow(color: Color.teal.opacity(0.25), radius: 12, x: 0, y: 5)
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

            NavigationLink(destination: MyWishlistView()) {
                StatCard(icon: "list.bullet", value: "\(activeWishlist)", label: "My Wishlist", tint: .blue)
            }
            .buttonStyle(.plain)

            NavigationLink(destination: GiftIdeasView(startHidingPurchased: true)) {
                StatCard(icon: "lightbulb.fill", value: "\(giftIdeas)", label: "Gift Ideas", tint: Color.brandRose)
            }
            .buttonStyle(.plain)
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
