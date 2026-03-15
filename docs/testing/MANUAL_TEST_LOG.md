# Manual Testing Log - Butlery App

**Status**: 459/962 completed (48%) — 438 passed, 1 failed (BUG-032), 20 N/A, 503 PENDING, 1 open bug (BUG-035)
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
| 19. Onboarding Flow | 12 | — | — | PENDING (P0) |
| 20. GDPR & Account Management | 15 | — | — | PENDING (P0) |
| 21. Session Timeout & Security | 8 | — | — | PENDING (P0) |
| 22. Realtime Collaborative Editing | 14 | — | — | PENDING (P1) |
| 23. Draft Auto-Save & Recovery | 7 | — | — | PENDING (P1) |
| 24. Backup & Restore | 8 | — | — | PENDING (P1) |
| 25. Universal Share Dialog | 10 | — | — | PENDING (P1) |
| 26. Deep Links & Receive Share | 10 | — | — | PENDING (P2) |
| 27. Group Ownership & Advanced Mgmt | 8 | — | — | PENDING (P2) |
| 28. Emoji Reactions & Comment Likes | 9 | — | — | PENDING (P2) |
| 29. Content Moderation & Reporting | 7 | — | — | PENDING (P2) |
| 30. Smart Import Content Detection | 5 | — | — | PENDING (P2) |
| 31. Import Rate Limiting | 4 | — | — | PENDING (P3) |
| 32. Friend Categories | 7 | — | — | PENDING (P3) |
| 33. Notification Preferences & Quiet Hours | 6 | — | — | PENDING (P3) |
| 34. Menu Comments & Social Interactions | 6 | — | — | PENDING (P3) |
| 35. Recipe Favorites | 5 | — | — | PENDING (P3) |
| 36. Fullscreen Image Viewer | 5 | — | — | PENDING (P3) |
| 37. Image Upload Queue & Progress | 6 | — | — | PENDING (P3) |
| 38. FAQ & Legal Pages | 6 | — | — | PENDING (P3) |
| 39. Cooking Mode Deep | 10 | — | — | PENDING (P1) |
| 40. Recipe Form Validation & Auto-Save | 12 | — | — | PENDING (P1) |
| 41. Portion Scaler & Unit Conversion | 8 | — | — | PENDING (P2) |
| 42. Assisted Import Wizard | 9 | — | — | PENDING (P2) |
| 43. Shopping Member & List Management | 14 | — | — | PENDING (P1) |
| 44. Messaging Polls | 8 | — | — | PENDING (P2) |
| 45. Offline & Connectivity | 10 | — | — | PENDING (P1) |
| 46. Profile Menu & Navigation | 10 | — | — | PENDING (P2) |
| 47. Recipe Detail Micro-Actions | 11 | — | — | PENDING (P1) |
| 48. Ingredient Substitutions & Unknown Ingredients | 8 | — | — | PENDING (P2) |
| 49. Theme Switching | 4 | — | — | PENDING (P3) |
| 50. Personal Tag Sharing | 6 | — | — | PENDING (P2) |
| 51. Menu & Shopping Templates | 7 | — | — | PENDING (P3) |
| 52. Swipe Gestures & Selection Mode | 7 | — | — | PENDING (P2) |
| 53. Chat Edge Cases | 8 | — | — | PENDING (P2) |
| 54. Collaborative Editing Toggle | 6 | — | — | PENDING (P1) |
| 55. AI Consent & Feature Flags | 5 | — | — | PENDING (P2) |
| 56. E2E: Recipe Lifecycle | 10 | — | — | PENDING (P0) |
| 57. E2E: Import-to-Cooking | 8 | — | — | PENDING (P0) |
| 58. E2E: Menu Planning Journey | 9 | — | — | PENDING (P1) |
| 59. E2E: Shopping Collaboration | 8 | — | — | PENDING (P1) |
| 60. E2E: Account Lifecycle | 7 | — | — | PENDING (P0) |
| 61. E2E: Offline Resilience | 8 | — | — | PENDING (P1) |
| 62. E2E: Notification Journeys | 8 | — | — | PENDING (P2) |
| 63. E2E: Cross-Feature Search | 7 | — | — | PENDING (P2) |
| 64. E2E: Multi-Content Sharing | 8 | — | — | PENDING (P1) |
| 65. E2E: New User First Hour | 6 | — | — | PENDING (P0) |
| 66. Multi-User: Concurrent Editing | 10 | — | — | PENDING (P0) |
| 67. Multi-User: Blocked User Behavior | 9 | — | — | PENDING (P1) |
| 68. Multi-User: Permission Escalation & Downgrade | 8 | — | — | PENDING (P1) |
| 69. Multi-User: Group Dynamics (3+ users) | 10 | — | — | PENDING (P1) |
| 70. Multi-User: Unfriend & Unshare Cascades | 8 | — | — | PENDING (P1) |
| 71. Multi-User: Messaging Edge Cases | 8 | — | — | PENDING (P2) |
| 72. Multi-User: Presence & Typing | 7 | — | — | PENDING (P2) |
| 73. Multi-User: Shared Content Lifecycle | 9 | — | — | PENDING (P1) |
| 74. Feedback FAB & Beta Form | 7 | — | — | PENDING (P1) |
| 75. Allergen Preferences Settings | 8 | — | — | PENDING (P1) |
| 76. Friend Profile & Social Actions | 9 | — | — | PENDING (P2) |
| 77. Language Switching & Localization | 6 | — | — | PENDING (P2) |
| 78. Chat Media & Conversation Creation | 8 | — | — | PENDING (P2) |
| 79. Shared Content Management | 8 | — | — | PENDING (P2) |
| 80. Device & Background Behaviors | 8 | — | — | PENDING (P3) |
| **TOTAL** | **962** | **438** | **20** | **1 failed, 503 pending** |

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

### Phase 19: Onboarding Flow (PENDING — P0)

First-run wizard: welcome → allergen → dietary → first recipe import.

| ID | Test | Status |
|----|------|--------|
| ONB-01 | Welcome page renders, "Nästa" advances to allergen page | PENDING |
| ONB-02 | Allergen page: select allergens, verify saved on advance | PENDING |
| ONB-03 | Allergen page: skip without selecting, verify defaults | PENDING |
| ONB-04 | Dietary page: select dietary preferences, verify saved | PENDING |
| ONB-05 | Dietary page: skip without selecting | PENDING |
| ONB-06 | Import page: trigger first-recipe import flow | PENDING |
| ONB-07 | Import page: skip import entirely | PENDING |
| ONB-08 | Full wizard completion navigates to home (Mina Recept) | PENDING |
| ONB-09 | Back navigation between pages preserves selections | PENDING |
| ONB-10 | Page indicator dots reflect current step | PENDING |
| ONB-11 | Landscape/tablet layout of onboarding pages | PENDING |
| ONB-12 | Re-opening app after completed onboarding does NOT show wizard again | PENDING |

### Phase 20: GDPR & Account Management (PENDING — P0)

Consent management (Art 7), data export (Art 20), account deletion, blocked users.

