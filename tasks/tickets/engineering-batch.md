# Linear Ticket Drafts — Engineering & Inclusion Audit (2026-05-22)

> Paste-ready ticket bodies. Linear MCP was not connected when these were prepared, so they have not been created in Linear yet. Each section is one ticket. Separator `---` marks ticket boundaries.

Findings from the fourth audit sweep — moving from product-UX gaps to engineering and inclusion gaps: accessibility, onboarding journey, edge-case content robustness, code-quality hygiene against the project's own stated rules, and localisation.

---

# Theme 1 — Accessibility (WCAG 2.1 AA)

## 1. Add semantic labels to loading indicators across views

**Labels:** `bug`, `settings`
**Priority:** Medium
**State:** Triage

### Finding
Seven `CircularProgressIndicator` instances render without `Semantics(label:)`, leaving screen-reader users unable to tell whether the app is loading or hung:
- `lib/views/quick_capture_view.dart` (OCR upload spinner)
- `lib/views/skriv_sjalv_recept_view.dart` (recipe save spinner)
- `lib/views/auth/mfa_challenge_dialog.dart` (MFA verification spinner)
- `lib/views/social/friend_profile_view.dart` (16px profile load spinner)
- `lib/views/recipe_detail_view.dart:272` (recipe hero placeholder spinner)
- A few more in the `views/social/*` tree.

### Proposed Improvement
Wrap each in `Semantics(label: context.l10n.a11yLoading, child: CircularProgressIndicator())`. Better: create a `BranderedLoader` widget that bakes this in, and migrate offenders.

### Effort vs Impact
Small / medium. Blocks screen-reader users from understanding async state.

---

## 2. Use `labelText` not `hintText` on form fields

**Labels:** `bug`, `recipe`, `account`
**Priority:** Medium
**State:** Triage

### Finding
- `recipe_detail_comments.dart` — comment composer uses `InputDecoration(hintText: ...)` only. Once the user starts typing, the hint disappears and no persistent label remains.
- `auth_view.dart` — password-reset field is a bare `TextField` with no decoration.

Both leave screen-reader users without persistent field identity.

### Proposed Improvement
Switch to `InputDecoration(labelText: context.l10n.<key>)`. Add a hint separately if needed.

### Effort vs Impact
Trivial / medium.

---

## 3. Cooking-mode title respects `textScaleFactor`

**Labels:** `bug`, `recipe`
**Priority:** Low
**State:** Triage

### Finding
`lib/views/cooking_mode_view.dart:142-148` — recipe title uses `AppTextStyles.headerTitle` directly, while step number and instruction text multiply by `vm.fontScale` (lines 141-162). Inconsistent: users at 1.25× system scale get scaled content but a fixed-size title. Violates WCAG 1.4.4 (Resize Text).

### Proposed Improvement
Multiply title `fontSize` by `vm.fontScale` to match the rest of the cooking-mode body.

### Effort vs Impact
Trivial / low.

---

## 4. Audit modal/dialog focus-return behaviour

**Labels:** `idea`, `settings`
**Priority:** Medium
**State:** Triage

### Finding
87 `showDialog` / `showModalBottomSheet` call sites across the app. Static analysis can confirm that dialogs trap focus (e.g. `barrierDismissible: false`), but **whether focus returns to the trigger button on close is not testable from code alone** — needs a manual screen-reader pass.

### Proposed Improvement
- Manual screen-reader test (TalkBack + VoiceOver) on a representative sample of dialogs: open, close via OK/Cancel, confirm focus returns to the calling button.
- Where focus doesn't return, attach a `FocusNode` on the trigger and call `requestFocus()` after dialog dismissal.
- Document the pattern in a `docs/accessibility/` note for future dialogs.

### Effort vs Impact
Small (audit) + variable (fixes) / medium.

---

## 5. Online-status indicator needs a non-colour signal

**Labels:** `bug`, `social`
**Priority:** Low
**State:** Triage

### Finding
`lib/views/social/friends_list/feed_tab.dart` and `social_avatar_components` render online status as a green dot. Users with red/green colour-blindness (~8% of men, ~0.5% of women) can't distinguish online from offline. Violates WCAG 1.4.1 (Use of Colour).

