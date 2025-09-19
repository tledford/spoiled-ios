import SwiftUI
import LinkPresentation
import UIKit

struct WishlistItemDetailView: View {
    let item: WishlistItem
    var isInGroupView: Bool
    let kidId: UUID?
    let groupId: UUID?
    let groupMemberId: String?
    @EnvironmentObject private var viewModel: WishlistViewModel
    @EnvironmentObject private var toastCenter: ToastCenter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    // Resolve latest item from the view model so UI reflects changes post-toggle
    private var currentItem: WishlistItem {
        if isInGroupView, let groupId, let gi = viewModel.groups?.firstIndex(where: { $0.id == groupId }) {
            if let kidId,
               let memberIndex = viewModel.groups?[gi].members.firstIndex(where: { member in member.kids.contains(where: { $0.id == kidId && $0.wishlistItems.contains(where: { $0.id == item.id }) }) }),
               let kidx = viewModel.groups?[gi].members[memberIndex].kids.firstIndex(where: { $0.id == kidId }),
               let ii = viewModel.groups?[gi].members[memberIndex].kids[kidx].wishlistItems.firstIndex(where: { $0.id == item.id }) {
                return viewModel.groups![gi].members[memberIndex].kids[kidx].wishlistItems[ii]
            }
            if let memberUserId = groupMemberId,
               let memberIndex = viewModel.groups?[gi].members.firstIndex(where: { $0.id == memberUserId }),
               let ii = viewModel.groups?[gi].members[memberIndex].wishlistItems.firstIndex(where: { $0.id == item.id }) {
                return viewModel.groups![gi].members[memberIndex].wishlistItems[ii]
            }
        }
        return item
    }

    var assignedGroups: [Group] {
        viewModel.groups?.filter { currentItem.assignedGroupIds.contains($0.id) } ?? []
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Link Preview Card
                    if let link = currentItem.link {
                        LinkPreviewView(url: link)
                    }
                    
                    // Price Card
//                    if let price = currentItem.price {
//                        PriceCard(price: price)
//                    }
                    
                    // Description Card
                    if !currentItem.description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Description")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text(currentItem.description)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: primaryShadowColor(colorScheme), radius: 5, x: 0, y: 2)
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
                        .shadow(color: primaryShadowColor(colorScheme), radius: 5, x: 0, y: 2)
                    } else if !isInGroupView && assignedGroups.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .foregroundStyle(.secondary)
                            Text("Not shared with any groups")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: subtleShadowColor(colorScheme), radius: 4, x: 0, y: 1)
                    }
                    
                    // Purchase Button
                    if isInGroupView {
                        // Determine disable state
                        let purchasedByOther: Bool = {
                            guard currentItem.isPurchased, let purchaser = currentItem.purchasedBy, purchaser != viewModel.currentUser?.id else { return false }
                            return true
                        }()
                        Button {
                            viewModel.toggleItemPurchased(currentItem, groupId: groupId, groupMemberId: groupMemberId, kidId: kidId)
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(currentItem.isPurchased ? (purchasedByOther ? "Already Purchased" : "Mark as Not Purchased") : "Mark as Purchased")
                                        .font(.headline)
                                    if purchasedByOther {
                                        Text("Purchased by another group member")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if currentItem.isPurchased {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .padding()
                            .foregroundColor(.white)
                            .background(currentItem.isPurchased ? Color.green : Color.accentColor)
                            .opacity(purchasedByOther ? 0.6 : 1.0)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(purchasedByOther)
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
            .navigationTitle(currentItem.name)
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
                    Task {
                        let ok = await viewModel.deleteWishlistItem(item, kidId: kidId)
                        if ok { toastCenter.success("Item deleted"); dismiss() }
                        else { toastCenter.error(viewModel.errorMessage ?? "Failed to delete item") }
                    }
                }
            } message: {
                Text("Are you sure you want to delete this item? This action cannot be undone.")
            }
        }
    }
}

// struct PriceCard: View {
//     let price: Double
//     @Environment(\.colorScheme) private var colorScheme
    
//     var body: some View {
//         HStack {
//             Text("Price")
//                 .font(.headline)
//                 .foregroundStyle(.secondary)
//             Spacer()
//             Text(String(format: "$%.2f", price))
//                 .font(.title2)
//                 .fontWeight(.bold)
//                 .foregroundColor(.accentColor)
//         }
//         .padding()
//         .background(Color(.systemBackground))
//         .clipShape(RoundedRectangle(cornerRadius: 12))
//         .shadow(color: primaryShadowColor(colorScheme), radius: 5, x: 0, y: 2)
//     }
// } 

// MARK: - Link Preview Support (LPLinkView in SwiftUI)

private struct LinkPreviewView: View {
    let url: URL
    var cornerRadius: CGFloat = 12

    @StateObject private var loader = LinkMetadataLoader()
    @State private var showShareSheet = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        SwiftUI.Group {
            if let metadata = loader.metadata {
                Link(destination: url) {
                    LPLinkViewRepresentable(metadata: metadata)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 80)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .shadow(color: primaryShadowColor(scheme), radius: 5, x: 0, y: 2)
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
                    .shadow(color: primaryShadowColor(scheme), radius: 5, x: 0, y: 2)
                }
            } else {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 80)
                    .overlay(
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading preview…").foregroundStyle(.secondary)
                        }
                    )
                    .shadow(color: primaryShadowColor(scheme), radius: 5, x: 0, y: 2)
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

// MARK: - Adaptive shadows

private func primaryShadowColor(_ scheme: ColorScheme) -> Color {
    switch scheme {
    case .light: return Color.black.opacity(0.1)
    case .dark: return Color.white.opacity(0.08)
    @unknown default: return Color.black.opacity(0.1)
    }
}

private func subtleShadowColor(_ scheme: ColorScheme) -> Color {
    switch scheme {
    case .light: return Color.black.opacity(0.06)
    case .dark: return Color.white.opacity(0.05)
    @unknown default: return Color.black.opacity(0.06)
    }
}

