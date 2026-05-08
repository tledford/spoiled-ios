import SwiftUI

// MARK: - PersonAvatar
/// Colored circle with the person's initials. Color is deterministic based on the name.
struct PersonAvatar: View {
    let name: String
    var size: CGFloat = 40
    var font: Font? = nil

    var body: some View {
        ZStack {
            Circle()
                .fill(avatarColor(for: name))
            Text(initials(for: name))
                .font(font ?? .system(size: size * 0.38, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [
            Color(red: 0.55, green: 0.35, blue: 0.96),   // violet
            Color(red: 0.20, green: 0.60, blue: 0.90),   // blue
            Color(red: 0.20, green: 0.78, blue: 0.65),   // teal
            Color(red: 0.94, green: 0.42, blue: 0.50),   // rose
            Color(red: 0.91, green: 0.67, blue: 0.24),   // gold
            Color(red: 0.95, green: 0.45, blue: 0.30),   // orange-red
            Color(red: 0.35, green: 0.75, blue: 0.40),   // green
        ]
        let hash = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[abs(hash) % colors.count]
    }
}

// MARK: - BirthdayBadge
/// Compact chip showing days until a birthday. Color shifts to red when close.
struct BirthdayBadge: View {
    let daysUntil: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gift.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(label)
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.18))
        .foregroundStyle(badgeColor)
        .clipShape(Capsule())
    }

    private var label: String {
        if daysUntil == 0 { return "Today! 🎉" }
        if daysUntil == 1 { return "Tomorrow!" }
        return "\(daysUntil) days"
    }

    private var badgeColor: Color {
        if daysUntil <= 7  { return .red }
        if daysUntil <= 30 { return .orange }
        return .brandGold
    }
}

// MARK: - EmptyStateView
/// Consistent empty-state presentation with animated icon, title, and subtitle.
struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    @State private var bouncing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.brandGold.opacity(0.7))
                .scaleEffect(bouncing ? 1.08 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: bouncing
                )
                .onAppear { bouncing = true }
            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PrivateBadge
/// Amber capsule shown on wishlist items not shared with any group.
struct PrivateBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9, weight: .semibold))
            Text("Private")
                .font(.system(size: 11, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.brandGold.opacity(0.15))
        .foregroundStyle(Color.brandGold)
        .clipShape(Capsule())
    }
}

// MARK: - AppSectionHeader
/// Standard section header with an icon and gold-colored title.
struct AppSectionHeader: View {
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

// MARK: - NavButton
/// Consistent style for navigation bar buttons.
/// Use `isIcon: true` (default) for icon-only buttons, `isIcon: false` for text/mixed buttons.
/// The system's Liquid Glass capsule provides the background automatically on iOS 26+.
struct NavButtonModifier: ViewModifier {
    var isIcon: Bool = true

    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: isIcon ? 36 : nil, height: 36)
            .padding(.horizontal, isIcon ? 0 : 14)
    }
}

extension View {
    func navButton(isIcon: Bool = true) -> some View {
        modifier(NavButtonModifier(isIcon: isIcon))
    }
}

// MARK: - SpoiledCard
/// A rounded card surface. Use as a container `.modifier(SpoiledCardModifier())` or wrap
/// content with `SpoiledCard { ... }`.
struct SpoiledCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder private var cardBackground: some View {
        Color.appSurface
    }
}

extension View {
    func spoiledCard() -> some View { modifier(SpoiledCardModifier()) }
}

/// Convenience container that wraps content in a SpoiledCard.
struct SpoiledCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }

    var body: some View {
        content()
            .modifier(SpoiledCardModifier())
    }
}

// MARK: - SizesPillButton
/// Gold pill button for revealing a member's clothing sizes.
struct SizesPillButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "tshirt.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Sizes")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.brandGold.opacity(0.15))
            .foregroundStyle(Color.brandGold)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GoldBadge
/// Generic gold-tinted count/label badge.
struct GoldBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.brandGold.opacity(0.18))
            .foregroundStyle(Color.brandGold)
            .clipShape(Capsule())
    }
}

// MARK: - Previews
#if DEBUG
#Preview("Components") {
    ScrollView {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                PersonAvatar(name: "Alice Smith", size: 40)
                PersonAvatar(name: "Bob Jones", size: 40)
                PersonAvatar(name: "Carol White", size: 40)
                PersonAvatar(name: "Dan Brown", size: 40)
            }
            BirthdayBadge(daysUntil: 3)
            BirthdayBadge(daysUntil: 14)
            BirthdayBadge(daysUntil: 60)
            PrivateBadge()
            GoldBadge(text: "3 members")
            EmptyStateView(
                systemImage: "gift",
                title: "Nothing here yet",
                subtitle: "Tap + to add your first wish"
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
#endif