### Proposed Improvement
- Add an icon overlay on the avatar (filled-circle for online, hollow for offline) OR a visible label ("Online", "Last seen 5 min ago") in a tooltip / a11y label.
- Confirm with `Semantics(label: 'Online')` so screen readers announce status.

### Effort vs Impact
Small / low.

---

## 6. Announce state changes via `SemanticsService.announce`

**Labels:** `idea`, `recipe`, `social`, `shopping`
**Priority:** Medium
**State:** Triage

### Finding
Cooking-mode advances are announced (`cooking_mode_view.dart:453-459`) — good. But other discrete state changes are silent to screen readers:
- Favoriting a recipe (`recipe_detail_view.dart:335`).
- Posting a comment.
- Marking a shopping item as bought.
- OCR extraction completing.

### Proposed Improvement
After each state change, call `SemanticsService.announce(context.l10n.<key>)`. Add keys: `a11yRecipeFavorited`, `a11yCommentPosted`, `a11yItemBought`, `a11yOcrComplete`.

### Effort vs Impact
Small / medium.

---

## 7. Add semantic labels to avatar components

**Labels:** `bug`, `social`
**Priority:** Low
**State:** Triage

### Finding
`SocialAvatarComponents.avatar()` in `lib/views/social/friends_list/friends_list_cards.dart` renders an `Image.network` (or initials fallback) with no semantic label. Screen readers announce a generic "image" or skip it entirely; users infer identity from surrounding text.

### Proposed Improvement
Pass `semanticLabel: profile.displayName` into the avatar component. For initials fallback, use the display name there too.

### Effort vs Impact
Small / low.

---

# Theme 2 — Onboarding & first-week retention

## 8. Surface Sign-out and Delete-Account in the Settings UI (GDPR-relevant)

**Labels:** `bug`, `account`
**Priority:** High
**State:** Triage

### Finding
Backend exists, UI does not:
- `lib/viewmodels/profile/profile_viewmodel.dart:57-67` — `logout()` is implemented (calls `AuthService.signOut()`).
- `lib/viewmodels/profile/profile_viewmodel.dart:76-111` — `deleteAccount()` is implemented and orchestrates a full GDPR-compliant purge via `AccountDeletionService`.
- `lib/views/settings/settings_hub_view.dart:34-114` — **no button or menu entry for either**. Users cannot find sign-out or delete-account from the app.

GDPR Art. 17 (right to erasure) effectively requires a discoverable path. Hiding the button is a compliance risk and increases support load.

### Proposed Improvement
Add a "Danger zone" section to `SettingsHubView` with:
- "Sign out" — confirm dialog → calls `logout()`.
- "Delete account" — multi-step confirm dialog (re-enter password + acknowledgements) → calls `deleteAccount()`.

### Effort vs Impact
Small / high. Pure wiring of existing services. Compliance + support-cost win.

---

## 9. Add social sign-in (OAuth) to sign-up

**Labels:** `idea`, `account`
**Priority:** Medium
**State:** Triage

### Finding
`lib/views/auth_view.dart` — sign-up requires name + email + password + 18+ checkbox + terms acceptance (5 fields, 2 checkboxes). No Google / Apple / Facebook OAuth. Industry data suggests OAuth can lift signup conversion 30–40%.

### Proposed Improvement
Add Apple Sign-In (mandatory on iOS), Google Sign-In, optionally Facebook. Reuse existing `AuthService` patterns; OAuth providers map to the same Firebase user. Keep email/password as a fallback.

### Effort vs Impact
Medium / high. Apple Sign-In is required for iOS App Store compliance anyway if any other OAuth is offered.

---

## 10. Add guest / demo mode for try-before-signup

**Labels:** `idea`, `account`
**Priority:** Medium
**State:** Triage

### Finding
No path to explore the app without signing up. Competitors (Paprika, BigOven) allow browsing recipes anonymously, with conversion gates at "save" / "share" / "create".

### Proposed Improvement
Anonymous Firebase Auth on first launch → user can browse seeded sample recipes, open the cooking mode, but write actions trigger a sign-up prompt. Convert anonymous user to permanent on sign-up (Firebase supports this natively).

### Effort vs Impact
Medium / medium-high. Significant retention gain at the top of the funnel.

---

## 11. Allow re-launching onboarding from Settings

**Labels:** `idea`, `account`, `settings`
**Priority:** Medium
**State:** Triage

