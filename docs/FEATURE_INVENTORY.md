# Butlery — Feature Inventory

> **What this is.** A single, plain-language map of every user-facing feature in Butlery, what each is supposed to do (read from the actual code, not from tickets), and whether a test currently proves it works. Built 2026-06-21 by reading the codebase cluster-by-cluster.
>
> **How to read it.** Start with *Coverage at a glance* and *Gaps worth ticketing*. The *Master index* lists all 137 features with their test status. The *Detailed records* hold the full story per feature. A companion sortable spreadsheet lives at `docs/feature_inventory.csv` (import into Google Sheets).
>
> **Test status legend.** **Verified** = a test exists that would fail if this broke. **Partial** = the logic underneath is tested but the screen/flow on top isn't, *or* only part of the feature is covered. **Untested** = no test found.
>
> **Feature IDs** are area-prefixed (AUTH-, REC-, IMP-, MENU-, SOC-, GRP-, COOK-, SET-, ENG-) so they never collide and are stable to cite in Linear tickets.

## Coverage at a glance

| Area | Features | Verified | Partial | Untested |
|---|---|---|---|---|
| Auth & Onboarding (AUTH) | 14 | 12 | 1 | 1 |
| Recipe Management (REC) | 15 | 1 | 11 | 3 |
| Recipe Import (IMP) | 11 | 5 | 6 | 0 |
| Menu & Shopping (MENU) | 15 | 13 | 2 | 0 |
| Social (SOC) | 18 | 12 | 3 | 3 |
| Groups & Messaging (GRP) | 12 | 7 | 4 | 1 |
| Cooking, Pantry & Search (COOK) | 12 | 9 | 3 | 0 |
| Settings, Legal & Admin (SET) | 14 | 7 | 3 | 4 |
| Engine & Background (ENG) | 26 | 16 | 8 | 2 |
| **Total** | **137** | **82** | **41** | **14** |

> _Partial refresh 2026-07-14:_ the AUTH and IMP rows above were re-verified against the current test suite (AUTH-11, AUTH-14 now Verified; IMP-06 now Partial — see the Tier-1 list below). The other rows still reflect the 2026-06-21 audit and have not been re-run wholesale.

**Reading the pattern:** the back-end engines and the menu/shopping flows are well-tested. The thinnest coverage is at the *screen* layer of recipe management — the create/edit forms have solid logic tests but almost no tests that drive the actual UI. The security/compliance-sensitive gaps flagged at build time have since been largely closed (MFA, client-side account deletion, receive-share, social extraction all now have tests — see the refreshed Tier-1 list); allergen/dietary filtering (REC-03) remains the one safety-sensitive item still lacking dedicated assertions.

## Gaps worth ticketing

Prioritized by risk, not by count. These are the candidates to turn into Linear tickets; the existing sprint loop can then fix them through its normal sign-off tiers.

**Tier 1 — safety / security / compliance, currently untested:**
- **REC-03 — Allergen/dietary recipe filtering (Partial).** The high-risk "only show allergen-free at 100% coverage" safety logic lives here; it has VM-level coverage but still lacks dedicated filter-path assertions given the safety stakes. **Still open — the one remaining Tier-1 gap.**

_Closed since the 2026-06-21 build (verified 2026-07-14):_
- **AUTH-11 / SET-05 — MFA (SMS).** Service logic now covered by `auth_mfa_service_test.dart` + `mfa_types_test.dart` (BUT-1333: enroll, code delivery, sign-in resolution, error mapping). Residual: the `MfaSettingsView` enrollment screen (SET-05) is still untested at the view layer — a Tier-2 UI gap, not a Tier-1 safety one.
- **AUTH-14 — Account deletion (client trigger).** Now has a dedicated path test — `account_deletion_journey_test.dart` drives `ProfileViewModel` → `AccountDeletionService` through the UI-triggered flow (cancel-does-nothing, confirm-fires-once).
- **IMP-06 — Receive-share** and **IMP-07 — Instagram/TikTok extraction.** Handler decision-logic is covered by `incoming_share_handler_test.dart` (BUT-941); extraction by `social_media_extractor_test.dart`, `extraction_manager_test.dart`, `platform_detector_test.dart`, `content_detector_service_test.dart`. IMP-06 remains **Partial** (no device-level share-intent E2E).

**Tier 2 — user-facing flows with logic tested but no UI test:**
- **REC-07 Quick capture, REC-08 Add-recipe hub, REC-09/REC-10 create & edit forms** — form submission, swipe gestures, and hub navigation untested at the screen layer.
- **AUTH-05 Email-verification gate** — the gate UI is untested.
- **SOC-06 / SOC-07 profile screens** and **SOC-18 report dialog** — untested at the view level.
- **GRP-06 Create group conversation** — viewmodel has no test.
- **SET-06 Collection statistics, SET-11 Legal pages, SET-12 FAQ** — untested (low logic risk; mostly display).

**Tier 3 — low risk, web-only or background:**
- **ENG-25 PWA install prompt, ENG-26 Recipe print** — web-only, no server cost, untested.
- **ENG-15 Predictive cache, ENG-14 Image optimization, ENG-06 personal-tag rule engine** — background services with adjacent coverage but no dedicated tests.

**Notes & known stubs surfaced during discovery:**
- **MENU-10** — ~~stub note~~ corrected 2026-07-02: `loadImportedMenuData` reads and parses real Firestore data end to end (workflow-map trace).
- **SET-12 FAQ** content is hardcoded Swedish, not localized via the normal l10n system — inconsistent with the rest of the app.
- **Intentional overlaps:** Cook-snaps appear as both REC-12 (gallery on the recipe page) and SOC-16 (the social feature) — same feature, two surfaces. Friend groups appear as SOC-05 and GRP-01 (friend-categorization vs. the group surface). The "social discovery dashboard" was deliberately removed and is confirmed gone.

---

## Master index

### Auth & Onboarding
| ID | Feature | Tests |
|---|---|---|
| AUTH-01 | Email/password sign-in | Verified |
| AUTH-02 | Email/password registration | Verified |
| AUTH-03 | Password reset email | Partial |
| AUTH-04 | Sign-out (manual / inactivity / forced) | Verified |
| AUTH-05 | Email-verification gate | Untested |
| AUTH-06 | GDPR age gate (under-15 block) | Verified |
| AUTH-07 | Onboarding allergen & dietary selection | Verified |
| AUTH-08 | Onboarding completion, resume & seeding | Verified |
| AUTH-09 | Change password | Verified |
| AUTH-10 | Change email | Verified |
| AUTH-11 | Multi-factor authentication (SMS) | Verified |
| AUTH-12 | GDPR consent management | Verified |
| AUTH-13 | GDPR data export | Verified |
| AUTH-14 | Account deletion (client trigger) | Verified |

### Recipe Management
| ID | Feature | Tests |
|---|---|---|
| REC-01 | Browse recipe collection (list/grid) | Partial |
| REC-02 | Recipe search with history | Partial |
| REC-03 | Multi-criteria filtering + sort | Partial |
| REC-04 | Favorite toggle | Partial |
| REC-05 | Swipe-to-edit / swipe-to-delete | Partial |
| REC-06 | Bulk selection + bulk actions | Partial |
| REC-07 | Quick capture (title only) | Untested |
| REC-08 | Add-recipe hub | Untested |
| REC-09 | Manual recipe entry (create) | Partial |
| REC-10 | Edit recipe | Partial |
| REC-11 | Recipe detail view | Partial |
| REC-12 | Cook-snap gallery (recipe surface) | Untested |
| REC-13 | Re-extract recipe from source | Verified |
| REC-14 | Personal tags & collections | Partial |
| REC-15 | Tag detail + automation rules | Partial |
| REC-16 | Voice recipe search (Tala in din sökning) | Verified |

### Recipe Import
| ID | Feature | Tests |
|---|---|---|
| IMP-01 | URL import (single + batch) | Verified |
| IMP-02 | Recipe-index (listing-page) expansion | Partial |
| IMP-03 | Smart (unified) import | Verified |
| IMP-04 | Photo / OCR import (multi-page) | Verified |
| IMP-05 | Text / paste import | Verified |
| IMP-06 | Receive-share (share intent) | Partial |
| IMP-07 | Social-media URL extraction | Partial |
| IMP-08 | File import (CSV/Excel) | Verified |
| IMP-09 | Import from archive (restore) | Partial |
| IMP-10 | Assisted import wizard | Partial |
| IMP-11 | Ingredient-line parsing (CRF/NER/ONNX) | Partial |

### Menu & Shopping
| ID | Feature | Tests |
|---|---|---|
| MENU-01 | Generate weekly menu from prompt | Verified |
| MENU-02 | Manual menu placement mode | Verified |
| MENU-03 | Edit weekly menu calendar | Verified |
| MENU-04 | Bulk move + copy week to next | Verified |
| MENU-05 | Swap single menu recipe | Partial |
| MENU-06 | Generate shopping list from menu | Verified |
| MENU-07 | Real-time collaborative menu | Verified |
| MENU-08 | Menu slot voting | Verified |
| MENU-09 | Conflict resolution + diff/recovery | Verified |
| MENU-10 | Share / import a menu | Verified |
| MENU-11 | Unified shopping list management | Verified |
| MENU-12 | Create shared shopping list | Verified |
| MENU-13 | Collaborative shopping view | Verified |
| MENU-14 | Browse shared shopping lists | Partial |
| MENU-15 | Share an existing shopping list | Verified |
| MENU-16 | Voice menu prompt (Tala in veckomenyn) | Verified |

### Social
| ID | Feature | Tests |
|---|---|---|
| SOC-01 | Send friend request | Verified |
| SOC-02 | Accept / reject / cancel request | Verified |
| SOC-03 | Friends list & remove friend | Verified |
| SOC-04 | Block / unblock user | Partial |
| SOC-05 | Friend groups / categories | Verified |
| SOC-06 | View public profile | Untested |
| SOC-07 | View friend profile | Untested |
| SOC-08 | Edit own profile (identity, privacy) | Partial |
| SOC-09 | Share recipe with friends | Verified |
| SOC-10 | Request a recipe share | Verified |
| SOC-11 | Accept a recipe-share request | Verified |
| SOC-12 | Shared-with-me browsing | Partial |
| SOC-13 | Comment on recipes | Verified |
| SOC-14 | Like / unlike comments | Verified |
| SOC-15 | Rate recipes (1–5 stars) | Verified |
| SOC-16 | Cook-snaps (social surface) | Verified |
| SOC-17 | Activity feed | Verified |
| SOC-18 | Report content / user | Untested |
| SOC-19 | Voice comment on recipes (Tala in en kommentar) | Verified |

### Groups & Messaging
| ID | Feature | Tests |
|---|---|---|
| GRP-01 | Create social group | Partial |
| GRP-02 | Group detail — manage & share | Verified |
| GRP-03 | Leave group / transfer ownership | Verified |
| GRP-04 | Add members / send invitations | Verified |
| GRP-05 | Group invitations — browse & join | Verified |
| GRP-06 | Create group conversation (chat) | Untested |
| GRP-07 | Group conversation member management | Verified |
| GRP-08 | Share recipes with a group | Verified |
| GRP-09 | Meal-vote poll | Partial |
| GRP-10 | Conversations list | Verified |
| GRP-11 | Direct (1:1) conversation start | Partial |
| GRP-12 | Chat (message/reply/edit/attach/poll) | Partial |

### Cooking, Pantry & Search
| ID | Feature | Tests |
|---|---|---|
| COOK-01 | Cooking mode (landscape split-view) | Verified |
| COOK-02 | Portion scaling in cooking mode | Verified |
| COOK-03 | Step timers (concurrent) | Verified |
| COOK-04 | Ingredient substitution suggestions | Partial |
| COOK-05 | Cooking-session presence + analytics | Verified |
| COOK-06 | Pantry item management | Verified |
| COOK-07 | Pantry add/edit via autocomplete | Partial |
| COOK-08 | Pantry swipe-delete with undo | Verified |
| COOK-09 | Pantry multi-select bulk delete | Verified |
| COOK-10 | Auto-add bought items to pantry | Verified |
| COOK-11 | Ingredient-set recipe search | Verified |
| COOK-12 | Ingredient lookup / normalization | Partial |
| COOK-13 | Köksbutlern voice assistant (cooking mode) | Verified |
| COOK-14 | Köksbutlern Q&A (substitutions/quantities/step jumps) | Verified |

### Settings, Legal & Admin
| ID | Feature | Tests |
|---|---|---|
| SET-01 | Settings hub | Partial |
| SET-02 | Allergen & dietary preferences | Verified |
| SET-03 | Notification preferences | Partial |
| SET-04 | Account security screen | Partial |
| SET-05 | MFA enrollment screen | Untested |
| SET-06 | Collection statistics | Untested |
| SET-07 | In-app notification inbox | Verified |
| SET-08 | Notification deep-link routing | Verified |
| SET-09 | Beta feedback FAB | Verified |
| SET-10 | Beta feedback form | Verified |
| SET-11 | Legal documents (terms/privacy/guidelines) | Untested |
| SET-12 | FAQ / help | Untested |
| SET-13 | My reports (status tracking) | Verified |
| SET-14 | Content moderation queue (admin) | Verified |

### Engine & Background
| ID | Feature | Tests |
|---|---|---|
| ENG-01 | Automatic recipe tagging (5-phase) | Verified |
| ENG-02 | Allergen/dietary status detection | Verified |
| ENG-03 | Quick phase-1 tag preview | Partial |
| ENG-04 | Automatic retagging scheduler | Partial |
| ENG-05 | Bulk / manual retag-all | Verified |
| ENG-06 | Personal-tag rule engine | Partial |
| ENG-07 | Tiered recipe parsing (import engine) | Verified |
| ENG-08 | Selective ingredient-line LLM enhancement | Partial |
| ENG-09 | On-device parsing cascade (CRF→NER→LLM) | Partial |
| ENG-10 | Parse-correction feedback (active learning) | Verified |
| ENG-11 | Recipe search (local, on-device matching) | Verified |
| ENG-12 | Allergen filtering in menu generation | Verified |
| ENG-13 | Offline sync & connectivity monitoring | Verified |
| ENG-14 | Image optimization & progressive loading | Partial |
| ENG-15 | Predictive cache / prefetch | Partial |
| ENG-16 | Ingredient-change stale-marking cascade | Verified |
| ENG-17 | LLM recipe extraction (server fallback) | Verified |
| ENG-18 | Social push notifications | Verified |
| ENG-19 | Notification gating (RC/quiet-hours/cap) | Verified |
| ENG-20 | Re-engagement: win-back & digest | Verified |
| ENG-21 | Rating aggregation (debounced) | Verified |
| ENG-22 | Upload & content moderation | Verified |
| ENG-23 | Account deletion cascade / GDPR engine | Verified |
| ENG-24 | Scheduled storage & data cleanup jobs | Partial |
| ENG-25 | PWA install prompt (web) | Untested |
| ENG-26 | Recipe print (web) | Untested |

---

## Detailed records

### Auth & Onboarding