| ID | Test | Status |
|----|------|--------|
| GDPR-01 | Consent management view loads current consent state | PENDING |
| GDPR-02 | Toggle analytics consent on/off, verify persisted | PENDING |
| GDPR-03 | Toggle marketing consent on/off | PENDING |
| GDPR-04 | Consent changes reflected immediately in UI | PENDING |
| GDPR-05 | Data export: initiate export, verify progress indicator | PENDING |
| GDPR-06 | Data export: download JSON file after export completes | PENDING |
| GDPR-07 | Data export: share exported data via share sheet | PENDING |
| GDPR-08 | Data export: export when user has zero recipes (edge case) | PENDING |
| GDPR-09 | Account deletion: initiate deletion flow, confirm dialog appears | PENDING |
| GDPR-10 | Account deletion: cancel at confirmation step | PENDING |
| GDPR-11 | Account deletion: complete deletion, verify logout + data removal | PENDING |
| GDPR-12 | Blocked users section: view blocked users list | PENDING |
| GDPR-13 | Blocked users section: unblock a user | PENDING |
| GDPR-14 | Blocked users section: empty state when no blocked users | PENDING |
| GDPR-15 | Blocked users: verify blocked user's content hidden from shared views | PENDING |

### Phase 21: Session Timeout & Security (PENDING — P0)

Auto-logout after 45min inactivity with 5-min warning dialog.

| ID | Test | Status |
|----|------|--------|
| SESS-01 | Warning dialog appears before timeout (at ~40 min inactivity) | PENDING |
| SESS-02 | Warning dialog: "Förläng session" resets timer, dialog closes | PENDING |
| SESS-03 | Warning dialog: "Logga ut" triggers immediate logout | PENDING |
| SESS-04 | Warning dialog: countdown timer displays remaining seconds | PENDING |
| SESS-05 | User activity (tap/scroll) resets inactivity timer | PENDING |
| SESS-06 | App backgrounded: timer pauses; foregrounded: timer resumes | PENDING |
| SESS-07 | Session timeout: automatic logout navigates to auth view | PENDING |
| SESS-08 | Multiple rapid extend-session taps: no duplicate timer creation | PENDING |

### Phase 22: Realtime Collaborative Editing (PENDING — P1)

Multi-user recipe and menu editing with conflict resolution and presence tracking.

| ID | Test | Status |
|----|------|--------|
| RT-01 | Share recipe in realtime mode (not static copy) | PENDING |
| RT-02 | Two users editing same recipe: changes sync bidirectionally | PENDING |
| RT-03 | Conflict resolution: concurrent edits to same field | PENDING |
| RT-04 | Presence indicator: see who else is viewing/editing | PENDING |
| RT-05 | Connection lost: optimistic update queued, sync on reconnect | PENDING |
| RT-06 | Connection indicator shows online/offline status | PENDING |
| RT-07 | Participant joins: presence updated for all viewers | PENDING |
| RT-08 | Participant leaves: presence updated | PENDING |
| RT-09 | Realtime menu: collaborator adds recipe to shared menu | PENDING |
| RT-10 | Realtime menu: collaborator removes recipe from shared menu | PENDING |
| RT-11 | Realtime menu: concurrent edits to menu slots | PENDING |
| RT-12 | Stop sharing: realtime connection terminated, fallback to static | PENDING |
| RT-13 | Permission changes during active session: editor downgraded to viewer | PENDING |
| RT-14 | Stale data detection after long offline period | PENDING |

### Phase 23: Draft Auto-Save & Recovery (PENDING — P1)

Debounced auto-save during recipe editing with draft recovery dialog.

| ID | Test | Status |
|----|------|--------|
| DRAFT-01 | Start editing recipe: auto-save fires after changes | PENDING |
| DRAFT-02 | Close edit view without saving: draft preserved | PENDING |
| DRAFT-03 | Re-open edit: draft recovery dialog appears with draft metadata | PENDING |
| DRAFT-04 | Choose "Återställ utkast": form populated with draft content | PENDING |
| DRAFT-05 | Choose "Kasta utkast": fresh form loaded | PENDING |
| DRAFT-06 | Multiple drafts available: dialog lists all with timestamps | PENDING |
| DRAFT-07 | Edit and save normally: draft cleared, no recovery prompt on next edit | PENDING |

### Phase 24: Backup & Restore (PENDING — P1)

Export recipes to JSON, import from backup file with duplicate detection.

| ID | Test | Status |
|----|------|--------|
| BAK-01 | Export recipes to JSON file (happy path) | PENDING |
| BAK-02 | Export when zero recipes: error or empty file handled | PENDING |
| BAK-03 | Export file contains correct recipe count and data structure | PENDING |
| BAK-04 | Import from backup file: recipes appear in list | PENDING |
| BAK-05 | Import with duplicates: duplicate detection dialog shown | PENDING |
| BAK-06 | Import with duplicates: skip duplicates option works | PENDING |
| BAK-07 | Import with duplicates: overwrite option works | PENDING |
| BAK-08 | Import corrupted/invalid file: error handled gracefully | PENDING |

### Phase 25: Universal Share Dialog (PENDING — P1)

Multi-step sharing flow for recipes, menus, and shopping lists.

| ID | Test | Status |
|----|------|--------|
| USD-01 | Open share dialog for recipe: share modes displayed | PENDING |
| USD-02 | Open share dialog for shopping list: appropriate mode shown | PENDING |
| USD-03 | Select share mode: target selection step appears | PENDING |
| USD-04 | Friend category filter in target selection | PENDING |
| USD-05 | Select multiple friends as targets | PENDING |
| USD-06 | Select group as target | PENDING |
| USD-07 | Add optional message to share | PENDING |
| USD-08 | Share to friend: success confirmation | PENDING |
| USD-09 | Share to group: success confirmation | PENDING |
| USD-10 | No friends available: empty state with "Lägg till vänner" prompt | PENDING |

### Phase 26: Deep Links & Receive Share (PENDING — P2)

Incoming share intents with content detection, deep link generation and navigation.

| ID | Test | Status |
|----|------|--------|
| DL-01 | Receive shared text: URL detected, routed to URL import | PENDING |
| DL-02 | Receive shared text: recipe text detected, routed to text import | PENDING |
| DL-03 | Receive shared text: social media URL detected, routed to social import | PENDING |
| DL-04 | Receive shared text: unrecognized content, manual fallback shown | PENDING |
| DL-05 | Deep link: friend invitation URL opens friend request flow | PENDING |
| DL-06 | Deep link: shared recipe URL opens recipe detail (or import) | PENDING |
| DL-07 | Deep link: expired link shows appropriate error | PENDING |
| DL-08 | Deep link: link with invalid parameters shows error gracefully | PENDING |
| DL-09 | Generate share link for a recipe, verify URL format | PENDING |
| DL-10 | Generate friend invitation link, verify URL format | PENDING |

### Phase 27: Group Ownership & Advanced Management (PENDING — P2)

Ownership transfer, advanced group admin, member removal with confirmations.

| ID | Test | Status |
|----|------|--------|
| GADM-01 | Transfer group ownership to another member | PENDING |
| GADM-02 | Transfer ownership dialog: only eligible members shown | PENDING |
| GADM-03 | Delete group as owner: confirmation dialog | PENDING |
| GADM-04 | Delete empty group: simplified delete flow | PENDING |
| GADM-05 | Edit group: change name/description | PENDING |
| GADM-06 | Remove member from group: confirmation dialog | PENDING |
| GADM-07 | Remove member: member removed, notification sent | PENDING |
| GADM-08 | Non-owner attempts admin actions: properly denied | PENDING |

### Phase 28: Emoji Reactions & Comment Likes (PENDING — P2)

Reactions on messages, likes on comments, emoji picker.