### Finding
`lib/views/onboarding/onboarding_view.dart` runs once. If a user later wants to revisit (e.g. allergies were just diagnosed, or they want to set dietary prefs they skipped), they must call support — there's no "Restart onboarding" affordance.

### Proposed Improvement
Settings → Account → "Set up dietary preferences again" → re-enters the onboarding flow from the allergen page (page 2). Skip age-gate (already passed).

### Effort vs Impact
Small / medium.

---

## 12. Make recipe seeding synchronous or surface failures

**Labels:** `bug`, `account`, `recipe`
**Priority:** High
**State:** Triage

### Finding
`lib/viewmodels/onboarding_viewmodel.dart:256-295` — on onboarding completion, `_seedStarterRecipes()` is called fire-and-forget (line 264, no `await`). Failures are logged but never surfaced. If seeding fails (network blip, Firestore quota, etc.), the user lands on an empty app on their first visit. Worst possible first impression.

### Proposed Improvement
Two options:
- (a) Await the seed and show a brief progress state during the last onboarding page. Don't let the user exit onboarding until seed completes (or fails clearly).
- (b) Keep fire-and-forget but on the empty recipe-list view, detect "newly-completed onboarding with no recipes" and show a "We're setting up your starter recipes…" loader + retry.

(a) is simpler; (b) is more resilient.

### Effort vs Impact
Small / high. Single biggest first-impression risk in the funnel.

---

## 13. Add a "What's new" / changelog surface

**Labels:** `idea`, `settings`
**Priority:** Low
**State:** Triage

### Finding
No infra detected for release notes, what's-new banner, or migration messages. When new features ship (e.g. cooking mode, meal planning), users stumble through them blind.

### Proposed Improvement
Use Firebase Remote Config (probably already in use somewhere) to deliver a small "What's new in vX.Y" payload. On first launch after an update, show a 1–2 screen splash with key changes + a "tell me more" link. Track dismissal per version.

### Effort vs Impact
Medium / low-medium. Compounding benefit as the app evolves.

---

## 14. Seed sample menus and shopping lists alongside recipes

**Labels:** `idea`, `account`, `menu`, `shopping`
**Priority:** Medium
**State:** Triage

### Finding
`lib/viewmodels/onboarding_viewmodel.dart:263` calls `UnifiedRecipeService.createPersonalRecipe()` for `RecipeSeeds.allRecipes` — recipes are seeded but no menu or shopping list. New users see recipes but no example of the full app workflow (recipes → menu → shopping → cook).

### Proposed Improvement
Seed one sample week-of-menu and one sample shopping list (derived from the seeded recipes). Bonus: aligns with the uxgap-batch #7 menu→shopping aggregation ticket — once that ships, the sample menu auto-generates the sample shopping list.

### Effort vs Impact
Small / medium.

---

## 15. Add lapsed-user re-engagement notifications

**Labels:** `idea`, `social`, `analytics`
**Priority:** Medium
**State:** Triage

### Finding
Analytics tracks the funnel well (`analytics_events.dart` has `onboardingCompleted`, `firstCook`, `userActivated`, `timeToFirstRecipe`), but there's no scheduled Cloud Function that detects users who signed up and haven't returned in N days and sends a re-engagement push.

### Proposed Improvement
Scheduled Cloud Function (daily) queries users with `lastActivityTime < now - 7d`, sends a contextual notification: "Your friend Alice shared a recipe with you" / "Try these 3 recipes you saved last week" / "You haven't set up your dietary preferences yet". Gated by push consent.

### Effort vs Impact
Medium / high. Direct retention metric impact.

---

## 16. Track "first friend" as an activation milestone

**Labels:** `idea`, `analytics`, `social`
**Priority:** Low
**State:** Triage

### Finding
`analytics_events.dart` records `firstFriend` (line 171) as a milestone, but the funnel events surrounding social bootstrapping are sparse — there's no `friendInviteSent`, `friendInviteAccepted`, or social-onboarding-step-by-step instrumentation. Drop-off in the social funnel is invisible.

### Proposed Improvement
Add: `socialOnboardingStarted`, `friendSearchPerformed`, `friendInviteSent`, `firstFriendRequestSent`. Hook into existing trackers.

