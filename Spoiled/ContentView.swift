import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var wishlistViewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @State private var showEditProfile = false

    var body: some View {
        TabView {
            Tab("Wishlist", systemImage: "gift.fill") {
                MyWishlistView()
            }
            Tab("Groups", systemImage: "person.3.fill") {
                GroupsView()
            }
            Tab("Gift Ideas", systemImage: "lightbulb.fill") {
                GiftIdeasView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
        }
        .overlay(alignment: .top) {
            if wishlistViewModel.isLoading {
                ProgressView().padding(.top, 8)
            }
        }
        .toast(toastCenter)
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: wishlistViewModel)
                .environmentObject(toastCenter)
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("NewUserCreated"))) { _ in
            toastCenter.info("Welcome! Let's finish setting up your profile.")
            showEditProfile = true
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WishlistViewModel())
        .environmentObject(ToastCenter())
}