| ID | Test | Status |
|----|------|--------|
| REACT-01 | Long-press message: emoji reaction picker appears | PENDING |
| REACT-02 | Select emoji reaction: reaction added to message | PENDING |
| REACT-03 | Remove own emoji reaction from message | PENDING |
| REACT-04 | Multiple users react to same message: reaction count aggregated | PENDING |
| REACT-05 | Like a recipe comment: like count increments | PENDING |
| REACT-06 | Unlike a recipe comment: like count decrements | PENDING |
| REACT-07 | Emoji reaction on shared recipe/menu content | PENDING |
| REACT-08 | Emoji reaction display shows correct emoji + count | PENDING |
| REACT-09 | Reaction from blocked user: not displayed | PENDING |

### Phase 29: Content Moderation & Reporting (PENDING — P2)

Report content dialog, reason selection, rate limiting on reports.

| ID | Test | Status |
|----|------|--------|
| MOD-01 | Report recipe: dialog opens with reason selection | PENDING |
| MOD-02 | Select reason and submit report: success confirmation | PENDING |
| MOD-03 | Cancel report dialog: no report submitted | PENDING |
| MOD-04 | Report a comment: dialog opens | PENDING |
| MOD-05 | Report a user/profile: dialog opens | PENDING |
| MOD-06 | Rate limit on reports: rate limit dialog shown if spamming | PENDING |
| MOD-07 | Content filter: profanity in recipe name/comment handled | PENDING |

### Phase 30: Smart Import Content Detection (PENDING — P2)

Automatic content type detection and routing in unified import view.

| ID | Test | Status |
|----|------|--------|
| SI-01 | Paste URL: auto-detected, routed to URL import | PENDING |
| SI-02 | Paste recipe text: auto-detected, routed to text import | PENDING |
| SI-03 | Paste social media link: platform badge shown, routed correctly | PENDING |
| SI-04 | Paste ambiguous content: options presented to user | PENDING |
| SI-05 | Empty paste/no content: appropriate empty state | PENDING |

### Phase 31: Import Rate Limiting (PENDING — P3)

Rate limit enforcement and fallback options during heavy import usage.

| ID | Test | Status |
|----|------|--------|
| IRL-01 | Import rate limit hit: rate limit dialog shown | PENDING |
| IRL-02 | Rate limit dialog: "Försök utan AI" fallback option | PENDING |
| IRL-03 | Rate limit dialog: "Manuell import" fallback option | PENDING |
| IRL-04 | Rate limit resets after cooldown period | PENDING |

### Phase 32: Friend Categories (PENDING — P3)

Category CRUD, member assignment, filtering in lists and share dialogs.

| ID | Test | Status |
|----|------|--------|
| FCAT-01 | Create a new friend category | PENDING |
| FCAT-02 | Rename a friend category | PENDING |
| FCAT-03 | Delete a friend category | PENDING |
| FCAT-04 | Add friend to a category | PENDING |
| FCAT-05 | Remove friend from a category | PENDING |
| FCAT-06 | Filter friends by category in friends list | PENDING |
| FCAT-07 | Category filter in share dialog target selection | PENDING |

### Phase 33: Notification Preferences & Quiet Hours (PENDING — P3)

Category toggles and quiet hours configuration.

| ID | Test | Status |
|----|------|--------|
| NOTIF-01 | Notification preferences view loads with current settings | PENDING |
| NOTIF-02 | Toggle a notification category off: persisted | PENDING |
| NOTIF-03 | Toggle a notification category on: persisted | PENDING |
| NOTIF-04 | Set quiet hours start/end time | PENDING |
| NOTIF-05 | Quiet hours active: no notifications during quiet period | PENDING |
| NOTIF-06 | Reset notification preferences to defaults | PENDING |

### Phase 34: Menu Comments & Social Interactions (PENDING — P3)

Comments, likes, and ratings on shared menus.

| ID | Test | Status |
|----|------|--------|
| MCOM-01 | View comments on shared menu | PENDING |
| MCOM-02 | Add comment to shared menu | PENDING |
| MCOM-03 | Edit own comment on shared menu | PENDING |
| MCOM-04 | Delete own comment on shared menu | PENDING |
| MCOM-05 | Like a menu comment | PENDING |
| MCOM-06 | Menu comment notification received by menu owner | PENDING |

### Phase 35: Recipe Favorites (PENDING — P3)

Boolean favorite flag on recipes, filtering and persistence.

| ID | Test | Status |
|----|------|--------|
| FAV-01 | Mark recipe as favorite from detail view | PENDING |
| FAV-02 | Unmark recipe as favorite | PENDING |
| FAV-03 | Filter/sort by favorites in recipe list | PENDING |
| FAV-04 | Favorite state persists across sessions | PENDING |
| FAV-05 | Favorite indicator visible on recipe card | PENDING |

### Phase 36: Fullscreen Image Viewer (PENDING — P3)

Fullscreen image viewing for recipes and messaging.

| ID | Test | Status |
|----|------|--------|
| IMG-01 | Tap recipe image: fullscreen viewer opens | PENDING |
| IMG-02 | Pinch-to-zoom in fullscreen viewer | PENDING |
| IMG-03 | Swipe to dismiss fullscreen viewer | PENDING |
| IMG-04 | Fullscreen viewer for messaging images | PENDING |
| IMG-05 | No-image recipe: fullscreen viewer not accessible | PENDING |

### Phase 37: Image Upload Queue & Progress (PENDING — P3)

Background upload with retry logic and progress UI. N/A on web for camera/gallery.

| ID | Test | Status |
|----|------|--------|
| UPL-01 | Upload image during recipe edit: progress indicator shown | PENDING |
| UPL-02 | Upload completes: image appears in recipe | PENDING |
| UPL-03 | Upload fails: retry button shown | PENDING |
| UPL-04 | Retry upload after failure: succeeds | PENDING |
| UPL-05 | Multiple images queued: queue processed sequentially | PENDING |
| UPL-06 | Cancel pending upload from queue | PENDING |

### Phase 38: FAQ & Legal Pages (PENDING — P3)

Static content pages: FAQ, privacy policy, terms, community guidelines.

| ID | Test | Status |
|----|------|--------|
| LEGAL-01 | FAQ view loads and displays expandable Q&A tiles | PENDING |
| LEGAL-02 | FAQ tiles expand/collapse on tap | PENDING |
| LEGAL-03 | Privacy policy view loads and scrolls | PENDING |
| LEGAL-04 | Terms of service view loads and scrolls | PENDING |
| LEGAL-05 | Community guidelines view loads and scrolls | PENDING |
| LEGAL-06 | Navigation to legal pages from settings/profile menu | PENDING |

### Phase 39: Cooking Mode Deep (PENDING — P1)

Landscape split-view with wakelock, immersive mode, and live portion scaling.

| ID | Test | Status |
|----|------|--------|
| COOK-01 | Entering cooking mode forces landscape orientation | PENDING |
| COOK-02 | Screen stays awake during cooking mode (wakelock active) | PENDING |
| COOK-03 | Status/nav bars hidden (immersive sticky mode) | PENDING |
| COOK-04 | Left panel (35%): ingredient list with live-scaled amounts | PENDING |
| COOK-05 | Right panel (65%): numbered instructions, scrollable | PENDING |
| COOK-06 | Minus button disabled at 1 portion (minimum) | PENDING |
| COOK-07 | Plus button disabled at 50 portions (maximum) | PENDING |
| COOK-08 | Scaling with null portions recipe (defaults to 1, scales correctly) | PENDING |
| COOK-09 | Close button exits cooking mode, restores portrait + system bars | PENDING |
| COOK-10 | Fractions displayed correctly (½, ¼, ¾) after scaling | PENDING |

### Phase 40: Recipe Form Validation & Auto-Save (PENDING — P1)

Form field limits, auto-save behavior, draft management, unsaved changes detection.