#### AUTH-01: Email/password sign-in
- **Entry:** AuthView (shown by AuthWrapper when no user; route `/auth`). Login is the default mode.
- **User story:** As a returning user, I want to log in with my email and password so that I can reach my recipes and account.
- **Expected behavior:** Validates email + password, delegates to `AuthService.signInWithEmail`. On success the auth-state stream updates, DI pushes the user scope, a `login` analytics event fires, and AuthWrapper routes onward (no manual navigation).
- **Edge cases:** "Succeeds" but no user returned → `errorLoginFailed`. FirebaseAuthException → mapped message. Android GMS false-positive errors swallowed, then re-checks `currentUser`. Session-expired banner shown after a prior token revocation.
- **Validation:** Email non-empty + Unicode-aware regex; password non-empty and ≥8. Email trimmed.
- **Test coverage:** Verified — `test/unit/viewmodels/auth_viewmodel_test.dart`, `test/unit/services/auth_service_test.dart`, `test/unit/repositories/auth_repository_test.dart`, `test/unit/core/utils/auth_error_mapper_test.dart`, `test/widget/views/auth/auth_view_register_routing_test.dart`, `test/smoke/journeys/auth.md`.

#### AUTH-02: Email/password registration
- **Entry:** AuthView in register mode (`toggleAuthMode`).
- **User story:** As a new user, I want to create an account with email, password, and a display name so that I can start using the app.
- **Expected behavior:** Validates all three fields, creates the user, sets display name, sends a verification email (non-blocking), pushes the user scope, logs `sign_up`. User is then unverified → routed to the email-verification gate.
- **Edge cases:** Verification-email failure caught/logged, doesn't block. FirebaseAuthException mapped. GMS false-positives swallowed. Null credential.user → returns false silently.
- **Validation:** Email (as AUTH-01); password ≥8; display name ≥2. Email + name trimmed. Legal links shown on the auth view.
- **Test coverage:** Verified — `test/unit/viewmodels/auth_viewmodel_test.dart`, `test/unit/services/auth_service_test.dart`, `test/widget/views/auth/auth_view_register_routing_test.dart`, `test/widget/views/auth/auth_view_legal_links_test.dart`.

#### AUTH-03: Password reset email
- **Entry:** AuthView "forgot password" path.
- **User story:** As a user who forgot my password, I want to request a reset link by email so that I can regain access.
- **Expected behavior:** Validates the email then calls `sendPasswordResetEmail`. Returns true on success.
- **Edge cases:** Invalid/empty email → validation error, no send. FirebaseAuthException mapped; other errors → `errorUnexpected`.
- **Validation:** Email non-empty + regex; trimmed.
- **Test coverage:** Partial — exercised via `auth_viewmodel_test.dart` and `auth_service_test.dart`; no dedicated reset-flow widget test.

#### AUTH-04: Sign-out (manual, inactivity, forced session-expiry)
- **Entry:** Profile/settings (manual); SessionTimeoutService (inactivity); auth-state stream on fatal error (forced).
- **User story:** As a user, I want to be securely signed out — by my own action, after inactivity, or when my session is invalid — so that my account stays protected.
- **Expected behavior:** `signOut` pops the user DI scope, signs out, clears the user, logs `logout`. Inactivity logout also clears consent cache. A fatal auth-stream error (user-disabled, token-expired, etc.) forces sign-out, sets `sessionExpired`, surfaces `errorSessionExpired`.
- **Edge cases:** Transient/non-fatal stream errors keep the session (BUG-31). signOut failure → `errorCouldNotLogOut`. forceSignOut always clears state in `finally`.
- **Test coverage:** Verified — `test/unit/services/auth_service_test.dart`.

#### AUTH-05: Email-verification gate (resend + reload)
- **Entry:** EmailVerificationView, shown by AuthWrapper when a signed-in user's email is unverified.
- **User story:** As a newly registered user, I want to verify my email (and resend the link) so that I can unlock the rest of the app.
- **Expected behavior:** Exposes `isEmailVerified`, `sendEmailVerification`, `reloadUser` (re-fetches the user so the gate re-evaluates). User held on this screen until verified.
- **Edge cases:** sendEmailVerification maps + rethrows; reloadUser failure logged and swallowed (stays on gate).
- **Test coverage:** **Untested** — no test for EmailVerificationView or the AuthWrapper verification branch.

#### AUTH-06: GDPR age gate (onboarding step 0)
- **Entry:** First onboarding page (OnboardingAgeGatePage) via `/onboarding`.
- **User story:** As a minor under 15, I should be blocked from creating an account so that the app complies with Swedish GDPR Art. 8.
- **Expected behavior:** User must explicitly pick a birth year (no default seeded). Age ≥15 passes; otherwise routed to a blocked screen. Birth year persisted at completion.
- **Edge cases:** No year → Next disabled. Under-15 best-effort deletes the Auth record; on `requires-recent-login` falls back to sign-out. A "parent info" dialog offers a kinder path. Back-dismiss prevented.
- **Validation:** Min age 15; birth year required.
- **Test coverage:** Verified — `test/widget/views/onboarding_age_gate_page_test.dart`, `test/unit/viewmodels/onboarding_viewmodel_test.dart`, `test/views/onboarding_journey_test.dart`.

#### AUTH-07: Onboarding allergen & dietary selection
- **Entry:** Onboarding allergen + dietary pages.
- **User story:** As a new user, I want to pick the allergens and diets I care about so that the app filters and tailors recipes for me from day one.
- **Expected behavior:** Multi-select toggles accumulate; on completion saved as `UserAllergenPreferences` (only if non-empty). Counts logged.
- **Edge cases:** Both empty → prefs saved as null. Re-toggling removes.
- **Test coverage:** Verified — `test/widget/views/onboarding_allergen_page_test.dart`, `onboarding_dietary_page_test.dart`, `onboarding_viewmodel_test.dart`.

#### AUTH-08: Onboarding completion, progress persistence & resume
- **Entry:** Onboarding wizard (welcome→allergen→dietary→import); resumed by AuthWrapper at the saved step.
- **User story:** As a new user, I want onboarding to remember where I left off and land me on a populated app so that I'm not stuck on empty screens.
- **Expected behavior:** Each step persists. Completion writes prefs + birth year (20s timeout), stamps `completed`, seeds starter recipes, builds a sample weekly menu + shopping list. Resumes at the saved page on cold start.
- **Edge cases:** Completion hang → timeout caught → returns false → generic error not infinite spinner (BUT-33). Per-recipe seed failures tolerated/counted. Sample-menu seeding idempotent.
- **Test coverage:** Verified — `onboarding_viewmodel_test.dart`, `onboarding_progress_service_test.dart`, `onboarding_journey_test.dart`, `onboarding_landscape_overflow_test.dart`.

#### AUTH-09: Change password (account security)
- **Entry:** AccountSecurityView, `/settings/account-security`.
- **User story:** As a signed-in user, I want to change my password (after confirming my current one) so that I can keep my account secure.
- **Expected behavior:** Validates inputs, reauthenticates with the current password, then changes it.
- **Edge cases:** Reauth failure → service error, aborts. FirebaseAuthException mapped.
- **Validation:** All three non-empty; new ≥8; new must equal confirm.
- **Test coverage:** Verified — `test/unit/viewmodels/account_security_viewmodel_test.dart`. Reauth is mandatory before the change.

#### AUTH-10: Change email (account security)
- **Entry:** AccountSecurityView, `/settings/account-security`.
- **User story:** As a signed-in user, I want to change my account email (after confirming my password) so that I can update my contact address.
- **Expected behavior:** Validates new email, reauthenticates, then `verifyBeforeUpdateEmail` (sends a link to the new address; change takes effect only after verification).
- **Edge cases:** Empty current password → validation error. Reauth/change failures surface service errors.
- **Test coverage:** Verified — `account_security_viewmodel_test.dart`. Uses verify-before-update.

#### AUTH-11: Multi-factor authentication (SMS enroll / unenroll / sign-in)
- **Entry:** MfaSettingsView (from Account Security); sign-in challenge surfaces during login when a factor is enrolled.
- **User story:** As a security-conscious user, I want a phone-based second factor so that my account is protected even if my password leaks.
- **Expected behavior:** AuthMfaService handles enroll (session → verify phone → SMS code → enroll, with auto-verify), unenroll, and sign-in resolution. Logs `mfa_enrolled`/`mfa_unenrolled`/MFA login.
- **Edge cases:** No user → false / `user-not-found`. Status reads default to "no MFA" on error. Various FirebaseAuthExceptions mapped. 60s SMS timeout.
- **Test coverage:** Verified (service) — `auth_mfa_service_test.dart` (BUT-1333) proves enroll start, SMS-code delivery to caller, sign-in resolution, and error→l10n mapping; `mfa_types_test.dart` covers the model. Residual: `MfaSettingsView` (the SET-05 enrollment screen) is still untested at the view layer.

#### AUTH-12: GDPR consent management (Article 7)
- **Entry:** ConsentManagementView; also a consent-renewal dialog.
- **User story:** As a user, I want to grant or revoke consent for analytics, marketing, social, and push so that I control how my data is used.
- **Expected behavior:** Loads current consent; four user-controllable toggles + two always-on required purposes. Save persists + reloads timestamps. Analytics observers honor the analytics consent.
- **Edge cases:** No stored consent → optional default false, `needsRenewal` true. Save false → `errorGeneric`. No user → must-be-logged-in error. Cache cleared on sign-out/inactivity.
- **Validation:** Essential services + data processing hard-coded true.
- **Test coverage:** Verified — `consent_viewmodel_test.dart`, `consent_service_test.dart`, `user_consent_test.dart`, `firebase_consent_repository_test.dart`, `consent_renewal_dialog_test.dart`, plus analytics-gate tests.

#### AUTH-13: GDPR data export (data portability)
- **Entry:** DataExportView.
- **User story:** As a user, I want to export all my personal data as a JSON file so that I can keep or move my information.
- **Expected behavior:** Runs a named operation (prevents concurrent exports), produces JSON + timestamp, download/share per-platform. Supports retry/clear/reset.
- **Edge cases:** No user / network / permission errors mapped to distinct messages. JSON cleared from memory on dispose.
- **Test coverage:** Verified — `data_export_viewmodel_test.dart`, `data_export_service_test.dart`.

