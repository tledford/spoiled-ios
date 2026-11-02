# Copilot Instructions for Spoiled iOS

## Build & Test

Open `Spoiled.xcodeproj` in Xcode. Build and run with `Cmd+R` or via `xcodebuild`:

```bash
# Build
xcodebuild -project Spoiled.xcodeproj -scheme Spoiled -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild -project Spoiled.xcodeproj -scheme Spoiled -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test
xcodebuild -project Spoiled.xcodeproj -scheme SpoiledTests -destination 'platform=iOS Simulator,name=iPhone 16' test -only-testing:SpoiledTests/SpoiledTests/example
```

Tests use Swift Testing (`@Test`, `#expect`), not XCTest.

## Related Repositories

The backend lives at `../spoiled-api-cf` (relative to this repo). It is a **Cloudflare Worker** built with **Hono** and **Drizzle ORM** backed by **Cloudflare D1** (SQLite). Routes mirror the iOS service layer 1:1 — `src/routes/bootstrap.ts`, `wishlist.ts`, `groups.ts`, `kids.ts`, `giftIdeas.ts`, `users.ts`. Firebase JWT verification is handled in `src/middleware/auth.ts`.

```bash
# From ../spoiled-api-cf
npm run dev        # local dev server at http://localhost:8787
npm run deploy     # deploy to Cloudflare
npm test           # vitest (runs in @cloudflare/vitest-pool-workers)
npm run seed       # seed local D1 with test data
npm run seed:reset # reset and re-seed
```

To hit the local worker from the app, see Environment switching below.

## Architecture

**MVVM + SwiftUI** with Firebase auth and a Cloudflare Worker backend.

### Targets and folders

- **`Spoiled/`** — the app target: entry point, auth, view models, and views.
- **`Shared/`** — a synchronized folder that is a member of *both* the app and the share
  extension: models, networking, `AppConfig`, date parsing, the design system, and the
  App Group plumbing (`SharedContainer`, `ShareSnapshot`, `FirebaseSession`). Anything the
  extension needs lives here; do not add app-only code (view models, screens) to it.
- **`SpoiledShare/`** — the share extension target (`dev.tomled.Spoiled.Share`).

### Layer overview

- **`SpoiledApp.swift`** — App entry point. Owns `WishlistViewModel`, `AuthViewModel`, and `ToastCenter` as `@StateObject`s; injects all three as `@EnvironmentObject` into the hierarchy.
- **Auth** (`Auth/`) — `AuthStore` protocol → `DefaultAuthStore` (Firebase implementation) → `AuthViewModel` (`@MainActor` `ObservableObject` wrapper used by views). Supports Google Sign-In and Apple Sign-In.
- **Networking** (`Shared/Networking/`) — `APIClient` executes typed `APIRequest` values. Services (`WishlistService`, `GroupsService`, etc.) are thin structs that wrap `APIClient`. All services accept an `APIClient` in `init`, defaulting to an unauthenticated one.
- **ViewModel** (`ViewModels/WishlistViewModel.swift`) — Single `@MainActor ObservableObject` that holds all app state (`currentUser`, `groups`, `kids`, `wishlistItems`, `giftIdeas`). After authentication, `configureAuth(using:)` is called to rebuild services with an auth-backed `APIClient`.
- **Models** (`Shared/Models/`) — Plain Swift value types (`WishlistItem`, `Group`, `Kid`, `GiftIdea`, `User`).
- **Views** (`Views/`) — SwiftUI views. Consume `WishlistViewModel` and `ToastCenter` via `@EnvironmentObject`.

### Bootstrap pattern

The app loads all state in a single call to `GET /api/v1/bootstrap`. `BootstrapService` decodes the response into `API*` intermediary types, then maps them to app models. If the user doesn't exist (404 `NOT_FOUND`), it auto-creates the user and retries.

### When a load fails

`WishlistViewModel.load()` reports through `loadFailure`, never `errorMessage`, which is only for saves. `ContentView` shows the tabs only once there's a `currentUser`; otherwise it shows `ConnectionErrorView`, so a failed load can't pass for an empty account. With data on screen, `StaleDataBanner` says it may be out of date.

Failed loads retry at 5, 15, 30 and 60 seconds, then wait for the 5-minute timer, and retry immediately when `ConnectionMonitor` sees the connection return. `BootstrapCache` keeps the last good bootstrap on disk so the app opens with data offline, and is deleted on sign-out. There is no offline queue: saves fail and roll back.

Show errors with `error.userFacingMessage`. Status codes and request IDs belong in logs.

### Dual model pattern

Every resource has:
1. An `API*` struct (e.g., `APIWishlistItem`) used only for decoding — tolerant of null/missing fields.
2. An app model struct (e.g., `WishlistItem`) used everywhere else.

Conversion happens via `asAppModel()` extension methods in `BootstrapService.swift`. Dates from the API always go through `parseAPIDate()` (`Shared/Utils/DateParsing.swift`), which handles ISO8601, `yyyy-MM-dd`, and unix epoch strings.

### Purchases and quantities

`WishlistItem` has a `quantityDesired` (default 1, up to 99) and `purchases`, one entry per person who bought some. `isPurchased` is computed: the total bought has reached `quantityDesired`. Members change only their own count, through `WishlistViewModel.setItemPurchaseQuantity`. `purchases` is only populated on group copies of an item; the API sends it empty on the owner's own copies, so owners can't see what's been bought. Check `isInGroupView` before showing purchase state.

