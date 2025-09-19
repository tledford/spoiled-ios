import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var auth: AuthViewModel
    @State private var showingEditProfile = false
    @State private var showDebug = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("Profile") {
                    if let user = viewModel.currentUser {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(user.name)
                                    .font(.headline)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Edit") {
                                showingEditProfile = true
                            }
                        }
                    }
                }
                
                Section("Kids") {
                    NavigationLink("Manage Kids") {
                        ManageKidsView()
                    }
                }
                
                Section("Account") {
                    Button(role: .destructive) {
                        auth.signOut()
                    } label: {
                        Text("Sign Out")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
        }
    }
}
