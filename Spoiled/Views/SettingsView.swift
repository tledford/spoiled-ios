import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
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
                        // Handle sign out
                    } label: {
                        Text("Sign Out")
                    }
                }

                #if DEBUG
                Section("Developer") {
                    NavigationLink("Debug Tools") { DebugToolsView() }
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(viewModel: viewModel)
            }
        }
    }
}