| ID | Test | Status |
|----|------|--------|
| FORM-01 | Title truncated at 100 characters (paste 101+ chars) | PENDING |
| FORM-02 | Ingredient line max 200 characters — excess rejected/truncated | PENDING |
| FORM-03 | Instruction line max 500 characters — excess rejected/truncated | PENDING |
| FORM-04 | Max 100 ingredients enforced — add attempt beyond 100 fails | PENDING |
| FORM-05 | Max 50 instructions enforced — add attempt beyond 50 fails | PENDING |
| FORM-06 | Form invalid with empty title → save button disabled | PENDING |
| FORM-07 | Form invalid with zero ingredients → save button disabled | PENDING |
| FORM-08 | Form invalid with zero instructions → save button disabled | PENDING |
| FORM-09 | Auto-save fires after 3s pause on normal fields | PENDING |
| FORM-10 | Auto-save fires after 1s pause on critical fields (title, ingredients) | PENDING |
| FORM-11 | Max 5 images — 6th add silently dropped | PENDING |
| FORM-12 | Reorder images counts as unsaved change → prompt on navigate away | PENDING |

### Phase 41: Portion Scaler & Unit Conversion (PENDING — P2)

Scaling logic, American unit conversion toggle, haptic feedback, fraction display.

| ID | Test | Status |
|----|------|--------|
| SCALE-01 | Minus/plus buttons with haptic feedback on tap | PENDING |
| SCALE-02 | Min 1 / max 20 portions (buttons disabled at limits) | PENDING |
| SCALE-03 | Scale bounce animation on portion change (unless reduced motion) | PENDING |
| SCALE-04 | Status banner shows "Scaled from N to M" when portions differ | PENDING |
| SCALE-05 | American unit conversion toggle visible only when US units present | PENDING |
| SCALE-06 | Toggle converts cup → dl, oz → g, etc. correctly | PENDING |
| SCALE-07 | Swedish fractions displayed (½, ¼, ¾) after scaling | PENDING |
| SCALE-08 | Swedish pluralization for unit-less items (e.g., "ägg" → "ägg") | PENDING |

### Phase 42: Assisted Import Wizard (PENDING — P2)

3-step manual fallback when auto-parsing fails: select ingredients → select instructions → review/edit.

| ID | Test | Status |
|----|------|--------|
| ASST-01 | Step 1: ingredient lines pre-detected with "Likely" badges | PENDING |
| ASST-02 | Step 1: "Select all highlighted" button selects pre-detected lines | PENDING |
| ASST-03 | Step 1: tap to toggle individual line selection | PENDING |
| ASST-04 | Step 1: proceed disabled until ≥1 ingredient selected | PENDING |
| ASST-05 | Step 2: only non-ingredient lines shown, instruction pre-detection | PENDING |
| ASST-06 | Step 3: editable title, description, portions, time fields | PENDING |
| ASST-07 | Step 3: add/remove/edit individual ingredients and instructions | PENDING |
| ASST-08 | Step 3: step prefixes auto-stripped ("Steg 1. " removed) | PENDING |
| ASST-09 | Complete wizard builds recipe and navigates to detail | PENDING |

### Phase 43: Shopping Member & List Management (PENDING — P1)

Member permissions, list conversion, clear/rename/delete operations, sharing status.

| ID | Test | Status |
|----|------|--------|
| SHOP-M01 | Convert personal list to collaborative: friend selection + description | PENDING |
| SHOP-M02 | Convert collaborative to personal: warning that collaborators lose access | PENDING |
| SHOP-M03 | Member management: owner shown with "Owner" label, no remove button | PENDING |
| SHOP-M04 | Member management: change permission dropdown (View/Edit/Admin) | PENDING |
| SHOP-M05 | Member management: remove member with confirmation dialog | PENDING |
| SHOP-M06 | Member management: add friends via search + checkbox selection | PENDING |
| SHOP-M07 | Sharing status dialog: read-only info with member list and permissions | PENDING |
| SHOP-M08 | Sharing status: "Manage Sharing" button only for owner/admin | PENDING |
| SHOP-M09 | Clear purchased items: confirmation shows count of bought items | PENDING |
| SHOP-M10 | Rename list: pre-filled field, 2–50 char validation | PENDING |
| SHOP-M11 | Delete list: confirmation shows item count if non-empty | PENDING |
| SHOP-M12 | Add item: auto-category suggestion from Swedish ingredient keywords | PENDING |
| SHOP-M13 | Edit item: price field available (not in add dialog) | PENDING |
| SHOP-M14 | Shopping export with emoji checkmarks (✅/⬜) and category headers | PENDING |

### Phase 44: Messaging Polls (PENDING — P2)

Create, vote, close polls in group chats.

| ID | Test | Status |
|----|------|--------|
| POLL-01 | Create poll: question field + 2 option fields (min required) | PENDING |
| POLL-02 | Add option button: up to 4 options total | PENDING |
| POLL-03 | Remove option: X button when >2 options exist | PENDING |
| POLL-04 | Multiple choice toggle (Switch) allows multi-select voting | PENDING |
| POLL-05 | Create button disabled until question + 2 options filled | PENDING |
| POLL-06 | Vote on poll: progress bar shows vote percentage per option | PENDING |
| POLL-07 | Close poll: only creator sees "Close poll" link; votes locked after | PENDING |
| POLL-08 | Total vote count displayed below options | PENDING |

### Phase 45: Offline & Connectivity (PENDING — P1)

Sync indicator, offline editing, connectivity status, queued changes.

| ID | Test | Status |
|----|------|--------|
| OFF-01 | Sync indicator: green cloud when synced (if always-visible) | PENDING |
| OFF-02 | Sync indicator: pulsing warning cloud during pending writes | PENDING |
| OFF-03 | Sync indicator: muted cloud-off icon when offline | PENDING |
| OFF-04 | Save recipe while offline: queued in local database | PENDING |
| OFF-05 | Reconnect after offline save: changes sync automatically | PENDING |
| OFF-06 | Connectivity banner: "No internet" state shown | PENDING |
| OFF-07 | Connectivity banner: "Firebase unavailable" state shown | PENDING |
| OFF-08 | Pull-to-refresh on recipe list: disabled when offline | PENDING |
| OFF-09 | Offline-saved recipe gets auto-tagged when connectivity returns | PENDING |
| OFF-10 | Queued changes count displayed somewhere (if UI exists) | PENDING |

### Phase 46: Profile Menu & Navigation (PENDING — P2)

Profile bottom sheet: all menu items, navigation targets, notification badges.

| ID | Test | Status |
|----|------|--------|
| PROF-01 | Profile menu opens as bottom sheet with avatar, name, email, stats | PENDING |
| PROF-02 | Stats row shows Recipes / Menus / Friends counts | PENDING |
| PROF-03 | Friends badge shows pending requests + group invitations count | PENDING |
| PROF-04 | Shared with me badge shows new shared items count | PENDING |
| PROF-05 | Messages badge shows unread conversation count | PENDING |
| PROF-06 | Navigate to each settings page (allergens, notifications, security) | PENDING |
| PROF-07 | Navigate to FAQ from profile menu | PENDING |
| PROF-08 | Navigate to My Tags (personal tags) from profile menu | PENDING |
| PROF-09 | Logout button: confirmation dialog, then full nav stack clear to /auth | PENDING |
| PROF-10 | Account deletion: 3-step flow (confirm → re-auth → loading → logout) | PENDING |

### Phase 47: Recipe Detail Micro-Actions (PENDING — P1)

Specific actions on recipe detail: mark as cooked, collaborative toggle, fork, delete, shopping add flow.

