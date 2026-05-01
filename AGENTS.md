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

To hit the local worker from the app, toggle `AppConfig.swift` (see Environment switching below).

## Architecture

**MVVM + SwiftUI** with Firebase auth and a Cloudflare Worker backend.

### Layer overview

- **`SpoiledApp.swift`** — App entry point. Owns `WishlistViewModel`, `AuthViewModel`, and `ToastCenter` as `@StateObject`s; injects all three as `@EnvironmentObject` into the hierarchy.
- **Auth** (`Auth/`) — `AuthStore` protocol → `DefaultAuthStore` (Firebase implementation) → `AuthViewModel` (`@MainActor` `ObservableObject` wrapper used by views). Supports Google Sign-In and Apple Sign-In.
- **Networking** (`Networking/`) — `APIClient` executes typed `APIRequest` values. Services (`WishlistService`, `GroupsService`, etc.) are thin structs that wrap `APIClient`. All services accept an `APIClient` in `init`, defaulting to an unauthenticated one.
- **ViewModel** (`ViewModels/WishlistViewModel.swift`) — Single `@MainActor ObservableObject` that holds all app state (`currentUser`, `groups`, `kids`, `wishlistItems`, `giftIdeas`). After authentication, `configureAuth(using:)` is called to rebuild services with an auth-backed `APIClient`.
- **Models** (`Models/`) — Plain Swift value types (`WishlistItem`, `Group`, `Kid`, `GiftIdea`, `User`).
- **Views** (`Views/`) — SwiftUI views. Consume `WishlistViewModel` and `ToastCenter` via `@EnvironmentObject`.

### Bootstrap pattern

The app loads all state in a single call to `GET /api/v1/bootstrap`. `BootstrapService` decodes the response into `API*` intermediary types, then maps them to app models. If the user doesn't exist (404 `NOT_FOUND`), it auto-creates the user and retries.

### Dual model pattern

Every resource has:
1. An `API*` struct (e.g., `APIWishlistItem`) used only for decoding — tolerant of null/missing fields.
2. An app model struct (e.g., `WishlistItem`) used everywhere else.

Conversion happens via `asAppModel()` extension methods in `BootstrapService.swift`. Dates from the API always go through `parseAPIDate()` (`Utils/DateParsing.swift`), which handles ISO8601, `yyyy-MM-dd`, and unix epoch strings.

### 401 auto-retry

`APIClient.execute()` retries once with a force-refreshed Firebase ID token on HTTP 401. If it still fails, it posts `Notification.Name.authUnauthorized`, which `SpoiledApp` listens to in order to sign the user out.

## Key Conventions

### Environment switching

`AppConfig.swift` has two commented lines. Toggle the comment to switch between the local worker (`../spoiled-api-cf` running on `npm run dev`) and production:

```swift
// static var api = APIConfig(scheme: "http", host: "192.168.1.178", port: 8787, version: "v1") // Local dev
static var api = APIConfig(scheme: "https", host: "prod.tomled.dev", version: "v1") // CF Worker
```

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

### Debug logging

`WishlistViewModel` uses `OSLog` behind `#if DEBUG` guards. Use the `dlog()`/`elog()` helpers — don't use `print()`.
