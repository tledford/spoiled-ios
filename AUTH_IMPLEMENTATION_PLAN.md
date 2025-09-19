# Firebase Implementation Plan (Auth + Analytics + Crashlytics)

Goal: Integrate Firebase Authentication (start with Google sign-in; Apple Sign-In deferred), Firebase Analytics, and Firebase Crashlytics into the iOS app. Update the backend (Cloudflare Worker) to verify Firebase ID tokens on protected routes. Keep the existing dev header path available in development.

This plan is phased to ship incrementally without breaking current dev flows.

---

## Phase 0 – Firebase setup and UX entry points

Scope

- Create Firebase project and iOS app in Firebase console.
- Download and add `GoogleService-Info.plist` to the iOS target.
- Add SPM dependencies: `FirebaseAuth`, `FirebaseAnalytics`, `FirebaseCrashlytics`, and `GoogleSignIn` (used by Firebase for Google flow).
- Apple Sign-In capability: deferred to a later phase.
- Define auth UX: Splash screen with “Continue with Google” button; add Settings logout. (Apple button optional placeholder; wiring deferred.)
- Create iOS Auth scaffolding (no backend dependency yet):
  - AuthState and AuthStore protocol
  - Basic `SplashView` with a Google button (Apple deferred)
- Keep existing app screens accessible when AuthState == authenticated.
- No backend changes yet; app still uses existing API with `X-User-Id` in dev.

Deliverables

- Swift files: `AuthStore.swift` (protocol), `SplashView.swift`, minimal `AuthViewModel`.
- Wire Splash into `SpoiledApp.swift` so it decides between Splash and the main app based on AuthState.
- Add Firebase initialization to app startup (configure SDKs, enable Crashlytics/Analytics).

Acceptance

- Building the app shows Splash when AuthState == unauthenticated and routes to the app when set to authenticated (temporarily mocked).

Notes

- Keep feature-flag/toggle to bypass Splash during development while backend work lands.

---

## Phase 1 – iOS Firebase Auth (Google only), Analytics, Crashlytics

Scope

- Integrate Firebase Authentication flow for Google sign-in only.
- Configure Google URL scheme (from `GoogleService-Info.plist` reversed client id).
- On sign-in, Firebase handles tokens and secure persistence automatically (no manual Keychain tokens needed).
- Integrate Firebase Analytics and Crashlytics with minimal setup.

Details

- Dependencies via SPM: `FirebaseAuth`, `FirebaseAnalytics`, `FirebaseCrashlytics`, `GoogleSignIn`.
- Firebase config: `FirebaseApp.configure()` in app startup.
- Google: Use `GIDSignIn` to obtain Google credential, then `Auth.auth().signIn(with:)` to Firebase.
- Analytics: Default collection enabled; set userId after login.
- Crashlytics: Enabled by default; set userId and key user properties. Ensure dSYM upload is configured for SPM via a Run Script build phase.
- UX: Splash shows Google button; after successful Firebase sign-in, route to app.

Acceptance

- Google sign-in completes successfully on device/simulator; Splash routes to app; Analytics and Crashlytics initialize without errors.

Risk/Note

- Ensure Crashlytics dSYM upload is set (SPM may require manual build phase script).

Note on Apple Sign-In (deferred)

- Apple capability and flow will be implemented in a later phase. Apple’s full name is only available on first consent; store if present and avoid overwriting later when implemented.

---

## Phase 2 – Backend: verify Firebase ID tokens

Scope

- Add authentication middleware to Cloudflare Worker (Hono) that accepts `Authorization: Bearer <Firebase ID Token>`.
- Verify Firebase ID tokens and set `currentUserId` from the verified Firebase UID.
- Keep existing dev header (`X-User-Id`) behind an `ENV=dev` flag for local/testing.

Backend design

- Users table updates:
  - Add column: `firebase_uid` (unique), plus `name`, `email`, `avatar_url`, `last_login_at` (as needed).
- Refresh tokens storage:
  - Not needed; Firebase manages refresh tokens and session persistence on the client.
- Tokens
  - Use Firebase ID token as the bearer token; verify signature and claims.
- Endpoints
  - No auth endpoints are required; the app signs in directly with Firebase.
- Middleware
  - If `Authorization: Bearer <idToken>` (Firebase) present and valid, set `currentUserId` = verified UID and proceed.
  - If `ENV=dev` and `X-User-Id` present, allow (for development only).
  - Otherwise 401.

Verification notes

- Firebase ID token claims:
  - `iss = https://securetoken.google.com/<project-id>`
  - `aud = <project-id>`
  - `sub = <firebase-uid>`
- Certificates (x509) URL: `https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com` (cache per Cache-Control headers).
- Reject tokens if expired or if `aud`/`iss` do not match configured project id.

Acceptance

- Protected routes accept Firebase ID tokens. Dev header path still works locally when flagged.

---

## Phase 3 – iOS token usage, auto-refresh, and API integration

Scope

- Use FirebaseAuth to retrieve a fresh ID token when needed and attach it to all API requests as `Authorization: Bearer <idToken>`.
- Handle automatic token refresh via Firebase SDK; no manual Keychain storage required.
- On 401, fetch a fresh ID token (`getIDTokenForcingRefresh`) once and retry; if still unauthorized, sign out or present Splash.

iOS details

- AuthStore responsibilities:
  - getValidIDToken(): returns current ID token or asks Firebase to refresh.
  - signInWithGoogle(): Firebase Google flow; on success, update auth state and set Analytics/Crashlytics user id.
  - signOut(): `Auth.auth().signOut()`, also `GIDSignIn.sharedInstance.signOut()`, clear app state.