### Effort vs Impact
Small / medium.

---

## 17. Obtain analytics consent before any analytics events fire

**Labels:** `bug`, `analytics`, `account`
**Priority:** High
**State:** Triage

### Finding
`lib/viewmodels/onboarding_viewmodel.dart:108` calls `analyticsService.logEvent('onboardingStarted')` at the very start of onboarding. At that point, the user has not yet been shown the consent UI in `consent_management_view.dart`. GDPR Art. 7 requires explicit, informed consent **before** analytics data collection.

### Proposed Improvement
Either:
- (a) Defer all non-essential analytics until after the consent step in onboarding.
- (b) Add a pre-signup consent screen (cookie/analytics disclosure) before any logging.

Essential / safety events (crash reporting, security audit) can fire without consent under "legitimate interest" — but funnel/marketing analytics cannot.

### Effort vs Impact
Medium / high. Reduces GDPR exposure.

---

## 18. Improve under-15 age-gate UX

**Labels:** `idea`, `account`
**Priority:** Low
**State:** Triage

### Finding
`lib/views/onboarding/onboarding_view.dart:78-79` redirects under-15 users to `OnboardingAgeGateBlockedView` with a forced sign-out. No "ask a parent to set up an account for you", no "come back when you're 15", no parent-mediated path.

### Proposed Improvement
On the blocked view:
- "I'll come back when I'm older" — clear, supportive copy + sign-out.
- "A parent can sign up for you" — opens an info page or pre-fills a parent-consent flow.

### Effort vs Impact
Small / low. Mostly a copy + flow improvement.

---

# Theme 3 — Edge-case content robustness

## 19. Use `ListView.builder` for ingredients and instructions in recipe detail

**Labels:** `performance`, `recipe`
**Priority:** Medium
**State:** Triage

### Finding
`lib/views/recipe_detail/recipe_detail_content.dart:172-250+` — ingredients and instructions render via `.asMap().entries.map()` into a `Column`, so all N items materialise on first build. A 100-ingredient + 50-step recipe (rare but real for elaborate baking) drops frames on lower-end Android. Shopping list already uses `ListView.builder` correctly (`shopping_list_content.dart:284`).

### Proposed Improvement
- Either wrap each section in a `ListView.builder(shrinkWrap: true, physics: NeverScrollableScrollPhysics(), itemCount: ...)`,
- Or refactor the detail view into a single `CustomScrollView` with `SliverList`s for ingredients and instructions.

The Sliver approach is best for performance; the shrinkWrap path is the smallest diff.

### Effort vs Impact
Small (shrinkWrap) / Medium (sliver refactor) / medium.

---

## 20. Cap or paginate `sharedWithUserIds` array

**Labels:** `bug`, `recipe`, `social`
**Priority:** Medium
**State:** Triage

### Finding
Recipe model carries `sharedWithUserIds` as a top-level array. No code-level upper bound. Firestore document size limit is 1MB; at ~36 bytes per UUID, the limit is reached at ~27 000 shares. Realistically not reached today, but the lack of any guard means a future viral-recipe feature could brick documents.

### Proposed Improvement
- Add a code-level cap (e.g. 200 shares per recipe) with a clear error message.
- For higher-scale needs, move shares to a subcollection (`recipes/{id}/shares/{uid}`) with cursor pagination. Defer subcollection migration until needed.

### Effort vs Impact
Small (cap) / Large (subcollection) / medium.

---

## 21. Validate ingredient quantities are non-negative

**Labels:** `bug`, `parsing`, `recipe`
**Priority:** Medium
**State:** Triage

### Finding
`lib/utils/text/ingredient_parser.dart` extracts ingredient quantity as `double` with no sign validation. Form validators (`lib/core/validators/form_validators.dart:163-165`) check recipe portions (1–100) but not per-ingredient quantities. Importing or manually entering "-2 cups flour" or "0 g salt" produces unhinged content.

### Proposed Improvement
- Parser: clamp negative parses to 0 with a warning log, or surface a parse-error per ingredient.
- Validator: require `quantity > 0` for ingredients with a quantity field (passes for "to taste" / "a pinch" which have no numeric quantity).
- Editor: per-ingredient validation message on save.

### Effort vs Impact
Small / medium.

---

## 22. Linkify URLs in recipe comments

