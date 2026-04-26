# firebase-backend-security — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it as Step 0 of every security/backend task and **APPEND** to it when
it discovers a new pattern, settles a GDPR question, or is corrected by the
user.

## How to update this file

- **Append-only** — never delete entries; supersede with a newer dated entry.
- **Date every entry** — `### YYYY-MM-DD — short title`.
- **One concept per entry** — easier to supersede later.

---

## Repository layer contract

**Every repository in `lib/repositories/` MUST use `PermissionValidationMixin`.**
This is non-negotiable — it's CLAUDE.md rule #3 and the foundation of the
authorization story. If you find a repository that doesn't use it, that is
a Critical-severity finding.

**Service access**: code uses `ServiceLocator.get<T>()` (in widgets/VMs) or
constructor injection (in DI modules). Never `FirebaseFirestore.instance`
directly — inject `FirestoreRepository`.

**DI registration**: `FirebaseRecipeRepository` is registered as the
`RecipeRepository` interface. Use the interface for `ServiceLocator.get`.

## Data-source rules (CLAUDE.md)

| Need | Use |
|---|---|
| Complete user data (settings, avatar, social) | `userService.currentUserProfile` |
| Auth/permission checks only | `permissionService.currentUserId` |

Never mix these — the bug pattern is "settings don't persist" because the
write went through the auth-only handle and the cache wasn't refreshed.

## Firestore rules pairing

`firestore.rules` (~72KB) MUST match repository permissions. When repository
code adds/removes a permission check, the matching rule branch must change
in lockstep. If they drift, either the rule is too permissive (security
hole) or the rule is too strict (rules-reject breaks the app).

The `firestore-rules-tester` agent owns proving rule behavior. Hand off to
it after rule changes — don't write rules tests yourself.

## Cost principles (CLAUDE.md)

- Avoid unnecessary Firebase reads/writes.
- Batch operations (Firestore batch limit: **500 ops per batch**;
  consolidated updates = 1 op per doc).
- Cache aggressively; use efficient queries with indexes.
- Prefer deterministic logic over LLM calls. LLMs only when truly needed
  (free-text, creative generation).

## GDPR compliance baseline

Required for every user-data-touching feature:

