# Manual Testing Log - Butlery App

**Status**: 459/459 completed (100%) — 438 passed, 1 failed (BUG-032), 20 N/A, 1 open bug (BUG-035)
**Tested**: 2026-01-07 to 2026-03-14 (34 sessions)
**Credentials**: User A: malin.gisslen1@gmail.com / Test1234 | User B: test.testsson2@gmail.com / TestPass123!

## Summary

| Phase | Tests | Passed | N/A | Notes |
|-------|-------|--------|-----|-------|
| 1. Authentication | 14 | 13 | 1 | AUTH-08 MFA settings (post-beta) |
| 2. Navigation & Home | 27 | 27 | 0 | |
| 3. Recipe Detail & Editing | 33 | 31 | 2 | Image upload N/A on web |
| 4. Recipe Import | 32 | 28 | 4 | File upload N/A on web |
| 5. Weekly Menu | 13 | 13 | 0 | |
| 6. Shopping Lists | 29 | 29 | 0 | |
| 7. Social Features | 40 | 35 | 5 | |
| 8. Messaging | 23 | 22 | 1 | Typing indicator needs 2 users |
| 9. Personal Tags | 21 | 21 | 0 | |
| 10. Settings & Account | 23 | 23 | 0 | |
| 11. Dialogs & Modals | 11 | 11 | 0 | |
| 12. Widgets & Components | 44 | 44 | 0 | |
| 13. Responsive Design | 9 | 9 | 0 | |
| 14. Accessibility | 7 | 6 | 1 | A11Y-06 keyboard nav (CanvasKit limitation) |
| 15. Error Handling | 13 | 13 | 0 | |
| 16. Social E2E | 30 | 30 | 0 | Multi-user verification |
| 17. Import Tagging | 32 | 27 | 4 | 1 FAIL: BUG-032 ICA URL import |
| 18. Tag & Allergen System | 58 | 56 | 2 | |
| **TOTAL** | **459** | **438** | **20** | **1 failed** |

## Bug Tracker

### Open

| ID | Title | Severity |
|----|-------|----------|
| BUG-035 | Share-to-group fails ("Kunde inte uppdatera gruppdelning") — hardcoded `ResourcePermission.read` ignores collaboration flag + Firestore `isValidTagResult` may reject write | Medium |

### Known Limitation

| ID | Title |
|----|-------|
| BUG-032 | ICA.se URL import fails — external site changed HTML format. Other URL sources work. |

### Fixed (33 bugs)

| ID | Title | Root Cause |
|----|-------|------------|
| BUG-003 | Recipe save fails on web | Firestore rules rejected v2 fields + null repository on auth state change |
| BUG-004 | Forgot password crashes | TextEditingController disposed during `notifyListeners()` |
| BUG-005 | "handlista" vs "inköpslista" | Inconsistent terminology in 6 files |
| BUG-006 | Dialog doesn't close after add | BaseDialog lifecycle issue — switched to simple AlertDialog |
| BUG-007 | Shopping list buttons unresponsive | `Material(color: transparent)` blocks web hit-testing → `MaterialType.transparency` |
| BUG-008 | Friend request buttons unresponsive | Same Material hit-testing fix as BUG-007 |
| BUG-009 | "Skapa lista" empty callback | `onAction: () {}` — connected to actual dialog methods |
| BUG-010 | Friend search no text input | SearchInputWidget StatelessWidget → StatefulWidget with TextFormField |
| BUG-011 | Friend list not syncing | `addMutualFriends` used OR instead of AND for partial state |
| BUG-012 | Platform.isIOS crashes on web | `dart:io` → `kIsWeb && defaultTargetPlatform` check |
| BUG-013 | Group edit TypeError | `pop(true)` type mismatch — changed to `pop(updatedCategory)` |
| BUG-014 | Group edit dialog overflow | Wrapped in `Flexible` + `SingleChildScrollView` |
| BUG-015 | updateCategory returns false | Only searched local cache — added refresh retry |
| BUG-016 | Group edit false error | Firestore SDK assertion after successful write — added verification re-fetch |
| BUG-017 | Group invitations not visible | Stream listener killed by Firestore assertion — added retry |
| BUG-018 | Members don't see groups | Categories stored per-owner — added `memberCategoriesStream` with collectionGroup |
| BUG-019 | Share dialog buttons unresponsive | Multiple hit-testing issues — moved buttons, added Material wrapper |
| BUG-020 | Collaborative recipes permission error | Collection name mismatch `unified_collaborative_recipes` vs `realtime_recipes` |
| BUG-021 | Unknown route /recipe-detail | Hardcoded route in 4 Discovery components → `Routes.receptDetalj` |
| BUG-022 | Tag group creation crashes | Dialog pops before ViewModel op completes — restructured all 7 dialog methods |
| BUG-023 | Rating sort crashes | PopupMenu teardown triggers rebuild — deferred via `addPostFrameCallback` |
| BUG-024 | "Skapa kopia" wrong route | Hardcoded `/editRecipe` → `Routes.redigeraRecept` |
| BUG-025 | Create tag (+) crashes | PopupMenuButton triggers dialog before layout — deferred via `addPostFrameCallback` |
| BUG-026 | Profile shows 0 friends | Used `_pendingRequestsCount` — split stats loading from notifications |
| BUG-027 | Recipe sharing silently fails | Firestore rules used V1 `sharedWithUserIds` field (removed in V2) |
| BUG-028 | Import errors in English | Added `_localizeImportError()` mapping in SmartImportViewModel |
| BUG-029 | Comments don't persist | 5-layer failure: silent exception, redundant permission gate, Firestore read rules, missing `reactions` field, wrong property name |
| BUG-030 | Blank screen on web | `ensureInitialized()` inside `runZonedGuarded` — moved to root zone |
| BUG-031 | Comment delete fails | `getCommentById()` threw UnimplementedError — implemented via `Repository.read()` |
| BUG-033 | Tag group rename crashes | PopupMenuButton layout assertion — deferred via `addPostFrameCallback` |
| BUG-034 | Share dialog list not scrollable | `NeverScrollableScrollPhysics()` → `ClampingScrollPhysics()` |