| ID | Test | Status |
|----|------|--------|
| RDA-01 | "Lagat idag": first-time vs repeat cook tracked differently | PENDING |
| RDA-02 | Delete recipe: confirmation dialog shows recipe name | PENDING |
| RDA-03 | Delete recipe: success pops navigation with snackbar | PENDING |
| RDA-04 | Add to shopping list: ingredient preview list shown first | PENDING |
| RDA-05 | Add to shopping list: select existing list OR create new (default name) | PENDING |
| RDA-06 | Add to shopping list: post-add dialog with "View list" navigation | PENDING |
| RDA-07 | Re-tag recipe: confirmation → non-dismissible loading → result snackbar with tag count | PENDING |
| RDA-08 | Personal tag quick selector: draggable bottom sheet with tag grid | PENDING |
| RDA-09 | Personal tag selector: "Hantera taggar" link navigates to PersonalTagsView | PENDING |
| RDA-10 | Personal tag selector: empty state with "Create tag" button | PENDING |
| RDA-11 | Recipe with null rating displays em dash (–), not 0 | PENDING |

### Phase 48: Ingredient Substitutions & Unknown Ingredients (PENDING — P2)

Substitution suggestions and unknown ingredient property assignment.

| ID | Test | Status |
|----|------|--------|
| SUBST-01 | Tap ingredient: substitution bottom sheet opens | PENDING |
| SUBST-02 | Substitution list shows name, ratio badge, notes, dietary tags | PENDING |
| SUBST-03 | No substitutions found: empty state message | PENDING |
| SUBST-04 | Unknown ingredient dialog: shows "X of N" counter in title | PENDING |
| SUBST-05 | Unknown ingredient: allergen toggle chips (8 allergens) | PENDING |
| SUBST-06 | Unknown ingredient: dietary property chips (8 properties) | PENDING |
| SUBST-07 | Unknown ingredient: "Skip" / "Previous" / "Save and next" flow | PENDING |
| SUBST-08 | Unknown ingredient: save writes to Firestore user ingredients | PENDING |

### Phase 49: Theme Switching (PENDING — P3)

Light/dark/system theme modes with persistence.

| ID | Test | Status |
|----|------|--------|
| THEME-01 | Toggle between light and dark theme | PENDING |
| THEME-02 | System theme follows OS dark/light preference | PENDING |
| THEME-03 | Theme preference persists across app restarts | PENDING |
| THEME-04 | Toggle cycles light↔dark only (does not return to system) | PENDING |

### Phase 50: Personal Tag Sharing (PENDING — P2)

Share personal tags with friends via link, import with duplicate name handling.

| ID | Test | Status |
|----|------|--------|
| PTAG-01 | Share a personal tag: sends to selected friends | PENDING |
| PTAG-02 | Recipient sees pending shared tag notification | PENDING |
| PTAG-03 | Import shared tag: creates local copy with rules and matching recipes | PENDING |
| PTAG-04 | Import tag with duplicate name: " (importerad)" suffix added | PENDING |
| PTAG-05 | Import tag with already-suffixed duplicate: incrementing number added | PENDING |
| PTAG-06 | Import deleted/expired shared tag: error message shown | PENDING |

### Phase 51: Menu & Shopping Templates (PENDING — P3)

Browse, use, and delete saved templates for menus and shopping lists.

| ID | Test | Status |
|----|------|--------|
| TMPL-01 | Menu template browser: list with name, description, category chips | PENDING |
| TMPL-02 | Tap menu template to use it (generates prompt) | PENDING |
| TMPL-03 | Delete menu template: confirmation dialog, removal from list | PENDING |
| TMPL-04 | Shopping template browser: list with name, description, item count | PENDING |
| TMPL-05 | Use shopping template to populate list | PENDING |
| TMPL-06 | Delete shopping template: confirmation dialog | PENDING |
| TMPL-07 | Empty template list: appropriate empty state | PENDING |

### Phase 52: Swipe Gestures & Selection Mode (PENDING — P2)

Recipe list swipe actions and multi-select mode behavior.

| ID | Test | Status |
|----|------|--------|
| SWIPE-01 | Swipe left on recipe card: delete confirmation dialog | PENDING |
| SWIPE-02 | Delete via swipe: undo snackbar appears | PENDING |
| SWIPE-03 | Swipe right on recipe card: navigates directly to edit view | PENDING |
| SWIPE-04 | Swipe gestures disabled during selection mode | PENDING |
| SWIPE-05 | Long-press recipe card: enters selection mode | PENDING |
| SWIPE-06 | Selection mode: bottom action bar with bulk delete | PENDING |
| SWIPE-07 | Exit selection mode: deselect all or tap back | PENDING |

### Phase 53: Chat Edge Cases (PENDING — P2)

Message limits, typing indicator bugs, auto-read, content filter, reply flow.

| ID | Test | Status |
|----|------|--------|
| CHAT-01 | Only last 50 messages loaded — no "load more" for older messages | PENDING |
| CHAT-02 | Send whitespace-only message: rejected with error | PENDING |
| CHAT-03 | Reply banner appears when replying; clears after send | PENDING |
| CHAT-04 | Reply banner: dismiss without sending clears reply state | PENDING |
| CHAT-05 | Typing indicator auto-clears after 3 seconds of no keystroke | PENDING |
| CHAT-06 | Messages auto-marked as read when stream delivers them | PENDING |
| CHAT-07 | Group chat subtitle shows participant count ("X deltagare") | PENDING |
| CHAT-08 | Direct chat subtitle shows nothing (no online/last-seen status) | PENDING |

### Phase 54: Collaborative Editing Toggle (PENDING — P1)

Enable/disable real-time collaborative editing on a recipe from detail view.

| ID | Test | Status |
|----|------|--------|
| COLLAB-01 | Enable collaborative editing: friend selection dialog with checkboxes | PENDING |
| COLLAB-02 | Enable button disabled until ≥1 friend selected | PENDING |
| COLLAB-03 | Enable success: recipe becomes collaborative, collaborators notified | PENDING |
| COLLAB-04 | Disable collaborative editing: confirmation dialog | PENDING |
| COLLAB-05 | Disable success: collaborators lose access | PENDING |
| COLLAB-06 | Permission denied for non-owner attempting to toggle | PENDING |

### Phase 55: AI Consent & Feature Flags (PENDING — P2)

GDPR consent gate for AI processing, feature flag kill switches.

| ID | Test | Status |
|----|------|--------|
| AIFL-01 | Import without AI consent: Swedish error message shown, not crash | PENDING |
| AIFL-02 | AI consent toggle in privacy settings enables/disables AI features | PENDING |
| AIFL-03 | Feature flag: disable sharing → sharing UI hidden/disabled | PENDING |
| AIFL-04 | Feature flag: disable messaging → messaging UI hidden/disabled | PENDING |
| AIFL-05 | Feature flag: disable social → social features hidden/disabled | PENDING |

### Phase 56: E2E: Recipe Lifecycle (PENDING — P0)

Complete journey: create → edit → tag → share → collaborate → rate → delete.

| ID | Test | Status |
|----|------|--------|
| E2E-R01 | Create recipe manually → verify appears in recipe list | PENDING |
| E2E-R02 | Edit recipe (change title, add ingredient) → verify changes saved | PENDING |
| E2E-R03 | Auto-tags generated after save → verify allergen/dietary badges show | PENDING |
| E2E-R04 | Add personal tags → verify tags appear on card and in filter | PENDING |
| E2E-R05 | Share recipe with User B → User B sees it in "Shared with me" | PENDING |
| E2E-R06 | User B imports shared recipe → copy appears in their recipe list | PENDING |
| E2E-R07 | User B rates and comments on shared recipe → User A sees rating/comment | PENDING |
| E2E-R08 | User A marks recipe as cooked → "lagat idag" chip updates | PENDING |
| E2E-R09 | User A deletes recipe → removed from list, shared copy still exists for User B | PENDING |
| E2E-R10 | Verify recipe appears in search by title, ingredient, and tag throughout lifecycle | PENDING |