**Labels:** `idea`, `social`, `recipe`
**Priority:** Low
**State:** Triage

### Finding
`lib/widgets/recipe/comment_item_widgets.dart:35` — comment renders as plain `Text()`. URLs are not clickable. Users posting "Try this technique: https://serious-eats..." get unclickable text. Plain-text rendering is safe (no XSS risk) but a UX miss.

### Proposed Improvement
Use a `RichText` or the `flutter_linkify` package (or implement a small regex-based linkifier). Linkify HTTP/HTTPS URLs; leave everything else plain. Tap → external browser.

### Effort vs Impact
Small / low.

---

## 23. Server-side timestamp validation for cook snaps

**Labels:** `bug`, `social`, `backend`
**Priority:** Low
**State:** Triage

### Finding
Cook-snap timestamps use `clock.now()` on the client. A user with skewed device clock (or malicious manipulation) can backdate or forward-date snaps. Firestore writes accept whatever the client provides.

### Proposed Improvement
Set the timestamp server-side using `FieldValue.serverTimestamp()` for new snaps. If the client needs an optimistic timestamp before commit, write both fields and prefer the server one on read.

### Effort vs Impact
Trivial / low. Touches the cook-snap create path only.

---

# Theme 4 — Code quality

## 24. Replace Map-based data access in account_deletion modules with typed models

**Labels:** `tech-debt`, `account`, `backend`
**Priority:** Low
**State:** Triage

### Finding
Two files violate the "no Map-based data access in business logic" rule:
- `lib/services/account/account_deletion/content_deletion_operations.dart:170,244-265,384-396` — reads shopping items and group menu participants via `data()['fieldName']`.
- `lib/services/account/account_deletion_service.dart:153,156,225-230,237-238,250-254,265-268,320-321,333-338` — passes status around as `Map<String, dynamic>` instead of a typed result.

Other repositories all use typed models — this is a localised inconsistency in the GDPR-cascade infrastructure.

### Proposed Improvement
- Introduce `GdprDeletionResult` (typed status), `UnifiedShoppingItem` and `GroupMenuParticipant` models.
- Refactor the two files to use them.

