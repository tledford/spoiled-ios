import SwiftUI

struct ShareComposerView: View {
    @ObservedObject var model: ShareComposerModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case name, link, details, person }

    var body: some View {
        NavigationStack {
            content
                .background(Color.appBackground.ignoresSafeArea())
                .navigationTitle("Add to Spoiled")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button { model.cancel() } label: {
                            Text("Cancel").navButton(isIcon: false)
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task { await model.save() }
                        } label: {
                            if model.isSaving {
                                ProgressView()
                            } else {
                                Text("Add").navButton(isIcon: false)
                            }
                        }
                        .disabled(!model.canSave)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Reading the page…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .signedOut:
            statusMessage(icon: "person.crop.circle.badge.exclamationmark",
                          title: "Sign in first",
                          message: "Open Spoiled and sign in, then you can save straight from the share sheet.")
        case .failed(let message):
            statusMessage(icon: "wifi.exclamationmark", title: "Can't load your lists", message: message)
        case .ready:
            form
        }
    }

    private var form: some View {
        ScrollView {
            VStack(spacing: 24) {
                destinationSection
                detailsSection
                if case .giftIdea = model.destination { personSection }
                if model.destination.isWishlist, !model.groups.isEmpty { groupsSection }
                if let errorMessage = model.errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Sections

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionHeader(icon: "tray.and.arrow.down.fill", title: "Save To")
            VStack(spacing: 0) {
                destinationRow(.myWishlist, label: "My Wishlist") {
                    icon("gift.fill")
                }
                ForEach(model.kids) { kid in
                    Divider().padding(.leading, 16)
                    destinationRow(.kid(kid.id), label: kid.name) {
                        PersonAvatar(name: kid.name, size: 28)
                    }
                }
                Divider().padding(.leading, 16)
                destinationRow(.giftIdea, label: "Gift Idea") {
                    icon("lightbulb.fill")
                }
            }
            .spoiledCard()
        }
    }

    private func destinationRow<Leading: View>(_ destination: ShareComposerModel.Destination,
                                               label: String,
                                               @ViewBuilder leading: () -> Leading) -> some View {
        Button {
            model.destination = destination
        } label: {
            HStack(spacing: 10) {
                leading()
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
                Spacer()
                if model.destination == destination {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brandGold)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func icon(_ systemName: String) -> some View {
        ZStack {
            Circle().fill(Color.brandGold.opacity(0.18))
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.brandGold)
        }
        .frame(width: 28, height: 28)
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionHeader(icon: "info.circle.fill", title: "Item Details")
            VStack(spacing: 0) {
                field(label: nameLabel) {
                    HStack(spacing: 8) {
                        TextField("What is it?", text: $model.name)
                            .focused($focusedField, equals: .name)
                        if model.isEnrichingTitle {
                            ProgressView().controlSize(.small)
                        }
                    }
                }

                Divider().padding(.leading, 16)

                field(label: "Link") {
                    TextField("https://", text: $model.linkString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .textContentType(.URL)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .link)
                }

                Divider().padding(.leading, 16)

                field(label: model.destination.isWishlist ? "Description" : "Notes") {
                    TextField("Optional notes…", text: $model.details, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .details)
                }
            }
            .spoiledCard()
        }
    }

    private var nameLabel: String {
        model.destination.isWishlist ? "Item Name" : "Gift Name"
    }

    private var personSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionHeader(icon: "person.fill", title: "Who Is It For")
            VStack(spacing: 0) {
                field(label: "Person's Name") {
                    HStack(spacing: 8) {
                        TextField("Name", text: $model.personName)
                            .textInputAutocapitalization(.words)
                            .focused($focusedField, equals: .person)
                        PersonSuggestionMenu(suggestions: model.peopleSuggestions,
                                             selection: $model.personName)
                    }
                }
            }
            .spoiledCard()
        }
    }

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppSectionHeader(icon: "person.3.fill", title: "Share with Groups")
            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { model.selectedGroupIds.count == model.groups.count && !model.groups.isEmpty },
                    set: { isSelected in
                        if isSelected { model.selectedGroupIds = Set(model.groups.map { $0.id }) }
                        else { model.selectedGroupIds.removeAll() }
                    }
                )) {
                    Label("All Groups", systemImage: "person.3.fill")
                        .font(.system(size: 15, weight: .semibold))
                }
                .tint(.brandGold)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                ForEach(model.groups) { group in
                    Divider().padding(.leading, 16)
                    Toggle(isOn: Binding(
                        get: { model.selectedGroupIds.contains(group.id) },
                        set: { isSelected in
                            if isSelected { model.selectedGroupIds.insert(group.id) }
                            else { model.selectedGroupIds.remove(group.id) }
                        }
                    )) {
                        Text(group.name)
                    }
                    .tint(.brandGold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .spoiledCard()

            if model.selectedGroupIds.isEmpty {
                Label("Not shared — only visible to you", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Color.brandGold.opacity(0.8))
                    .padding(.horizontal, 4)
            }
        }
    }

    private func statusMessage(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.brandGold.opacity(0.8))
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Close") { model.cancel() }
                .buttonStyle(.borderedProminent)
                .tint(.brandGold)
                .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