### Phase 57: E2E: Import-to-Cooking (PENDING — P0)

Complete journey: import recipe → auto-tag → add to menu → add ingredients to shopping → cook.

| ID | Test | Status |
|----|------|--------|
| E2E-I01 | Import recipe via URL → recipe created with parsed ingredients/instructions | PENDING |
| E2E-I02 | Auto-tagging runs → verify correct allergen, dietary, time, method tags | PENDING |
| E2E-I03 | Unknown ingredients detected → unknown ingredient dialog appears, user assigns properties | PENDING |
| E2E-I04 | Add recipe to weekly menu → recipe appears in menu view | PENDING |
| E2E-I05 | Export menu ingredients to shopping list → items appear categorized | PENDING |
| E2E-I06 | Check off shopping items as purchased → completion percentage updates | PENDING |
| E2E-I07 | Open recipe in cooking mode → landscape, scaled ingredients, scrollable instructions | PENDING |
| E2E-I08 | Scale portions in cooking mode → verify ingredient amounts update correctly | PENDING |

### Phase 58: E2E: Menu Planning Journey (PENDING — P1)

Complete journey: generate menu → customize → save → share → collaborate → export.

| ID | Test | Status |
|----|------|--------|
| E2E-M01 | Generate weekly menu with AI → 7 days of meals populated | PENDING |
| E2E-M02 | Replace a single day's meal → new recipe selected | PENDING |
| E2E-M03 | Save menu with name → appears in saved menus list | PENDING |
| E2E-M04 | Load saved menu → all recipes restored correctly | PENDING |
| E2E-M05 | Share menu with User B → User B sees in "Shared with me" menus tab | PENDING |
| E2E-M06 | User B imports shared menu → copy with all recipes in their list | PENDING |
| E2E-M07 | User B comments on shared menu → User A sees comment | PENDING |
| E2E-M08 | Export all menu ingredients to shopping list → verify item count matches | PENDING |
| E2E-M09 | Delete saved menu → removed from list, no orphaned data | PENDING |

### Phase 59: E2E: Shopping Collaboration (PENDING — P1)

Complete journey: create list → share → both users edit → check off → complete.

| ID | Test | Status |
|----|------|--------|
| E2E-S01 | User A creates personal shopping list with items | PENDING |
| E2E-S02 | User A converts to collaborative → selects User B → both see list | PENDING |
| E2E-S03 | User A adds item → User B sees it appear in real-time | PENDING |
| E2E-S04 | User B checks off item → User A sees it checked in real-time | PENDING |
| E2E-S05 | User B adds item → User A sees it appear | PENDING |
| E2E-S06 | User A clears purchased items → both users see cleared list | PENDING |
| E2E-S07 | User A changes User B permission to View → User B can no longer edit | PENDING |
| E2E-S08 | User A converts back to personal → User B loses access | PENDING |

### Phase 60: E2E: Account Lifecycle (PENDING — P0)

Complete journey: register → onboard → use features → export data → delete account.

| ID | Test | Status |
|----|------|--------|
| E2E-A01 | Register new account → lands on onboarding wizard | PENDING |
| E2E-A02 | Complete onboarding (allergens + dietary + skip import) → lands on home | PENDING |
| E2E-A03 | Create a recipe, add a friend, send a message → data exists | PENDING |
| E2E-A04 | Export data (GDPR Art 20) → JSON contains recipes, friends, messages | PENDING |
| E2E-A05 | Change password → can login with new password | PENDING |
| E2E-A06 | Delete account → all data removed, logged out, cannot re-login | PENDING |
| E2E-A07 | User B checks: deleted user's shared content, messages, friend status all gone | PENDING |

### Phase 61: E2E: Offline Resilience (PENDING — P1)

Complete journey: go offline → make changes → reconnect → verify sync.

| ID | Test | Status |
|----|------|--------|
| E2E-O01 | Go offline → create new recipe → verify saved locally | PENDING |
| E2E-O02 | Edit existing recipe while offline → changes queued | PENDING |
| E2E-O03 | Add items to shopping list while offline → items queued | PENDING |
| E2E-O04 | Reconnect → all queued changes sync to Firestore | PENDING |
| E2E-O05 | Offline-created recipe gets auto-tagged after reconnect | PENDING |
| E2E-O06 | Navigate between views while offline → cached data shown, no crashes | PENDING |
| E2E-O07 | Pull-to-refresh while offline → disabled or shows offline message | PENDING |
| E2E-O08 | Receive shared content while offline → appears after reconnect | PENDING |

### Phase 62: E2E: Notification Journeys (PENDING — P2)

Action triggers notification → recipient receives → taps to navigate to correct screen.

| ID | Test | Status |
|----|------|--------|
| E2E-N01 | User A sends friend request → User B gets notification → tap opens requests | PENDING |
| E2E-N02 | User A shares recipe → User B gets notification → tap opens shared content | PENDING |
| E2E-N03 | User A comments on shared recipe → User B gets notification → tap opens recipe | PENDING |
| E2E-N04 | User A invites to group → User B gets notification → tap opens group invitations | PENDING |
| E2E-N05 | User A sends message → User B gets notification → tap opens chat | PENDING |
| E2E-N06 | User A enables collaborative editing → User B gets notification → tap opens recipe | PENDING |
| E2E-N07 | Comment batching: 3 comments within 5 min → single "3 nya kommentarer" notification | PENDING |
| E2E-N08 | Quiet hours active → no notifications delivered during configured window | PENDING |

### Phase 63: E2E: Cross-Feature Search (PENDING — P2)

Search across multiple dimensions and verify results reflect all data changes.

| ID | Test | Status |
|----|------|--------|
| E2E-X01 | Search by recipe title → correct results | PENDING |
| E2E-X02 | Search by ingredient name → recipes containing that ingredient shown | PENDING |
| E2E-X03 | Filter by allergen (e.g., glutenfri) + search term → intersection correct | PENDING |
| E2E-X04 | Filter by personal tag + dietary tag → intersection correct | PENDING |
| E2E-X05 | Sort by rating → highest rated first; sort by time → fastest first | PENDING |
| E2E-X06 | Search in shared-with-me → finds shared recipes/menus by title and sender | PENDING |
| E2E-X07 | Edit recipe title → search with new title finds it, old title does not | PENDING |

### Phase 64: E2E: Multi-Content Sharing (PENDING — P1)

Share recipes, menus, and shopping lists in a single session; verify all appear correctly.

| ID | Test | Status |
|----|------|--------|
| E2E-MC01 | User A shares recipe to User B → appears in Shared recipes tab | PENDING |
| E2E-MC02 | User A shares menu to User B → appears in Shared menus tab | PENDING |
| E2E-MC03 | User A shares shopping list to User B → appears in Shared shopping tab | PENDING |
| E2E-MC04 | User B imports recipe (copy-on-write) → independent copy in their list | PENDING |
| E2E-MC05 | User B imports menu → all recipes within menu also copied | PENDING |
| E2E-MC06 | User B joins shopping list → collaborative real-time editing works | PENDING |
| E2E-MC07 | User B dismisses a shared item → no longer appears in inbox | PENDING |
| E2E-MC08 | User A shares to group → all group members see content in their inbox | PENDING |

