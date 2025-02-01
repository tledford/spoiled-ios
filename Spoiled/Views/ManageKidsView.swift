import SwiftUI

struct ManageKidsView: View {
    @EnvironmentObject private var viewModel: WishlistViewModel
    @State private var showingAddKidSheet = false
    
    var body: some View {
        List {
            if let currentUserKids = viewModel.kids {
                ForEach(Array(currentUserKids.enumerated()), id: \.element.id) { index, kid in
                    NavigationLink(destination: EditKidView(kidIndex: index)) {
                        Text(kid.name)
                    }
                }
            }
        }
        .navigationTitle("Manage Kids")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddKidSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddKidSheet) {
            AddKidView()
                .environmentObject(viewModel)
        }
    }
} 
