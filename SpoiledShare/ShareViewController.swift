import UIKit
import SwiftUI
import FirebaseCore

/// Hosts the SwiftUI composer that the iOS share sheet presents.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureFirebase()

        let items = (extensionContext?.inputItems as? [NSExtensionItem]) ?? []
        let model = ShareComposerModel { [weak self] saved in
            self?.finish(saved: saved)
        }

        // Match the appearance the user picked in the app (stored in the App Group).
        let composer = ShareComposerView(model: model)
            .preferredColorScheme(ThemeStore.currentColorScheme)
        let host = UIHostingController(rootView: composer)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)

        Task { await model.start(items: items) }
    }

    private func configureFirebase() {
        // The signed-in user comes from the keychain group shared with the app; see
        // `FirebaseSession` for why no access-group call is needed here.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    private func finish(saved: Bool) {
        if saved {
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        } else {
            extensionContext?.cancelRequest(withError: NSError(domain: NSCocoaErrorDomain,
                                                               code: NSUserCancelledError))
        }
    }
}