### Phase 65: E2E: New User First Hour (PENDING — P0)

Simulates what a brand-new user experiences in their first session.

| ID | Test | Status |
|----|------|--------|
| E2E-FH01 | Register → complete onboarding → empty home screen with helpful empty state | PENDING |
| E2E-FH02 | Import first recipe via URL → recipe appears with tags | PENDING |
| E2E-FH03 | Create recipe manually → all form fields work for first recipe | PENDING |
| E2E-FH04 | Generate first weekly menu → menu populated despite only 1-2 recipes | PENDING |
| E2E-FH05 | Open profile menu → all navigation items work with zero data | PENDING |
| E2E-FH06 | Search friends → find User B → send request → User B accepts → friends visible | PENDING |

### Phase 66: Multi-User: Concurrent Editing (PENDING — P0)

Both User A and User B editing the same content simultaneously. Requires two browser sessions.

| ID | Test | Status |
|----|------|--------|
| MU-CE01 | Both users open same collaborative recipe → both see each other's presence | PENDING |
| MU-CE02 | User A edits title while User B edits description → both changes saved | PENDING |
| MU-CE03 | Both users edit the SAME field simultaneously → conflict resolution fires, no data loss | PENDING |
| MU-CE04 | User A adds ingredient while User B removes ingredient → both changes reflected | PENDING |
| MU-CE05 | User A reorders instructions while User B edits instruction text → no corruption | PENDING |
| MU-CE06 | Both users add to same collaborative shopping list → items appear for both in real-time | PENDING |
| MU-CE07 | User A checks off item while User B edits same item → no race condition | PENDING |
| MU-CE08 | Both users edit same collaborative menu → recipe changes sync bidirectionally | PENDING |
| MU-CE09 | User A loses connection mid-edit → User B continues → User A reconnects → state merges | PENDING |
| MU-CE10 | Rapid alternating edits (A types, B types, A types) → no lost keystrokes or flickering | PENDING |

### Phase 67: Multi-User: Blocked User Behavior (PENDING — P1)

Verify that blocking a user cascades correctly across all features.

| ID | Test | Status |
|----|------|--------|
| MU-BL01 | User A blocks User B → User B disappears from A's friend list | PENDING |
| MU-BL02 | User B's shared recipes no longer visible to User A in "Shared with me" | PENDING |
| MU-BL03 | User B's shared menus no longer visible to User A | PENDING |
| MU-BL04 | User B's comments on User A's recipes become hidden | PENDING |
| MU-BL05 | User B's emoji reactions on User A's content become hidden | PENDING |
| MU-BL06 | User B cannot send friend request to User A | PENDING |
| MU-BL07 | User B cannot send message to User A | PENDING |
| MU-BL08 | User B's profile not shown in User A's search results | PENDING |
| MU-BL09 | User A unblocks User B → previous shared content reappears (or does it?) | PENDING |

### Phase 68: Multi-User: Permission Escalation & Downgrade (PENDING — P1)

Real-time permission changes while users are actively using shared content.

| ID | Test | Status |
|----|------|--------|
| MU-PE01 | User A downgrades User B from Editor to Viewer on shared recipe → B can no longer edit | PENDING |
| MU-PE02 | Downgrade happens while User B is actively editing → edit session terminates gracefully | PENDING |
| MU-PE03 | User A upgrades User B from Viewer to Editor on shopping list → B can now add items | PENDING |
| MU-PE04 | User A removes User B from collaborative recipe → B loses access immediately | PENDING |
| MU-PE05 | User A changes User B's shopping list permission (View/Edit/Admin) → reflected in B's UI | PENDING |
| MU-PE06 | Admin (not owner) promotes another member to Admin → permission granted | PENDING |
| MU-PE07 | Admin removes member → member loses access | PENDING |
| MU-PE08 | Owner transfers ownership → old owner becomes regular member, new owner gets admin controls | PENDING |

### Phase 69: Multi-User: Group Dynamics (3+ users) (PENDING — P1)

Tests requiring User A, User B, and a third participant (or multiple group members).

| ID | Test | Status |
|----|------|--------|
| MU-GD01 | Create group with 3 members → all three see the group | PENDING |
| MU-GD02 | Share recipe to group → all 3 members see it in "Shared with me" | PENDING |
| MU-GD03 | One member leaves group → no longer sees group content, other 2 unaffected | PENDING |
| MU-GD04 | Owner removes member B → member B loses access, member C unaffected | PENDING |
| MU-GD05 | Group chat: messages from all 3 members visible to everyone | PENDING |
| MU-GD06 | Group chat: one member mutes → no notifications for that member, others still get them | PENDING |
| MU-GD07 | Group poll: all 3 vote → percentages calculated correctly with 3 voters | PENDING |
| MU-GD08 | Collaborative shopping list shared with group → all 3 can add/check items | PENDING |
| MU-GD09 | Owner deletes group → all members lose access, group conversations archived | PENDING |
| MU-GD10 | Invite new member to existing group → new member sees existing shared content | PENDING |

### Phase 70: Multi-User: Unfriend & Unshare Cascades (PENDING — P1)

Verify data cleanup when relationships end.

| ID | Test | Status |
|----|------|--------|
| MU-UF01 | User A unfriends User B → both lose each other from friend list | PENDING |
| MU-UF02 | After unfriend: User B's static shared recipes remain in A's list (copy-on-write) | PENDING |
| MU-UF03 | After unfriend: User B loses access to A's realtime collaborative recipes | PENDING |
| MU-UF04 | After unfriend: User B loses access to A's collaborative shopping lists | PENDING |
| MU-UF05 | After unfriend: existing direct messages remain readable but sending is blocked | PENDING |
| MU-UF06 | User A unshares a recipe → User B no longer sees it in "Shared with me" | PENDING |
| MU-UF07 | User A unshares, User B already imported → B's copy is unaffected | PENDING |
| MU-UF08 | User A unshares menu → all associated shared recipe links also removed for B | PENDING |

### Phase 71: Multi-User: Messaging Edge Cases (PENDING — P2)

Messaging scenarios requiring two simultaneous users with specific timing.

| ID | Test | Status |
|----|------|--------|
| MU-MS01 | Both users send message at the exact same time → both messages appear in order | PENDING |
| MU-MS02 | User A sends message while User B is offline → B sees it when reconnecting | PENDING |
| MU-MS03 | User A deletes message → User B no longer sees it (real-time removal) | PENDING |
| MU-MS04 | User A reacts to User B's message → B sees reaction in real-time | PENDING |
| MU-MS05 | User A sends image → User B sees image preview and can open fullscreen | PENDING |
| MU-MS06 | User A replies to User B's message → reply banner references correct message | PENDING |
| MU-MS07 | Read receipts: User B opens conversation → User A sees messages marked as read | PENDING |
| MU-MS08 | Archive conversation on User A side → User B's conversation unaffected | PENDING |

### Phase 72: Multi-User: Presence & Typing (PENDING — P2)

Online status and typing indicators across two simultaneous sessions.

| ID | Test | Status |
|----|------|--------|
| MU-PT01 | User B opens chat → User A sees User B as "online" (presence indicator) | PENDING |
| MU-PT02 | User B starts typing → User A sees typing indicator within 1-2 seconds | PENDING |
| MU-PT03 | User B stops typing → typing indicator clears after ~5 seconds | PENDING |
| MU-PT04 | User B closes app → User A sees status change to "offline" (may have delay) | PENDING |
| MU-PT05 | User B opens collaborative recipe → User A sees B in participant list | PENDING |
| MU-PT06 | User B leaves collaborative recipe → User A sees B removed from participant list | PENDING |
| MU-PT07 | User B force-kills app → presence stays "online" temporarily (known limitation) | PENDING |