- APIClient
  - Adds Authorization header if `getValidIDToken()` returns a token.
  - Retries once on 401 with forced refresh; then fails and emits sign-out if still unauthorized.
- Security
  - Firebase SDK persists auth securely; no manual Keychain storage.

Acceptance

- Fresh install: Splash → Firebase login → app loads with data using Bearer ID token.
- Relaunch: app resumes session silently.
- Expired token scenarios auto-recover without user impact.

---

## Phase 4 – Logout, settings, and observability

Scope

- Add Logout button in Settings; on tap, sign out of Firebase and show Splash.
- UX fallbacks: if token refresh fails (revoked/expired), show Splash and a toast explaining session expired.
- Observability: identify user to Analytics/Crashlytics (`setUserID`), log auth events, and add key properties.

Acceptance

- Logout reliably returns the app to Splash; subsequent API calls are unauthenticated until login.

---

## Phase 5 – Hardening and polish

Scope

- Backend: cache Firebase certs (per Cache-Control) to reduce verification latency.
- Rate limit protected routes.
- Improve middleware error responses with consistent JSON.
- Add tests:
  - Backend: valid/invalid Firebase ID token, expired token, wrong project id, dev header path.
  - iOS: unit tests for AuthStore, APIClient refresh-on-401 behavior; basic Analytics/Crashlytics wiring validation.
- Documentation: update `API_INTEGRATION_STATUS.md` and add iOS README snippets.

---

## iOS Tasks Breakdown

- Dependencies

  - Add SPM packages: `FirebaseAuth`, `FirebaseAnalytics`, `FirebaseCrashlytics`, `GoogleSignIn`.
  - Apple’s `AuthenticationServices` and capability will be added in Phase 6.

- Files to add

  - `Auth/AuthStore.swift` – protocol + concrete `DefaultAuthStore` implementing the flows above.
  - `Auth/AuthViewModel.swift` – publishes `authState`, exposes `signIn()`/`signOut()`.
  - `UI/SplashView.swift` – Google button, errors, loading indicator. (Apple button added later.)

- App wiring

  - In `SpoiledApp.swift`, observe `AuthViewModel.authState`:
    - unauthenticated → `SplashView`
    - authenticated → current root (`ContentView`)
  - Initialize Firebase in `SpoiledApp` startup; set Crashlytics/Analytics user id on login.

- Networking integration

  - Update `APIClient.swift` to inject Firebase ID token in Authorization header and support 401 refresh.
  - Bootstrap: after sign-in/refresh, call `BootstrapService` to load initial user state.

- Logout
  - Button in `SettingsView` calling `AuthViewModel.signOut()`.

---

## Backend Tasks Breakdown (Cloudflare Worker + Hono)

- Env/config

  - Settings: `FIREBASE_PROJECT_ID`, `ENV` (dev/prod).
  - Cache Firebase certs; refresh per Cache-Control headers.

- Routes

  - No `/auth/*` routes required; clients authenticate via Firebase.

- Middleware

  - Parse and verify Bearer Firebase ID token; set `currentUserId`.
  - Allow `X-User-Id` only when `ENV=dev`.

- Data

  - Migration for `users` table to add `firebase_uid` and backfill current dev user as needed.

- Integration
  - Ensure all existing routes that currently assume `currentUserId` work with token-derived IDs.

---

## Contracts (quick reference)

- Authorization header: `Authorization: Bearer <Firebase ID Token>`
- Claims: `iss=https://securetoken.google.com/<project-id>`, `aud=<project-id>`, `sub=<firebase-uid>`, `exp`, `iat`.
- Backend maps `sub` (UID) to internal user id (or uses UID directly as user id if desired).

Error modes

- 400 – invalid body
- 401 – invalid/expired token
- 403 – revoked session
- 429 – rate limited

---

## Rollout and Migration

- Keep current dev flow working until middleware verification is ready.
- Ship Phase 1 to TestFlight as internal-only.
- After Phase 2 lands, gate routes in staging to require Firebase tokens; verify happy paths.
- Enable token verification in production; remove reliance on `X-User-Id` except in local dev.

---

## Open Questions / Decisions

- Event taxonomy for Analytics (names, parameters) and PII policy.
- Whether to use Firebase UID as our primary user id or map to our existing UUIDs.
- Crash-free target thresholds and alerting.

---

## Definition of Done (initial Firebase integration)

- User can sign in with Google via Firebase, and the app loads data with Authorization header carrying Firebase ID token. (Apple Sign-In deferred.)
- Relaunch resumes session silently.
- Logout signs the user out and returns to Splash.
- Analytics and Crashlytics are initialized and tagged with the user id.

---

## Next Step

- Proceed with Phase 1: Add Firebase via SPM, initialize in app startup, wire Google sign-in to FirebaseAuth, and add basic Analytics/Crashlytics.

---

## Phase 6 – iOS Apple Sign-In (Deferred)

Scope

- Integrate Apple Sign-In flow and capability in Xcode target.
- Add Apple button to Splash (or enable it if already present) and wire to FirebaseAuth.

Details

- Enable Sign In with Apple capability in the app target.
- Use `ASAuthorizationAppleIDProvider` to obtain credential; exchange via `OAuthProvider.credential(withProviderID: "apple.com", idToken:rawNonce:)` into Firebase.
- Handle user’s full name on first consent; persist if present and avoid overwriting later.
- Update Analytics/Crashlytics user identification on Apple login.

Acceptance

- Apple Sign-In completes successfully; app routes to main; Analytics/Crashlytics work.
