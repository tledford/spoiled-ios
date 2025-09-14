# API Integration Status (Spoiled iOS)

Last updated: 2025-08-16

## Summary

Core API wiring is in place and working for bootstrap, wishlist (user and kids), gift ideas, and profile updates. Group and kid management UIs still perform local-only changes with TODOs; and there’s no API to let group members mark another user’s item as purchased.

## Environment/config

- Base URL: defined in `AppConfig.api` (currently http://192.168.1.179:8787/api/v1).
- Dev identity: iOS sends `X-User-Id` header from `AppConfig.devUserId` (matches backend dev middleware).
- Bootstrap: App loads all initial data via `GET /api/v1/bootstrap` (see `BootstrapService`).

## What’s working (Done)

- Networking layer: `APIClient` with JSON, error decoding, ISO8601 dates, and dev header.
- Bootstrap load: `BootstrapService.load()` maps server shapes into app models (`User`, `Group`, `Kid`, `WishlistItem`, `GiftIdea`).
- My wishlist (user): create/update/delete via `WishlistService` ->
  - POST/PATCH/DELETE `/users/:userId/wishlist/:itemId?`
- Kids’ wishlist: create/update/delete via `WishlistService` ->
  - POST/PATCH/DELETE `/users/:userId/kids/:kidId/wishlist/:itemId?`
- Gift ideas: create/update/delete via `GiftIdeasService` ->
  - POST/PATCH/DELETE `/users/:userId/gift-ideas/:ideaId?`
- Profile update: `UsersService.updateUser` ->
  - PATCH `/users/:userId`
- View model uses the above services for add/update/delete and updates local state; saving flags and error handling are in place.

## Gaps and remaining work (To‑Do)

1. Groups API integration (client + UI)

- Missing iOS service for groups; UI methods are TODO-only:
  - `WishlistViewModel.addGroup(_:)`
  - `WishlistViewModel.updateGroup(_:newName:)`
  - `WishlistViewModel.addMemberToGroup(email:to:)`
  - `WishlistViewModel.removeMemberFromGroup(_:from:)`
- Backend routes available and should be wired:
  - POST `/groups` (create; adds current user as admin)
  - PATCH `/groups/:groupId` (rename; admin only)
  - POST `/groups/:groupId/members` (add by userId or email; admin only)
  - DELETE `/groups/:groupId/members/:userId` (remove member; admin only)
  - Optional: DELETE `/groups/:groupId` (not exposed in UI yet)

2. Kids management (client + UI)

- `AddKidView` and `EditKidView` only mutate local state with TODOs.
- Backend routes to use (create service `KidsService`):
  - GET `/users/:userId/kids` (optional; bootstrap already gives full kid objects)
  - POST `/users/:userId/kids` (create)
  - PATCH `/users/:userId/kids/:kidId` (update)
  - DELETE `/users/:userId/kids/:kidId` (remove link or delete; guarded by guardian checks)

3. Group member “mark purchased” workflow (requires backend + iOS)

- Current UI calls `WishlistViewModel.toggleItemPurchased(...)` but it’s local-only and labeled TODO.
- Backend has `wishlist_items.is_purchased`, `purchased_by`, `purchased_at`, but no route allowing non-owners to toggle based on shared group.
- Proposal:
  - Add a route, e.g. `POST /groups/:groupId/wishlist/:itemId/purchase` with `{ purchased: boolean }` that:
    - Validates current user is a member of `:groupId` and item is visible in that group (owner assigned to that group).
    - Updates `is_purchased`, `purchased_by` = currentUserId or `NULL`, and `purchased_at` accordingly.
  - iOS: add `togglePurchase(groupId:itemId:memberId:purchased:)` in `WishlistService` (or `GroupActionsService`) and call it from `WishlistViewModel.toggleItemPurchased`.

4. Data refresh consistency

- After group/kid operations, do a light refresh (re-run bootstrap or narrowly fetch changed resource) to prevent state drift.

5. Configuration polish

- Provide per-scheme `AppConfig` presets (Dev/Prod), and optionally read host/port from Info.plist or environment. Support HTTPS when deployed.

6. Polishing and tests

- Add simple unit tests for request building (paths/methods/body) and mapping logic.
- Manual test script (see below) to validate common flows.

## Mapping: UI feature → API route → Status

- App launch: `GET /bootstrap` → Done
- My wishlist: `POST/PATCH/DELETE /users/:userId/wishlist` → Done
- Kids’ wishlist: `POST/PATCH/DELETE /users/:userId/kids/:kidId/wishlist` → Done
- Gift ideas: `POST/PATCH/DELETE /users/:userId/gift-ideas` → Done
- Edit profile: `PATCH /users/:userId` → Done
- Create/rename group: `POST /groups`, `PATCH /groups/:groupId` → To‑Do (client)
- Add/remove group member: `POST /groups/:groupId/members`, `DELETE /groups/:groupId/members/:userId` → To‑Do (client)
- Mark member item purchased: proposed `POST /groups/:groupId/wishlist/:itemId/purchase` → To‑Do (backend + client)
- Add/update/delete kid (entity): `/users/:userId/kids` (+ `:kidId`) → To‑Do (client)

## Concrete next steps

- Implement `GroupsService` in iOS with methods: create, rename, addMember(email|userId), removeMember, delete(optional).
- Wire `AddGroupView`, `EditGroupView`, and related `WishlistViewModel` methods to the service; on success, update local state and consider a background bootstrap refresh.
- Implement `KidsService` in iOS with methods: create, update, delete; wire `AddKidView` and `EditKidView`.
- Add backend route for group member purchase toggle; update iOS to call it from `WishlistViewModel.toggleItemPurchased`.
- Add lightweight refresh after mutating operations (groups/kids) to keep derived data in sync.
- Optional: expose a pull-to-refresh on Groups and Gift Ideas screens (already present on Wishlist).

## Manual test checklist (Dev)

1. Run the API (wrangler dev) and seed: enable `SEED_ENABLED`, call `POST /api/dev/seed?reset=true`.
2. In iOS, set `AppConfig.api` host to your machine (or tunnel), confirm port matches wrangler.
3. Launch app:
   - Wishlist loads with items and groups; Gift Ideas show seeded data; Kids appear.
4. Verify:
   - Add/Update/Delete Gift Idea.
   - Add/Update/Delete My Wishlist item (with group assignments) and confirm assignments show in Group detail.
   - Add/Update/Delete Kid item.
5. After implementing Groups/Kids services:
   - Create group, rename, add/remove member by email.
   - Create/Edit/Delete Kid entity.
6. After adding “mark purchased” route:
   - In a group, toggle a member’s item purchased state and see the change persist across refresh.