### Phase 73: Multi-User: Shared Content Lifecycle (PENDING — P1)

Full lifecycle of shared content from both sender and receiver perspectives.

| ID | Test | Status |
|----|------|--------|
| MU-SC01 | User A shares recipe with message → User B sees message alongside recipe | PENDING |
| MU-SC02 | User B views shared recipe → marked as "viewed" (read indicator for A) | PENDING |
| MU-SC03 | User B dismisses shared recipe → disappears from B's inbox, A unaffected | PENDING |
| MU-SC04 | User B imports shared recipe → marked as "imported" for A's tracking | PENDING |
| MU-SC05 | User A edits original recipe after sharing → static copy for B is unchanged | PENDING |
| MU-SC06 | User A edits recipe shared in realtime mode → B sees changes live | PENDING |
| MU-SC07 | User B searches shared content → finds by title, sender name, and share message | PENDING |
| MU-SC08 | "Show imported" toggle → previously imported items reappear in B's list | PENDING |
| MU-SC09 | Multiple shares: A shares 3 recipes + 2 menus → B sees all 5 with correct tab counts | PENDING |

### Phase 74: Feedback FAB & Beta Form (PENDING — P1)

Verify the feedback FAB ("!") button and beta feedback form dialog.

| ID | Test | Status |
|----|------|--------|
| FEED-01 | Feedback FAB ("!") visible on every main screen | PENDING |
| FEED-02 | Tap FAB opens feedback form dialog | PENDING |
| FEED-03 | Form includes category picker, description field, screenshot toggle | PENDING |
| FEED-04 | Submit with description → success snackbar, dialog closes | PENDING |
| FEED-05 | Submit with empty description → validation error | PENDING |
| FEED-06 | Cancel closes dialog without submitting | PENDING |
| FEED-07 | FAB does not obstruct bottom navigation or other buttons | PENDING |

### Phase 75: Allergen Preferences Settings (PENDING — P1)

Verify allergen/dietary preferences settings screen and retag action.

| ID | Test | Status |
|----|------|--------|
| APREF-01 | Open allergen preferences from Settings | PENDING |
| APREF-02 | Toggle individual allergens on/off | PENDING |
| APREF-03 | Toggle dietary preferences on/off | PENDING |
| APREF-04 | "Show on cards" / "Show on detail" / "Show coverage" display toggles | PENDING |
| APREF-05 | Save changes → persisted on reload | PENDING |
| APREF-06 | Reset to defaults restores default allergen set | PENDING |
| APREF-07 | "Re-tag All Recipes" shows retag progress dialog with cancel | PENDING |
| APREF-08 | Discard changes reverts unsaved toggles | PENDING |

### Phase 76: Friend Profile & Social Actions (PENDING — P2)

Verify friend profile view and social action buttons.

| ID | Test | Status |
|----|------|--------|
| FPROF-01 | Open friend profile from friends list | PENDING |
| FPROF-02 | Friend stats display (friends count, public recipes) | PENDING |
| FPROF-03 | "Send message" navigates to DM conversation | PENDING |
| FPROF-04 | "Share recipe" opens recipe selection dialog | PENDING |
| FPROF-05 | "Remove friend" shows confirmation, removes on confirm | PENDING |
| FPROF-06 | "Report" opens report content dialog | PENDING |
| FPROF-07 | Block user from profile → user disappears from friends list | PENDING |
| FPROF-08 | Unblock user from Settings > Blocked Users section | PENDING |
| FPROF-09 | Group invitation card: accept/decline incoming group invite | PENDING |

### Phase 77: Language Switching & Localization (PENDING — P2)

Verify language toggle and localization behavior.

| ID | Test | Status |
|----|------|--------|
| LANG-01 | Profile edit shows language radio buttons (Svenska/English) | PENDING |
| LANG-02 | Switch language → all UI labels update immediately | PENDING |
| LANG-03 | Language persists after app restart | PENDING |
| LANG-04 | Allergen/dietary names display in selected language | PENDING |
| LANG-05 | Error messages display in selected language | PENDING |
| LANG-06 | Date/time formatting follows locale (e.g. "15 mars" vs "March 15") | PENDING |

### Phase 78: Chat Media & Conversation Creation (PENDING — P2)

Verify new conversation creation and image sharing in chat.

| ID | Test | Status |
|----|------|--------|
| CHATM-01 | "New conversation" button opens friend picker dialog | PENDING |
| CHATM-02 | Select friend → new DM conversation created, navigates to it | PENDING |
| CHATM-03 | "New group conversation" → select 2+ friends → group chat created | PENDING |
| CHATM-04 | Group chat shows all member names in header | PENDING |
| CHATM-05 | Image picker button in chat compose area | PENDING |
| CHATM-06 | Select image → preview shown → send → image appears in chat | PENDING |
| CHATM-07 | Received image renders as thumbnail, tap opens fullscreen | PENDING |
| CHATM-08 | Image sending shows upload progress indicator | PENDING |

### Phase 79: Shared Content Management (PENDING — P2)

Verify dismiss/undismiss, audit log, and parsing correction flows.

| ID | Test | Status |
|----|------|--------|
| SCM-01 | Dismiss received shared recipe → disappears from "Shared with me" | PENDING |
| SCM-02 | Undismiss (if UI exists) → item reappears | PENDING |
| SCM-03 | Dismiss shared menu → removed from shared menus list | PENDING |
| SCM-04 | Editable menu items preview: remove items before adding to shopping list | PENDING |
| SCM-05 | View audit log in GDPR/account section (if surfaced in UI) | PENDING |
| SCM-06 | Submit parsing correction ("this tag is wrong") on recipe detail | PENDING |
| SCM-07 | AI re-consent dialog triggers for existing users after consent version bump | PENDING |
| SCM-08 | Accept/decline re-consent → preference persisted | PENDING |

### Phase 80: Device & Background Behaviors (PENDING — P3)

Verify device integrity, caching, OCR quota, and retag progress behaviors.

| ID | Test | Status |
|----|------|--------|
| DEV-01 | Device integrity warning shown on rooted/jailbroken device (if testable) | PENDING |
| DEV-02 | Warning can be dismissed, app continues to function | PENDING |
| DEV-03 | URL import hits global recipe cache → faster import for previously-imported URL | PENDING |
| DEV-04 | Cache miss → normal import speed, cache populated for next time | PENDING |
| DEV-05 | OCR quota reached → user-facing error/upgrade prompt | PENDING |
| DEV-06 | OCR quota resets → photo import works again | PENDING |
| DEV-07 | Retag progress dialog shows progress bar and recipe count | PENDING |
| DEV-08 | Cancel retag mid-progress → stops cleanly, partial results kept | PENDING |

## Web Testing Notes

- **CanvasKit text input**: Works via Ctrl+A + type when field is focused (hidden DOM input activates)
- **CanvasKit dialog buttons**: Clickable via shadow DOM canvas pointer events (`flt-glass-pane > shadowRoot > canvas`)
- **Firebase Auth signout on web**: `window.firebase_auth.getAuth()` + `firebase_auth.signOut(auth)`
- **Bottom-positioned buttons**: Intermittent hit-testing issues on web (save buttons sometimes unresponsive)
- **N/A on web**: File upload (4), image upload (2), keyboard nav (1), MFA SMS (1), typing indicator (1), salad recipe (1), other (10)