#### AUTH-14: Account deletion (right to erasure — client trigger)
- **Entry:** ProfileViewModel (account settings). Service: AccountDeletionService.
- **User story:** As a user, I want to permanently delete my account and all associated data so that I can exercise my GDPR right to erasure.
- **Expected behavior:** Cleans search indexes + offline cache client-side, then invokes the `requestAccountDeletion` Cloud Function (which cascades server-side — see ENG-23) and deletes the Auth user last; resets local notification state and signs out.
- **Edge cases:** No user → error. Token older than 5 min → `requiresReauth`, caller must re-auth and retry. No client-side `user.delete()` (removed to avoid an auth race, BUT-788).
- **Test coverage:** Verified — `account_deletion_journey_test.dart` drives the UI-triggered path (`ProfileViewModel.deleteAccount` → `AccountDeletionService.deleteUserAccount`), asserting the confirm-dialog seam (cancel does nothing, confirm fires once with the userId's context + reason). The server cascade ENG-23 is tested separately.

---

### Recipe Management

#### REC-01: Browse recipe collection (list/grid)
- **Entry:** "Mina recept" tab (`MinaReceptView`).
- **User story:** As a home cook, I want to browse my saved recipes in a list or grid so that I can quickly find something to cook.
- **Expected behavior:** Renders recipe cards; list/grid toggle (persisted; 2/3/4 columns by device). Pull-to-refresh (syncs if online). Pagination via "Visa fler" (50/page). Scroll offset persisted + restored across navigation. Cards show allergen/dietary badges, pantry-match %, favorite toggle. Header surfaces ingredient-search, live cooking-session card, family presence bar.
- **Edge cases:** Skeleton while loading; retry on error; onboarding empty state vs "no results" when filtered.
- **Test coverage:** Partial — `recipe_list_viewmodel_test.dart`, `recipe_card_test.dart`, `recipe_card_golden_test.dart`; no widget test for `MinaReceptView` itself (toggle, scroll restore, pagination untested at view level).

#### REC-02: Recipe search with history
- **Entry:** Search box in `MinaReceptView`.
- **User story:** As a home cook, I want to search my recipes by text and reuse recent searches so that I find recipes faster.
- **Expected behavior:** Debounced 300ms filter via `SearchService`. Queries ≥3 chars saved to history (max 10, dedup, persisted). Recent-search chips re-run; per-entry removal.
- **Edge cases:** <3 chars not saved; duplicate moves to front.
- **Test coverage:** Partial — `recipe_list_viewmodel_test.dart`, `recipe_events_tracker_search_test.dart`; debounce/history persistence not explicitly asserted.

#### REC-03: Multi-criteria filtering + sort
- **Entry:** Filter panel + quick-filter chips in `MinaReceptView`.
- **User story:** As a home cook, I want to filter by time, meal type, rating, allergens, diet, personal tags, favorites and pantry-availability so that I see only relevant recipes.
- **Expected behavior:** Independent dimensions: time (OR), meal type (OR), rating (highest threshold wins), allergen-free (AND, requires 100% coverage + valid tagging), dietary (AND, same safety gate), personal tags (AND include / OR exclude), favorites-only, pantry-only (async match). Sort + all filters persisted and restored. "Rensa alla" clears.
- **Edge cases:** Allergen/dietary filters exclude recipes with no tag analysis UNLESS system-seeded (keeps starters visible). Coverage <1.0 or `needsRetagging` → excluded for safety. Pantry filter empty until async resolves.
- **Validation:** **Safety-critical** — "free" only trusted at 100% coverage with valid tagging.
- **Test coverage:** Partial — `recipe_list_viewmodel_test.dart`, `personal_tag_filter_chips_test.dart`. The allergen-safety filtering is high-risk and warrants dedicated assertions.

#### REC-04: Favorite toggle
- **Entry:** Heart icon on cards + recipe-detail hero bar.
- **User story:** As a home cook, I want to mark recipes as favorites so that I can find loved recipes quickly.
- **Expected behavior:** Boolean `isFavorite` (not a personal tag). Optimistic update with revert on failure (re-reads to avoid clobbering concurrent edits). Detail view announces new state to screen readers. No confirmation/undo.
- **Edge cases:** Failure reverts; hidden on read-only (friend's) recipes; disabled in selection mode.
- **Test coverage:** Partial — covered indirectly in list/detail VM tests; no dedicated favorites test.

#### REC-05: Swipe-to-edit / swipe-to-delete on cards
- **Entry:** Horizontal swipe on a recipe card.
- **User story:** As a home cook, I want to swipe a card to quickly edit or delete it so that I manage my collection without menus.
- **Expected behavior:** Swipe right → edit route. Swipe left → confirmation dialog → delete + 5s "Ångra" undo. Haptics. Custom semantics mirror swipe for screen readers. First-use hint banner.
- **Edge cases:** Disabled in selection mode. Delete is class-2 (dialog + undo). Undo restores by id.
- **Test coverage:** Partial — `recipe_delete_manager_test.dart` covers delete/undo; gesture/Dismissible behavior not in a widget test.

#### REC-06: Bulk selection + bulk actions
- **Entry:** Long-press a card → selection mode.
- **User story:** As a home cook, I want to select multiple recipes and act on them at once so that I can share, tag, add-to-menu, or delete in bulk.
- **Expected behavior:** Selection AppBar: select-all, bulk-share, bulk-tag (appends tag to recipes missing it, snapshot-based undo), bulk-add-to-menu, bulk-delete (confirm + undo). Per-recipe save errors swallowed so one failure doesn't block the batch.
- **Edge cases:** Disabled at 0 selected. `selectedRecipes` skips ids that went missing mid-delete.
- **Test coverage:** Partial — `recipe_selection_manager_test.dart`, `recipe_delete_manager_test.dart`, bulk-tag/undo in `recipe_list_viewmodel_test.dart`. Selection AppBar UI untested.

#### REC-07: Quick capture (title + meal type only)
- **Entry:** `/quickCapture` — "Snabbspara" button on the add-recipe hub.
- **User story:** As a busy cook, I want to instantly save just a recipe name (and meal type) so that I capture an idea without filling a full form.
- **Expected behavior:** Autofocused title field + meal-type chips (default "Middag"). Saves a personal recipe with empty ingredients/instructions. On success: pops + success snackbar with "Redigera" action.
- **Edge cases:** Save-in-progress disables button; failure shows error snackbar.
- **Validation:** Title required + non-empty.
- **Test coverage:** **Untested** — no test for `quick_capture_view.dart` or its VM.

#### REC-08: Add-recipe hub
- **Entry:** `/laggTill` ("Lägg till" tab).
- **User story:** As a home cook, I want a single screen offering all the ways to add a recipe so that I can pick the right entry point.
- **Expected behavior:** "Snabbspara" + a 2×2 grid: Importera länk → smart import, Skriv manuellt, Från bild → photo import, Från arkiv → archive import. Responsive; a11y identifiers on all buttons.
- **Test coverage:** **Untested** — no widget test for `lagg_till_recept_view.dart`.

#### REC-09: Manual recipe entry (create)
- **Entry:** `/skrivSjalv`; also fork/template target.
- **User story:** As a home cook, I want to write a recipe from scratch so that I can save my own dishes with full detail.
- **Expected behavior:** Full form (meal type, ≤5 images with per-image upload status/retry/cancel-undo, title, description, portions, time, reorderable ingredient/instruction lists, personal tags, rating, source URL). First recipe → celebration overlay; otherwise tag-result-aware snackbar. Draft-recovery on open.
- **Edge cases:** Save-race guard; unsaved-changes confirm on back; controllers in State to prevent text scrambling.
- **Validation:** Title 3–100 + profanity filter; description ≤500 + filter; numeric fields via FormValidators.
- **Test coverage:** Partial — `recipe_form_viewmodel_test.dart`, `recipe_form_state_test.dart`, `recipe_auto_save_manager_test.dart`, `recipe_image_deletion_undo_test.dart`, `recipe_persistence_manager_test.dart`, `first_recipe_celebration_overlay_test.dart`. View-level form interaction untested.

#### REC-10: Edit recipe
- **Entry:** `/redigeraRecept` — from card swipe, detail overflow, quick-capture snackbar.
- **User story:** As a recipe owner, I want to edit any field of an existing recipe so that I can correct or improve it.
- **Expected behavior:** Manual-entry form + portion-scaler (scales off immutable original), auto-tag management, related-recipes editor, collaborative-status awareness (banners, conflict banner, permission-based save/fork), auto-save indicator. On save: invalidates collaborative status, pops with `true`.
- **Edge cases:** Unsaved-changes confirm; fork path for non-owners; save/fork gated on valid + not-saving.
- **Test coverage:** Partial — `recipe_form_viewmodel_test.dart`, `recipe_collaborative_manager_test.dart`, `recipe_permission_manager_test.dart`; no `EditRecipeView` widget test.

#### REC-11: Recipe detail view
- **Entry:** `/receptDetalj` — tap a card; also from notifications (read-only / share-request modes).
- **User story:** As a home cook, I want a full recipe page with image, ingredients, instructions, metadata and actions so that I can cook and manage it.
- **Expected behavior:** Collapsing hero image (tap → fullscreen; no-image → illustration). Hero actions: start cooking, favorite (owner), share, save-a-copy/fork. Overflow: edit, duplicate, add-to-menu, generate shopping list, re-tag, edit-tags, delete, collaboration toggle, view source, print (web), report. FAB → add to shopping list. Body: title, heirloom section, completeness banner, portion-scaled ingredients, sharing status, cook-snap gallery, comments. Tablet two-column.
- **Edge cases:** `readOnly` hides owner actions for friends' recipes; `shareRequest` shows accept/dismiss banner.
- **Test coverage:** Partial (reasonably well covered) — `recipe_detail_view_test.dart`, `recipe_detail_read_only_test.dart`, `recipe_detail_completeness_banner_test.dart`, `recipe_detail_metadata_rating_format_test.dart`, `recipe_detail_headings_a11y_test.dart`, `recipe_detail_source_icon_test.dart`, `recipe_detail_viewmodel_test.dart` (+ reextract).

#### REC-12: Cook-snap gallery (recipe surface)
- **Entry:** Cook-snap gallery section in recipe detail. *(Same feature as SOC-16, viewed from the recipe page.)*
- **User story:** As a cook, I want to attach photos of the dish I made so that I (and the recipe's audience) can see real results.
- **Expected behavior:** Add via image-source dialog. A snap inherits the recipe's visibility; for non-private recipes a disclosure dialog shows the audience with a per-snap override. Delete (own): confirm + 7s undo. Report others' snaps.
- **Edge cases:** Private recipes skip disclosure. Friend names fall back to a count.
- **Test coverage:** **Untested at the recipe-management surface** (see SOC-16 / `cook_snap` model+service tests).

#### REC-13: Re-extract recipe from source artefact
- **Entry:** Recipe detail overflow → "Visa fångad källa" → re-extract.
- **User story:** As a cook, I want to re-parse a recipe from its captured source so that I can recover from a bad parse without re-importing.
- **Expected behavior:** Confirmation (warns it discards manual edits), then re-runs extraction preserving id/createdAt/sourceArtefact.
- **Edge cases:** Only when `sourceArtefact != null`; discards manual edits.
- **Test coverage:** Verified — `recipe_detail_viewmodel_reextract_test.dart`.

#### REC-14: Personal tags & collections management
- **Entry:** `/settings/personal-tags` (`PersonalTagsView`); also from filter panel + tag selectors.
- **User story:** As a home cook, I want to create, organize and automate personal tags (collections) so that I can categorize recipes my own way.
- **Expected behavior:** Tags grouped + ungrouped, sortable. Create/edit/delete/reorder, bulk select (merge ≥2, bulk delete ≥1), delete-all-unused with count confirm. Tags are shareable (collections).
- **Edge cases:** Add-menu deferred a frame to avoid lifecycle bugs; sort cache invalidated on tag-hash change.
- **Test coverage:** Partial — `personal_tag_viewmodel_test.dart`, `personal_tag_selection_manager_test.dart`, tagging model tests. View untested.

#### REC-15: Tag detail + automation rules
- **Entry:** `TagDetailView` (tap a tag).
- **User story:** As a home cook, I want to edit a tag and define rules that auto-apply it so that recipes get tagged automatically.
- **Expected behavior:** Tag header + usage + rules. Inline name edit; add/edit/delete/toggle automation rules; "Tillämpa regler" applies to existing recipes (progress → result). Share tag. Delete shows cascade preview (how many recipes lose the tag).
- **Edge cases:** Loading/not-found; rule + tag delete need confirmation.
- **Test coverage:** Partial — VM + rule model covered (`personal_tag_rule_test.dart`, `personal_tag_viewmodel_test.dart`); `TagDetailView` widget untested.

#### REC-16: Voice recipe search ("Tala in din sökning")
- **Entry:** Mic in the Mina recept search field (`SearchFilterWidget.enableVoiceInput` → `VoicePromptButton`).
- **User story:** As a home cook, I want to speak a search query so that I can find a recipe without typing.
- **Expected behavior:** Push-to-talk → on-device KB-Whisper transcription → transcript lands in the search box as if typed (same onSearchChanged path; Algolia/Firestore routing untouched). Opt-in per surface — other lists sharing the search facade show no mic. Audio deleted after transcription, never uploaded.
- **Edge cases:** Denied mic → typed search untouched; model missing → "inte tillgänglig" notice with typing pointer; hidden on web.
- **Test coverage:** Verified — `search_filter_widget_test.dart` (spoken query → onSearchChanged; no mic by default), plus the shared `voice_prompt_button_test.dart` degradation suite.

### Recipe Import

#### IMP-01: URL import (single + multi-URL batch)
- **Entry:** `/importViaUrl`; also from ReceiveShare for detected recipe URLs.
- **User story:** As a home cook, I want to paste one or several recipe links and have them fetched and parsed so that I don't retype recipes from sites I browse.
- **Expected behavior:** Single URL → platform detect + mobile→web conversion → headless extraction → parse → editor. Multiple URLs (various separators, de-duplicated) → sequential batch fetch (never concurrent — cost/rate-limit safety) with per-URL progress + retry, partial-success tolerance, combined handoff to the multi-recipe picker. Pre-fetch suggestions flag known sites, keywords, social links.
- **Edge cases:** Empty/malformed URL; non-http(s); private/reserved host blocked (SSRF guard); whole-batch failure surfaces batch error while good rows stay importable.
- **Validation:** Localized URL validation; only well-formed fetchable URLs kept.
- **Test coverage:** Verified — `url_import_viewmodel_test.dart`, `url_import_strategy_test.dart`, `import_via_url_view_multi_test.dart`.

#### IMP-02: Recipe-index (listing-page) expansion
- **Entry:** Opt-in banner within `/importViaUrl` after an index page is detected.
- **User story:** As a user pasting a category/index page, I want the app to offer to import every recipe it links to so that I can bulk-add a collection in one step.
- **Expected behavior:** Probe-fetches (SSRF-guarded), harvests recipe links, shows "import all N" only when link count ≥ threshold. On opt-in runs the sequential batch fetch. Never auto-runs.
- **Edge cases:** Single page / fetch fail / too few links → no banner (silent). URL edited mid-probe clears stale links.
- **Test coverage:** Partial — via `url_import_viewmodel_test.dart` (no dedicated expander test).

#### IMP-03: Smart (unified) import
- **Entry:** `/smartImport` — primary "Importera länk" tile, deep-link target, empty-state CTA.
- **User story:** As a user, I want one box where I paste either a URL or recipe text and the app figures out what to do so that I don't have to choose an import method.
- **Expected behavior:** Classifies URL vs text + platform; runs a fetching→analyzing→creating phase machine. Resolves to success (→ editor), needs-help (→ assisted dialog), rate-limited (→ dialog with real retryAfter), or failure. Clipboard checked once. Offline URL imports saved as pending + auto-retried on reconnect.
- **Edge cases:** Offline + URL → saved for later. Rate-limit routed structurally. User input wins over late-resolving pending prefs. Order-sensitive error matching avoids mislabeling.
- **Validation:** `canImport` = non-empty trimmed; blocked while importing.
- **Test coverage:** Verified — `smart_import_viewmodel_test.dart`, `smart_import_view_smoke_test.dart`, `import_result_handler_test.dart`.

#### IMP-04: Photo / OCR import (multi-page, heirloom scans)
- **Entry:** `/photoImport` — "Från bild" tile + onboarding import page.
- **User story:** As a user with a paper or cookbook recipe, I want to photograph pages and have the text extracted and parsed so that I can digitize heirloom recipes without typing.
- **Expected behavior:** Camera/gallery (compressed) → quality assessment → multi-provider OCR (OCR.space → Google Vision → Tesseract) → auto-parse. Up to 5 pages, reorderable, combined into ONE recipe. OCR text + first image persisted as a draft. Heirloom metadata form. Failed OCR retry. Confidence/quality surfaced.
- **Edge cases:** No image; unsupported format; >15MB rejected; quality hard-reject before OCR to save quota; blank page → error not silent append.
- **Validation:** Format whitelist, 15MB cap, quality gate.
- **Test coverage:** Verified — `photo_import_viewmodel_test.dart` (+multi), `photo_import_allergen_banner_journey_test.dart`, `photo_import_draft_restore_test.dart`, `photo_import_announce_test.dart`.

#### IMP-05: Text / paste import ("Från sociala medier")
- **Entry:** `/franSocialaMedier` — also landing for share-intent text, social extraction, single-photo OCR handoff.
- **User story:** As a user, I want to paste recipe text copied from anywhere and have it structured so that content without a scrapable URL still imports.
- **Expected behavior:** Paste/type (max 10000 chars), auto-saved draft. A cheap recipe-likeness heuristic warns before spending a paid LLM parse on non-recipe text (override allowed). Multi-recipe paste → picker; single → editor. 60s timeout message. Source URL attribution carried.
- **Edge cases:** Empty; <10 chars rejected; non-recipe → confirm dialog; server hang → timeout message.
- **Validation:** Non-empty + ≥10 chars.
- **Test coverage:** Verified — `text_import_viewmodel_test.dart`, `text_import_strategy_test.dart`, `text_import_normalizer_test.dart`.

#### IMP-06: Receive-share (share intent from other apps)
- **Entry:** `/receiveShare` — OS share sheet hands content to the app.
- **User story:** As a user, I want to share a link or text from another app into Butlery and have it routed to the right importer so that importing is one tap from where I found the recipe.
- **Expected behavior:** Classifies the shared content (social URL / recipe URL / recipe text / plain) + platform, renders an adaptive screen routing each to the right importer with a manual-copy fallback. Threads import-funnel analytics.
- **Edge cases:** Extraction failure → inline error + retry + manual copy. No URL → text import.
- **Test coverage:** Partial — `incoming_share_handler_test.dart` (BUT-941) proves the routing decision logic (auth-gate, hold-until-routable, never break startup); `social_media_extractor_test.dart` + `content_detector_service_test.dart` cover the underlying extraction/classification. No device-level share-intent E2E (OS share sheet → app) yet.

#### IMP-07: Social-media URL extraction (Instagram/TikTok/YouTube)
- **Entry:** ReceiveShare auto-extract + URL-import suggestion.
- **User story:** As a user, I want to pull recipe text out of an Instagram/TikTok/YouTube post so that I can import recipes that live inside social posts.
- **Expected behavior:** Detects platform, selects a strategy, returns extracted text + metadata. YouTube has a tiered strategy (video-ID → metadata → transcript → LLM), falling back to user-assisted import with the transcript, then a manual-screenshot state.
- **Edge cases:** Failure carries a `reason` for analytics; YouTube with no transcript → manual fallback; paywalled posts → extraction error.
- **Test coverage:** Partial — `youtube_import_strategy_test.dart` covers YouTube; `social_media_extractor_test.dart` covers the facade, `extraction_manager_test.dart` the strategy dispatch, and `platform_detector_test.dart` platform detection. Instagram/TikTok live-network scraping is still not exercised end-to-end.

#### IMP-08: File import (CSV/Excel)
- **Entry:** `/fileImport`.
- **User story:** As a user migrating from a spreadsheet, I want to upload a CSV/Excel file of recipes and pick which to import so that I can bulk-load an existing collection.
- **Expected behavior:** Picks + parses, presents a batch-preview to select, saves each selection, continuing past failures and reporting imported/failed counts. Survives VM disposal mid-import.
- **Edge cases:** Cancel / no recipes → empty; parse exception → generic error; per-recipe failure increments without aborting.
- **Test coverage:** Verified — `file_import_viewmodel_test.dart`, `file_import_strategy_parsing_test.dart` (+ structure).

#### IMP-09: Import from archive (restore previously-archived recipes)
- **Entry:** `/importFranArkiv`.
- **User story:** As a returning user, I want to browse, filter, and re-import recipes I previously archived so that I can recover removed recipes without re-entering them.
- **Expected behavior:** Lists archived recipes with tag/time/text filters; multi-select (incl. select-all), import-selected or import-all (filtered). Clears selection after a batch import.
- **Edge cases:** Import error surfaced; no selection → import-all path.
- **Test coverage:** Partial — `archive_import_viewmodel_test.dart`; manager classes not separately confirmed.

#### IMP-10: Assisted import (3-step manual line-selection wizard)
- **Entry:** From SmartImport's needs-help state or manual trigger.
- **User story:** As a user whose recipe couldn't be auto-parsed, I want to tap which lines are ingredients vs instructions so that even messy content becomes a recipe.
- **Expected behavior:** 3-step wizard — select ingredient lines (pre-highlighted), select instruction lines (scored), review/edit all fields. Cleans step-number prefixes. Builds a personal recipe with source URL + thumbnail.
- **Edge cases:** Can't proceed without a selection; portions clamped 1–100, time 0–1440.
- **Validation:** Per-step validation; save needs title + ≥1 ingredient + ≥1 instruction.
- **Test coverage:** Partial — base-VM + `import_recipe_journey_test.dart` exercise surrounding flow; no dedicated assisted-import VM test. *(Pure free fallback — no LLM/network.)*

#### IMP-11: Ingredient-line parsing (CRF / NER / ONNX)
- **Entry:** Not a screen — runs downstream of every import during parse. *(See ENG-09 for the engine-level view.)*
- **User story:** As a user, I want ingredient lines like "2 dl mjöl" split into quantity/unit/name so that recipes scale, generate shopping lists, and match the pantry/allergen systems.
- **Expected behavior:** Tiered parsing — Swedish heuristics + a CRF parser (Viterbi) and an ONNX-backed NER path (WordPiece) with remote model loading + hash verification. A line classifier separates ingredient vs instruction vs noise.
- **Edge cases:** Model load fail / hash mismatch → rule-based fallback; garbage lines filtered.
- **Test coverage:** Partial — strategy/normalizer tests exist; CRF/NER/ONNX have a separate test subtree outside this cluster's sweep.

### Menu & Shopping

#### MENU-01: Generate weekly menu from prompt
- **Entry:** `/veckomeny` — generate FAB / prompt input.
- **User story:** As a meal planner, I want to type a request and get a full week of recipes auto-distributed onto the calendar so that I don't have to pick each meal by hand.
- **Expected behavior:** Prompt keyword-filtered (favoriter/senaste); generates a category→recipes map; recently-used recipes down-weighted; distributed onto the today-anchored ISO week honoring day-pins; persisted; session-placed entries get a "NY" badge.
- **Edge cases:** Empty pool throws; filtered pool <3 falls back to full; concurrent generation guarded; save before publish so a failed write never shows a phantom week; overflow recipes go to a tray.
- **Validation:** Prompt non-empty; allergen/dietary filtering optional (household-aggregated when enabled).
- **Test coverage:** Verified — `menu_generator_test.dart`, `weekly_menu_plan_viewmodel_test.dart`, `menu_service_test.dart`, `menu_constraint_parser_test.dart`. *(LLM only in MenuService; distribution deterministic.)*

#### MENU-02: Manual menu placement mode
- **Entry:** From the generate flow → placement screen.
- **User story:** As a planner who wants control, I want to hand-place each generated recipe onto specific days so that the week matches my preferences before anything is saved.
- **Expected behavior:** Generated recipes become a placeable tray; tap-to-select then tap-a-cell to place (auto-advances). "Placera resten automatiskt" distributes the rest. All in-memory; `confirm()` does one batched save; backing out discards.
- **Edge cases:** Blocks placing into an occupied single slot; ÄNDRA-after-auto starts from an empty week + disables week nav (avoids duplicate menu); DST-safe arithmetic.
- **Test coverage:** Verified — `menu_placement_viewmodel_test.dart`.

#### MENU-03: Edit weekly menu calendar (assign/move/remove/clear/undo)
- **Entry:** `/veckomeny` cells, drag-and-drop, "Rensa veckan".
- **User story:** As a planner, I want to add, drag, and remove recipes on the week grid and clear the whole week so that I can fine-tune my plan.
- **Expected behavior:** assign/move/remove each persist. `clearWeek` wipes entries + overflow tray with a 7s undo snapshot; overflow recipes can be dropped into slots.
- **Edge cases:** No-op when plan null or move is identical; clear snapshot captures overflow so undo doesn't lose tray recipes.
- **Test coverage:** Verified — `weekly_menu_plan_viewmodel_test.dart`, `calendar_weekly_menu_widget_test.dart`.

#### MENU-04: Bulk multi-select move + copy week to next
- **Entry:** `/veckomeny` header multi-select + "Kopiera denna vecka → nästa vecka".
- **User story:** As a planner, I want to select several entries and move them all at once, and copy this week into next week, so that bulk reorganizing is fast.
- **Expected behavior:** Selection mode flips tap behavior; `bulkMoveSelected` persists in one write. `copyWeekToNext` additively copies to next ISO week, skipping duplicates, without navigating away.
- **Edge cases:** Selection mode separate from drag-and-drop; emptying selection auto-exits; failed bulk move still clears selection.
- **Test coverage:** Verified — `weekly_menu_plan_viewmodel_test.dart`, `veckomeny_view_mode_toggle_test.dart`.

#### MENU-05: Swap a single menu recipe (smart scoring)
- **Entry:** Generated-menu review, per-recipe swap action.
- **User story:** As a planner reviewing a generated menu, I want to swap one recipe for a similar alternative so that I can replace meals I don't like without regenerating everything.
- **Expected behavior:** Filters eligible recipes (same category, not already present) and, with smart-swap on, scores them (+3 cuisine, +2 category, +1 seasonal) with random tie-break.
- **Edge cases:** Empty pool → null + "exhausted" message; smart-swap can be disabled for pure-random.
- **Test coverage:** Partial — `menu_generator_test.dart` (swap-scoring specifics not separately asserted).

#### MENU-06: Generate shopping list from the weekly menu
- **Entry:** `/veckomeny` "Generera inköpslista" FAB → `/inkopslista`.
- **User story:** As a planner, I want one tap to turn my week's recipes into a single aggregated shopping list so that I don't transcribe ingredients by hand.
- **Expected behavior:** Aggregates all resolvable menu ingredients (deterministic, zero LLM) into one list per ISO week. Regenerating updates the marked list in place; bought-status survives for matching lines. Pantry staples excluded with a surfaced count.
- **Edge cases:** Empty plan → `nothingToGenerate`; unresolved (deleted) recipes skipped; double-tap → `alreadyRunning`; null = real failure.
- **Test coverage:** Verified — `menu_shopping_list_generator_test.dart`, `menu_shopping_aggregator_test.dart`, `menu_to_shopping_journey_test.dart`. *(Manual additions don't survive regeneration.)*

#### MENU-07: Real-time collaborative menu editing
- **Entry:** `/realtime-menu`.
- **User story:** As a household member, I want to edit a shared menu live alongside others so that we can plan together in real time.
- **Expected behavior:** Streams the menu; add/remove/move/reorder/clear/regenerate apply optimistically then reconcile. Tracks participants, connection status, and permission gating. Owners manage participants, basic info, delete, or make a personal copy.
- **Edge cases:** Updates blocked when no menu / no permission / offline (distinct errors); offline pauses watching and auto-resumes; optimistic changes cleared when the authoritative update lands.
- **Test coverage:** Verified — `realtime_menu_viewmodel_test.dart`, `realtime_menu_operations_test.dart`, `realtime_menu_state_test.dart`, `realtime_menu_service_test.dart`, `realtime_stream_manager_test.dart`.

#### MENU-08: Menu slot voting
- **Entry:** Per-slot vote UI inside a collaborative menu.
- **User story:** As a group member, I want to start a vote between recipe alternatives for a slot and cast my vote so that the group decides democratically what to cook.
- **Expected behavior:** Subscribes to live votes; create a vote on a (category, slot) with alternatives + a window (default 24h); members vote, add alternatives, resolve to a winner. Splits active/resolved.
- **Edge cases:** No active vote → null (StateError caught); subscription cancels prior + guards disposed.
- **Test coverage:** Verified — `menu_voting_viewmodel_test.dart`, `menu_slot_vote_test.dart`.

#### MENU-09: Collaborative-edit conflict resolution + diff/recovery
- **Entry:** Conflict banner on a shared menu; full-screen ConflictDiffView.
- **User story:** As a collaborator whose edit was silently overwritten, I want to see which fields differed and re-apply my version so that my changes aren't lost without recourse.
- **Expected behavior:** Last-write-wins resolver; a banner surfaces the conflict; the diff view shows field-level local-vs-remote (green = mine, gold = collaborator's). If mine lost, "Behåll min version" re-applies it via a permission-checked path rebuilt on top of the latest remote so it legitimately wins next time.
- **Edge cases:** No-changes diff → empty state; missing sync service → error toast; keep-bar only when local lost; double-tap guarded.
- **Test coverage:** Verified — `conflict_diff_view_test.dart`, `conflict_banner_test.dart`, `conflict_diff_test.dart`, `realtime_conflict_resolver_test.dart`, `menu_preview_conflict_banner_test.dart`.

#### MENU-10: Share a menu with friends / import a shared menu
- **Entry:** `/menu-preview` (share) + shared-menu inbox.
- **User story:** As a user, I want to send a weekly menu to friends and import menus they send me so that we can swap meal plans.
- **Expected behavior:** Distributes a menu (optional message + title) to selected friends; recipients mark-as-viewed and import. Tracks sharing stats + activity summary.
- **Edge cases:** Share validates non-empty menu/name/≥1 friend; failures log/rethrow.
- **Corrected 2026-07-02:** `loadImportedMenuData` reads real Firestore data end to end — the old stub note was stale (workflow-map trace).
- **Test coverage:** Verified — `menu_social_manager_test.dart`, `social_menu_operations_test.dart`, `firebase_shared_menu_repository_test.dart`, `shared_menu_viewmodel_test.dart`.

#### MENU-11: Unified shopping list management (CRUD + items + categories + export)
- **Entry:** `/inkopslista`.
- **User story:** As a shopper, I want to create/rename/delete lists, add/edit/remove/check-off items, reorder categories, and export so that I can manage my shopping end to end.
- **Expected behavior:** Manages personal + collaborative lists, active list, item CRUD, toggle-bought, clear-bought, uncheck-all, bulk add from recipe ingredients, bulk delete with undo, category move + order overrides, search, grouping, text export. Checked-off items can auto-add to pantry with a one-time opt-in prompt.
- **Edge cases:** All mutations gated on `canEditActiveList` (logs DENIED, returns false); whitespace names rejected; bulk reports all/some success.
- **Validation:** Permission checks; pantry pref read/written via `currentUserProfile` (data-source rule).
- **Test coverage:** Verified — `unified_shopping_viewmodel_test.dart`, `shopping_item_tiles_test.dart`, `shopping_item_tile_selection_test.dart`, `unified_shopping_service_test.dart`, `pantry_from_shopping_test.dart`.

#### MENU-12: Create a shared (collaborative) shopping list
- **Entry:** `/create-shared-shopping`.
- **User story:** As a user, I want to create a named shopping list shared with chosen friends (optionally seeded from a menu) so that we can shop collaboratively.
- **Expected behavior:** Title + optional description + friend multi-select; creates the collaborative list, returns the id, clears the form. Supports guest-editing and auto-remove-completed flags.
- **Edge cases:** Requires authenticated profile; title ≤100, description ≤500, ≥1 friend.
- **Test coverage:** Verified — `create_shared_shopping_list_view_test.dart`, `collaborative_shopping_operations_test.dart`.

#### MENU-13: Collaborative shopping list view (claim/assign, split-store, presence)
- **Entry:** `/collaborative-shopping`.
- **User story:** As a co-shopper, I want to claim items, see who's shopping live, and split the list so that we divide the shopping without overlap.
- **Expected behavior:** Live-streams; add item, toggle completion, clear completed, claim/unclaim. View modes: flat, "Min del / {name}s del / Otilldelat", by-store-zone. Real-time presence with heartbeat, leaves on dispose.
- **Edge cases:** Claim returns claimed / conflict / denied / error; only assignee may unclaim; edits gated on `canEdit`.
- **Test coverage:** Verified — `collaborative_shopping_viewmodel_test.dart`, `collaborative_shopping_view_test.dart`, `collaborative_shopping_items_test.dart`, `shopping_presence_module_test.dart`, `shopping_permission_manager_test.dart`, `collaborative_shopping_operations_test.dart`.

#### MENU-14: Browse shared shopping lists
- **Entry:** `/shared-shopping-lists`.
- **User story:** As a user, I want to see all collaborative shopping lists I participate in so that I can pick one to open.
- **Expected behavior:** Loads all lists, exposes only the collaborative ones; supports refresh.
- **Edge cases:** Load errors swallowed; empty when none.
- **Test coverage:** Partial — no dedicated VM test; card covered by `shopping_list_card_test.dart`, model by `shared_shopping_list_test.dart`.

#### MENU-15: Share an existing shopping list with friends
- **Entry:** Shopping list share dialog.
- **User story:** As a list owner, I want to pick friends and a message and share my existing list with them so that they gain access without me recreating it.
- **Expected behavior:** Loads friends; multi-select + custom message; shares with each selected friend, logs analytics, reports partial failures. Provides a sharing summary.
- **Edge cases:** Blocks with no selection; per-friend failures mark partial failure.
- **Test coverage:** Verified — `shopping_share_viewmodel_test.dart`, `shopping_share_operations_test.dart`, `shopping_social_share_module_test.dart`.

#### MENU-16: Voice menu prompt ("Tala in veckomenyn")
- **Entry:** Mic button in the Veckomeny prompt field (`VoicePromptButton`).
- **User story:** As a home cook with my hands or head full, I want to speak my weekly-menu request so that I don't have to type it.
- **Expected behavior:** Push-to-talk → on-device KB-Whisper transcription (Swedish; model OTA-delivered + SHA-256 fail-closed) → transcript lands EDITABLE in the prompt field → normal generation. Spoken register handled by the parser (filler strip, last-wins self-corrections). Audio deleted after transcription on every exit path, never uploaded.
- **Edge cases:** Denied/permanently-denied mic → rationale/settings snackbar, typed input untouched; missing model or failed transcription → quiet snackbar pointing back to typing; silence hallucinations parse to empty, never a garbage menu; hidden on web.
- **Test coverage:** Verified — `voice_capture_service_test.dart` (all-exit-path audio cleanup), `whisper_model_manager_test.dart` (fail-close delivery), `voice_prompt_button_test.dart` (states + degradation), `spoken_prompt_golden_test.dart` (29 spoken transcripts). Real-device latency check pending (founder).

### Social

#### SOC-01: Send friend request
- **Entry:** `/friends` Search tab; also from public/friend profiles.
- **User story:** As a user, I want to search for and send a friend request to another user so that we can connect and share recipes.
- **Expected behavior:** Search by name/email, see relationship status, tap to send. On success search clears, analytics logs the source, UI refreshes.
- **Edge cases:** Can't send to self/existing friend/pending; email search only if target opted in; no result if target not searchable.
- **Validation:** Privacy-gated by the target's `isSearchable`/`allowEmailSearch`.
- **Test coverage:** Verified — `friends_invitations_operations_test.dart`, `friends_viewmodel_test.dart`, `friend_request_test.dart`, `friends_list_view_test.dart`.

#### SOC-02: Accept / reject / cancel friend request
- **Entry:** `/friends/requests` + the Requests tab.
- **User story:** As a user, I want to accept, reject, or cancel friend requests so that I control who is in my network.
- **Expected behavior:** Accept (creates friendship, first-friend milestone once), reject, or cancel outgoing. Requester profiles pre-loaded.
- **Edge cases:** Request may have vanished (double-tap / other device) — looked up first, service no-ops safely.
- **Validation:** Only recipient accepts/rejects; only sender cancels.
- **Test coverage:** Verified — `friends_viewmodel_test.dart`, `friends_invitations_operations_test.dart`, `friends_internal_operations_test.dart`.

#### SOC-03: Friends list & remove friend (unfriend)
- **Entry:** `/friends` Friends tab.
- **User story:** As a user, I want to view my friends and remove someone so that I can curate my network.
- **Expected behavior:** Reactive list; removing updates the list, clears any selection, logs `friend_removed`. Empty state when none.
- **Edge cases:** Stream-reactive (no manual refresh); notifications coalesced to ≤1/frame to avoid Android freeze.
- **Test coverage:** Verified — `friends_viewmodel_test.dart`, `friends_empty_state_test.dart`, `friend_card_test.dart`, `friends_repository_integration_test.dart`.

#### SOC-04: Block / unblock user
- **Entry:** Friend profile / search result / request cards.
- **User story:** As a user, I want to block a user so that they cannot interact with me, and unblock later.
- **Expected behavior:** Block adds to `blockedUsers`; unblock removes + logs. Blocked users' comments filtered out of threads.
- **Edge cases:** Friendship status returns `blocked`, preventing request actions; filter no-op when block set empty.
- **Test coverage:** Partial — block-list comment filtering covered indirectly (`comments_service_test.dart`); no dedicated block/unblock VM test.

#### SOC-05: Friend groups / categories
- **Entry:** `/friends` Groups tab. *(Same subsystem as GRP-01, friend-categorization surface.)*
- **User story:** As a user, I want to organize friends into named groups so that I can share content with a subset at once.
- **Expected behavior:** Create a group (name, emoji, members), search groups, view friends in a group, see a friend's groups.
- **Edge cases:** Duplicate name guarded; empty groups filtered; group-creation error surfaced separately.
- **Test coverage:** Verified — `friend_category_test.dart`, `friend_category_member_test.dart`, `friend_categories_operations_test.dart`, `friend_category_manager_test.dart`, `friend_category_repository_test.dart`.

#### SOC-06: View public profile
- **Entry:** `/public-profile`.
- **User story:** As a user, I want to view another user's public profile and their public recipes so that I can decide whether to connect.
- **Expected behavior:** Loads the target's profile + public recipes. Error if not found.
- **Edge cases:** Null profile → error state; no public recipes → empty section.
- **Test coverage:** **Untested** — no dedicated PublicProfileViewModel test.

#### SOC-07: View friend profile (stats, message, share, report)
- **Entry:** `/friend-profile`.
- **User story:** As a user, I want to view a friend's profile with stats and quick actions so that I can message them, see their shared recipes, or report them.
- **Expected behavior:** Friend stats, "shared recipes by this friend", start-conversation (debounced), profile sharing, report option.
- **Edge cases:** Conversation-start debounced to prevent double navigation.
- **Test coverage:** **Untested** at the view level (underlying friend data covered).

#### SOC-08: Edit own profile (cooking identity, bio, avatar, privacy)
- **Entry:** `/profile/edit`.
- **User story:** As a user, I want to edit my display name, bio, cooking identity, avatar, and privacy settings so that my profile reflects me and respects my privacy choices.
- **Expected behavior:** Dual-profile (snapshot vs working copy) with field-level change detection. Editable: name, avatar, bio (≤160), skill level, cuisines (≤5), and privacy toggles (searchable, email-search, online-status, activity-to-feed + per-event-type). Turning off online status clears the live dot immediately.
- **Edge cases:** Name uniqueness checked before save; cuisine add blocked at 5; reactive sync only reloads when no unsaved edits.
- **Validation:** Name 2–50, unicode + `-_.`, unique; ≤5 cuisines; bio ≤160.
- **Test coverage:** Partial — `profile_viewmodel_test.dart`; no dedicated test for the user_profile VM's validation/privacy paths.

#### SOC-09: Share recipe with friends
- **Entry:** Recipe detail share action → friend-selection sheet.
- **User story:** As a user, I want to share a recipe with selected friends so that they can view (and optionally collaborate on) it.
- **Expected behavior:** Select friends, optional message, share → returns an invitation id. Same VM also shares menus + lists.
- **Edge cases:** Can't share with zero friends or while in progress; menu/list shares validate content exists.
- **Notes:** `social.shareRecipe` creates a NEW collaborative doc (distinct from the share-request path SOC-11 which mutates the original).
- **Test coverage:** Verified — `social_sharing_viewmodel_test.dart`, `social_recipe_sharing_service_test.dart`, `social_recipe_operations_test.dart`.

#### SOC-10: Request a recipe share from a friend
- **Entry:** Activity feed — tapping a friend's recipe preview that isn't shared with you.
- **User story:** As a user, I want to ask a friend to share a recipe I saw them cook so that I can view it myself.
- **Expected behavior:** If the recipe isn't shared, a dialog offers to request; on confirm creates a `recipeShareRequest` and fires a deterministic (no-LLM) critical notification to the owner.
- **Edge cases:** Idempotent — duplicate request is a no-op that still returns true; false only when unauthenticated; notification failure non-fatal.
- **Test coverage:** Verified — `social_request_recipe_test.dart`, `social_request_test.dart`, `social_recipe_service_test.dart`. *(Phase 2 work; notification opens the owner's recipe with a share-back banner.)*

#### SOC-11: Accept a recipe-share request (owner side)
- **Entry:** Share-request notification → owner's recipe detail with a share-back banner.
- **User story:** As a recipe owner, I want to accept a friend's request to share my recipe so that they gain read access to it.
- **Expected behavior:** Adds the requester to the ORIGINAL recipe's `memberPermissions` as viewer (in-place via `shareRecipeWithUsers`), then marks the request accepted. Status flips only after the share succeeds.
- **Edge cases:** False if no recipeId, wrong owner, or the share fails (status not flipped). Shares in place because the read rule keys off the original doc.
- **Notes:** This is the two-paths gotcha — accept mutates the original, not a new doc. Fixed a Critical read-friend-recipe bug.
- **Test coverage:** Verified — `social_recipe_service_test.dart`, `social_request_recipe_test.dart`.

#### SOC-12: Shared-with-me browsing (recipes, menus, shopping lists)
- **Entry:** `/shared`.
- **User story:** As a user, I want an inbox of content others shared with me so that I can find, search, and open shared recipes/menus/lists.
- **Expected behavior:** Tabbed inbox with per-type unread counts, unified debounced search, mark-all-as-viewed, refresh-all, and a toggle to show/hide imported content (hidden by default).
- **Edge cases:** Toggling imported reloads all; tab titles append unread counts; errors aggregated across three sub-VMs.
- **Test coverage:** Partial — sub-services covered; no dedicated coordinator-VM test.

#### SOC-13: Comment on recipes (post, reply, edit, delete, threading)
- **Entry:** Recipe detail comments section.
- **User story:** As a user, I want to comment on and reply to recipes so that I can discuss them with friends.
- **Expected behavior:** Real-time stream, threaded replies, post (with optional images), edit/delete own, live count, profanity flag on the draft. Blocked-user comments filtered.
- **Edge cases:** Empty text won't post; already-watching guard; concurrent edit/delete → error surfaced.
- **Validation:** Non-empty; author-only edit/delete; content-filtered.
- **Test coverage:** Verified — `comment_crud_operations_test.dart`, `comment_utilities_test.dart`, `comments_service_test.dart`, `comment_visibility_test.dart`, `comment_form_widget_test.dart`, `comment_image_attachments_test.dart`, `comment_posted_announce_test.dart`.

#### SOC-14: Like / unlike comments
- **Entry:** Comment item in recipe detail.
- **User story:** As a user, I want to like a friend's comment so that I can acknowledge it without replying.
- **Expected behavior:** Toggle like; like status batch-loaded for visible comments after a refresh.
- **Validation:** One like per user per comment.
- **Test coverage:** Verified — `comment_likes_system_test.dart`.

#### SOC-15: Rate recipes (1–5 stars)
- **Entry:** Recipe detail rating control.
- **User story:** As a user, I want to rate a recipe so that I record how much I liked it (and contribute to a shared recipe's aggregate).
- **Expected behavior:** Personal recipes persist the rating in-doc; shared/collaborative use the social rating system (per-user → aggregate). Optimistic with revert. A 4–5 rating may trigger an in-app review prompt. Remove own rating.
- **Edge cases:** Failed persist reverts + throws; review-prompt failure never affects rating.
- **Test coverage:** Verified — `rating_statistics_test.dart`, `rating_notifications_test.dart`, `social_engagement_metrics_test.dart`.

#### SOC-16: Cook-snaps (photos of cooked dishes)
- **Entry:** Recipe detail gallery; also in the activity feed carousel. *(Same feature as REC-12.)*
- **User story:** As a user, I want to post photos of a dish I cooked so that friends can see my results on the recipe and in the feed.
- **Expected behavior:** Real-time gallery; add a snap (camera/gallery) with caption + visibility (default `sameAsRecipe`); delete own. Multi-photo → swipeable carousel.
- **Edge cases:** Upload double-submit guarded; visibility independent of recipe scope when explicitly set.
- **Test coverage:** Verified — `cook_snap_test.dart`, `cook_snap_service_visibility_test.dart`, `cook_snap_visibility_test.dart`, `cook_snap_photo_carousel_test.dart`, `cook_snap_gallery_golden_test.dart`.

#### SOC-17: Activity feed
- **Entry:** `/friends` Feed tab.
- **User story:** As a user, I want a feed of my friends' cooking activity (cooked / shared, with photos) so that I stay connected to what they're making.
- **Expected behavior:** Paginated (20/page), client-side type filter chips, date headers, pull-to-refresh, infinite scroll, tap a preview to open. Two empty states ("find friends" vs "quiet so far").
- **Edge cases:** Tapping an unshared friend recipe routes into the request-a-share flow (SOC-10); friend recipes open read-only; opted-out actors excluded upstream.
- **Validation:** Respects each actor's activity-sharing toggles (SOC-08).
- **Test coverage:** Verified — `activity_feed_service_test.dart`, `activity_event_test.dart`, `activity_pings_feed_test.dart`, `social_events_tracker_milestone_test.dart`. *(Discovery dashboard confirmed removed.)*

#### SOC-18: Report content / user
- **Entry:** Friend profile + group member/detail + search + request cards.
- **User story:** As a user, I want to report a profile or other content so that abusive users/content can be moderated.
- **Expected behavior:** A report dialog takes a content type + id and submits to the moderation pipeline.
- **Test coverage:** **Untested** at the dialog level. *(Pairs with SOC-04 block filtering and SOC-13 profanity filtering.)*


#### SOC-19: Voice comment on recipes ("Tala in en kommentar")
- **Entry:** Mic on the recipe comment form (`CommentFormWidget` → `VoicePromptButton`).
- **User story:** As a user, I want to dictate a comment so that I can share a note about a recipe without typing.
- **Expected behavior:** Push-to-talk → on-device KB-Whisper transcription → transcript APPENDS editable to the comment field and flows through the same onChanged path as typing — draft persistence, the profanity gate (BUT-1393) and the account-maturity gate (BUT-1419) all see it as typed text. Nothing posts automatically. Audio deleted after transcription, never uploaded.
- **Edge cases:** Denied mic → typed text untouched; busy states (posting/uploading) disable the mic; hidden on web.
- **Test coverage:** Verified — `comment_form_widget_test.dart` (append+editable+draft parity, denied-mic fallback), plus the shared `voice_prompt_button_test.dart` degradation suite.
### Groups & Messaging

#### GRP-01: Create social group (friend category)
- **Entry:** Groups tab "Skapa grupp" → create-group dialog.
- **User story:** As a user, I want to create a named friend group with an emoji, description, and initial invited friends so that I can organize friends and share with them collectively.
- **Expected behavior:** Creates a `FriendCategory` (empty membership), then sends email invitations to selected friends. Broadcasts a group-created event + milestone analytics.
- **Edge cases:** Friend with invalid email skipped; create returning null throws; first-group milestone fires once.
- **Validation:** Name required + not duplicate.
- **Notes:** Group creation sends invitations friends must accept — it does NOT add them directly.
- **Test coverage:** Partial — `create_group_viewmodel_test.dart`, `group_draft_codec_test.dart`, `create_group_dialog_draft_test.dart`.

#### GRP-02: Group detail — view, manage & share
- **Entry:** `/group-detail` (`GroupDetailView`, groupId).
- **User story:** As a group member, I want to see members, stats, pending invitations, and household status, and (as admin) edit/manage it so that I can coordinate and share content.
- **Expected behavior:** Loads the category, member profiles, pending invitations. Household toggle (only one group can be household), share recipes/menus/lists, start a meal-vote poll. Stale-gated refresh (>30s); pull-to-refresh forces.
- **Edge cases:** Group deleted / user removed (event bus) nulls the group; membership re-check on member events.
- **Validation:** Admin-gated edit/delete/add; leave only if member; share requires auth.
- **Test coverage:** Verified — `social_group_detail_viewmodel_test.dart`, `group_detail_view_test.dart`, `group_detail_report_tiles_test.dart`, `group_member_multiselect_test.dart`.

#### GRP-03: Leave group / transfer ownership
- **Entry:** Group action buttons in GroupDetailView.
- **User story:** As a group member, I want to leave a group, and as the owner I want safe ownership succession so that the group isn't orphaned.
- **Expected behavior:** Non-owner leaves freely; owner of an empty group is offered delete; owner with members must transfer ownership first (atomic Firestore transaction), then reload.
- **Edge cases:** No loaded group / no user → StateError; transfer failure returns false.
- **Test coverage:** Verified — covered in `social_group_detail_viewmodel_test.dart`.

#### GRP-04: Add members to group / send invitations
- **Entry:** AddMembersToGroupView (from GroupDetailView).
- **User story:** As a group admin, I want to search, multi-select friends, and invite them so that I can grow the group.
- **Expected behavior:** Loads friends excluding existing members, self, and already-invited; search + select-all; sends invitations per friend, tracks sent/failed, clears successful selections, reloads.
- **Edge cases:** No selection / no group short-circuits; partial failures reported; group-not-found throws.
- **Test coverage:** Verified — `add_members_to_group_viewmodel_test.dart`.

#### GRP-05: Group invitations — browse, join, accept/decline
- **Entry:** Groups tab pending-invitations section.
- **User story:** As a user, I want to see available groups and pending invitations and accept/decline/join so that I can become a member of friends' groups.
- **Expected behavior:** Loads available groups + received invitations. Join adds me; accept adds me to `friendUserIds` + reloads; reject cancels. Per-id concurrency guards prevent double-submits.
- **Edge cases:** No user errors; duplicate in-flight ignored; not-found throws; load failures fall back to empty.
- **Test coverage:** Verified — `group_invitations_viewmodel_test.dart`, `group_invitation_test.dart`, `group_events_test.dart`.

#### GRP-06: Create group conversation (group chat)
- **Entry:** CreateGroupConversationView; also indirectly by meal-vote poll creation.
- **User story:** As a user, I want to name a group chat and select multiple friends so that I can message several friends at once.
- **Expected behavior:** Loads friends, search + multi-select with preview/count; creates the group conversation and navigates into the chat.
- **Edge cases:** Disposed guards; missing friend throws; creation failure surfaces error + returns null.
- **Validation:** Non-empty name AND ≥2 members AND no in-flight create.
- **Test coverage:** **Untested** (viewmodel) — no dedicated test; the service create path is covered in `messaging_service_test.dart`.

#### GRP-07: Group conversation detail — member management
- **Entry:** `/group-detail` via the messaging variant (from chat app-bar info). *(Distinct from GRP-02; same route concept, different consumer.)*
- **User story:** As a group-chat participant, I want to view members, add/remove, rename, and leave so that I can manage the conversation.
- **Expected behavior:** Streams the conversation. Admin (creator) can add/remove members + rename; any member can leave. Exposes available-friends-to-add.
- **Edge cases:** Admin can't remove self (must leave); empty title rejected; conversation missing from stream → cached copy.
- **Validation:** Admin-only add/remove/rename; non-empty title.
- **Test coverage:** Verified — `group_detail_viewmodel_test.dart`, `group_info_card_locale_test.dart`.

#### GRP-08: Share recipes with a group
- **Entry:** "Dela recept" in GroupDetailView.
- **User story:** As a group member, I want to select multiple of my recipes and share them with the whole group at once so that everyone gets collaborative access.
- **Expected behavior:** Loads personal recipes, flags those already shared with a member, search + multi-select (unshared-first); fans each recipe to all members, logs share + milestone, marks shared.
- **Edge cases:** Empty selection / in-flight short-circuits; null share result throws; analytics never gates the return.
- **Test coverage:** Verified — `group_recipe_selection_viewmodel_test.dart`. *(Uses the `social.shareRecipe` new-doc path.)*

#### GRP-09: Meal-vote poll for a group ("Vad ska vi äta?")
- **Entry:** Poll action in GroupDetailView.
- **User story:** As a group member, I want to launch a poll of recipe suggestions in a group chat so that the group can vote on what to eat.
- **Expected behavior:** Builds up to 4 variety-biased suggestions from the household/allergen/dietary-filtered pool (deterministic, no LLM); creates a group conversation, builds a poll, sends it.
- **Edge cases:** Empty pool → import CTA; no group / unauth → null; mealtype-less recipes bucketed via title-hash.
- **Test coverage:** Partial — touched in `social_group_detail_viewmodel_test.dart`, `messaging_service_close_poll_test.dart`, `poll_message_widget_recipe_test.dart`.

#### GRP-10: Conversations list — browse, search, pin, archive, delete
- **Entry:** `/messages`.
- **User story:** As a user, I want a searchable list of my conversations with pin/archive/delete controls so that I can find and organize my chats.
- **Expected behavior:** Streams all conversations, splits pinned/regular/archived, search over title + last message. Pin/archive optimistic with rollback; delete; mark-read on open; new-conversation dialog (direct or group).
- **Edge cases:** Stream errors set a list error; optimistic rollback on failure; mark-read errors swallowed.
- **Test coverage:** Verified — `conversations_viewmodel_test.dart`, `conversations_list_view_test.dart`, plus conversation model/module tests.

#### GRP-11: Direct (1:1) conversation start
- **Entry:** New-conversation dialog + friend profile.
- **User story:** As a user, I want to start a one-to-one chat with a friend so that I can message them privately.
- **Expected behavior:** Starts (or reuses) a direct conversation and navigates into the chat.
- **Edge cases:** Disposed guard → null; errors → null + message.
- **Test coverage:** Partial — start path in `conversations_viewmodel_test.dart`, `messaging_service_test.dart`.

#### GRP-12: Chat — messaging, reply, edit, delete, attachments, polls, typing
- **Entry:** `/chat`.
- **User story:** As a participant, I want to send/reply/edit/delete messages, attach images, react, create polls, and see typing/presence so that I can have a rich conversation.
- **Expected behavior:** App bar (info/mute/leave) + message stream + typing indicator + input. Routes message actions (reply/edit/delete/copy/report), image attachments, poll creation; can share menus/recipes/lists into chat. Feature-flag gated.
- **Edge cases:** Messaging disabled → disabled scaffold; non-friend → blocked banner instead of input; presence absent → typing disabled silently.
- **Validation:** Friendship-blocked disables input; feature flag; ownership for edit/delete/report.
- **Test coverage:** Partial — `chat_viewmodel_test.dart`, message model/module tests, `message_input_field_test.dart`, messaging service/repo tests; no widget test for the facade.

### Cooking, Pantry & Search

#### COOK-01: Cooking mode (landscape split-view)
- **Entry:** `/cooking-mode` — recipe detail "start cooking".
- **User story:** As a home cook, I want a hands-free full-screen cooking view with ingredients beside instructions so that I can follow a recipe at the stove without my screen sleeping.
- **Expected behavior:** Forces landscape, enables wakelock, hides system UI (restores on exit). Left panel (~35%) scaled ingredients; right (~65%) numbered steps with the active step highlighted + auto-scrolled. Top bar: lowercase title, font-scale toggle (A/A+/A++, persisted), close. Prev/next + tap-a-step nav with haptics + screen-reader announcements.
- **Edge cases:** Zero-instructions → dedicated empty state; session lifecycle guarded against double-fire/orphan events; broadcast/analytics failures swallowed.
- **Validation:** Step nav clamped; portions clamped 1–50.
- **Test coverage:** Verified — `cooking_mode_journey_test.dart`, `cooking_mode_viewmodel_test.dart`, `cooking_mode_viewmodel_lifecycle_test.dart`, `cooking_mode_touch_target_test.dart`.

#### COOK-02: Portion scaling in cooking mode
- **Entry:** Portion +/- stepper in the ingredients panel.
- **User story:** As a cook, I want to scale the recipe up or down while cooking so that ingredient amounts match the portions I'm making.
- **Expected behavior:** Re-scales every ingredient line; structured-first with a per-entry string fallback for legacy recipes.
- **Edge cases:** No-op if unchanged or out of 1–50; buttons disable at bounds; `originalPortions` 0 → factor 1.0 (no divide-by-zero).
- **Test coverage:** Verified — `cooking_mode_viewmodel_test.dart`.

#### COOK-03: Step timers (concurrent, with notifications)
- **Entry:** Long-press a step / tap a duration chip / tap a timer in the strip.
- **User story:** As a cook, I want one or more countdown timers tied to specific steps so that I don't burn anything while several things cook at once.
- **Expected behavior:** Step-timer sheet pre-filled with the parsed Swedish duration (default 5 min). One timer per step → multiple run concurrently; an active-timers strip overviews them. On expiry: haptic + snackbar + an OS-level local notification (alerts when backgrounded). Reconciles against an absolute end-time on resume.
- **Edge cases:** Re-opening reuses the running timer; parser rejects durations outside 0–12h.
- **Test coverage:** Verified — `cooking_mode_active_timers_strip_test.dart` + duration parser/service tests. A first-use hint banner teaches the gesture.

#### COOK-04: Ingredient substitution suggestions (in cooking mode)
- **Entry:** Long-press an ingredient row.
- **User story:** As a cook who's out of an ingredient, I want substitute suggestions so that I can keep cooking without a shopping trip.
- **Expected behavior:** Fetches suggestions, shows them in a sheet; choosing one routes through the edit path to replace the line.
- **Edge cases:** Substitution service unresolvable → empty list (offline-safe); recipe service unresolvable → "open edit to swap" snackbar instead of crash.
- **Test coverage:** Partial — `ingredient_substitution_test.dart`, `substitution_suggestion_service_test.dart` cover the "never throws" contract; the view-level long-press→replace flow untested.

#### COOK-05: Cooking-session presence broadcast + analytics
- **Entry:** Automatic on entering/leaving cooking mode.
- **User story:** As a user in friend groups, I want friends to see I'm "lagar just nu" so that the feed reflects live activity; and as the product, I want cooking-session funnel analytics.
- **Expected behavior:** On enter broadcasts a live session to every friend category + fires `cooking_session_started`. Step changes broadcast the current step. On exit clears the broadcast + fires completed/abandoned with duration + distinct steps viewed.
- **Edge cases:** Fire-and-forget with swallowed errors; start/end guarded against re-entry/no-prior-start.
- **Test coverage:** Verified — `cooking_session_module_test.dart`, `recipe_events_tracker_cooking_test.dart`, `firebase_cooking_session_repository_test.dart`, plus the VM lifecycle test.

#### COOK-06: Pantry ("Skafferiet") item management
- **Entry:** PantryView — a sub-tab under the shopping area.
- **User story:** As a user, I want to track ingredients I have at home, organized by storage location, so that I know my stock and what's expiring.
- **Expected behavior:** Items grouped into collapsible sections by location with counts. An "expiring" section (expired or within 3 days) at top. Add via FAB / empty-state. Each row: name, quantity+unit, color-coded expiry badge.
- **Edge cases:** Empty state illustration; null user → no-ops; immutable list replacement on writes.
- **Validation:** Add requires non-empty name; quantity parsed (comma→dot), default 1.0.
- **Test coverage:** Verified — `pantry_service_test.dart`, `firebase_pantry_repository_test.dart`, `pantry_item_test.dart`, `test/widget/views/pantry/*`.

#### COOK-07: Pantry add/edit via ingredient autocomplete
- **Entry:** Pantry FAB / empty-state (add) or tapping a row (edit).
- **User story:** As a user, I want to add a pantry item by typing an ingredient name with autocomplete (or free text), setting quantity, unit, location, expiry, and a note, so that entries are accurate and quick.
- **Expected behavior:** Debounced autocomplete (300ms, limit 10); picking a suggestion fills the Swedish name + auto-selects location. Submit creates from ingredient or raw text, or updates when editing. Fixed unit list; clearable expiry date picker.
- **Edge cases:** Empty name aborts; debounce short-circuits identical queries; editing falls back to 'st' if stored unit unknown; date bounded -30d to +3y.
- **Test coverage:** Partial — VM search/add covered indirectly; the sheet appears only in an a11y test, not a dedicated behavioral test.

#### COOK-08: Pantry swipe-delete with undo
- **Entry:** Swipe a pantry row.
- **User story:** As a user, I want to quickly remove a pantry item and undo if I mis-swiped, without a confirmation dialog.
- **Expected behavior:** Swipe deletes immediately + 7s "Ångra" snackbar; undo re-persists with a fresh id. No confirm dialog.
- **Edge cases:** Context/strings captured before dismissal; no swipe-delete while in selection mode.
- **Test coverage:** Verified — `pantry_item_card_undo_test.dart`, `pantry_viewmodel_restore_test.dart`.

#### COOK-09: Pantry multi-select + bulk delete with undo
- **Entry:** Long-press a row → selection mode.
- **User story:** As a user, I want to select several pantry items and delete them in one action (with undo) so that clearing out stock is fast.
- **Expected behavior:** Selection mode shows a contextual bulk bar (count, close, delete) replacing the FAB; bulk delete + single 7s undo. Auto-exits when last item deselected.
- **Edge cases:** Empty selection no-op; on bulk-delete error the undo snackbar is suppressed (can't restore items still present).
- **Test coverage:** Verified — `pantry_selection_manager_test.dart`, `pantry_viewmodel_bulk_test.dart`, `pantry_bulk_delete_test.dart`, `pantry_item_card_selection_test.dart`.

#### COOK-10: Auto-add bought shopping items to pantry
- **Entry:** Automatic when a shopping item is checked off, gated by a settings toggle.
- **User story:** As a user, I want items I buy to flow automatically into my pantry so that I don't have to re-enter them.
- **Expected behavior:** On a genuine false→true checkoff, if the preference is on, adds to pantry. Dedup: matching ingredient name (case-insensitive) + unit aggregates quantity instead of duplicating.
- **Edge cases:** No-op on re-toggle, un-check, or preference off / null profile.
- **Validation:** Preference read from `currentUserProfile` (data-source rule).
- **Test coverage:** Verified — `pantry_from_shopping_test.dart`, `auto_add_pantry_tile_test.dart`.

#### COOK-11: Ingredient-set recipe search ("Sök med ingredienser")
- **Entry:** `/ingredient-search` — from My Recipes, a filter chip, and a keyboard shortcut.
- **User story:** As a user, I want to pick ingredients I have and see which recipes I can mostly make so that I can cook from what's on hand.
- **Expected behavior:** Debounced autocomplete chips; search ranks recipes by ingredient-overlap % (descending; zero-overlap excluded). Results show match %, matched/total, a shared/collaborative badge, and a "Saknas: X, Y" missing-ingredient line. Searches personal + collaborative (deduped).
- **Edge cases:** Search disabled with no ingredients; legacy recipes normalized in-memory + cached; collaborative-fetch failure degrades to personal-only.
- **Test coverage:** Verified — `ingredient_search_viewmodel_test.dart`; match/lookup services covered at the service level.

#### COOK-12: Ingredient lookup / normalization service
- **Entry:** Backend service powering pantry + ingredient-search autocomplete, missing-ingredient resolution, recipe-ingredient normalization.
- **User story:** As a user typing Swedish ingredient names, I want fuzzy, forgiving matching so that "köttfärs", "kottfars", plurals, and compound words all resolve to the right ingredient.
- **Expected behavior:** Searches user-defined ingredients first, then global DB by exact name → alias → fuzzy variations (compound splits, plural/definite forms, adjective stripping). Swedish char normalization. LRU-caches 500 lookups. Parses quantity/unit out of raw lines; resolves taxonomy IDs to Swedish names.
- **Edge cases:** Empty after cleaning → null (no cache pollution); cache version bumped on clear; offline repo failures caught.
- **Test coverage:** Partial — `firebase_ingredient_repository_offline_degrade_test.dart` covers offline; the lookup/variation/cache logic has no dedicated test (exercised indirectly).

#### COOK-13: Köksbutlern voice assistant (cooking mode)
- **Entry:** Big mic button in cooking mode (bottom-right over the instructions panel), plus an auto talk-window that opens for ~6 s right after every readout finishes.
- **User story:** As a cook with hands covered in dough or busy at the stove, I want to hear the current step and ingredients read aloud and steer cooking mode by voice — "nästa", "läs igen", "sätt timer tio minuter" — so that I never have to touch the screen mid-cook.
- **Expected behavior:** Command set — step navigation (nästa/föregående), re-read the current step, read the ingredient list, set a timer (Swedish number words + digits + "en kvart"/"en halvtimme"), ask how much time is left on a timer, and a "tyst" stop command. Readouts use the phone's built-in Swedish OS voice (on-device, $0); recognition is 100% on-device via the shipped KB-Whisper stack, routed through a deterministic command interpreter (no LLM). After each readout the mic auto-opens for a short talk-window so a follow-up command needs no touch; a big mic button is always available for push-to-talk too. Speaker and microphone are strictly sequential — the butler's voice is always stopped before the mic opens, and the talk-window only opens after the readout's completion callback. A speaker/mute toggle in the app bar silences readouts and closes the talk-window without disabling button commands. Timer commands confirm aloud before the timer starts.
- **Edge cases:** Misheard command → the butler says "Jag uppfattade inte" and the transcript shows in a transient heard-chip; two consecutive misses add a spoken hint that the ordinary step buttons still work. Talk-window silence closes it quietly with no error. No Swedish TTS voice installed on the device → text-only degrade (readouts skipped), but spoken commands keep working. Muted → no readouts and no auto talk-window (button push-to-talk still available). Portion scaling is deliberately excluded from voice commands — a misheard number there would silently change amounts.
- **Test coverage:** Verified — `test/unit/services/voice/tts_service_test.dart` (TTS wrapper + sv-SE degrade), `test/unit/services/voice/cooking_command_interpreter_test.dart` (golden suite of spoken-command transcripts), `test/unit/viewmodels/cooking/cooking_voice_controller_test.dart` (state-machine + sequential speaker/mic invariants), `test/widget/widgets/cooking/voice_assist_button_test.dart` (button states, mute toggle). Real-device kitchen noise test pending (Malin).


#### COOK-14: Köksbutlern Q&A (substitutions, quantities, step jumps)
- **Entry:** Same mic as COOK-13 (cooking-mode voice assistant) — question phrasings route to answers.
- **User story:** As a cook mid-recipe, I want to ask the butler "vad kan jag ersätta grädde med?", "hur mycket mjölk behöver jag?" or "gå till steg fyra" so that I get answers without touching the screen.
- **Expected behavior:** Closed deterministic grammar (no LLM, zero running cost). Substitutions: raw spoken span → SubstitutionSuggestionService (canonical lookup, max 3) read aloud with ratio qualifiers ("halva mängden") and context hints. Quantities: answered with the recipe's own portion-scaled ingredient line (definite-form stemming, "köttfärsen" finds "köttfärs"). Step jumps: word or digit numbers, out-of-range speaks the step count. Talk-window reopens after every answer.
- **Edge cases:** Unknown ingredient → honest "hittade inte" naming what was heard; no extractable span → unrecognized (heard-chip); existing commands keep precedence (timer query owns "hur mycket tid kvar").
- **Test coverage:** Verified — interpreter Q&A golden group (frames × ingredients incl. crème fraiche/multi-word, precedence guards) + 7 controller arm tests (raw-span pass-through, ratio speech, scaled-line answers, stemming, out-of-range).
### Settings, Legal & Admin

#### SET-01: Settings hub
- **Entry:** `/settings`.
- **User story:** As a user, I want one organized settings screen so that I can find food, notification, account, language, and legal/help options in one place.
- **Expected behavior:** Grouped sections deep-linking to allergens, personal tags, an inline auto-add-to-pantry switch, notifications, account security, backup/restore, sign-out, delete-account (destructive styling), language picker, FAQ, terms, an appeal-email launcher, and a moderator tile gated by `watchIsAdmin()` (non-admins never see it).
- **Edge cases:** Appeal mailto failure → snackbar; food/language tiles listen to services so they reflect external changes.
- **Test coverage:** Partial — `settings_hub_food_tile_test.dart` (food tile only; admin/legal tiles untested).

#### SET-02: Allergen & dietary preferences
- **Entry:** `/settings/allergens`.
- **User story:** As an allergic user, I want to choose which allergens and diets to track and where they display so that recipe cards/details warn me about what matters to me.
- **Expected behavior:** FilterChips for allergens + diets; display toggles (cards, detail, coverage, include-unknown-in-menu); Save appears only on change; reset-to-defaults with confirm; a retag section re-analyzes all user recipes.
- **Edge cases:** Save disabled while loading / no changes; reset behind confirm; allergen disclaimer always shown.
- **Test coverage:** Verified — `allergen_preferences_viewmodel_test.dart`, `allergen_preferences_view_test.dart`.

#### SET-03: Notification preferences (categories + quiet hours)
- **Entry:** `/settings/notifications`.
- **User story:** As a user, I want granular control over notification categories, digest frequency and quiet hours so that I only get the alerts I want, when I want them.
- **Expected behavior:** Master toggle (gates the Android 13+ OS permission); 7 per-category toggles (dimmed when master off); digest dropdown; quiet-hours toggle (default 22:00–08:00) with time pickers. Optimistic save with revert. Analytics on each category toggle. Sound and vibration are NOT offered here — BUT-1783 removed those two switches because the OS notification channel owns both, so the stored value could never take effect.
- **Edge cases:** OS permission declined → preference persists OFF; save failure reverts + error; load failure → retry.
- **Test coverage:** View widget tested (BUT-1353, plus the BUT-1783 removal pin); preference manager + types unit-tested.

#### SET-04: Account security (password + email + MFA + legal)
- **Entry:** `/settings/account-security`.
- **User story:** As a user, I want to change my password and email, manage MFA, and reach legal/reports from one combined security screen so that account safety is centralized.
- **Expected behavior:** Change-password + change-email (re-auth + verification), MFA sub-section, and legal links (terms, guidelines, my-reports, OS licenses).
- **Edge cases:** Email change sends verification rather than changing immediately.
- **Test coverage:** Partial — `account_security_viewmodel_test.dart` (VM only; view untested).

#### SET-05: Multi-factor authentication enrollment
- **Entry:** MfaSettingsView (from Account Security). *(UI for AUTH-11.)*
- **User story:** As a security-conscious user, I want to enroll/unenroll phone-based MFA so that my account is protected by a second factor.
- **Expected behavior:** Info card; phone entry (auto +46) → SMS → 6-digit verify; lists enrolled factors with delete; re-auth required before enroll + unenroll.
- **Edge cases:** Auto-verification bypasses manual entry; error codes mapped; empty phone/code guarded.
- **Test coverage:** **Untested** — none for MfaSettingsView or AuthMfaService.

#### SET-06: Collection statistics
- **Entry:** `/settings/collection-stats`.
- **User story:** As a user, I want statistics about my recipe collection so that I can see totals, distribution, activity, and what's incomplete.
- **Expected behavior:** Hero banner (totals); breakdown (personal/collaborative/high-rated); top meal-types + tags charts; cooking summary; completeness section with tappable quick-fix chips that open incomplete recipes.
- **Edge cases:** Empty-state widgets; distribution bar hidden at 0; "all complete" state.
- **Test coverage:** **Untested** — no collection-stats test.

#### SET-07: In-app notification inbox
- **Entry:** `/notifications`.
- **User story:** As a user, I want a history of my notifications that I can tap to deep-link, mark read, and bulk-dismiss so that I can manage what I've received.
- **Expected behavior:** Paginated list (infinite scroll); tap marks-opened + routes through the same deep-link path as an FCM tap; unread bold; "mark all read"; long-press multi-select bulk dismiss.
- **Edge cases:** Legacy entries without a route → home; dynamic data coerced to String; branded empty state; error + retry.
- **Test coverage:** Verified — `notifications_viewmodel_test.dart`, `notification_history_entry_test.dart`.

#### SET-08: Notification deep-link routing
- **Entry:** FCM push tap or in-app inbox tap.
- **User story:** As a user, I want tapping a notification to open the right screen so that I land on the recipe/request/menu it refers to, not a crash or blank.
- **Expected behavior:** Maps server-stamped `route` + `targetId` to navigator actions; resolves recipeId to a full Recipe before pushing detail; records server-side `recordNotificationOpened` (CTR) fire-and-forget; logs analytics.
- **Edge cases:** Null/unknown route → home + event; recipe missing/unreadable → home; navigator unmounted after async → skip; failures never break navigation.
- **Test coverage:** Verified — `notification_deep_link_router_test.dart`. *(Route constants are the contract Cloud Functions must align to.)*

#### SET-09: Beta feedback FAB
- **Entry:** Floating "!" button on every authenticated screen.
- **User story:** As a beta user, I want a one-tap feedback button that captures a screenshot so that I can report bugs in-context from anywhere.
- **Expected behavior:** Square "!" at bottom-right, visible only when authenticated; on tap captures a screenshot via RepaintBoundary and opens the feedback form.
- **Edge cases:** Hidden when unauthenticated; screenshot best-effort (proceeds without on failure).
- **Test coverage:** Verified — `feedback_fab_test.dart`.

#### SET-10: Beta feedback form
- **Entry:** Opened by the feedback FAB.
- **User story:** As a beta user, I want to choose a category, describe an issue, optionally leave my email, and attach/remove the screenshot so that my report is useful.
- **Expected behavior:** Category dropdown (bug/feature/general), description (≤2000), optional email (≤100), screenshot preview with remove; submits via FeedbackService. Success → thanks snackbar.
- **Edge cases:** Empty description blocks submit; screenshot optional; submit shows spinner + disabled.
- **Test coverage:** Verified — `feedback_form_dialog_test.dart`, `feedback_entry_test.dart`. *(Last-20-interactions enrichment lives server-side in FeedbackService.)*

#### SET-11: Legal documents (terms, privacy, community guidelines)
- **Entry:** `/legal/terms`, `/legal/privacy`, `/legal/community-guidelines`.
- **User story:** As a user, I want to read the terms, privacy policy, and community guidelines so that I understand my rights and the rules.
- **Expected behavior:** Loads a localized markdown asset and renders it as selectable text, with a contact footer. Responsive width.
- **Edge cases:** Falls back to the Swedish asset if the locale file is missing; load failure → error + retry.
- **Test coverage:** **Untested** — no terms/privacy/guidelines view tests.

#### SET-12: FAQ / help
- **Entry:** `/faq`.
- **User story:** As a user, I want answers to common questions so that I can learn how to use the app without contacting support.
- **Expected behavior:** Static list of 5 Swedish Q&A items in expansion tiles (importing, sharing, weekly menu, tags, reporting).
- **Test coverage:** **Untested**. *(Content is hardcoded Swedish, not l10n-localized — inconsistent with the rest of the app.)*

#### SET-13: My reports (report status tracking)
- **Entry:** `/settings/my-reports`.
- **User story:** As a user who reported content, I want to see my submitted reports and their lifecycle status so that I have transparency (required by Google Play UGC appeal policy).
- **Expected behavior:** Lists reports with content-type icon, reason, timestamp, and a colored status badge (pending/reviewed/actioned/closed). Pull-to-refresh; loading/error/empty states.
- **Test coverage:** Verified — `my_reports_viewmodel_test.dart`.

#### SET-14: Content moderation queue (admin/moderator)
- **Entry:** `/admin/moderation` — admin-gated tile.
- **User story:** As a moderator, I want a queue of open reports with state-machine actions so that I can advance, close, hide, or delete reported content.
- **Expected behavior:** `watchIsAdmin()` gates access (non-admins get "not authorised"). Admins get a live list of open reports with actions: Advance, Hide/Delete (profile → reversible suspend, else hard delete), Close. Take-down behind confirm.
- **Edge cases:** Advance/close hidden when already closed; profile takedown reversible, others hard delete.
- **Validation:** Admin enforced UI-side and (per comments) by Firestore rules.
- **Test coverage:** Verified — `moderator_review_viewmodel_test.dart`. *(Other admin tabs live in the separate admin dashboard app; this in-app moderator screen is the user-facing one.)*

### Engine & Background

#### ENG-01: Automatic recipe tagging (5-phase tag engine)
- **Entry:** Automatic on recipe save/import (silent).
- **User story:** As a home cook, I want my recipes auto-labeled with allergen, dietary, method, difficulty, mood and cuisine tags so that I can filter and trust safety info without tagging anything by hand.
- **Expected behavior:** Looks up each ingredient, then runs a 5-phase pipeline (base/allergen/dietary → derived → complex/difficulty → mood/season → cuisine). Each phase has its own time budget. Produces a TagResult with tri-valued allergen status, dietary status, coverage %, unknown ingredients. Safety-resolves conflicting tags.
- **Edge cases:** Empty → empty; phase-1 failure → failed result; later-phase exception → that phase skipped; timeout → remaining skipped but phase 1 always completes; "all unknown" flagged, not retried; config-validation failure → degraded mode.
- **Validation:** Rejects out-of-range coverage / future timestamps / missing version before saving.
- **Test coverage:** Verified — `tag_generator_test.dart`, `tagging_service_test.dart`, `tagging_pipeline_runner_test.dart`, `tagging_edge_cases_test.dart`, `tag_phase2_derived_test.dart`, `tagging_performance_test.dart`, `tagging_golden_test.dart`, `tagging_integration_test.dart`. *(Fully deterministic, no LLM.)*

#### ENG-02: Allergen / dietary status detection (tri-valued)
- **Entry:** Automatic, part of tagging; surfaced as allergen badges.
- **User story:** As an allergic user, I want each recipe marked FREE / CONTAINS / UNKNOWN per allergen so that I can avoid unsafe meals at a glance.
- **Expected behavior:** Phase 1 computes per-allergen status from matched ingredient properties; always completes even on timeout. UNKNOWN is hidden in UI (only FREE/CONTAINS shown).
- **Edge cases:** Unknown ingredients lower coverage; draft AI ingredients flagged.
- **Validation:** Config registry validated at startup; failure → degraded mode.
- **Test coverage:** Verified — `allergen_config_test.dart`, `allergen_key_consistency_test.dart`, `allergen_mismatch_test.dart`, `allergen_status_badge_test.dart`. *(Safety-critical core; deterministic.)*

#### ENG-03: Quick phase-1 tag preview (import responsiveness)
- **Entry:** Automatic during import preview, before full save-time tagging.
- **User story:** As someone importing a recipe, I want to see allergen/dietary status immediately in the preview so that I don't wait for full tagging before deciding to save.
- **Expected behavior:** Runs only phase 1 with a short 5s timeout; returns null on timeout/failure rather than blocking.
- **Test coverage:** Partial — covered indirectly via `tag_generator_test.dart`; no dedicated preview test.

#### ENG-04: Automatic retagging scheduler
- **Entry:** Automatic 5s after startup + optional every 24h.
- **User story:** As a user, I want recipes that failed tagging or went stale to be re-tagged automatically so that my allergen/tag data stays correct.
- **Expected behavior:** Scans for recipes needing retag (failed, lookup-timeout, stale version), processes in batches of 10 with delays, caps at 100/session.
- **Edge cases:** 3× consecutive failures skipped until reset; "all unknown" skipped; concurrent runs guarded.
- **Test coverage:** Partial — exercised via tagging tests; no dedicated scheduler test.

#### ENG-05: Bulk / manual retag-all
- **Entry:** User-initiated from settings ("retag all").
- **User story:** As a user, I want to force-retag my whole library so that after an ingredient-DB update my tags refresh on demand.
- **Expected behavior:** Fetches recipes, optionally force-retags all, batches of 10 in parallel with delays, live progress, surfaces real errors (not silent "0 retagged").
- **Edge cases:** Invalid results skipped; if all fail, throws explicitly so the dialog shows it.
- **Test coverage:** Verified — `tagging_service_test.dart`.

#### ENG-06: Personal-tag rule engine (smart collections)
- **Entry:** Automatic when recipes are saved/evaluated.
- **User story:** As an organizer, I want my custom tag rules to auto-apply to matching recipes so that my collections stay populated without manual tagging.
- **Expected behavior:** Evaluates enabled rules against recipes, tracks which rule matched, does ingredient lookup only when needed, enforces exclusive-group constraints.
- **Edge cases:** Empty rules/recipes short-circuit; no auth → empty.
- **Test coverage:** Partial — adjacent logic in `tag_editing_service_test.dart`, `tag_resolution_service_test.dart`; no dedicated rule-evaluator test. *(Separate subsystem from auto-tags; deterministic.)*

#### ENG-07: Tiered recipe parsing (import engine)
- **Entry:** Automatic on URL/text import.
- **User story:** As a user importing recipes, I want reliable extraction so that I rarely have to fix the result, and cheaply so the app stays affordable.
- **Expected behavior:** Runs 4 tiers in cost order — SchemaOrg (JSON-LD) → SiteConfig (CSS) → RuleBased (Swedish classifier + CRF) → LLM fallback — stopping as soon as a tier clears the quality threshold. Reliable domains get a higher bar; structured tiers a discount. Merges results.
- **Edge cases:** Security check blocks unsafe content; cache hit short-circuits; circuit breaker disables cache after 3 failures; most-actionable Swedish error on total failure.
- **Validation:** Quality threshold 0.65 base, +0.15 reliable domain, cap 0.95.
- **Test coverage:** Verified — `parsing_golden_test.dart`, `parser_accuracy_benchmark.dart`, `parsed_recipe_cache_test.dart`, `parsed_recipe_structure_isolate_roundtrip_test.dart`, `parse_events_tracker_test.dart`. *(Core cost control — LLM last resort.)*

#### ENG-08: Selective ingredient-line LLM enhancement
- **Entry:** Automatic inside parsing, just before the full-LLM fallback.
- **User story:** As a user, I want imports accurate without burning money, so the app should only ask the AI to fix the few lines it's unsure about rather than re-reading the whole recipe.
- **Expected behavior:** Sends only low-confidence ingredient lines (~500 tokens) for re-parsing instead of the whole recipe (~3000), splices results back, skips the LLM tier if quality now passes.
- **Edge cases:** Skipped with no LLM, no uncertain lines, or >50% uncertain (full LLM better then).
- **Test coverage:** Partial — no dedicated test; parsing goldens cover the broader flow. *(~6× fewer tokens on partial-quality imports.)*

#### ENG-09: On-device ingredient parsing cascade (CRF → BERT NER → LLM)
- **Entry:** Automatic inside every parse tier. *(Engine view of IMP-11.)*
- **User story:** As a user, I want ingredient quantities/units parsed accurately on my device so that imports work fast, offline, and without cloud cost where possible.
- **Expected behavior:** CRF model first (ranges, alternatives, optionals); low-confidence lines (<0.7) → on-device BERT NER ONNX; only still-uncertain → cloud LLM. Regex fallback when no model.
- **Edge cases:** CRF weights load lazily with retry window; remote weight upgrades once/session; BERT downloaded on demand; all init fire-and-forget so parsing never blocks.
- **Test coverage:** Partial — goldens + benchmark exercise CRF/regex; ONNX NER path untested. *(Strong cost lever; models hot-upgradeable from Storage.)*

#### ENG-10: Parse-correction feedback (active learning)
- **Entry:** Automatic when a user edits a freshly imported recipe.
- **User story:** As a user, I want my corrections to a bad import to quietly improve future parsing so that the importer gets smarter over time.
- **Expected behavior:** Fans a correction into per-field jobs (from/to, truncated to 500 chars) uploaded via `logParseCorrection` for server-side aggregation.
- **Test coverage:** Verified — `parse_correction_uploader_test.dart`, `parsing_correction_repository_test.dart`. *(Feeds the corpus that trains CRF/NER.)*

#### ENG-11: Recipe search (local, on-device matching)
- **Entry:** Automatic as the user types in recipe search.
- **User story:** As a user browsing recipes, I want search to match instantly across my loaded library without a network round-trip per keystroke.
- **Expected behavior:** Substring matching over already-cached recipes (title/description/ingredients/instructions/personal tags) via `SearchService`, sorted locally — no per-keystroke network call. *(BUT-1500: the dead Algolia-routing path was removed; Algolia infrastructure remains for indexing / user search.)*
- **Edge cases:** Empty query short-circuits; search covers only recipes already loaded into the list.
- **Test coverage:** Verified — `search_service_test.dart`, `search_repository_test.dart`.

#### ENG-12: Allergen / dietary filtering in menu generation
- **Entry:** Automatic when generating a weekly menu (opt-in toggles, off by default).
- **User story:** As an allergic user, I want the menu generator to never propose recipes containing my allergens so that my auto-planned week is safe.
- **Expected behavior:** Reads allergen preferences, drops recipes whose tagResult reports CONTAINS; UNKNOWN dropped only in strict mode. Household variant aggregates allergens across members first.
- **Edge cases:** Recipes with no tag data included as a safe default; empty eligible pool throws (no auto-relaxation); single-swap returns exhausted when none remain.
- **Validation:** Gated by the filter settings.
- **Test coverage:** Verified — `menu_generator_test.dart` (contains/free/unknown, strict vs tolerant, multi-allergen, empty pool), `menu_viewmodel_test.dart`. *(Depends on ENG-02 tag quality.)*

#### ENG-13: Offline sync & connectivity monitoring
- **Entry:** Automatic; offline banner + sync indicator + flush on reconnect.
- **User story:** As a user with spotty connectivity, I want to keep using the app offline and have my changes saved and synced automatically when I'm back online so that I never lose work.
- **Expected behavior:** Detects online/offline; on reconnect flushes recipes queued in a local Drift/SQLite DB with retry + backoff. Queued offline-tagging ops also retry. Async mutex prevents concurrent syncs.
- **Edge cases:** Web hardcoded always-online; per-recipe failures recorded + skipped; partial success reported.
- **Test coverage:** Verified (extensive) — `offline_service_test.dart`, `offline_initialization_test.dart`, `offline_sync_manager_test.dart`, `offline_user_storage_test.dart`, `connectivity_monitoring_service_test.dart`, `offline_tagging_sync_test.dart`, plus banner/indicator widget tests.

#### ENG-14: Image optimization & progressive loading
- **Entry:** Automatic wherever recipe images render.
- **User story:** As a user, I want recipe images to load fast and smoothly so that browsing feels responsive and doesn't blow my data/memory.
- **Expected behavior:** Blur-up progressive loading, DPR-aware cache sizing, fade-in (respecting reduce-motion), stable cache keys. Memory cache capped at 100MB, LRU eviction under pressure with hit/miss stats.
- **Edge cases:** Local vs network handled separately; Storage has no URL transforms so pre-generated thumbnails used; broken images → error widget.
- **Test coverage:** Partial — `image_factory_test.dart`, `image_preview_card_test.dart`, format util tests; no dedicated OptimizedImageLoader test.

#### ENG-15: Intelligent predictive cache / prefetch
- **Entry:** Fully background; no user-visible entry.
- **User story:** As a user, I want recipes I'm likely to open next to load instantly so that the app feels fast at the times of day I cook.
- **Expected behavior:** Learns a per-user behavior pattern (views, recency, meal-type-by-hour, active friends), prefetches every 5 min, evicts by a recency/frequency/age score under a 50MB cap. Pauses in background; clears on memory pressure (keeps current user).
- **Edge cases:** Anonymous fallback; friends-activity preload stubbed; clear-in-progress guard.
- **Test coverage:** Partial — `cache_operations_test.dart`, `cache_optimization_test.dart` cover cache modules; no dedicated IntelligentCacheManager test. *(Uses `permissionService.currentUserId` per the data-source rule.)*

#### ENG-16: Ingredient-change stale-marking cascade (server)
- **Entry:** Automatic server-side trigger when the central ingredient DB changes.
- **User story:** As a user, I want my recipes' allergen badges to update automatically when the ingredient database is corrected so that I'm never shown stale safety info.
- **Expected behavior:** `onIngredientPropertiesChanged` finds recipes containing the changed ingredient and batch-marks their generator version `stale-properties`; the client retags on next load (ENG-04). Soft-delete cascade + 30-day grace hard-delete. Admin bulk-retag (rate-limited 5/day, audit-logged).
- **Edge cases:** Dart↔server Swedish normalization must match for array-contains queries.
- **Test coverage:** Verified — `normalization-parity.test.ts`; bulk-retag via admin tests.

#### ENG-17: LLM recipe extraction service (server fallback)
- **Entry:** Automatic — last parsing tier; also powers OCR image import + video-transcript import.
- **User story:** As a user, I want even messy or unstructured recipe sources to import cleanly so that I can save anything I find.
- **Expected behavior:** `structureRecipe` callable sends PII-scrubbed text to Vertex AI Gemini (`gemini-2.5-flash-lite`, EU multi-region for GDPR) in four modes (extract/enhance/spoken/ingredientLines), returns schema-validated JSON with a salvage path for truncated long recipes.
- **Edge cases:** Truncated responses salvaged; PII scrubbed pre-send; per-call cost estimate returned.
- **Validation:** Two fail-open kill switches (`aiEnabled`, `llmParserEnabled`) + rate-limit middleware. Prompts hot-reloaded with SHA-256 A/B bucketing.
- **Test coverage:** Verified — `llm-kill-switch.test.ts`, `prompts-config.test.ts`, `structure-recipe-empty.test.ts`, `parse-recipe-response-*.test.ts`, `parse-ingredient-lines.test.ts`, `ocr-validation.test.ts`, `pii-scrubber.test.ts`, `prompt-ab-bucket.test.ts`, `gemini-cache-telemetry.test.ts`. *(The single biggest running-cost surface — guarded by kill switches, rate limits, smallest model, prompt-caching telemetry.)*

#### ENG-18: Social push notifications
- **Entry:** Automatic when a friend acts (request, share, comment, rating).
- **User story:** As a user, I want to be notified when friends interact with me or my recipes so that I stay engaged with my cooking circle.
- **Expected behavior:** `sendNotification`/`sendNotificationBatch` deliver typed, route-validated payloads. Server authorization: you can only notify friends or pending-request peers. `acceptFriendRequest` atomically writes mutual friend docs server-side. Profile changes fan out to denormalized copies.
- **Edge cases:** Deep-link routes allow-listed; non-friend sends rejected.
- **Test coverage:** Verified — `send-notification.test.ts`, `accept-friend-request.integration.test.ts`, `notification-payload.test.ts`. *(All delivery passes through ENG-19 gating.)*

#### ENG-19: Notification gating (RC flags, quiet hours, rate cap)
- **Entry:** Automatic — every non-silent push passes through before delivery.
- **User story:** As a user, I want notifications respected to my preferences and not spammy so that the app never wakes me at night or floods me.
- **Expected behavior:** Three layers — per-type RC flag; quiet hours (IANA TZ, default Europe/Stockholm; low-importance dropped, high delayed + drained every 5 min); rate cap via transaction (10/24h total, 5 non-critical; critical bypasses non-critical cap).
- **Edge cases:** All layers fail open if RC/Firestore unreachable; midnight-wrap windows handled; over-cap silently dropped.
- **Test coverage:** Verified — `quiet-hours.test.ts`, `notification-rate-cap.test.ts`, `deliver-scheduled-notifications.test.ts`, `notification-effectiveness.test.ts`, `record-notification-opened.test.ts`.

#### ENG-20: Re-engagement — win-back & weekly digest
- **Entry:** Automatic scheduled jobs; user sees a push + in-app notification.
- **User story:** As a lapsed user, I want a gentle, relevant nudge to return; as an active user, a weekly recap of my cooking.
- **Expected behavior:** Daily lapsed detection at 7/14/30-day marks with a deterministic A/B copy variant, push copy from RC (Swedish fallback), sent via FCM (respecting ENG-19). Weekly Monday digest. Day-N retention events. Anomaly detection + low-performer suppression auto-mute underperforming types.
- **Edge cases:** RC failure → compiled Swedish strings; variant forwarded to Analytics for cohort attribution.
- **Test coverage:** Verified — `detect-lapsed-users.test.ts`, `winback-variant.test.ts`, `track-retention.test.ts`, `compute-feature-retention.test.ts`, `send-activity-digest.test.ts`, `detect-anomalies.test.ts`, `north-star-weekly.test.ts`. *(Deterministic; no LLM.)*

#### ENG-21: Rating aggregation (debounced)
- **Entry:** Automatic on rate create/update/delete; user sees aggregate stars.
- **User story:** As a user, I want recipe ratings to show an accurate average and count so that I can judge a recipe at a glance.
- **Expected behavior:** A rating change writes a 5s debounce marker; a 1-min scheduled drain re-reads all ratings and writes denormalized stats. Collapses bursts into one write to stay under Firestore's write limit.
- **Edge cases:** Marker claimed-by-delete to avoid double aggregation; ≤1 min lag.
- **Test coverage:** Verified — `rating-aggregation.test.ts`.

#### ENG-22: Upload & content moderation
- **Entry:** Automatic on every image upload + comment/message creation.
- **User story:** As a user, I want the app to block malicious uploads and spammy duplicate posts so that the shared space stays safe and clean.
- **Expected behavior:** `moderateUpload` magic-byte-checks every finalized upload against its declared Content-Type, deleting spoofed files + audit-logging. `duplicate-content-guard` hashes author+normalized-body and deletes a comment/message repeated within 5 min.
- **Edge cases:** At-least-once retries de-duped via stored event ID; only text chat guarded; SafeSearch/Vision deferred on cost/privacy.
- **Test coverage:** Verified — `moderate-upload.test.ts` (+integration), `duplicate-content-guard.test.ts`, `moderation-rules.test.ts`. *(Cheap deterministic checks; avoids paid image classification.)*

#### ENG-23: Account deletion cascade / GDPR engine (server)
- **Entry:** User-initiated account deletion (triggered by AUTH-14); also a self-serve audit-log export.
- **User story:** As a user, I want deleting my account to truly erase my data so that my privacy rights are honored.
- **Expected behavior:** `requestAccountDeletion` runs a 3-tier Admin-SDK cascade (own content deleted, comments anonymized to preserve threads, subcollections cleared, root doc removed, Auth user deleted). A post-cascade probe records residuals + flags `gdprCompliant: false` if any remain. `exportAuditLogs` serves Article 15. `purgeExpiredAuditLogs` enforces tiered retention.
- **Edge cases:** Residuals surfaced in `failedCollections`; comments anonymized rather than deleted.
- **Test coverage:** Verified — `request-account-deletion.test.ts` (+integration), `purge-audit-logs.test.ts`, `audit-logs-rules.test.ts`, `export-audit-logs.test.ts`, `notification-queues-gdpr.test.ts`.

#### ENG-24: Scheduled storage & data cleanup jobs
- **Entry:** Fully background scheduled jobs.
- **User story:** As a user (and the operator), I want orphaned files and stale data cleaned up automatically so that the app stays cheap to run and my deleted content doesn't linger.
- **Expected behavior:** On recipe delete, Storage images deleted immediately. Scheduled jobs purge parse cache >90d, notification history >90d, rate-limit docs >90d, soft-deleted ingredients >30d (marking referencing recipes stale), expired social requests, orphaned shared-content metadata.
- **Edge cases:** Paginated with safety cutoffs (e.g. 8-min) to avoid runaway jobs.
- **Test coverage:** Partial — `cascade-audit-log.test.ts` (+wirings), `purge-audit-logs.test.ts`; several cleanup jobs lack dedicated tests.

#### ENG-25: PWA install prompt (web)
- **Entry:** Web only — a bottom banner after the 3rd session.
- **User story:** As a web user, I want to add Butlery to my home screen so that it feels like a native app.
- **Expected behavior:** Reads the browser's deferred install prompt; banner surfaces only after 3 sessions and if available. Install triggers the native add-to-home-screen prompt; dismiss persists a permanent flag.
- **Edge cases:** Non-web builds compile a stub (banner renders nothing).
- **Test coverage:** **Untested**.

#### ENG-26: Recipe print (web)
- **Entry:** Web only — "Print" in the recipe detail menu.
- **User story:** As a web user, I want to print a clean copy of a recipe (or save as PDF) so that I can cook from paper.
- **Expected behavior:** Generates a clean serif HTML page (Swedish headings), opens it in a new tab, and calls the browser print dialog. No direct PDF (user chooses print-to-PDF).
- **Edge cases:** Double-gated (menu item + service both web-only).
- **Test coverage:** **Untested**. *(Uses native print; zero server cost.)*

