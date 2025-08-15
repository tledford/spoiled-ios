import SwiftUI
import LinkPresentation
import UIKit

struct WishlistItemDetailView: View {
    let item: WishlistItem
    var isInGroupView: Bool
    let kidId: UUID?
    let groupId: UUID?
    let groupMemberId: UUID?
    @EnvironmentObject private var viewModel: WishlistViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var assignedGroups: [Group] {
        viewModel.groups?.filter { item.assignedGroupIds.contains($0.id) } ?? []
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Link Preview Card
                    if let link = item.link {
                        LinkPreviewView(url: link)
                    }
                    
                    // Price Card
                    if let price = item.price {
                        PriceCard(price: price)
                    }
                    
                    // Description Card
                    if !item.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(item.description)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    
                    // Groups Card
                    if !isInGroupView && !assignedGroups.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shared With")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            ForEach(assignedGroups) { group in
                                HStack {
                                    Image(systemName: "person.3.fill")
                                        .foregroundStyle(.secondary)
                                    Text(group.name)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    
                    // Purchase Button
                    if isInGroupView {
                        Button {
                            viewModel.toggleItemPurchased(item, groupId: groupId, groupMemberId: groupMemberId)
                        } label: {
                            HStack {
                                Text(item.isPurchased ? "Mark as Not Purchased" : "Mark as Purchased")
                                    .font(.headline)
                                Spacer()
                                if item.isPurchased {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(item.isPurchased ? Color.green : Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Delete button section
                    if !isInGroupView {
                        Section {
                            Button(role: .destructive) {
                                showingDeleteAlert = true
                            } label: {
                                HStack {
                                    Spacer()
                                    Text("Delete Item")
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !isInGroupView {
                        Button("Edit") {
                            showingEditSheet = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditWishlistItemView(item: item, kidId: kidId)
                    .environmentObject(viewModel)
            }
            .alert("Delete Item", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    viewModel.deleteWishlistItem(item, kidId: kidId)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this item? This action cannot be undone.")
            }
        }
    }
}

struct PriceCard: View {
    let price: Double
    
    var body: some View {
        HStack {
            Text("Price")
                .font(.headline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "$%.2f", price))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.accentColor)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
} 

// MARK: - Link Preview Support (LPLinkView in SwiftUI)

private struct LinkPreviewView: View {
    let url: URL
    var cornerRadius: CGFloat = 12

    @StateObject private var loader = LinkMetadataLoader()
    @State private var showShareSheet = false

    var body: some View {
        SwiftUI.Group {
            if let metadata = loader.metadata {
                Link(destination: url) {
                    LPLinkViewRepresentable(metadata: metadata)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 100)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
            } else if loader.failed {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "link").imageScale(.large)
                        Text("View Item Online").font(.headline)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 110)
                    .overlay(
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading preview…").foregroundStyle(.secondary)
                        }
                    )
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .task {
                        loader.fetch(url: url)
                    }
            }
    }
    .contentShape(Rectangle())
        .contextMenu {
            Button {
                UIPasteboard.general.url = url
            } label: {
                Label("Copy Link", systemImage: "doc.on.doc")
            }

            Button {
                showShareSheet = true
            } label: {
                Label("Share…", systemImage: "square.and.arrow.up")
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ActivityView(activityItems: [url])
        }
        .onAppear {
            loader.fetch(url: url)
        }
    }
}

private final class LinkMetadataLoader: ObservableObject {
    @Published var metadata: LPLinkMetadata?
    @Published var failed: Bool = false
    private var isLoading = false

    private static let cache = NSCache<NSURL, LPLinkMetadata>()

    func fetch(url: URL) {
        if metadata != nil || failed || isLoading { return }

        if let cached = Self.cache.object(forKey: url as NSURL) {
            self.metadata = cached
            return
        }

        isLoading = true
        let provider = LPMetadataProvider()
        provider.startFetchingMetadata(for: url) { [weak self] meta, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                if let meta = meta {
                    Self.cache.setObject(meta, forKey: url as NSURL)
                    self.metadata = meta
                } else {
                    self.failed = true
                }
            }
        }
    }
}

private struct LPLinkViewRepresentable: UIViewRepresentable {
    let metadata: LPLinkMetadata

    func makeUIView(context: Context) -> LPLinkView {
        let view = LPLinkView(metadata: metadata)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }

    func updateUIView(_ uiView: LPLinkView, context: Context) {
        uiView.metadata = metadata
    }
}

// Wrapper for UIActivityViewController to present the iOS share sheet from SwiftUI
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        controller.excludedActivityTypes = excludedActivityTypes
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // no-op
    }
}