### Joining groups

Nobody joins a group without agreeing. Admins invite by email, which only creates a pending invitation, or share the group's invite link. An email invitation appears in `WishlistViewModel.groupInvitations` when it matches the verified address on the user's token, and Spoiled sends no email. Invite links (`https://prod.tomled.dev/invite/<code>`) arrive through `.onOpenURL` in `SpoiledApp` and are held in the `pendingInviteCode` app storage until `ContentView` can show `JoinGroupView`, so they survive sign-in. Someone installing the app from the link's landing page types the code instead, since there are no deferred deep links. Every path ends at a screen saying what joining shares (`GroupSharingNotice`).

### 401 auto-retry

`APIClient.execute()` retries once with a force-refreshed Firebase ID token on HTTP 401. It posts `Notification.Name.authUnauthorized`, which `SpoiledApp` listens to in order to sign the user out, only when the session has really ended: the refreshed token was rejected too, or Firebase reports the session is over (`FirebaseSession.isSessionOver`).

Anything temporary must not sign the user out. If a token can't be fetched for another reason, like having no connection, `execute()` throws `APIError.tokenUnavailable` and sends nothing. The worker returns 503 `AUTH_UNAVAILABLE`, not 401, when it can't check a token.

### Share extension

`SpoiledShare` lets the user save a shared page straight to their wishlist, one of their
kids' wishlists, or a gift idea.

- **Auth** — the extension reads the app's Firebase session out of the shared keychain
  group `$(AppIdentifierPrefix)dev.tomled.Spoiled`. This works purely through entitlements:
  Firebase stores the user with no explicit access group, so it lands in each process's
  default group, and both targets declare that one group. Never call
  `Auth.auth().useUserAccessGroup(_:)` — it switches to a different keychain item, does not
  bring the existing user across, and deletes the old one, signing everybody out on update
  (see the note in `Shared/FirebaseSession.swift`). With no session the extension shows a
  "sign in first" state instead of failing silently.
- **App state** — `WishlistViewModel` mirrors the user id, kids, groups, and gift-idea
  people into the App Group `group.dev.tomled.Spoiled` (`ShareSnapshotStore`) on every
  state change. The extension reads that for an instant form; if the cache is missing it
  calls `/bootstrap` itself.
- **Prefill** — `SharePreprocessor.js` runs inside the Safari page and returns title,
  description, price, and any selected text. Shares from other apps arrive as a URL or
  plain text, and `SharedLinkParser` falls back to `LPMetadataProvider` for the title.
  `SharedTitleCleaner` (in `Shared/`, so it is unit-testable) trims store prefixes and
  trailing site names. Every parsed field is editable before saving.
- **Capabilities** — the App Group and Keychain Sharing entitlements are on both targets.
  A device build needs those capabilities registered for both App IDs.

## Key Conventions

### Environment switching

Builds use production unless a Debug build is given a local worker's address. Release builds always use production; `AppConfig` reads the address only under `#if DEBUG`.

- **On the iPhone:** `./build-deploy.sh --local [port]` finds this Mac's network address and passes it as build settings. The default port is 8788, because something else on this Mac usually holds 8787.
- **From Xcode:** copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` (git-ignored) and fill it in. Delete it to go back to production.
- **The worker:** `npm run dev -- --port 8788` in `../spoiled-api-cf`.

`SPOILED_LOCAL_API_HOST` and `SPOILED_LOCAL_API_PORT` reach the app through the `SpoiledLocalAPIHost` and `SpoiledLocalAPIPort` keys in both targets' Info.plist.

### Adding a new service method

1. Define a private `struct *Request: APIRequest` with `typealias Response = ...`.
2. Add a method to the service struct that calls `client.execute(...)`.
3. Call from `WishlistViewModel` using the `_*ServiceOverride` (set by `configureAuth`) rather than the stored `let` property.

### Toast feedback

Inject `@EnvironmentObject private var toastCenter: ToastCenter` and call:

```swift
toastCenter.success("Item saved.")
toastCenter.error("Something went wrong.")
toastCenter.info("Welcome!")
```

### Analytics

All events go through static methods on `AnalyticsEvents` (enum in `Analytics/AnalyticsEvents.swift`). Event names use `lowercase_with_underscores`. Add new events there.

Screen tracking uses the `.trackScreen("ScreenName")` view modifier applied to the root content of a screen.

### `OkResponse`

API calls that return no meaningful body use a shared `OkResponse` decodable type (defined in one of the service files). Discard the result with `_ = try await client.execute(...)`.

### Text sizes and VoiceOver

Text has to grow with Dynamic Type. Use a text style (`.font(.subheadline.weight(.semibold))`), or `.scaledFont(size:relativeTo:)` for display sizes no style matches. Don't use `.font(.system(size:))`. Rows with several columns stack at accessibility sizes (`dynamicTypeSize.isAccessibilitySize`, with `AnyLayout` so views keep their identity).

Icon-only buttons need an `.accessibilityLabel`. Decorative icons get `.accessibilityHidden(true)`, and section titles get the `.isHeader` trait.

### Debug logging

`WishlistViewModel` uses `OSLog` behind `#if DEBUG` guards. Use the `dlog()`/`elog()` helpers — don't use `print()`.