### Effort vs Impact
Small / low. Code-quality consistency; not blocking. The GDPR cascade is critical, so changes should ship with strong tests (see #25).

---

## 25. Add test coverage to the largest untested services and viewmodels

**Labels:** `test-gap`, `recipe`, `social`, `account`
**Priority:** Medium
**State:** Triage

### Finding
Top 10 largest service / viewmodel files have **zero tests**:

| File | Lines |
|---|---|
| `lib/viewmodels/recipe_image_manager.dart` | 1,247 |
| `lib/services/messaging_service.dart` | 880 |
| `lib/viewmodels/recipe_list_viewmodel.dart` | 878 |
| `lib/services/ocr_extraction_service.dart` | 838 |
| `lib/viewmodels/recipe_form_state.dart` | 763 |
| `lib/viewmodels/personal_tag_viewmodel.dart` | 762 |
| `lib/viewmodels/photo_import_viewmodel.dart` | 703 |
| `lib/services/user_service.dart` | 646 |
| `lib/services/analytics_service.dart` | 583 |
| `lib/services/share_service.dart` | 556 |

These are the highest-blast-radius files in the codebase. Any one of them breaking silently is a major outage.

### Proposed Improvement
Add a test per file, focused on the **intended behavior contract** per CLAUDE.md's testing philosophy (not getter coverage). Prioritise:
1. `recipe_image_manager.dart` — image upload + heirloom orphan path (relates to robustness-batch #18).
2. `ocr_extraction_service.dart` — multi-provider fallback + caching invariants.
3. `messaging_service.dart` — message delivery + conversation creation.
4. `recipe_list_viewmodel.dart` — filter/sort behaviour (related to robustness-batch #7).
5. `share_service.dart` — multi-target share semantics.

Then continue down the list.

### Effort vs Impact
Large (cumulative) / very high. Each test prevents regression on a high-traffic surface.

---

## 26. Resolve or date-cap BUT-427-ops cert fingerprint placeholders

**Labels:** `tech-debt`, `security`, `backend`
**Priority:** Low
**State:** Triage

### Finding
`lib/services/security/cert_pin_config.dart:41-71` carries 9 `TODO(BUT-427-ops)` placeholders for cert fingerprints. ~7 months old per `git blame`. Intentionally an ops task per the comments, but stale TODOs without a date or owner drift.

### Proposed Improvement
- Either populate the fingerprints (probably an ops follow-up — coordinate with whoever owns BUT-427).
- Or annotate each TODO with a target date (`TODO(BUT-427-ops, by 2026-Q3)`) so it's not invisible.

### Effort vs Impact
Trivial / low. Hygiene.

---

# Theme 5 — Localisation

Localisation audit verdict: **production-ready for Swedish/English**. ARB key parity is perfect (4 660 keys each, zero diff), plurals are compliant across 28+ rules, date/time formatting passes locale correctly, decimal separator handling tolerates both `,` and `.`, unit conversion handles US→Swedish at import, language switcher is discoverable. Two minor follow-ups below.

## 27. Pass user locale to LLM Cloud Functions

**Labels:** `idea`, `import`, `parsing`, `backend`
**Priority:** Low
**State:** Triage

### Finding
`lib/services/llm/llm_service.dart` and `llm_models.dart` import `AppLocale` but don't include the user's locale in calls to `structureRecipe` / extraction functions. OCR hints are also hardcoded — `lib/services/ocr_extraction_service.dart:412,438,501,525,551` pass `'eng'`, `'swe+eng'`, `['sv', 'en']`. A user on English locale importing a Swedish-source recipe gets unpredictable output language, with no way to nudge the model toward their UI locale.

### Proposed Improvement
- Plumb `AppLocale.current.localeName` (or `Localizations.localeOf(context)`) through to the LLM call payloads.
- In the Cloud Function prompt, add: "Respond in <locale>. Preserve original ingredient/dish names where culturally meaningful."
- For OCR, derive the language hint dynamically from user locale instead of hardcoding.

### Effort vs Impact
Small / low. Low-frequency friction today; gets bigger if/when the app expands beyond Swedish-primary users.

---

## 28. Apply locale-aware currency formatting on shopping-item prices

**Labels:** `idea`, `shopping`
**Priority:** Low
**State:** Triage

### Finding
`lib/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart:114` captures a `_priceController` as a plain `double` with no currency symbol or `NumberFormat`. If displayed to the user, Swedish-locale would expect "7,50 kr" while English-locale would expect "7.50 SEK" or "$7.50" — none of which currently happens. Low impact if prices stay internal metadata, but the entry path has no parsing for the comma decimal either, so a Swedish user typing "7,50" probably gets a parse error.

### Proposed Improvement
- Use `NumberFormat.simpleCurrency(locale: localeName)` for display.
- Parse on input via `NumberFormat.decimalPattern(localeName).parse(...)` so commas-vs-dots resolve per locale.
- Decide on a default currency (`SEK`?) and let it be overridden per item.

### Effort vs Impact
Small / low. Defensive — prevents a class of bugs that would land the moment prices become user-visible.

---

## Reference index

| # | Title | Theme | Labels | Priority |
|---|---|---|---|---|
| 1 | Semantic labels on loading indicators | A11y | bug, settings | Medium |
| 2 | labelText not hintText on form fields | A11y | bug, recipe, account | Medium |
| 3 | Cooking-mode title respects textScaleFactor | A11y | bug, recipe | Low |
| 4 | Audit modal focus-return | A11y | idea, settings | Medium |
| 5 | Online-status non-colour signal | A11y | bug, social | Low |
| 6 | Announce state changes via SemanticsService | A11y | idea, recipe, social, shopping | Medium |
| 7 | Semantic labels on avatars | A11y | bug, social | Low |
| 8 | Sign-out / Delete-account in Settings UI | Onboarding | bug, account | High |
| 9 | Social sign-in (OAuth) | Onboarding | idea, account | Medium |
| 10 | Guest / demo mode | Onboarding | idea, account | Medium |
| 11 | Re-launch onboarding from Settings | Onboarding | idea, account, settings | Medium |
| 12 | Make recipe seeding synchronous / surfaced | Onboarding | bug, account, recipe | High |
| 13 | "What's new" / changelog surface | Onboarding | idea, settings | Low |
| 14 | Seed sample menus & shopping lists | Onboarding | idea, account, menu, shopping | Medium |
| 15 | Lapsed-user re-engagement notifications | Onboarding | idea, social, analytics | Medium |
| 16 | Track "first friend" as activation milestone | Onboarding | idea, analytics, social | Low |
| 17 | Pre-consent gate on analytics events | Onboarding | bug, analytics, account | High |
| 18 | Improve under-15 age-gate UX | Onboarding | idea, account | Low |
| 19 | ListView.builder for ingredients/instructions | Edge-case | performance, recipe | Medium |
| 20 | Cap or paginate sharedWithUserIds | Edge-case | bug, recipe, social | Medium |
| 21 | Validate non-negative ingredient quantities | Edge-case | bug, parsing, recipe | Medium |
| 22 | Linkify URLs in comments | Edge-case | idea, social, recipe | Low |
| 23 | Server-side timestamp on cook snaps | Edge-case | bug, social, backend | Low |
| 24 | Typed models in account_deletion modules | Code quality | tech-debt, account, backend | Low |
| 25 | Test coverage for largest untested services/VMs | Code quality | test-gap, recipe, social, account | Medium |
| 26 | Resolve/date-cap BUT-427-ops cert TODOs | Code quality | tech-debt, security, backend | Low |
| 27 | Pass user locale to LLM Cloud Functions | Localisation | idea, import, parsing, backend | Low |
| 28 | Locale-aware currency formatting on prices | Localisation | idea, shopping | Low |

---

## What's confirmed clean (audit notes — not gaps)

The hygiene side of the codebase is in good shape against its own rules:

- **No new large-file violations** beyond `docs/architecture/ACCEPTED_LARGE_FILES.md` — count moved 135 → 137, all churn within the accepted set.
- **Zero direct `FirebaseFirestore.instance`** usage outside `lib/repositories/firebase/`, `lib/core/bootstrap/`, and one approved infra path.
- **Zero `.withOpacity(` references** — migration to `withValues(alpha:)` is complete.
- **`PermissionValidationMixin`** present on every user-scoped Firebase repository; absences are all intentional (parsing-correction analytics, infra repos, read-only config, noop/Algolia integrations).
- **Zero forbidden data-source mixing** (`permissionService.currentUserProfile` doesn't exist; `userService.currentUserId` used only in valid contexts).
- **Zero non-English comments**, zero section dividers, zero doc-comments on private methods.
- **Dependencies are healthy** — outdated picks are intentionally pinned with documented rationale (BUT-793, BUT-750).
- **Touch targets compliant** — `TappableWrapper` enforces 48dp throughout.
- **Theming compliant** — no hardcoded `Color(0x...)` literals found; all colour access goes through `ColorScheme` or `butleryColors`.
- **Dismissible / swipe gestures all have `customSemanticsActions` fallbacks** for switch-control / voice-control users.
- **Localisation is production-ready** — ARB key parity is exact (4 660 keys each, zero diff between `app_sv.arb` and `app_en.arb`), plural handling uses ICU syntax across 28+ entries (no concatenation-based plurals), `DateFormat` calls pass `localeName` everywhere checked, decimal-separator regex accepts both `,` and `.`, unit conversion runs at import (US→Swedish), language switcher in `settings_hub_view.dart:67` is discoverable.
- **Maintenance-mode blocker hardcoded Swedish** (`lib/widgets/maintenance_mode_blocker.dart:63,88`) is intentional — copy comes from Remote Config but the failsafe title/button must work even if `AppLocalizations` fails to initialise. Documented at lines 5-7.

---

## Cross-batch dependency notes

- **#8 (Sign-out / Delete-account UI)** is the most user-impactful gap in this batch. GDPR compliance + immediate support-cost reduction. Should be sequenced ahead of less critical items.
- **#17 (pre-consent analytics)** has overlapping concerns with transparency-batch #7 (analytics event list under consent) — fix them together.
- **#19 (ListView.builder for ingredients)** is independent but a strong candidate to bundle with **#25 (test coverage)** — the same recipe-detail surface needs both rendering improvements and test gating.
- **#14 (sample menu/shopping seed)** unlocks the demo of uxgap-batch #7 (menu→shopping aggregation) on first launch.
- **#12 (sync seeding)** and **#10 (guest mode)** both touch the first-launch flow — consider sequencing them as a single onboarding refresh.