- [ ] User consent before data collection
- [ ] Data minimization (only what's needed)
- [ ] Right to access (user can retrieve their data)
- [ ] Right to deletion (cascading where the data lives in subtrees)
- [ ] Right to rectification (user can update)
- [ ] Data portability (export functionality)
- [ ] Privacy policy linked from any consent surface

Critical finding if any of these is missing for a new user-data feature.

## Security best practices

- Input validation and sanitization on every write boundary.
- Error handling must NOT leak sensitive data (no raw Firestore error
  messages to the user).
- Audit logging for security-critical operations (rule grants, role
  changes, deletions).
- No exposed API keys or credentials — `.env` is gitignored; check
  `.env.example` matches the shape but contains no secrets.
- HTTPS-only, encryption at rest where applicable.

## Performance & query optimization

- Compound queries require composite indexes — confirm in
  `firestore.indexes.json` before merging.
- `where()` clauses: indexed fields first.
- Always `limit()` results that could grow large.
- No "read entire collection" queries on user-facing paths.
- Use subcollections for scalable per-user data.

## Real-time listener hygiene

- StreamBuilder/StreamProvider patterns; never raw `onSnapshot` in widgets.
- Listeners attached in `initState`/ViewModel `init`.
- Listeners disposed in `dispose()` — leak finder catches violations.
- Stream errors handled (don't let an unhandled stream crash the UI).

## Severity tagging for findings

- **Critical** — security vulnerability, GDPR violation, data-loss risk,
  memory leak.
- **High** — missing permission check, missing index for a deployed query,
  performance issue at scale.
- **Medium** — optimization opportunity, incomplete validation.
- **Low** — code organization, documentation.

Always include specific code examples and remediation steps.

---

## Discovered patterns

*Append new dated entries below as the agent learns them.*

### 2026-04-25 — initial seed
Knowledge file seeded from CLAUDE.md (rules #3, data-source enforcer, cost
principles), the existing agent description, and `MEMORY.md` gotchas
(Firestore batch limit). Future entries should record genuinely new
permission patterns, GDPR decisions, query patterns, or surprising
Firestore/Firebase behavior — not re-derivations of what's already here.

### 2026-04-25 — iOS PrivacyInfo.xcprivacy required-reason codes (BUT-587/596/603)
Apple required-reason API codes that map to Butlery's actual SDK usage:

- **FileTimestamp**: `C617.1` = display timestamps to the user (image_picker
  EXIF for recipe photo). `3B52.1` = read mtimes for app-internal cache
  eviction (cached_network_image, flutter_image_compress, sqlcipher).
- **UserDefaults**: `CA92.1` covers freerasp internal state + flutter_inappwebview
  cookie/session store (worst-case fallback even if pods ship own manifest).
- **DiskSpace**: `E174.1` = optimise size of user-generated files (Firestore
  LRU GC, Crashlytics). `85F4.1` = display to user (we don't do that).
- **SystemBootTime**: `35F9.1` = telemetry timing (Firebase Performance,
  Analytics session timing). All on-device until consent.

Decision rule: declare at app level **defensively** even when the linked
pod ships its own bundled manifest, because Apple's auto-merge produces a
combined report that's clearer if the app-level declarations enumerate
the reason explicitly. NEVER declare a reason that has no genuine usage —
false declarations are themselves an Apple review risk.

`NSPrivacyCollectedDataTypeUserID` for Firebase Auth UID: `Linked=true`
(it IS the user's identity), `Tracking=false` (not used cross-app),
purpose `AppFunctionality` only. Never list under `Analytics` purpose
even though analytics events include the UID — Apple separates "data
collected" from "purpose of collection".

CocoaPods on Windows: `ios/Pods/` and `ios/Podfile.lock` are macOS-only
artefacts. Audit docs must use `pubspec.yaml` versions and mark every
"can't verify locally" pod as UNVERIFIED_LOCAL with app-level fallback
coverage, then enforce verification on the macOS CI runner.

### 2026-04-25 — store-submission rating defense triad (BUT-624/590/416)
The **UGC + messaging + 24-h moderation SLA** triad is what keeps Butlery
at Apple 12+ / Play Teen instead of 17+/Mature. If any of the three
weakens, the rating must move up or the app gets rejected:

- **UGC surfaces** (recipes / comments / ratings / group messages /
  friend pings) — every one needs a report entry-point that lands in
  `reports/` and surfaces in `Settings → Granska rapporter` for admins.
- **Messaging** — confined to friend-graph + group membership. Opening
  DM to non-friends would push Apple to 17+ (see
  `docs/ops/age-rating-runbook.md` §5.11 re-submission triggers).
- **24-h moderation SLA** — `docs/ops/moderation-runbook.md` is the
  written defense Apple Guideline 1.2 + Play UGC policy require.

Practical implication for this agent: when reviewing changes that touch
report/block/moderation rules or that introduce a new UGC surface,
flag any of these as Critical:
- Removing a report entry-point.
- Opening DM to non-friends.
- Lowering or silencing the report → admin notification path.
- Removing the age gate (`birthYear ≤ 2013`) at sign-up.
- Adding location data to user-to-user surfaces (presence is currently
  online/offline only — pure presence; no geo).

These also force a re-fill of both store age-rating questionnaires
(see `docs/ops/age-rating-runbook.md` §5.11 + §6).

### 2026-04-26 — ReportContentDialog uses STRING contentType, not an enum (BUT-511)
The reusable `ReportContentDialog.show(...)` API takes `contentType: String`,
not an enum. The two `enum ContentType` definitions in the codebase
(`lib/services/content_detector_service.dart`,
`lib/viewmodels/shared_content/shared_content_search_viewmodel.dart`) are
**unrelated** to reports. Don't try to "wire ContentType.group through" — it
doesn't exist as an enum and shouldn't be added.

Allowed string values are documented in the comment on
`ContentReport.contentType` (`lib/models/social/content_report.dart`):
`'recipe' | 'comment' | 'message' | 'profile' | 'shopping_list' |
'cook_snap' | 'rating' | 'group'`. New values just need to be appended to
that comment list AND handled in `ReportService._resolveContentRef` if
admins should be able to delete the content from the moderator UI. Without
a `_resolveContentRef` case, admins can still close/dismiss the report —
they just can't delete the underlying content.

Firestore rules `match /reports/{reportId}` does NOT whitelist
`contentType` values — any string passes the create rule. The
content-side delete rule is what matters: the target collection's rule
block must have `allow delete: if isAdmin();` for moderation to work.

For `'group'` (BUT-511), the content lives at
`users/{ownerId}/friend_categories/{categoryId}` — same shape as
`'recipe'`. So the `_resolveContentRef` case needs `report.contentOwnerId`
(group ownerId) AND `report.contentId` (categoryId), and the
`friend_categories` rule needed an `allow read, delete: if isAdmin();`
moderation override added (it didn't have one). Pre-existing partial
coverage to flag for follow-up: `'profile'`, `'cook_snap'`, and
`'shopping_list'` content types also lack admin-delete rule branches —
admins can close those reports but not delete the content.

UI placement rule: never show "Report" to the content owner reporting
themselves. For groups: hide if `currentUserId == group.ownerId`. For
member tiles: hide if `member.uid == currentUserId`. Mirrors
`friend_profile_view.dart` pattern.

### 2026-04-26 — ContentFilterService.ensureClean is the pre-publish UGC gate (BUT-517)
`lib/services/moderation/content_filter_service.dart` is the canonical
client-side trust-and-safety gate for every UGC text surface. Use the new
`ensureClean(text, fieldName: …) -> ContentFilterResult` API. The legacy
`containsProfanity()` boolean stays as a non-blocking warning surface for
chat compose + comment compose (`chat_viewmodel.dart:92`,
`social_comments_manager.dart:57`); do NOT delete it.

Wiring rules (BUT-517 enforced this baseline):

- **TextFormField surfaces**: compose `FormValidators.contentFilter(fieldName)`
  into the existing `FormValidators.combine([...])` chain. The validator
  returns `null` when ContentFilterService isn't registered (narrow widget
  tests), so adding it doesn't break unrelated tests.
- **`DialogFormFields.buildTextFormField` (lib/widgets/common/dialogs)**
  bakes the gate into its default validator chain → every dialog
  name/description field (group create, shopping list, menu save, etc.)
  inherits the gate for free. Don't re-add it on top.
- **Service-level gates** (cook_snap_service, etc.): call `ensureClean`
  and throw `Exception(result.reason!)`. Don't bypass with raw
  `containsProfanity` or you lose the localized message string.
- **FormFieldsManager validators** (recipe_form_state ingredients +
  instructions): use a private `_ensureClean(value, fieldName: …)` wrapper
  that does `ServiceLocator.tryGet<ContentFilterService>()` so dynamic
  list rows get the gate too. The static FormValidators path doesn't
  reach FormFieldsManager because that manager owns its own validator.

Localization: re-use `contentFilterWarning` already in `app_en.arb` +
`app_sv.arb`. Never invent a per-field rejection message — Apple/Play
review reads the same string everywhere and a generic warning works in
both inline `errorText` and SnackBar without leaking the field name.

`ContentFilterResult.fieldName` is preserved for telemetry only — the
user-facing `reason` deliberately omits it. The test
`test/unit/services/moderation/content_filter_service_test.dart`
documents this contract; if a future agent makes the rejection message
field-specific, that test will fail with a clear "UI-safe" reason.

### 2026-04-25 — reviewer demo seeding pattern (BUT-416)
Apple/Play reviewers reject empty-state social apps as "unable to
evaluate functionality" (Apple Guideline 2.1 / Play UGC compliance).
Butlery's seed contract is in `docs/ops/app-review-demo.md`:

- Two reviewer accounts (`reviewer-apple@butlery.app`,
  `reviewer-google@butlery.app`) — credentials rotated per submission.
- Two seeded "friend" accounts (`demo-friend-1@…`, `demo-friend-2@…`)
  with pre-accepted friend relationships.
- One Demo Family group with shared weekly menu.
- 3 sample comments, 1 rating, 1 sample report (benign reason — spam
  duplicate) so reviewer can verify the flow without producing
  offensive content.

The reviewer-demo seeding script does not yet exist
(`functions/src/admin/seed-reviewer-data.ts`); the founder runs the
checklist by hand for now. Future agents adding reviewer-related
infra: respect the **temporary admin grant must be revoked within 7
days** rule (admins can hard-delete content; leaked admin = data
loss vector).