## Phase Details

### Phase 1: Authentication (13/14 passed)
Registration form, login/logout, password reset, error display all verified. AUTH-08 (MFA settings) N/A — post-beta feature.

### Phase 2: Navigation & Home (27/27 passed)
Search, filter, sort, grid/list toggle, pull-to-refresh, pagination all verified.

### Phase 3: Recipe Detail & Editing (31/33 passed)
Cooking mode, portion scaling, overflow menu, text editing (CanvasKit Ctrl+A + type) all verified. 2 N/A: image upload not automatable on web.

### Phase 4: Recipe Import (28/32 passed)
URL import, text paste, manual entry, archive import all verified. 4 N/A: file upload/photo import not automatable on web.

### Phase 5: Weekly Menu (13/13 passed)
Generate, replace, save, load, clear, shopping list export all verified.

### Phase 6: Shopping Lists (29/29 passed)
Full CRUD, auto-categorization, bulk actions, templates verified.

### Phase 7: Social Features (35/40 passed)
Friends, groups, sharing, profile all verified. 5 N/A.

### Phase 8: Messaging (22/23 passed)
Full messaging flow, search, info, mute, conversation delete (swipe gesture) verified. 1 N/A: typing indicator needs 2 simultaneous users.

### Phase 9: Personal Tags (21/21 passed)
Tag CRUD, rules, groups, filters, CanvasKit text input all verified.

### Phase 10-15 (all passed)
Settings (23), Dialogs (11), Widgets (44), Responsive (9), Accessibility (6/7), Error Handling (13) — all verified. A11Y-06 N/A (CanvasKit keyboard nav limitation).

### Phase 16: Social E2E (30/30 passed)

Multi-user verification (User A acts → User B verifies):

| Area | Tests | Key Results |
|------|-------|-------------|
| Friends (4) | All PASS | Send/accept/reject/remove friend requests |
| Groups (9) | All PASS | Create, invite, accept/decline, rename, leave, remove member, delete |
| Sharing (6) | All PASS | Share to friend/group, static/realtime copy, unshare, share with message |
| Messaging (5) | All PASS | Send, reply, link, new conversation, delete (swipe) |
| Comments (3) | All PASS | Comment, reply, delete on shared recipe |
| Ratings (2) | All PASS | Rate and change rating |
| Notifications (1) | PASS | Friend request notification |

### Phase 17: Import Tagging Verification (27/32 passed, 1 failed)

Tag accuracy verified with 4 imported recipes (kycklinggryta, linssoppa, carbonara, stekt ris):
- **Time** (3/3): under-15/30, under-45/60, over-60 all correct
- **Protein** (4/4): notkött, fisk, vegetarisk, kyckling all correct
- **Allergen** (5/5): gluten, mjölk, ägg, nötter all detected correctly
- **Dietary** (4/4): vegetarisk/pescetarian/vegan status all correct
- **Cooking method** (3/3): ugnsbakad, stekt, soppa all correct
- **Dish type** (2/3): pasta + ris correct. 1 N/A: no salad recipe
- **Import methods**: URL FAIL (BUG-032 ICA only), manual entry PASS, text paste PASS
- **Edge cases** (4/7): unknown ingredients, partial data, re-tagging verified. 3 N/A.

### Phase 18: Tag & Allergen System (56/58 passed)

| Area | Tests | Result |
|------|-------|--------|
| Personal Tags CRUD (5) | All PASS | Create, view, edit (CanvasKit text), delete |
| Tag Groups (3) | All PASS | Create, rename, delete |
| Rules & Preferences (11) | 9 PASS, 2 N/A | Automation rules, allergen/dietary toggles, tri-state badges |
| Filter Panel (9) | All PASS | 7 filter sections, include/exclude personal tags |
| Tag Display (8) | All PASS | List chips, grid hidden, allergen badges (red/green) |
| Multi-filter & Sort (11) | All PASS | Time+diet, diet+allergen combos, sort by title/time |
| Automation Rules (5) | All PASS | 12 conditions, 5 operators, match modes |
| Allergen Settings & Search (6) | All PASS | 19 allergens, search by name ("kladd"→6) and ingredient ("lax"→2) |

## Web Testing Notes

- **CanvasKit text input**: Works via Ctrl+A + type when field is focused (hidden DOM input activates)
- **CanvasKit dialog buttons**: Clickable via shadow DOM canvas pointer events (`flt-glass-pane > shadowRoot > canvas`)
- **Firebase Auth signout on web**: `window.firebase_auth.getAuth()` + `firebase_auth.signOut(auth)`
- **Bottom-positioned buttons**: Intermittent hit-testing issues on web (save buttons sometimes unresponsive)
- **N/A on web**: File upload (4), image upload (2), keyboard nav (1), MFA SMS (1), typing indicator (1), salad recipe (1), other (10)
