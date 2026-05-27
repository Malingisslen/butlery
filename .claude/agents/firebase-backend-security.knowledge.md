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

### 2026-04-26 — admin-delete rules tracking vs. ReportService coverage (BUT-728)

`ReportContentDialog` accepts these contentType strings (per
`ContentReport` model comment): `'recipe' | 'comment' | 'message' |
'profile' | 'shopping_list' | 'cook_snap' | 'rating' | 'group'`.

Admin-delete works only when **two** things are true:
1. `ReportService._resolveContentRef` has a case for the contentType
   (otherwise `deleteReportedContent` returns false with "Unknown
   contentType" warning).
2. The Firestore rule block for that path has `allow read, delete:
   if isAdmin();` (otherwise the delete returns permission-denied).

Coverage matrix as of 2026-04-26:

| contentType      | `_resolveContentRef` | rule block exists | admin override |
|------------------|----------------------|-------------------|----------------|
| `recipe`         | yes                  | yes (line 204)    | yes (line 233) |
| `comment`        | yes                  | yes (line 862)    | yes (line 899) |
| `message`        | yes                  | yes (line 959)    | yes (line 983) |
| `rating`         | yes                  | yes (line 1126)   | yes (line 1151)|
| `group`          | yes                  | yes (line 288)    | yes (line 322) |
| `cook_snap`      | yes (line 205)       | **NO RULE BLOCK** | n/a — entire `cook_snaps` collection is default-denied |
| `profile`        | **MISSING**          | yes (line 420)    | n/a            |
| `shopping_list`  | **MISSING**          | yes (lines 237, 1002) | n/a        |

**Gap to fix BEFORE adding admin-delete rules:**

- `cook_snaps`: needs a full rule block (owner read/write, plus
  admin read+delete moderation override). The collection IS used
  (`firebase_cook_snap_repository.dart`) so the absence of any rule
  is a Critical-severity bug — current writes must be failing or
  bypassed via Cloud Functions admin SDK. Investigate before
  patching rules-only.
- `profile`: `_resolveContentRef` needs a case mapping to the
  `public_profiles/{userId}` doc (NOT the `users/{userId}` private
  doc — moderation should not nuke private settings/consent).
  `public_profiles` already has `allow delete: if isOwner(userId);`
  on line 455 — needs `|| isAdmin()` extension OR a separate
  admin-override allow line.
- `shopping_list`: `_resolveContentRef` needs to disambiguate
  between `users/{ownerId}/unified_shopping_lists/{listId}` (private)
  and `unified_shared_shopping_lists/{listId}` (shared). Reports
  flow likely targets the shared list (only shared lists are visible
  to others to be reportable in the first place). Then add admin
  override to whichever rule block.

**Lesson: don't add admin-delete rules for paths that
`_resolveContentRef` can't resolve.** A rule without the resolver
is dead code; a resolver without the rule is a permission-denied
crash for the moderator. They MUST land together. The pre-existing
"already partial coverage to flag for follow-up" note in the
2026-04-26 BUT-511 entry above slightly overstates current coverage
— `profile` and `shopping_list` lack BOTH halves, not just rules.

### 2026-04-26 — BUT-728 closes the moderation coverage matrix; cook_snaps prod gap fixed

Resolved the gaps flagged in the BUT-728 entry above. New coverage:

| contentType      | `_resolveContentRef`         | rule block + admin override |
|------------------|------------------------------|------------------------------|
| `profile`        | added (public_profiles/{uid})| public_profiles delete admin override added (line ~459) |
| `shopping_list`  | added (unified_shared_…)     | unified_shared_shopping_lists `allow read, delete: if isAdmin();` (line ~1041) |
| `cook_snap`      | already present              | **NEW full rule block added** (lines ~1166-1208) — was missing entirely |

**Cook_snap prod gap (Critical) — root cause:** the `cook_snaps`
top-level collection is written directly by `firebase_cook_snap_repository.dart`
via `BaseFirebaseRepository.create()` → `collection.doc(id).set(...)`.
There is NO Cloud Function intermediary (verified: zero matches for
`cook_snap` in `functions/src`). With no `match /cook_snaps/{id}`
block, the default-deny `match /{document=**}` at end of rules was
catching every write. Either cook-snap creation has been silently
failing in production, or the bug existed only in client paths that
were never exercised. Either way, the new block uses set()-style
update permission (full doc rewrite is the repo's actual behavior),
not field-diff style.

**Pattern for collections written via `BaseFirebaseRepository`:**
- `create` rule: check `request.auth.uid == request.resource.data.userId`
  and `hasRequiredFields([…])` matching the model's `toFirestore()`.
- `update` rule: check BOTH `resource.data.userId` AND
  `request.resource.data.userId` against `request.auth.uid` — because
  base repo overwrites the whole doc via `set()`, both sides are
  populated, and pinning both blocks userId-switch attacks even though
  the update is a full rewrite.
- `delete` rule: `request.auth.uid == resource.data.userId`.
- Required-fields list: only include fields that the model's
  `toFirestore()` always emits (skip nullable optionals — for
  CookSnap that means `userAvatarUrl`, `thumbnailUrl`, `caption`).

**Caption length validation in rules** (CookSnap.maxCaptionLength=200):
mirrored in the rule via `request.resource.data.get('caption', '').size() <= 200`
with a null-tolerant guard. The model's `_sanitizeCaption` clamps to
200 already; the rule enforces server-side defense in depth against
clients that bypass the model.

**Profile reports correctly target `public_profiles/{uid}`, NOT
`users/{uid}`.** The private `users/{uid}` root holds settings,
consent records, and rate_limit subcollections — moderator-deletion
of that doc would orphan or destroy GDPR-relevant private data. The
public_profiles mirror is the right surface: it's what other users
actually see, and the rule already had owner-delete (now augmented
with admin-delete).

**Shopping-list reports correctly target only
`unified_shared_shopping_lists`, NOT `users/{uid}/unified_shopping_lists`.**
Private user-scoped lists are never visible to other users — they
literally cannot be reported in the first place. The resolver
disambiguates by being shared-only.

**Hand-off note:** the rules-tester agent should add coverage for:
1. cook_snap owner CRUD happy path + admin delete
2. cook_snap userId-switch attack on update rejected
3. public_profile admin delete works without owner consent
4. unified_shared_shopping_list admin read+delete works for non-member admin

### 2026-04-26 — Presence backends differ: Firestore needs TTL, RTDB self-clears (BUT-477)

The three "presence" surfaces in Butlery are split across two backends, and
they need very different cleanup strategies:

| Surface | Backend | Path | Cleanup mechanism |
|---|---|---|---|
| Recipe presence | **Firestore** | `recipePresence/{recipeId}/activeUsers/{userId}` | per-doc `expiresAt` + TTL policy |
| Shopping presence | **Firestore** | `shoppingPresence/{listId}/activeUsers/{userId}` | per-doc `expiresAt` + TTL policy |
| Cooking session | **RTDB** | `cooking_sessions/{groupId}/{userId}` | `onDisconnect().remove()` (already self-clears in seconds) |

The naming `recipe_presence` / `shopping_presence` (snake_case) in Linear /
docs is a slight misnomer — the actual collection-name constants in
`firestore_collections.dart` are camelCase (`recipePresence`,
`shoppingPresence`). The subcollection name `activeUsers` is the
collection-group target for any cross-list query.

**Pattern for client-side TTL:**

- Add `expiresAt: Timestamp` field to every write (`set` / `update` /
  heartbeat). Compute as `Timestamp.fromDate(now + 60s)` — using
  `serverTimestamp()` would force a second read to compare in client
  filters.
- Refresh cadence is **half the TTL window** (30s for a 60s TTL) so a
  single missed heartbeat does not flicker the indicator.
- On `markUserInactive`, set `expiresAt = now` to force immediate
  eviction (don't wait for the sweeper).
- Client read paths filter `expiresAt < now` in-memory — Firestore
  composite index on `(isActive, expiresAt)` would be needed to put
  this in the `where()` clause, and the row-count is small enough
  that in-memory filtering is fine.
- Legacy rows (no `expiresAt` field) optimistically pass the filter —
  the server-side TTL sweeper catches them; surfacing a stale user is
  the lesser harm vs. dropping a real one because of missing data.

**TTL policy is NOT in `firestore.indexes.json`.** The `firebase deploy
--only firestore:indexes` flow does not configure TTL — that's a separate
admin API. Two options:

1. `gcloud firestore fields ttls update <field> --collection-group=<col>
   --enable-ttl --project=<id>` (one-time, document in a runbook).
2. Firebase Console → Firestore → TTL tab → Add policy.

I created `docs/ops/presence-ttl-runbook.md` documenting the gcloud
command. TTL deletes are free of read quota but DO count against delete
quota at standard pricing. First sweeper run can take up to 24 h after
activation.

**GDPR cascade on presence:** presence rows contain `userId`,
`displayName`, and `avatarUrl` — all linked PII. Right-to-Erasure
cannot wait for the 60s TTL sweeper. Add to
`functions/src/cleanup/on-user-deleted.ts`:

```ts
const snapshot = await db
  .collectionGroup("activeUsers")
  .where("userId", "==", userId)
  .get();
// batch.delete each doc, BATCH_LIMIT=500 chunking
```

Requires a collection-group index on `activeUsers.userId` in
`firestore.indexes.json` (added). The `collectionGroup('activeUsers')`
sweep covers BOTH presence surfaces in one query because they share
the same subcollection name.

**RTDB cooking_session does NOT need cascade work.** It already
self-clears via `onDisconnect().remove()` (see
`firebase_cooking_session_repository.dart`). Account deletion implies
the device is no longer connected, so RTDB has cleared the row by
the time `onUserDeleted` fires. The repository's docstring is
explicit: "no account-deletion cascade needed — stale rows
self-clear within seconds of the user going offline."

**Test pattern for the cascade:** `functions/src/__tests__/presence-cascade.test.ts`
implements a minimal in-memory `FakeFirestore` stub supporting only
`collectionGroup → where(==) → get` and `batch → delete → commit`. No
emulator needed. The stub scans path strings and matches the second-to-
last segment against the collection-group name. This pattern (no
emulator, narrow stub) is preferred over `@firebase/rules-unit-testing`
for pure data-manipulation logic — emulator-based tests are reserved
for actual rule enforcement. Module-level `admin.firestore()` calls
require `admin.initializeApp({ projectId: ... })` early in the test
setup, otherwise import-time `app/no-app` errors fire before any test
code runs.

**Test seam pattern for cleanup functions:** `cleanupPresenceRows(uid)`
calls `cleanupPresenceRowsWithDb(db, uid)` where the With-Db variant is
`export`-ed. Tests inject a stub `db`; production code uses the
module-level `admin.firestore()`. Same pattern as `runOcrRecipeImage` /
`runStructureRecipe` test seams (BUT-559).

### 2026-04-26 — firebase_crashlytics has NO web SDK (BUT-449)

`firebase_crashlytics: ^5.x` only ships `android/`, `ios/`, and `macos/`
folders — there is no `web/`. Wiring `kIsWeb` branches to call
`FirebaseCrashlytics.instance.recordError(...)` does nothing on web; the
calls silently no-op. Confirmed by inspecting the package contents at
`~/.pub-cache/hosted/pub.dev/firebase_crashlytics-5.0.4/`.

For Flutter Web error tracking, the working pattern is:

1. Cloud Function `logWebError` (callable, AppCheck-enforced, rate-limited
   via existing `enforceRateLimit`) that re-emits the payload as a
   structured `logger.write({ severity, labels: { event: 'web_error' }})`
   into Cloud Logging.
2. Client-side `WebErrorReporter` installed only when `kIsWeb &&
   hasConsent && !kDebugMode` (mirrors the native Crashlytics consent
   gate at `main.dart:_enableCollectionIfConsented`).
3. Both `FlutterError.onError` (framework errors) and
   `PlatformDispatcher.instance.onError` (uncaught async / zone errors)
   chain through the reporter; we preserve the prior handler so
   `presentError` still runs for dev overlays.
4. Every text field (message, stack, context) routes through
   `lib/services/llm/pii_scrubber.dart` (the BUT-421/422/423 client
   scrubber) before leaving the device. Server-side `log-web-error.ts`
   re-scrubs as defence-in-depth and DROPS the report when redaction
   ratio >50% (heavy-PII guard, mirrors `log-parse-correction.ts`).

**Why not Sentry:** would have meant a new heavy dependency, separate
secrets management, and a second cost line. The callable approach uses
infra Butlery already operates and pays for.

### 2026-04-26 — LLM kill-switch dual-control pattern (BUT-439)

Two independent gates, both deliberately layered, both fail open on
missing config (resilience > strict-deny):

| Gate | Source | Path | Latency |
|------|--------|------|---------|
| Server (authoritative) | Firestore | `system/config.aiEnabled`, `system/config.llmParserEnabled` | <1 min |
| Client (UX shortcut) | Remote Config | `ai_enabled`, `llm_parser_enabled` | up to 12 h |

Both flags exist for a reason:
- `aiEnabled` (master) — kills EVERY Vertex call. Cost spike, regulatory
  pause, full Vertex outage.
- `llmParserEnabled` (per-feature) — kills only the recipe-parse
  pipeline (`structureRecipe` + the OCR text-mode retry that delegates
  to it). OCR vision (`ocrRecipeImage` first pass) stays live. Use for
  prompt regression on the parser specifically.

**Audit at the time of BUT-439:** only two Vertex-calling functions in
`functions/src/llm/`:
- `structure-recipe.ts:117-145` — checks BOTH flags, gate at
  `runStructureRecipe` entry, before any `getGeminiClient()` call.
- `ocr-recipe-image.ts:218-226` — checks `aiEnabled` only via the
  `defaultIsAiDisabled` test seam. Per-feature flag enforcement comes
  via the OCR retry path delegating to `runStructureRecipe`.
- `ocr-retry.ts` is an orchestrator — calls `runStructureRecipe`,
  inherits the gate.
- `gemini-client.ts` is a utility wrapper, no entry point.

**Test seam pattern:** `runStructureRecipe(req, authUidHash, deps?)`
where `deps?.loadKillSwitch` is a `() => Promise<KillSwitchConfig |
undefined>` injectable. Default reads `system/config`. Tests pass a
stub returning the desired flag combo. This mirrors the pre-existing
`isAiDisabled` seam on `runOcrRecipeImage` — added belatedly to
`runStructureRecipe` for parity. **Don't try to stub `admin.firestore`
directly** — it's a getter on the FirebaseNamespace, not a writable
property; `Object.defineProperty` workarounds are racy across tests.
Inject the seam.

**Per-user cap (`llmMaxDailyInvocationsPerUser`):** already covered by
`functions/src/middleware/rate_limiter.ts` token bucket. Daily ceiling
is implicit from refill rate × 1440 min. If a strict calendar-day cap
is later required, extend `RateLimitConfig` with `dailyMaxInvocations`
and a 24-h rolling counter. **Out of scope for BUT-439** — current rate
limiter is sufficient for the launch envelope.

**Fail-open trade-off documented:** Firestore doc missing → AI on. This
is intentional — first-day deployment shouldn't block users while ops
seeds the doc. Firestore unreachable mid-call → outer `catch` in
`runStructureRecipe` turns the exception into an `internal` HttpsError,
so the user sees an error (fail closed for the user). Bypass is not
silent.

Runbook: `docs/ops/llm-kill-switch-runbook.md` — operator commands for
both flips (Firebase Console URL, gcloud, server-side TS snippet),
monitoring filters, decision log.

### 2026-04-27 — Recipe live watcher is now bounded; older pages cursor-paginated (BUT-484)

`FirebaseRecipeRepository.watchRecipes` and `subscribeToUserRecipes`
previously capped at `.limit(500)` — silently dropping recipes #501+.
Replaced with a default-100 live page plus a new
`loadMoreRecipes(userId, afterUpdatedAt, afterRecipeId, pageSize)` cursor
method on the `RecipeRepository` interface.

**Why a doc-cursor (`startAfterDocument`) and not a value-cursor:**
multiple recipes can share the same `core.updatedAt` (bulk imports
write the same `serverTimestamp()` to many docs in the same batch).
Value-based `startAfter([Timestamp])` would either miss or double-emit
the boundary's tied siblings depending on which side of the cursor the
ordering put them. `startAfterDocument` is the only race-safe
disambiguator Firestore offers when ties on the order-by field are
possible. Fallback to value-cursor is kept for the case where the
boundary doc was deleted between pages — caller must dedupe by id.

**Live watcher must stay bounded.** Don't be tempted to remove the
limit entirely "since pagination exists now": the live listener cost
scales with `pageSize` for every snapshot delta, and an unbounded watch
on a 5000-recipe collection costs 5000 reads on first attach plus the
delta cost. The live page should approximate one viewport-of-recipes;
older history is paginated by explicit user action ("Visa fler recept"
button or scroll-end).

**Pattern for similar live-list collections:**
- Watcher: `.orderBy(<sortField>, descending: true).limit(pageSize).snapshots()`.
- Pager: `.orderBy(<sortField>, descending: true).startAfterDocument(boundary).limit(pageSize).get()`.
- Boundary refresh on delete-between-pages: `.startAfter([sortFieldValue])`
  fallback with caller-side id dedup.
- Interface change is non-breaking when the new param is named-optional
  with a default — existing callers don't need updates, mocktail stubs
  with `any()` matchers still match.

The `RecipeListViewModel.canLoadMore` / `loadMore()` is currently a
**display-window pager** over already-fetched recipes; wiring it into
the new repo `loadMoreRecipes` is a follow-up VM/service change. The
backend cap is the immediate fix — display-window is fine until users
have >100 recipes loaded into memory at once.

### 2026-04-27 — Cloud Storage versioning + lifecycle infra (BUT-419)

Mirrors the BUT-450 alerting / BUT-418 backups pattern: hardened
`infrastructure/storage/setup-storage-versioning.sh` + runbook at
`docs/ops/storage-lifecycle-runbook.md`. User runs the script with
authenticated gcloud after pull.

**Lifecycle rule shape that matters:** `{age:30, isLive:false}`
applied alongside `--versioning`. `isLive:false` is the critical
guard — without it the rule would auto-delete LIVE objects after 30
days, which is the opposite of recoverability. Verified the rule via
`gcloud storage buckets describe --format=json` and grep for both
`"enabled": true` (versioning) and `"type": "Delete"` (lifecycle) so
the script fails non-zero if either policy silently no-oped.

**GDPR cascade nuance for storage:** when versioning is enabled, the
existing `on-user-deleted.ts` cascade `gsutil rm` only deletes LIVE
generations — noncurrent versions linger up to 30d. Documented as
accepted posture (same retention tier as Firestore PITR + weekly
exports). If a future regulator demands strict immediate erasure, the
follow-up is a generation-aware cascade (list + remove by
`#GENERATION` ID under the user's prefix). Out of scope for BUT-419.

**Bucket name disambiguation:** `STORAGE_BUCKET` is the Firebase
Storage bucket name (e.g. `butlery-app-1.appspot.com`), NOT the
project ID. Easy mistake — runbook explicitly calls this out under
Prerequisites.

### 2026-04-27 — account-deletion repo migration is partial-by-design (BUT-498)

The `lib/services/account/account_deletion/` services were originally
written with `FirebaseFirestore`-direct queries because of the
**cross-user scrub paths** that legitimately don't fit a per-resource
repository:

- `_scrubCollaborativeListReferences` — patches `items[].assignedToUserId`
  and `items[].purchasedByUserId` on OTHER users' shared shopping lists.
- `_scrubGroupWeeklyMenuPlans` — patches `participants[]`,
  `participantUserIds[]`, and `memberPermissions{}` on OTHER users' group
  menu plans, with orphan-deletion when zero participants remain.
- `removeFromSharedContent` — collectionGroup query on `members`
  subcollections + `arrayRemove` on parent `sharedToUserIds` arrays
  across multiple owners.
- Recipe-comments anonymization (NOT deletion) — preserves thread
  structure by patching `authorId='deleted'` instead of deleting docs.

**Scope of the BUT-498 migration**: only the four collections that
already have a clean per-user repo `deleteAllByUser` method got wired:
`cook_snaps` (CookSnapRepository), `activity_events`
(ActivityEventRepository), `weekly_menu_plans` (WeeklyMenuPlanRepository),
and `pantry` (PantryRepository.deleteAll). Three of the four gained an
explicit `validateOwnership` guard inside `deleteAllByUser`.
PantryRepository doesn't extend `BaseFirebaseRepository` — its
ownership is structural via the subcollection path under `users/{uid}`.

**Constructor pattern for testability**: `ContentDeletionOperations`
now takes optional repo injections (`cookSnapRepository:`,
`activityEventRepository:`, `weeklyMenuPlanRepository:`,
`pantryRepository:`). Production passes none → falls through to
`ServiceLocator.get<X>()` lazy-resolution. Tests pass fakes wired to
the same `FakeFirebaseFirestore` so end-to-end behaviour assertions
still work. The pattern is applied in
`test/unit/services/account/content_deletion_group_menu_scrub_test.dart`:
`MockAuthRepository.setAuthState(userId: …)` satisfies the new
`validateOwnership` precondition; the real
`FirebaseWeeklyMenuPlanRepository` is wired with the same fake
firestore the test seeds against.

**Residual direct Firestore use after BUT-498** (intentional):
content_deletion (recipes / menus / shopping-lists / personal_tags /
personal_tag_groups + 2 scrub paths), all of social_deletion (6
methods including the 2 cross-user paths), all of profile_deletion
(9 collections), all of storage_deletion (realtime + presence), and
private/public profile reads in data_export_service.

**Lesson for future migrations:** don't try to push the cross-user
scrub paths into per-resource repos. Those operations cross ownership
boundaries by design (GDPR Art-17 cascade), and burying them inside
e.g. `friend_repository.deleteAllForUser()` would lose the audit
trail. The right follow-up is to add `deleteAllByUser(userId)` (with
ownership validation) to the per-user-subcollection repos: recipes,
menus, shopping lists, personal tags, personal tag groups, FCM tokens,
notifications. The scrubs stay in the deletion-service layer.

### 2026-04-27 — audit_logs read tightening (BUT-424); GDPR Art-15 must move to a Cloud Function

`audit_logs/{logId}` previously allowed `request.auth.uid ==
resource.data.userId` to read. The repository docstring at
`lib/repositories/firebase/firebase_audit_repository.dart` already
contradicted this ("Users CANNOT read their own audit logs — prevents
tampering detection"). The intent is correct: a compromised account
should not be able to enumerate the audit trail and craft attacks
around the gaps.

Read rule is now `if isAdmin();`. Create remains an authenticated
self-uid-pinned write with a 2-second rate limit (the fire-and-forget
client path is unchanged). Update + delete stay denied (immutable
trail).

**Side-effect this fix exposes:**
`lib/services/account/export/compliance_export_manager.dart`
`exportAuditLogs(userId)` reads from the client SDK directly. With
the tightened rule, that read returns permission-denied → the
client-side GDPR Art-15 audit-log export breaks. The catch block
in that method already swallows errors into an `{error, note}`
shape, so the broader export job continues — but the audit-log
section will be empty for end-users.

**Mandatory follow-up before the next GDPR data subject access
request lands:** add a callable Cloud Function at
`functions/src/exports/audit-logs.ts` that uses the Admin SDK to
bypass the rule and returns the user's own audit slice. Mirror the
existing parsing-correction export shape. Until that function ships,
the export JSON's `audit_logs.error` field surfaces "permission
denied" — UX-acceptable for now (no GDPR request in the queue) but
genuinely broken if a regulator asks tomorrow.

**Test pattern for `isAdmin()` rules:** seed
`/admins/{uid}` via `withSecurityRulesDisabled` in setUpAll (the
collection itself is rules-locked — no client-side admin grant). The
admin context is just `env.authenticatedContext(adminUid)` — the
rule's `exists()` check resolves against the seeded doc. Pattern is
identical across cook-snaps, friend_categories, and audit_logs tests.

### 2026-04-27 — recipe_comments ownership denormalisation (BUT-458)

The pre-BUT-458 recipe_comments read rule was `allow read: if
isAuthenticated();` — **any logged-in user could read every
comment in the global collection**. The original tradeoff comment
acknowledged this as an intentional S3 because recipes live under
`users/{ownerId}/recipes/{recipeId}` and the rule has no efficient
way to look up the owner from just a `recipeId`.

**Pattern: denormalise ownership onto the child doc at write time.**
Two new fields on every new recipe_comment:
- `recipeOwnerId: string` — the recipe owner's uid.
- `sharedWithUserIds: string[]` — mirror of the share record's
  `sharedToUserIds` (the recipe's recipients).

New read rule:
```
allow read: if isAuthenticated() && (
  request.auth.uid == resource.data.authorId
  || ('recipeOwnerId' in resource.data
      && request.auth.uid == resource.data.recipeOwnerId)
  || ('sharedWithUserIds' in resource.data
      && request.auth.uid in resource.data.sharedWithUserIds)
);
allow read: if isAdmin();
```

**Legacy fallback:** the `'recipeOwnerId' in resource.data` guards
make legacy comments (no denorm fields) fall through to author-only
read — a deliberate one-time degradation. A backfill migration
restores recipe-owner / shared-recipient visibility on legacy rows.

**Backfill is a follow-up.** Pattern for it: `collectionGroup
queries are not feasible (recipe_comments is a top-level
collection, not a subcollection). Direct collection scan with
`recipe_comments.where('recipeOwnerId', '==', null).limit(500).get()`
chunked, then per-row look up the recipe owner via
`shared_content/{contentId}` (since most comments are on shared
recipes; personal-recipe comments stamp their author == owner).
Alternative if the recipe is no longer accessible: stamp
`recipeOwnerId = authorId, sharedWithUserIds = []` so the row stays
author-only-readable forever (graceful degradation for orphans).

**Repository contract:** `FirebaseCommentsRepository` now takes an
optional `RecipeOwnershipResolver` typedef returning a
`RecipeOwnershipSnapshot {recipeOwnerId, sharedWithUserIds}`. The
resolver is invoked in `addComment` before the write; failures are
non-blocking (the comment writes without the new fields, and the
rule degrades to author-only read for that row). Wire the resolver
in `social_module.dart` next to the existing
`recipeAccessValidator` callback — both surfaces share the same
underlying recipe-graph access. **NOT YET WIRED** in DI as of
2026-04-27 — the field is plumbed but the production resolver
implementation is still pending. Wiring it makes new comments
production-correct; legacy comments need the backfill.

### 2026-04-27 — blocking gate placement: target-uid field is the discriminator (BUT-459)

`isNotBlockedBy(targetUserId)` was already wired on `social_requests
create`. BUT-459 extended it to comment / rating / notification
creates. The pattern is uniform:

| Collection | Target-uid field | Notes |
|---|---|---|
| `social_requests` | `request.resource.data.toUserId` | already had the gate |
| `user_notifications` | `request.resource.data.userId` | recipient field is direct |
| `recipe_comments` | `request.resource.data.recipeOwnerId` | requires BUT-458 denorm |
| `recipe_ratings` | `request.resource.data.recipeOwnerId` | requires BUT-458 denorm |

**Self-notify must remain unblocked.** The user_notifications rule
has an OR-branch for `request.resource.data.userId == request.auth.uid`
(system events) that bypasses both the friendship check and the
new blocking gate. Without this, every system-driven self-event
write (welcome notification, kill-switch ack, etc.) would deny.

**Block-doc id format is `${blockerUid}_${blockedUid}`** —
`isNotBlockedBy(t)` checks `exists(/blocks/$(t + '_' +
request.auth.uid))`, i.e. "the actor's uid concatenated AFTER the
target's uid". Tests must seed in this exact order or the gate
no-ops. Caught the first time when the test passed when it should
have failed — the seed had the parts reversed.

**Backwards-compatible-by-field-presence pattern:** for ratings
(where the existing model has been deployed), the new
`recipeOwnerId` field is OPTIONAL — the rule reads as
`!('recipeOwnerId' in request.resource.data) ||
isNotBlockedBy(request.resource.data.recipeOwnerId)`. Legacy
clients without the field skip the gate (auth uid pinning + rate
limit still hold). New clients populate the field and the gate
fires. This avoids forcing a coordinated client-rules deploy and
is the right shape for any "add a denormalised field for rule
enforcement" migration on a deployed collection.

**Test seeding pattern for blocking:** seed the friendship pair
(both directions) AND the block doc, then the test discriminates
on the block — not on the friendship. Without the friendship,
the user_notifications test would deny on the wrong predicate
(friendship gate) and you'd think the blocking gate worked when
it didn't.

### 2026-04-27 — data-export repo migration is partial-by-design (BUT-501)

Mirrors the BUT-498 deletion pattern: only collections with a clean
`per-user-export` symmetry get migrated to a repo method this run.
Cross-user reads, top-level shared graphs, and user-subcollections
without a typed repo stay direct on Firestore — same architectural
decision as the deletion side, for the same reasons.

**Migrated** (8 collections / 5 repos extended with an
`exportXxxByUser` method, all guarded by `validateOwnership`):

| Manager | Collection | Repo method |
|---|---|---|
| activity_export_manager | `recipe_comments` | `CommentsRepository.exportCommentsByAuthor` |
| activity_export_manager | `recipe_ratings` | `RatingsRepository.exportRatingsByUser` |
| activity_export_manager | `feedback` | `FeedbackRepository.exportFeedbackByUser` |
| content_export_manager | `cook_snaps` | `CookSnapRepository.exportCookSnapsByUser` |
| content_export_manager | `activity_events` | `ActivityEventRepository.exportEventsByUser` |
| content_export_manager | `weekly_menu_plans` | `WeeklyMenuPlanRepository.exportAllByUser` |
| content_export_manager | `group_weekly_menu_plans` | `GroupWeeklyMenuPlanRepository.exportPlansForParticipant` |
| content_export_manager | `pantry` (subcoll) | `PantryRepository.exportAllByUser` |

**Residual (still direct-Firestore — explicitly out of scope this
sprint, per the same prioritisation as BUT-498):**

- `content_export_manager`: recipes (both `users/{uid}/recipes` and
  top-level `recipes` shapes), menus (both shapes), shopping_lists,
  personal_tags, personal_tag_groups. Five collections; the
  `RecipeRepository`, `ShoppingRepository`, etc. don't yet have a
  bulk-export-by-owner method matching the export shape (they have
  watchers and per-item reads). Adding them is the obvious next step.
- `social_export_manager` (entire file — 7 collections): `friends`
  subcollection, `social_requests` (sent + received), `conversations`
  + nested `messages`, `shared_content`, `blocks` (in + out),
  `friend_categories`, `conversation_memberships`. These cross
  ownership boundaries by design (you query other people's docs to
  find your participation). Same structural reason BUT-498's social
  deletion path stays direct.
- `compliance_export_manager`: `audit_logs` (already broken at the
  rules layer per the BUT-424 entry above — needs a Cloud Function
  exporter), `users/{uid}/consent` subcollection. The consent path
  could fit a `ConsentRepository` later.
- `preferences_export_manager` (5 collections): `users/{uid}/settings`,
  `user_notifications`, `user_notification_preferences`,
  `user_fcm_tokens`, `users/{uid}/category_preferences`,
  `users/{uid}/list_category_orders`. Mostly user-subcollection
  shapes that don't have typed repos.
- `data_export_service._exportUserProfile`: 2-doc read on
  `users/{uid}` and `public_profiles/{uid}`. The public side could
  use `UserRepository.fetchProfile`; the private side has no clean
  repo (it's owned by the Auth/Session services). Left direct for
  now since ownership is implicit (auth uid IS the doc id).

**Pattern that worked for the read-side migration:**
- Add a method `exportXxxByUser(String userId, {int maxDocuments})`
  to the existing repo interface. Returns `List<Map<String, dynamic>>`
  shaped as `[{id, data}]`, NOT typed entities — the export pipeline
  needs the raw Firestore map for its `sanitizeForJson` step (which
  walks `Timestamp`/`GeoPoint`/`DocumentReference`). Round-tripping
  via the model class would lose timestamp precision.
- Implementation pattern (mirrors `deleteAllByUser`):
  ```dart
  await validateOwnership(
    currentUserId: requireCurrentUserId(),
    resourceOwnerId: userId,
    resourceType: collectionName,
  );
  final snapshot = await collection
      .where('<owner-field>', isEqualTo: userId)
      .limit(maxDocuments)
      .get();
  return snapshot.docs.map((d) => {'id': d.id, 'data': d.data()}).toList();
  ```
- For doc-id-prefix-binding collections (weekly_menu_plans), use the
  same `where(FieldPath.documentId, isGreaterThanOrEqualTo: '${uid}_')`
  + `` upper-bound trick the `deleteAllByUser` version uses.
- For map-key-binding collections (group_weekly_menu_plans —
  participation is `memberPermissions.${uid} != null`), use the
  same dotted-key `isNotEqualTo: null` query.

**Test wiring pattern:** `data_export_service_test.dart` wires
fake-firestore-backed `Firebase*Repository` instances via the new
optional constructor params. Production passes none → falls through
to `ServiceLocator.get<X>()`. The new BUT-501 test seeds one row in
each migrated collection and asserts `total_count == 1` — proves the
repo path is live and `validateOwnership` accepts the self-export
case. Without this assertion, the export's existing `try/catch` wraps
any failure into `{'error': ...}` and the legacy "should export X
section" smoke tests pass even if the migration regresses.

**FeedbackRepository gotcha:** the repo's constructor previously
called `FirebaseStorage.instance` eagerly. Tests that wire only the
read path (export) but never the write path (uploadScreenshot) blew
up with `[core/no-app] No Firebase App` because Storage init pulls
in the platform Firebase app at construction time. Fix: lazy-init
the storage getter — `final FirebaseStorage? _injectedStorage; get
_storage => _injectedStorage ?? FirebaseStorage.instance;`. Same
pattern is worth applying preemptively to any repo that pulls in a
heavyweight Firebase service the read path doesn't need.

### 2026-04-27 — FCM token store hardening (BUT-457)

`fcm_token_manager.dart` already used `FlutterSecureStorage` as the
local token store — the SharedPreferences fallback the ticket warned
about was a historical artifact in the constants (the `_tokenStorageKey
= 'fcm_token'` name suggested SharedPreferences but the actual writes
went to SecureStorage). Fix:

1. Added a one-time migration `_migrateFromSharedPreferencesIfNeeded()`
   that runs on every `initialize()`. Reads the legacy `fcm_token` and
   `fcm_token_timestamp` keys from SharedPreferences, copies a present
   token to SecureStorage (only if SecureStorage doesn't already have
   one — never clobber the canonical store), then `prefs.remove()`s
   both keys regardless. A sentinel `fcm_token_sp_migration_done` in
   SecureStorage gates re-runs.
2. Annotated `_saveTokenLocally()` to make the contract explicit: on
   secure-storage write failure, log and move on — **MUST NOT**
   mirror to SharedPreferences (regression guard for a future
   contributor tempted to add a fallback "for resilience").
3. Three new BUT-457 test cases: migration scrubs SP and sets the
   sentinel; sentinel makes a second-init no-op; on Firestore save
   failure no plaintext write to SP happens.

**Test infrastructure gotcha:** the existing FCM test file's
SecureStorage method-channel handler was a flat "always return
test-device-id for read, true for write" — that doesn't simulate
the per-key sentinel needed for migration tests. Replaced with a
per-test `Map<String, String?>` keyed off `args['key']`, which is
also what the real plugin uses. Default for an unknown key is null;
the legacy `butlery_fallback_device_id` reader gets a literal
`'test-device-id'` to keep the existing device-id tests green.

**SharedPreferences mocking pattern:** `SharedPreferences.setMockInitialValues({...})`
in `setUp()` resets the in-memory backing store between tests — no
platform-channel handler needed. To assert that a key was scrubbed,
just `getInstance().getString(key)` and check for null.

### 2026-04-27 — third-party HTTPS pinning (BUT-427)

`http_certificate_pinning ^3.0.1` is the package; the SDK constraint is
satisfied by 3.0.x. The package ships a `SecureHttpClient` and a Dio
`CertificatePinningInterceptor` — **neither is sufficient on its own**:

- `SecureHttpClient.send(BaseRequest)` falls through unconditionally and
  only the non-streaming `get/post/...` helpers run the pin check.
  HttpContentFetcher and OCRExtractionService both use `client.send(...)`
  directly (size-capped streaming reads, multipart uploads) — using the
  package's send() bypass would silently disable pinning on the hottest
  third-party paths. Roll our own `BaseClient` that overrides `send()`.
- The Dio interceptor takes a single static fingerprint list. Algolia
  uses 4-5 different host URLs (`*-dsn.algolia.net`,
  `*.algolia.net`, three shuffled `*.algolianet.com`) — needs a per-host
  variant that reads pins from a config map.

**Architecture:**

| File | Role |
|---|---|
| `lib/services/security/cert_pin_config.dart` | Global host → pin list map. Empty list = wired but inactive. |
| `lib/services/security/pinned_http_client.dart` | `BaseClient` wrapper for `package:http` callers (OCR + URL scrape). Overrides `send()` so streaming requests are pinned. |
| `lib/services/security/pinned_http_client_factory.dart` | Builds the http client and wires the analytics callback. |
| `lib/repositories/algolia/algolia_pinning_interceptor.dart` | Per-host Dio interceptor for Algolia. Lives next to the algolia repo because `dio` is a transitive dep of `algoliasearch` only — keeping it there avoids needing dio as a top-level dependency. |

**Telemetry contract (`ssl_pin_mismatch`):** logs `host` and `error_kind`
(`'mismatch'`, `'check_failed'`, `'non_https_pinned_host'`). The request
still throws — soft-fail means the app does not crash, NOT that we accept
an unverified cert.

**Empty pin list = no-op fall through.** Hosts with no configured pins
(or with a TODO placeholder list) fall through to the platform trust
store. This keeps the wrapper safe to install everywhere — a misconfigured
pin map cannot itself break unrelated requests, and the ops rotation task
can populate real fingerprints without a code change at the call sites.

**Pin lookup contract:** `pinsForHost(host)` returns `List<String>` —
empty (NOT null) for unknown hosts. Callers rely on the empty-list
contract and would crash on null. Unit-tested explicitly so a future
contributor doesn't change the return type.

### 2026-04-27 — push notification deep-link routing (BUT-641)

The pre-BUT-641 wiring was an inline lambda in main.dart that pushed
whatever `route` came in `RemoteMessage.data`. Two regression risks:
1. legacy in-flight payloads without `route` crashed (null pushed to
   `pushNamed`),
2. no analytics → push CTR was unmeasurable.

**Pattern: dedicated router class with route constants.**
`NotificationRoutes.{recipe, friendRequest, commentThread,
cookingSession, menuVoting, winback}` are the canonical strings the
Cloud Functions sender must align against. Adding a route requires
adding the constant AND the `case` branch in `handle()`.

**Three-state outcome model:**

| Input | Behavior | Analytics event |
|---|---|---|
| `route == null \|\| empty` (legacy) | push home (and clear stack) | `notification_payload_missing_route` |
| `route` not in known set (drift) | push home (and clear stack) | `notification_payload_unknown_route` |
| Known route | navigator action | `notification_opened` |

The unknown-route guard is the early-warning signal for client-server
drift: a Cloud Functions sender shipping a new route string before the
client knows about it is exactly what BUT-641 is meant to surface, not
crash on.

**Wired in main.dart `_onApplicationReady`:**
```dart
final notificationRouter = NotificationDeepLinkRouter(
  navigatorResolver: () => appNavigatorKey.currentState,
  analyticsResolver: () => ServiceLocator.tryGet<AnalyticsService>(),
);
NotificationService.onNotificationTapped = notificationRouter.handle;
```

`NotificationService._handleMessageOpened` extracts `route`, `targetId`,
`notificationType` from `RemoteMessage.data` and forwards them. When
`route` is null it forwards `''` so the router (not the wrapper) owns
the missing-route default. `getInitialMessage` (terminated-app launch)
flows through the same `_onMessageOpenedApp` callback already, no
separate wiring needed.

**Test pattern: `Mock implements NavigatorState` needs an explicit
`toString({DiagnosticLevel minLevel})` override.** NavigatorState mixes
in Diagnosticable; mocktail's default `toString() => '$runtimeType'`
doesn't satisfy that signature and produces a compile-time error. The
override is one line — but a `Fake implements NavigatorState` hits the
same wall.

### 2026-04-29 — concurrency-safe per-host serialization guard (BUT-736)

**Anti-pattern caught in `PinningDioInterceptor`:** a single nullable
instance field `Future<X>? _inflight` used as a "wait for the previous
in-flight call" guard collapses under concurrent callers:

```dart
// BROKEN — request B clobbers request A's reference;
// A's `finally { _inflight = null }` then nulls B's slot →
// any later request C bypasses the guard entirely.
Future<X>? _inflight;
if (Platform.isIOS && _inflight != null) await _inflight;
try {
  _inflight = doWork();
  result = await _inflight;
} finally {
  _inflight = null;
}
```

**Fix pattern:** key by the discriminator that the underlying
serialization actually requires (host, in this case — Alamofire's
constraint is per-host on iOS, NOT global). Store futures in a
`Map<Key, Future<X>>` and clear the entry only if it still points to
*this* call's future:

```dart
final Map<String, Future<X>> _inflightByKey = {};

if (Platform.isIOS) {
  final pending = _inflightByKey[key];
  if (pending != null) await pending;
}
final future = doWork();
_inflightByKey[key] = future;
try {
  result = await future;
} finally {
  if (identical(_inflightByKey[key], future)) {
    _inflightByKey.remove(key); // don't clobber a later concurrent call
  }
}
```

**Test seam pattern for race regressions:** inject a stub that returns
`Completer<T>().future` so the test controls completion order. Fire N
requests concurrently, wait for all stub completers to be REGISTERED
(`_pumpUntil(() => completers.length == N)`), then complete them in
*reverse* order. If the production code crosses futures, the wrong
request will see the wrong outcome — exactly the failure mode that a
"all tests passed because everything ran sequentially" suite would
miss.

### 2026-04-29 — DI singleton pattern for pinned HTTP clients (BUT-735)

**Anti-pattern caught in `HttpContentFetcher`:** allocating a fresh
`PinnedHttpClientFactory.create()` per call and tearing it down in a
`finally` block. Each call paid TLS handshake + DNS, no keep-alive
across calls.

**Reference good pattern in same codebase:** `OcrExtractionService`
caches its pinned client in `_cachedHttpClient ??=
PinnedHttpClientFactory.create()` (lazy init, reused for the lifetime
of the service).

**Best pattern for app-shared infra HTTP:** register a singleton
`http.Client` in `core_module.dart` built via
`PinnedHttpClientFactory.create()`, with `dispose: (c) => c.close()`
so GetIt owns the lifecycle:

```dart
container.registerSingleton<http.Client>(
  PinnedHttpClientFactory.create(),
  dispose: (client) => client.close(),
);
```

Inject into consumers via constructor with the
`_httpClient ?? PinnedHttpClientFactory.create()` fallback preserved
for ad-hoc/test construction. The
`shouldCloseClient = _httpClient == null` rule keeps semantics
correct — the injected DI client is NEVER closed by the consumer
(GetIt closes it once on app shutdown), only the per-call fallback is.

**Why pinning is no-op-safe at this layer:** `PinnedHttpClient`
short-circuits to the inner client for hosts without configured pins
in `CertPinConfig.hostPins`. So registering a pinned wrapper as the
shared `http.Client` doesn't break consumers that hit unpinned
third-parties — pinning only fires for hosts that opted in.

**Test the contract, not the implementation:** wrap the injected
client in a `_TrackingClient extends http.BaseClient` that counts
`close()` calls. Two `fetchHtmlWithTimeout` calls + zero closes =
reuse confirmed. A future contributor tempted to "simplify" by
re-introducing per-call construction will fail this test before
shipping the regression.

### 2026-04-30 — server-side notification gate review patterns (BUT-647 / BUT-645 / BUT-638)

Three recurring failure modes when a Cloud Function reads from a
Firestore collection it expects "the client" to populate:

1. **Producer-consumer drift.** `suppress-low-performers.ts` reads
   `notification_opened_events` to compute CTR. Header comment says
   "client writes" — but no Flutter code writes to that collection,
   and the default-deny `match /{document=**}` rule would block it
   even if it tried. Verified by greppping `lib/` for the collection
   string and finding zero hits. **Pattern: when a Cloud Function
   header says "X writes here", grep for the producer in the same
   commit.** No producer = the consumer ships dead. For analytics
   events that already land in BigQuery via the Analytics export,
   prefer reading from BigQuery to avoid the dual-write trap. If
   Firestore is required, ship a callable `recordX` Cloud Function
   alongside the consumer (App-Check + rate-limited) and wire the
   client in the same sprint.

2. **PII-bearing queue collections need `expireAt` AND a GDPR
   cascade — neither is automatic.** `scheduled_notifications` stores
   payload `title`/`body`/`data` indefinitely (no TTL field, no
   sweeper). `notification_send_events` writes `expireAt` and
   relies on the operator-configured TTL policy (which itself is
   manual: gcloud or Firebase Console — see BUT-477 presence-TTL
   runbook for the command). **Checklist for any new server-written
   collection that contains userId or other PII:** (a) `expireAt`
   field on the doc, (b) gcloud TTL policy in a runbook, (c)
   `on-user-deleted.ts` cascade (`collectionGroup` query + batched
   delete with BATCH_LIMIT=500 chunking), (d) single-field index on
   `userId` for the cascade query.

3. **Compound-equality + range queries need composite indexes —
   single-field auto-indexing is not enough.** `deliver-scheduled-
   notifications.ts` runs `where("status","==","pending").where
   ("deliverAt","<=",now)`. That's `==` + range on different fields,
   so it needs a composite index in `firestore.indexes.json`. Grep
   `firestore.indexes.json` for the collection name in the same
   review pass; missing entry = first scheduled invocation throws
   `FAILED_PRECONDITION` and keeps throwing on the schedule until
   noticed.

**Drainer poison-pill rule.** When a scheduled drainer claims a doc
via transaction `pending → delivered`, then sends, then rolls back
to `pending` on send failure: the bounce is unbounded. Permanent
failures (revoked tokens, malformed payloads) loop forever. Always
add a max-attempts cutoff that flips to `status: "failed"` with
`failedAt` and `lastError` so the dead-letter rate is observable.
Pattern: `attempts >= MAX_ATTEMPTS ? "failed" : "pending"` in the
catch arm.

**Region pinning verification.** `setGlobalOptions({ region:
"europe-west1" })` in `functions/src/index.ts` (currently line 20)
covers every export. New `onSchedule` exports inherit it
automatically — no per-function region override needed. If a future
agent removes the global option to override per-function, every
unconverted export silently flips to `us-central1` (default) which
is a privacy regression for EU users. Treat removal of that line
as Critical without the matching per-function migration.

**Fail-open vs fail-closed on RC reads.** Notification flags fail
open (`notification-rc-flags.ts:91-95`) — RC outage doesn't mute
the entire app. This is the right call for pushes specifically: a
flaky RC fetch silently muting all notifications is far worse than
sending a few extra during an outage. Contrast: `system/config`
LLM kill-switch also fails open at the gate (BUT-439) but the
outer `runStructureRecipe` catch turns Firestore-unreachable into
an `internal` HttpsError so the user sees an error. Per-domain
trade-off: pushes are tolerable to over-send, LLM calls are
expensive to over-send.

**Gate placement in `dispatchNotification` skips legacy callers
that don't pass `notificationType`.** `send-notification.ts:259`
gates only when `payload?.notificationType` is truthy. Acceptable
as a migration step — but once all callers stamp the type field,
the conditional should become an assertion, not a fall-through.
Otherwise legacy paths permanently bypass the BUT-647/645 system.

### 2026-04-30 — server-side notification gate fixes round 2 (C1/C2/H1/M1)

Round-2 review of Agent A's fixes to the BUT-647/645 review findings.
All four fixes are functionally correct; documenting the patterns that
worked and the still-open Medium gaps:

**C1 — `recordNotificationOpened` callable.** Pattern that worked:
- Internal core `runRecordNotificationOpened(userId, req, deps?)`
  takes uid as a parameter; wrapper enforces `request.auth` and maps
  validation `Error.message.includes("required"|"maximum length"|...)`
  to `HttpsError("invalid-argument", ...)`. The string-match approach
  is brittle but acceptable; a future refactor that renames a
  validation message could silently degrade to `internal` — a typed
  `class ValidationError extends Error` would be tidier.
- Deterministic doc id `<userId>_<notificationId>` with slash
  sanitization (`replace(/[/]/g, "_")`). Read-then-set lets the call
  honestly report `recorded=false` on dedup vs blind set.
- Client wired via `FirebaseFunctions.instanceFor(region: 'europe-west1')`
  — the `.instance` default would silently 404 against us-central1
  in production. **This is a recurring footgun for region-pinned
  projects.** When reviewing any new callable client wiring, grep
  for `FirebaseFunctions.instance` (without `For`) — that's the bug
  shape.
- Regression-guard test `producerConsumerEndToEnd()` correctly goes
  red if the writer call is removed: producer writes 10 docs into
  shared `openedDocs` map → consumer reads via `Array.from(map.values())`
  → 50 sends + 0 opens (if writer removed) → CTR=0 → flips=1 → fail.
  Test wires the *real* writer + *real* aggregator with a shared
  fake DB — neither side is mocked.

**Still-Medium for C1:**
1. No length cap on `route` field — `notificationId` capped at 256,
   `notificationType` at 64, but `route` is unbounded (callable
   hard-cap of 10MB is the only ceiling). Add `route.length > 256`
   check matching the others.
2. No rate limit (the codebase's `enforceRateLimit` middleware
   pattern is not applied). Auth + dedup + 30d TTL + small doc size
   bound the abuse vector, but parity with other callables would
   add the token bucket. Acceptable for ship; track as a follow-up.
3. No `enforceAppCheck: true`. Most callables in this project don't
   set it (only LLM + log-web-error do), so this is parity with
   convention rather than a regression — but fully closing the
   "cheap signal flooding" vector means App Check + rate limit.

**C2 — GDPR cascade on `notification_opened_events`.** Confirmed
the three-collection sweep in `cleanupNotificationQueuesWithDb`
uses BATCH_LIMIT=500 chunking (not naive single-write). One-loop-
per-collection, fresh batch per collection, batch.commit on
chunk-full and on tail. Pattern correct.

**Still-Medium for C2:** the new producer
`record-notification-opened.ts` does NOT carry the gcloud TTL
command in its module docstring. `scheduled-notifications.ts`
and `notification-send-events.ts` both document the operator
command inline. Add to record-notification-opened header:

```
gcloud firestore fields ttls update expireAt \
  --collection-group=notification_opened_events --enable-ttl
```

Without it, an operator reads only the cleanup cascade comment
(line 102-108 of on-user-deleted.ts) and may not realize
`notification_opened_events` itself needs a manual TTL policy
flip — same passive-expiry trap as scheduled_notifications.

**H1 — composite index.** Entry at `firestore.indexes.json:245-252`
is in `indexes[]` (correct top-level array, NOT inside
`fieldOverrides`). Schema matches the existing entries: same
`collectionGroup` / `queryScope: "COLLECTION"` / `fields[]` shape.
`firebase deploy --only firestore:indexes` will accept it. The
query `where("status","==","pending").where("deliverAt","<=",now)`
is supported by an `(status ASC, deliverAt ASC)` composite — `==`
on the leading field plus range on the trailing field is the
canonical compound shape.

**M1 — drainer poison-pill.** Refactor to
`runDeliverScheduledNotifications(deps?)` (db, now, send injectable).
MAX_ATTEMPTS=5 is exported. Transaction at line 85-97 reads doc,
verifies `status === "pending"`, atomically stamps
`status="delivered"`, `deliveredAt`, `attempts=attemptsBefore+1`.

**Race analysis (the explicit concern):** if attempt 5 succeeds at
FCM, the transaction has already stamped `delivered` BEFORE the
send; the catch arm at 134-166 only fires on send failure. So
attempt 5 success → doc stays `delivered` (no flip to `failed`).
Correct. The doc is "claimed-delivered-then-sent", which is the
deliberate at-most-once trade-off documented in
`scheduled-notifications.ts` lines 57-65.

Failure-arm rollback at line 163 sets `status: "pending"` but does
NOT reset `attempts` — the bumped counter is the loop guard so
the next run picks up the same doc with attempts=N+1 after the
transaction's next bump. Math: 0 → claim bump 1 → fail rollback
to pending(1) → claim bump 2 → fail rollback to pending(2) → ...
→ claim bump 5 → fail at 5==MAX → park at `failed`. Five tries
exactly, as intended.

Malformed branch at 115-124 parks immediately without rolling back
the bump — also correct (a malformed doc never recovers).

**M1 test-fake limitation worth noting (not a fix request):** the
fake DB's `get()` at deliver-scheduled-notifications.test.ts:49-55
returns ALL store docs without filtering by `status` or `deliverAt`.
That's fine for a contract test of the transaction logic (which
re-checks status before claiming), but it means the test cannot
catch a regression where the production query filter is removed
(e.g. accidentally dropping the `where("status","==","pending")`
clause). For a defense-in-depth follow-up, an emulator-backed
test that exercises the actual query would close this.

**Acceptance:** approved for commit. The remaining items (C1
length-cap on route, gcloud TTL doc on the new producer) are
follow-up Medium polish, not commit-blockers.

### 2026-04-30 — BUT-501 closed: ExportRepo gateway pattern

The third-cycle "partial-by-design" residual finally drained. Strategy
was a single dedicated `FirebaseDataExportRepository` (under
`lib/repositories/firebase/`) that owns every direct-Firestore read the
GDPR export pipeline still needs. Each method calls `validateOwnership`
at entry, then performs the read.

**Why this beat the "split into a dozen new typed repos" alternative:**
- `users/{uid}/settings`, `user_notification_preferences`, FCM token
  shapes (top-level + subcoll), `friend_categories`, `category_preferences`,
  `list_category_orders`, `users/{uid}/conversation_memberships`, blocks
  (in/out), social_requests (sent/received), conversations + nested
  messages, shared_content (recipe slice), shared menus
  (sent/received), users/{uid} private profile, public_profiles/{uid}
  — these are 16+ collection shapes that don't have natural typed
  models. Building 16 new `XxxRepository` interfaces just to satisfy
  "no direct Firestore in managers" would be repository-cargoculting.
- One gateway funnels every "export-only direct read" through a single
  `validateOwnership` choke point — defence-in-depth on top of the
  rules layer at exactly one place to audit.
- Methods on the gateway return raw `{id, data}` (or single `data`)
  shapes — the export pipeline needs the raw Firestore map for its
  `sanitizeForJson` step (Timestamps, GeoPoints). Round-tripping
  through typed models would lose precision.

**Migrated to the gateway:** all 28 direct-Firestore calls across the
five export manager files. Final grep confirms `_firestore.` field
access is gone except the documented BUT-424 audit_logs read in
`compliance_export_manager.dart` (audit_logs is admin-only at the
rules layer; user-side export needs a Cloud Function exporter — that's
still the BUT-424 follow-up, not a BUT-501 residual).

**Migrated to typed repos** (when the natural home existed):
- `users/{uid}/recipes` → `FirebaseRecipeRepository.exportPersonalRecipesByUser`
- top-level `recipes` filtered by `userId` → `FirebaseRecipeRepository.exportTopLevelRecipesByOwner`
- `users/{uid}/personal_tags` → `FirebasePersonalTagRepository.exportAllByUser`
- `users/{uid}/personal_tag_groups` → `FirebasePersonalTagGroupRepository.exportAllByUser`

**Test wiring change:** `data_export_service_test.dart` now also
constructs and injects `FirebaseRecipeRepository`,
`FirebasePersonalTagRepository`, `FirebasePersonalTagGroupRepository`,
and `FirebaseDataExportRepository` — all backed by the same fake
firestore. The "should export recipes" test was the canary that
caught the missing wire (had been silently returning `error` payload
because there was no test seam to a real RecipeRepository before).

**DI:** `FirebaseDataExportRepository` registered in `core_module.dart`
in the same scope as `DataExportService`, since the latter holds it
as a `late final` and passes it down to every manager constructor.

### 2026-04-30 — BUT-458 closed: RecipeOwnershipResolver wired + backfill CF

**Resolver wiring:** `FirebaseRecipeOwnershipResolver` is the production
implementation of the `RecipeOwnershipResolver` typedef in
`comments_repository.dart`. It takes `getRecipe: Future<Recipe?> Function`
and resolves ownership as: collaborative → `socialData.ownerId` +
`memberPermissions.keys` (excluding owner); personal → `createdBy` + empty.
Wired in `social_module.dart` lazily via `UnifiedRecipeService.getRecipeById`
(the service is user-scoped — registered post-login — so the resolver
checks `container.isRegistered<UnifiedRecipeService>()` and returns null
when unregistered, which is the existing fallback contract: comments
write without denorm fields and rules degrade to author-only read).

**Why `UnifiedRecipeService.getRecipeById` and not the coordinator's
getRecipe**: `SocialRecipeCoordinator` takes `getRecipe` as a
constructor arg but doesn't expose it publicly. UnifiedRecipeService
exposes a `Recipe? getRecipeById(String)` directly (synchronous, from
its in-memory cache + Firestore fallback) which is what we want here.

**Backfill Cloud Function** (`functions/src/migrations/backfill-recipe-comments-denorm.ts`):
admin-only callable (gated by `requireAdmin` from `shared/`), region
`europe-west1`, paginated by `__name__` cursor (no collectionGroup
index needed for `recipe_comments` itself — it's top-level). For each
unmigrated comment, uses `collectionGroup('recipes')` + `where(documentId, ==, recipeId)`
to find the owning recipe; resolves owner from `socialData.ownerId`
or `core.createdBy` or path-derived parent uid. Orphan comments
(recipe gone) get stamped `recipeOwnerId = authorId, sharedWithUserIds = []`
so they stay readable by the comment author forever — graceful
degradation per the original BUT-424 entry's recommendation.

**Idempotency contract:** comments with non-empty `recipeOwnerId` are
skipped. The Test in `__tests__/backfill-recipe-comments.test.ts`
re-runs against an already-migrated state and asserts `migrated == 0,
skipped == 1`.

**Region pin:** `onCall({ region: "europe-west1" }, ...)` — Butlery
convention. Same region as the rest of the functions.

**Hard ceiling:** `MAX_BATCHES_PER_INVOCATION = 50` × `BATCH_SIZE = 200`
= 10k comments per invocation. The `hasMore` flag in the response
signals when re-invocation is needed (a follow-up cron / manual
re-call). For the current beta scale this is way more than needed
in one call.

---

### 2026-04-30 — BUT-501 close-out: data-export gateway pattern

**Pattern: read-only query gateway for typeless export collections.**

When a feature (here: GDPR export) needs to read many user-scoped
collections that don't have proper typed `Repository<Model>` interfaces
yet, the right move is a single gateway repo, not scattered
`FirebaseFirestore.instance` calls in services.

`FirebaseDataExportRepository` (`lib/repositories/firebase/firebase_data_export_repository.dart`)
demonstrates the contract:

1. Extends `BaseFirebaseRepository<Object>` to inherit `firestore`,
   `requireCurrentUserId()`, and the `PermissionValidationMixin`.
2. CRUD methods (`fromFirestore`, `toFirestore`, `getId`, all four
   `validate*Permission`) throw / return false — gateway is read-only.
3. Single private `_guardSelfExport(userId, resourceType)` that calls
   `validateOwnership(currentUserId: requireCurrentUserId(), resourceOwnerId: userId, ...)`.
   Every public method calls this **first**, before any Firestore read.
4. Public methods return raw `{id, data}` shapes — no model layer because
   each export-manager re-shapes for the JSON output anyway.

**Why this is acceptable defence-in-depth:** Firestore rules already
gate user-scoped reads, but the gateway adds an in-process check that
the *authenticated* uid matches the *requested* userId before any
network call. Cheaper than a rules-deny round-trip and gives a clean
log line on attempted cross-user export.

**Spot-check verdict (3 methods, all clean):**
- `exportPersonalMenus` — `users/{uid}/menus`, guarded, path uses the
  same `userId` that was just validated → no path-substitution risk.
- `exportSharedMenusByOwner` — top-level `menus where sharedByUserId == userId`,
  guarded; the `where` clause uses the *same validated userId* → no
  read-time bypass.
- `exportConversationsAndMessages` — top-level `conversations where
  participantIds arrayContains userId`, guarded; the per-conversation
  `messages` subcollection inherits the parent doc's access decision.
  Note: this returns *all* messages in conversations the user
  participates in, including messages from other participants. That is
  correct for GDPR Article 15 (right of access — the user did receive
  these messages) but `social_export_manager.exportMessages` then
  filters to `senderId == userId || recipientIds contains userId` as
  belt-and-braces. Good.

**Residual direct-Firestore call:** exactly one — `compliance_export_manager.dart:49`
reading `audit_logs`. By design per BUT-424: rules deny user-side
reads of `audit_logs` (admin-only), so the call exists to *attempt*
the read and degrade gracefully when denied. A Cloud Function
exporter is the long-term fix. The class docstring documents this.

**Lingering `cloud_firestore` imports (not bypasses):**
- `compliance_export_manager.dart:3` — needed for the audit_logs
  `FirebaseFirestore` field.
- `preferences_export_manager.dart:3` — needed for the `Timestamp`
  type-check on `fcmData['updatedAt']` (untyped Map value).
Both legitimate; not regressions.

**DI wiring:** `core_module.dart:282` registers
`FirebaseDataExportRepository` as a lazy singleton; `DataExportService`
constructs the gateway with the shared `firestore` + `authRepository`
and passes it down to every manager. Test seam: each manager accepts
optional `dataExportRepository` and falls back to `ServiceLocator.get`.
This matches the project pattern.

**Anti-pattern this replaced:** five managers each holding their own
`FirebaseFirestore _firestore` field with 28 unguarded direct calls.
That is exactly the "direct Firestore = bypasses
PermissionValidationMixin" failure mode CLAUDE.md rule #3 prohibits.

### 2026-04-30 — BUT-458 ownership-resolver: lazy DI gating for user-scoped services

The recipe-comments denorm pipeline needs an ownership snapshot
(`recipeOwnerId`, `sharedWithUserIds`) at comment-create time. The
resolver depends on `UnifiedRecipeService`, which is **user-scoped**
(registered post-login in `social_module.configureUserScope`), but the
comments repository is **app-scoped** (registered pre-login in
`configure`). Naive `container<UnifiedRecipeService>()` would throw
during cold-start or pre-login comment attempts.

**Pattern (verified in `social_module.dart:273-286`):**
```dart
recipeOwnershipResolver: (recipeId) async {
  try {
    if (!container.isRegistered<UnifiedRecipeService>()) return null;
    final recipeService = container<UnifiedRecipeService>();
    final resolver = FirebaseRecipeOwnershipResolver(
      getRecipe: (id) async => recipeService.getRecipeById(id),
    );
    return await resolver.resolve(recipeId);
  } catch (_) { return null; }
}
```

Three layers of fail-soft:
1. `isRegistered<T>()` gate — returns null pre-login.
2. Outer try/catch — catches any GetIt resolution race.
3. Resolver's own try/catch (`firebase_recipe_ownership_resolver.dart:67`)
   — catches Firestore exceptions, doc-missing, malformed docs.

**No race condition concern:** even if `isRegistered` flips between
the check and the lookup (it cannot in single-threaded Dart, but if it
could), the outer try/catch catches the resulting GetIt exception.
Defensive belt-and-braces is correct here because comment-write must
NEVER fail because of an ownership-resolution failure — the comment
writes without denorm fields and rules degrade to author-only read.

**`isCollaborative` is keyed off `RecipeType.collaborative`, NOT
`socialData != null`** (verified: `recipe_unified.dart:1167`
`bool get isCollaborative => type == RecipeType.collaborative`). This
matters because legacy recipes can have a `socialData` blob for
historical reasons without being collaborative. Always go through
`Recipe.collaborative(...)` factory or `recipe.isCollaborative` getter
— never test `recipe.socialData != null` directly when deciding
ownership semantics. The resolver follows this correctly:
- collaborative → try `socialData.ownerId`, fall back to `createdBy`
- personal → straight to `createdBy`

**Shared-list filter:** `_resolveSharedIds` filters out the owner from
the `memberPermissions.keys` list (lines 99-105). This is a
correctness optimization, not just cosmetic — without it the rule's
owner-branch and member-branch would both fire and you'd get
duplicate-evaluation cost on every comment read.

**Export-method discipline (BUT-501 sibling work in this sprint):**
`exportPersonalRecipesByUser`, `exportTopLevelRecipesByOwner` (recipe
repo), and `exportAllByUser` (personal_tag, personal_tag_group, pantry,
weekly_menu_plan repos) all call `validateOwnership` BEFORE the
collection read. Pattern verified across all six call sites — none
of the typed-repo export methods bypass the mixin. Use this as the
template when adding new `exportXxxByUser` methods on typed repos.

The `FirebaseDataExportRepository` gateway (BUT-501) and the typed
repos with `exportXxxByUser` are complementary, not competing — the
gateway handles collections that lack a typed repo today, the typed
repos own their own data. New work should prefer adding the method
to the typed repo and removing the gateway counterpart, per the
docstring on `FirebaseDataExportRepository`.

---

### 2026-04-30 — production-ServiceLocator bridge for unit tests that drive the deletion cascade

When writing a unit test that constructs the real `AccountDeletionService`
and exercises its full cascade against `FakeFirebaseFirestore`, you MUST
bridge the production `ServiceLocator` to the test GetIt instance:

```dart
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;

setUpAll(() async {
  await BaseUnitTest.setupUnit();
  production.ServiceLocator.initialize(DIContainer());
});
```

Without this bridge, internal calls like
`ServiceLocator.get<FirebaseBlockRepository>()` inside
`AccountDeletionService._deleteBlockRecords` throw "ServiceLocator not
initialized" — caught by the helper's try/catch — and the step silently
lands in `failedCollections` with no residual deletion. Result: a
green-looking test that proves nothing about the block-deletion path.

After the bridge, register typed repos that the cascade resolves via
ServiceLocator (BlockRepository in particular) against the same
`FakeFirebaseFirestore` your seed uses. See
`test/unit/services/account/account_deletion_residual_test.dart` (BUT-671).

---

### 2026-04-30 — production residuals surfaced by BUT-671 (filed for follow-up)

The post-deletion residual test surfaced three real production GDPR
gaps. Each is asserted POSITIVELY in the test (as a tripwire) so a
future fix will turn the assertion red and force a documentation update:

1. **`menus` (top-level) where `sharedByUserId == deletedUid`** is NOT
   wiped by `ContentDeletionOperations.deleteMenus`. That method only
   touches the `users/{uid}/menus` subcollection. The
   `FirebaseDataExportRepository.exportSharedMenusByOwner` query that
   reads top-level menus shared BY the user has no symmetric delete.
2. **`menus.sharedToUserIds` arrays** are not scrubbed of the deleted
   UID on inbound shared menus. The shopping-list cascade has the
   symmetric scrub (`assignedToUserId`/`purchasedByUserId`), but menus
   don't. Means the deleted user's UID lingers in array fields on
   other users' menu docs after Art 17 erasure.
3. **`blocks` field-name inconsistency** — `FirebaseBlockRepository`
   writes/queries `blockedId`; `FirebaseDataExportRepository.exportIncomingBlocks`
   queries `blockedUserId`. They cannot both be right; the export will
   silently return zero incoming blocks. Pick one, migrate, update both.

Worth filing as separate Linear tickets when scope allows. Do NOT fix
in the same commit as the test (per BUT-671 scope guard).

---

### 2026-04-30 — audit-log retention windows (BUT-665)

Documented retention policy for `audit_logs/{id}`:

- **Consent events** (operation startsWith `consent_`): **24 months** —
  Art 7(1) requires controller to demonstrate consent across complaint-
  resolution horizons.
- **General events**: **6 months** — Art 5(1)(c) data minimisation,
  sized to cover SOC2-style incident MTTD (~200 days industry, 180 day floor).

Enforced by `functions/src/audit_logs/purge-expired.ts`
(`purgeExpiredAuditLogs`), Sunday 05:00 UTC, region `europe-west1`.

Implementation note: Firestore can't NOT-IN against a prefix in a query,
so the CF queries by `timestamp < cutoff` once and filters
consent-vs-general client-side. Acceptable because batch size is bounded
(`MAX_DOCS_PER_RUN_PER_CATEGORY = 10000`).

The general bucket runs FIRST so consent events older than 6mo (but
younger than 24mo) are not accidentally purged — the general filter
excludes anything starting with `consent_`. Pinning regression test:
`generalBucketIgnoresFreshConsent` in
`functions/src/__tests__/purge-audit-logs.test.ts`.

Co-exists with the legacy `cleanupOldAuditLogs` (flat 90-day default
from Remote Config) at 03:00 UTC. The legacy CF should be retired once
the new one has been observed for a full retention cycle.

Privacy review: as of 2026-04-30, no production call site to
`logPermissionCheck` / `logTagModification` passes `ip` or `userAgent`
in metadata. Repo-wide grep confirmed. The doc-comment example showing
`{'ip': '192.168.1.1'}` is aspirational. If/when IP/UA capture is
added, the truncation contract (IPv4 -> /24, UA family+major) is
documented in `docs/security/audit-logs-retention.md` Privacy review section.

### 2026-04-30 — Deterministic doc id is the idempotency primitive for daily aggregators (BUT-605)
When a scheduled CF emits one row per (entity, bucket) per UTC day, use
`<entityId>_<bucketKey>` as the doc id and `set()` (full overwrite),
not `add()` with a generated id. Re-running the CF on the same UTC day
becomes a no-op overwrite instead of producing duplicate rows. Pattern
applied in `functions/src/analytics/track-retention.ts` (`<userId>_d<N>`).
**Single-writer invariant** — if a second writer ever targets the same
collection path it will silently last-write-wins; add a comment at the
collection's first writer documenting the single-writer assumption.

### 2026-04-30 — `where('operation', 'not-in', [...])` is the right shape for category-split purge
`purgeAuditCategoryWithDb` currently does `where('timestamp', '<', cutoff)
.limit(10k)` then filters consent vs general client-side. This is
correct for current volume but degrades when one category dominates the
timestamp ordering — the wasted rows are still subtracted from the
per-run budget. Future refactor: use `where('operation', 'not-in', [...consentOps])`
for the general bucket (Firestore allows up to 10 values in `not-in`;
the consent vocabulary is `consent_updated`, `consent_granted`,
`consent_revoked` plus a small headroom). Composite index needed:
`(operation asc, timestamp asc)`. Not urgent — flag during the legacy
`cleanupOldAuditLogs` retirement work.

### 2026-05-01 — `FieldValue.arrayRemove` doesn't survive batched updates in fake_cloud_firestore
While implementing BUT-747 (`_scrubInboundSharedMenus`), used
`batch.update(ref, {'sharedToUserIds': FieldValue.arrayRemove([uid])})`.
The fake-firestore harness silently dropped the transform — the doc
still contained the UID after `batch.commit()` and the residual
tripwire failed. Switched to read-modify-write
(`raw.where((id) => id != uid).toList()` then `batch.update` with the
plain list). Same single-update cost on real Firestore, but the test
fake actually applies it. Same lesson as the `_scrubGroupWeeklyMenuPlans`
note in this file ("dotted-field idiom works on real Firestore but
misbehaves in test fakes; explicit list rewrite is unambiguous").
**Pattern:** for any cross-user array scrub in cascade code, prefer
explicit list rewrites over `FieldValue.arrayRemove` so test fakes
exercise the same branch.

### 2026-05-01 — Field-name canonicalisation between writer + read-only gateway
BUT-748 root cause: `FirebaseBlockRepository` writes `blockedId` (via
`BlockRecord.toFirestore()`); `FirebaseDataExportRepository.exportIncomingBlocks`
queried `blockedUserId`. Production export silently returned zero
incoming blocks for every GDPR Art-15 export ever issued. **No data
migration was needed** because the wrong field was only ever READ —
nothing wrote it. **Diagnostic for similar cases:** grep the literal
field-name string (with quotes) across `lib/` + `functions/src/`. If
the only hit outside the broken reader is the broken reader itself,
no migration is required; the fix is read-side only. If hits include
a writer using the alternate name, plan a migration step.

### 2026-05-01 — Read-only gateway repos: shape-grouping refactor pattern
`FirebaseDataExportRepository` (BUT-740) had 23 near-identical methods,
each `_guardSelfExport → query.limit(n).get() → map → toList`. Three
shapes: A (`[{id, data}]`), B (`[data]`), C (`data?`). Collapsed to
two private helpers (`_queryList(query, userId, resource, {limit,
includeIds})` and `_readDoc(ref, userId, resource)`) plus an
`ExportResourceType` enum to retire 16 stringly-typed `resourceType`
literals. Public method bodies became 3-7 lines of fat-arrow
delegation. Bespoke shapes (shopping-list nested-items, conversations
+ messages join) kept as-is — the helper extraction is for the
copy-paste majority, not every method. **Net:** ~150 lines saved
without behavioural change; data_export_service_test.dart unchanged
and still 16/16 green. **When applying this pattern:** keep the
`includeIds` flag binary (don't add a third "id-only" branch — fork
the helper if a fourth shape appears).

### 2026-05-01 — Recipient self-scrub rule pattern (BUT-747)

When a collection holds shared docs with a `recipients` array (here:
`menus.sharedToUserIds`), GDPR Art 17 erasure requires the recipient
to be able to remove their own UID from foreign-owned docs. Pattern
that landed in `firestore.rules:610-618` for the `menus` collection:

```
allow update: if isAuthenticated() && (
  (request.auth.uid == resource.data.sharedByUserId
    && cannotModify(['sharedByUserId', 'sharedAt']))
  || (resource.data.sharedToUserIds is list
    && request.auth.uid in resource.data.sharedToUserIds
    && !(request.auth.uid in request.resource.data.sharedToUserIds)
    && request.resource.data.diff(resource.data).affectedKeys()
        .hasOnly(['sharedToUserIds']))
);
```

Three guards on the recipient branch:
1. `in` BEFORE — recipient must currently be on the share.
2. `!in` AFTER — recipient must NOT be on the share after.
3. `affectedKeys().hasOnly(['sharedToUserIds'])` — no other field may
   change in the same update.

**Known residual gap (filed as Medium, not Critical):** the rule does
NOT enforce that *other* UIDs in the array are preserved. A malicious
recipient can submit `sharedToUserIds: []` and simultaneously remove
themselves AND boot every other recipient. Owner remains in control
(can re-add) so this is a griefing vector, not data loss. Tightening
would require something like:
`request.resource.data.sharedToUserIds.toSet() ==
 resource.data.sharedToUserIds.toSet().difference(
 [request.auth.uid].toSet())` — feasible in CEL but adds rule cost.
The corresponding `menus-rules.test.ts` coverage explicitly tests
"recipient cannot ADD" (M11) and "recipient cannot remove OTHER while
keeping self" (M12), but does NOT test the simultaneous-self+other
removal case. If you tighten the rule, add an M18 first.

**Important:** the production cascade (`_scrubInboundSharedMenus` in
`content_deletion_operations.dart`) does the right thing — it always
writes `raw.where((id) => id != userId).toList()`, preserving every
other recipient. The rule gap only matters against a malicious
client.

### 2026-05-01 — Production-rule-vs-fake-Firestore lesson (BUT-746/747)

Two distinct sub-lessons surfaced this sprint:

(1) Production residuals are NOT visible to `FakeFirebaseFirestore`
    when the cascade writes against a production-side collection
    (here: top-level `menus`) but the test fake doesn't run the rules.
    The BUT-671 residual test was designed exactly to be a tripwire
    on this — assert positively that the residual exists, so a future
    fix flips it red. Pattern: `_expectMatchingExists` (TRIPWIRE),
    converted to `_expectNoMatching` once the fix lands. Keep this
    file-header comment style (link the ticket, name the cascade
    method, explain why the assert flipped) so the test reads as a
    history of the bug not just a green check.

(2) Cascade code that writes to top-level (cross-user) collections
    MUST handle `permission-denied` separately from transient errors,
    because the rules engine is the *only* line of defense against
    cross-user write bypass. Pattern (verified in
    `_deleteSharedMenusOwnedBy` and `_scrubInboundSharedMenus`):

    ```dart
    } on FirebaseException catch (e) {
      app_logger.AppLogger.error(
          '[$_logTag] Failed (${e.code})', e);
      if (e.code == 'permission-denied') rethrow;
    } catch (e) {
      app_logger.AppLogger.error('[$_logTag] Failed', e);
    }
    ```

    Permission-denied bubbles up so the parent `deleteMenus` returns
    false → entry in `failedCollections` → user-visible deletion
    failure → operator pages a real human. Network/quota gets the
    legacy best-effort swallow (cascade keeps going). The split is
    the difference between "audit log shows we tried" and "audit
    log shows we silently failed Art 17".

    `cloud_firestore` is the right import (top of file already), and
    `FirebaseException` is the type — same one Firestore throws on
    rule rejection in flutter SDK.

### 2026-05-01 — image_format on analytics events is not new fingerprinting (BUT-662)
Tagging `image_format` / `image_format_sent` (`'jpeg'|'png'|'heic'|'webp'|'gif'|'unknown'`) on `import_started` / `import_success` / `extraction_error` events does **not** add fingerprinting surface beyond what's already declared:

- `platform` user property already declares iOS/Android/web — and HEIC is essentially an iOS-only signal that the platform property already covers. `image_format` adds at most a 6-way bucket inside an existing 3-way bucket.
- Format strings are not user-typed and not user-controlled (they come from magic-byte detection on bytes the user just chose to share with the OCR pipeline) — no PII risk.
- The `_piiHashKeys` / `_piiDropKeys` lists in `FirebaseAnalyticsRepository` deliberately do not need to grow for these — they're closed-set enums, not free text or IDs.

Consent gate path for the BUT-662 emit sites:
- `AnalyticsService.logImportStarted` → `ImportEventsTracker.logImportStarted` → `hasAnalyticsConsent()` gate → `repository.logImportStarted` ✅ gated
- `AnalyticsService.logImportSuccess` → `ImportEventsTracker.logImportSuccess` → `hasAnalyticsConsent()` gate → `repository.logImportSuccess` ✅ gated
- `AnalyticsService.logExtractionError` → `ImportEventsTracker.logExtractionError` → **no consent gate** (pre-existing, intentionally exempt as "error tracking" — same as auth events). This was not introduced by BUT-662.

The error-event consent exemption is a standing GDPR question: is "error tracking" a legitimate-interests basis under Art. 6(1)(f), or does it need consent? Current posture: errors are exempt and parameter values are bounded (URL host only, error truncated to 100 chars, error category bucketed, no user content). The new `image_format` parameter does not change that posture — it's a closed-set enum.

`AnalyticsRepository` is a non-Firestore repository (wraps the Firebase Analytics SDK, not a `BaseFirebaseRepository<Model>`). It has no `validateCreatePermission` etc. and is not subject to PermissionValidationMixin — that requirement targets Firestore-backed repos. Don't flag the absence of the mixin here as Critical.

### 2026-05-01 — Algolia EU cluster + analytics-consent gate (BUT-580)
Three concerns settled for any third-party search/analytics processor:

**1. EU cluster invariant (GDPR Chapter V).** `AlgoliaSearchRepository` now
runs an EU-cluster runtime check at construction (NOT `assert`, which would
no-op in release): app id must end in `-eu`. Non-EU app id throws
`ArgumentError` and `SearchModule.initialize()` catches it and stays on
Firestore. Escape hatch `assertEuCluster: false` for shared-cluster apps
where region is verified out-of-band in the dashboard. Pattern applies to
any third-party EU-region service: never trust `assert` for cross-border
guards — it disappears in release builds.

**2. PII in queries.** Audited `searchRecipes`, `searchUsers`,
`getSuggestions` — none pass `userToken`, `clickAnalytics`, or
`analyticsTags`. Grep across `lib/` for those three identifiers came up
empty, confirming no upstream wrapper bundles them. Algolia queries reach
the cluster anonymously. Re-grep on any future Algolia change.

**3. Consent gate placement for analytics-class third parties.** Algolia
search-personalisation lives in the `analytics` consent bucket
(`ConsentPurpose.analytics`). Gate placed in `SearchModule.initialize()`
via a private `_hasAnalyticsConsent(GetIt)` helper that returns `false`
when `ConsentService` isn't registered yet (pre-sign-in) OR when consent
is denied. Default delegate is `FirestoreSearchRepository`, so denied
consent silently falls back — no UI break. Tradeoff: consent granted
*after* startup needs an app restart to flip on Algolia (acceptable in
beta). For future "live consent flip" needs, hook
`ConsentService.onConsentChanged` from the module.

**Test pattern.** Don't try to test `SearchModule.initialize()` end-to-end
— it reads `String.fromEnvironment` (compile-time) and instantiates
Firebase. Test the load-bearing invariant (the constructor's EU check)
directly in `test/unit/repositories/algolia/`. The DI module's role is
just "catch ArgumentError → keep Firestore", which is a one-liner.

### 2026-05-01 — Member-gated collectionGroup queries must run BEFORE membership deletion (BUT-732)

`removeFromSharedContent` in `social_deletion_operations.dart` runs four
queries in sequence — order matters when rules gate reads on
membership:

1. Query memberDocs (`collectionGroup('members').where('userId',==,uid)`).
2. arrayRemove `sharedToUserIds` on parents.
3. **batchDeleteDocs(memberDocs)** ← user loses `isSharedMember` access here.
4. Query engagements (`collectionGroup('engagements').where('userId',==,uid)`).

Step 4 is governed by rule
`allow read: if isAuthenticated() && hasSharedAccess('shared_content', contentId);`
where `hasSharedAccess` = `isSharedOwner || isSharedMember`. Once step 3
deletes the user's `members/{uid}` docs, `isSharedMember` returns false
for non-owned content, so the engagements collectionGroup query
permission-denies on those docs. Firestore aborts collectionGroup
queries on the FIRST per-doc rule failure — so engagement scrub may
silently fail for any user who engaged on non-owned shared content.

**Rule of thumb for GDPR cascades:** when scrubbing across
collectionGroups gated by parent-membership, query EVERY membership-
dependent collection BEFORE deleting the membership rows. Or move the
cascade to a Cloud Function with admin SDK (the BUT-407 pings cascade
runs client-side too but its rule scopes membership differently — pings
read isn't `hasSharedAccess`-gated).

### 2026-05-01 — Legacy `sharedWith` cleanup needs an update permission path (BUT-732)

`removeFromSharedContent` now also runs
`shared_content.where('sharedWith', arrayContains: uid)` and writes
`arrayRemove(uid)`. Problem: `shared_content` update rule requires
`request.auth.uid == sharedByUserId || isSharedMember(...)`. Legacy
docs that ONLY use the flat `sharedWith` array (pre-members
subcollection) have no `members/{uid}` entry — so the user fails
`isSharedMember`, and unless they're the owner the update is denied.
Recipient's read access (`request.auth.uid in sharedToUserIds`) is
get-only, NOT update.

Two options for the fix: (a) add a recipient-self-scrub branch to the
shared_content update rule mirroring the BUT-749 pattern on `/menus/`
(allow update IFF `request.auth.uid in resource.data.sharedWith` AND
the only diff is `arrayRemove(self)` on `sharedWith`), or (b) move the
legacy scrub to a Cloud Function. (a) is consistent with the existing
recipient-scrub pattern; (b) is simpler if legacy data volume is low.

### 2026-05-01 — collectionGroup `engagements.userId` index missing (BUT-732)

`firestore.indexes.json` has no entry for
`collectionGroup: "engagements", fieldPath: "userId"`. The pattern is
established (`members.userId`, `activeUsers.userId` both have
`COLLECTION_GROUP` field overrides). Without it the GDPR cascade
errors with `failed-precondition: query requires an index`. Add to
`fieldOverrides`:

```json
{
  "collectionGroup": "engagements",
  "fieldPath": "userId",
  "indexes": [
    { "order": "ASCENDING", "queryScope": "COLLECTION" },
    { "order": "ASCENDING", "queryScope": "COLLECTION_GROUP" }
  ]
}
```

### 2026-05-01 — Multi-listener pattern for cross-module mid-session signals (BUT-752)

`ConsentService` listener API (`addConsentChangeListener` /
`removeConsentChangeListener`) is the canonical pattern for any
service that needs to broadcast state changes to multiple unrelated
modules. Three invariants the implementation must hold:

1. **Iterate a copy of the list** — listeners may unregister
   themselves during dispatch (`for (final l in List.of(_listeners))`).
2. **Try/catch each listener individually** — one bad listener
   cannot abort sibling notifications (defence-in-depth).
3. **Cache state BEFORE notifying** — `_cachedConsent = consent` runs
   before listener loop, so any listener calling back into
   `hasConsent` sees the new value. No partial-state risk.

**Listener-leak rule.** Modules that are long-lived DI singletons
(`SearchModule`) can register without removing — leaking is bounded by
the DI container's lifetime. Modules with shorter lifecycles
(`FCMService` is also app-scope but disposed on logout in the social
graph) MUST remove in dispose. SearchModule's missing remove is
intentional and correct.

### 2026-05-01 — `:redacted` token in path scrubbing — collision-safe (BUT-692)

`scrubUrlParams` writing literal `:redacted` to opaque path segments
is safe downstream because:
- Threshold for redaction is segment length ≥ 20, so a real `:redacted`
  segment (9 chars) never re-triggers double-redaction.
- Output goes to LLM input (text), no URL parser downstream.
- Dart `Uri.replace(pathSegments:)` correctly percent-encodes; first
  segment `:` is unambiguous because the URL has a verified scheme
  (`parsed.hasScheme` precondition at scrubUrlParams line 65).

No action needed; this is a non-issue.

### 2026-05-01 — Engagements collectionGroup wildcard is the canonical self-scoped GDPR scrub pattern (BUT-732)

`firestore.rules:1552-1554` declares a top-level
`match /{path=**}/engagements/{userId} { allow read: if auth.uid == userId; }`
that is INDEPENDENT of the inner `shared_content/{contentId}/engagements/{userId}`
block at `firestore.rules:542-548` (which gates read on `hasSharedAccess`).

Firestore's permissive-OR semantics across matching path templates mean the
wildcard alone authorizes a `collectionGroup('engagements').where('userId',
isEqualTo: uid)` query — even after the user's `members/{uid}` doc has been
deleted earlier in the same cascade. So order doesn't matter for the
engagement scrub: members-delete then engagement-collectionGroup-query is
fine, no permission-deny race.

**Use this pattern for any future self-scoped scrub where the doc ID equals
the user's UID.** Per-doc deletes go through the direct-path inner rule
(`auth.uid == userId`). No `hasSharedAccess` membership check needed.

### 2026-05-01 — Legacy `sharedWith` array scrub requires admin context (BUT-732)

The flat `sharedWith: [uid, ...]` array on legacy `shared_content` docs
CANNOT be cleaned up from the user-side deletion path. `firestore.rules:515-518`
permits `update` only to (a) the `sharedByUserId` owner or (b) a
member-subcollection participant. A recipient who only appears in the
legacy array has neither, so the call permission-denies server-side.

Cleanup MUST run in an admin-context Cloud Function cascade. The user-side
operation should silently no-op (with a comment block documenting why) and
report success — failing the whole deletion on a doomed legacy update would
strand the user mid-erasure. Test pins the no-op contract: legacy field
stays after `removeFromSharedContent`.

### 2026-05-01 — `engagements.userId` collectionGroup index shape (BUT-732)

Required shape for self-scoped collectionGroup queries on a `userId` field
(matches `members.userId` and `activeUsers.userId` precedent):

```json
{ "collectionGroup": "engagements", "fieldPath": "userId",
  "indexes": [
    { "order": "ASCENDING", "queryScope": "COLLECTION" },
    { "order": "ASCENDING", "queryScope": "COLLECTION_GROUP" }
  ] }
```

Both scopes needed: COLLECTION_GROUP for the cross-parent erasure query,
COLLECTION for any per-`shared_content` doc listing.

### 2026-05-01 — `firestore.rules` untouched ⇒ no `firestore-rules-tester` handoff

When a sprint adds a new collectionGroup query that relies on an EXISTING
rule (here, the `engagements` wildcard at line 1552-1554), the
`firestore-rules-tester` agent is NOT required because no rule branch
changed. Required-marker triggers in CLAUDE.md key on `firestore.rules`
file diff, so a clean diff there means the commit can proceed without a
rules-tester run. Confirmed for BUT-732 commit.

### 2026-05-02 — FCM consent-revoke residual-token gap (BUT-573 follow-up)

`FCMService._revokePushAccess()` deletes the token from three stores:
SDK (`_messaging.deleteToken()`), user profile Firestore doc
(`UserService.clearFCMToken()`), and the FCMService in-memory
`_currentToken` cache. **Gap:** there are TWO local writers — `FCMService`
(memory only) and `FCMTokenManager._saveTokenLocally()` which writes to
`FlutterSecureStorage` under key `'fcm_token'` (BUT-457 hardening).
The revoke path does NOT touch FCMTokenManager's SecureStorage. On revoke
mid-session the SecureStorage copy lingers until next `_refreshToken()`
(which only OVERWRITES, not deletes) or `FCMTokenManager.cleanup()` (only
called on logout — see notification_service.dart line 67 + 114).

GDPR Art. 17 implication: Art. 17 covers **personal data held by the
controller**. The token in SecureStorage is on the user's own device, in
encrypted Keychain/Keystore — arguably not "data held by the controller"
in the strict GDPR sense, and `_messaging.deleteToken()` already
invalidates it on Google's servers so the SecureStorage copy is dead
weight (any push attempt with it would 404). However: defence in depth
says delete it anyway. **Fix in a follow-up:** add a `clearLocalToken()`
on FCMTokenManager that deletes both `_tokenStorageKey` and
`_tokenTimestampKey` from SecureStorage + nulls `_currentToken`, and
call it from `FCMService._revokePushAccess()` (best-effort, same
swallow-and-log pattern). FCMTokenManager is not statically reachable
from FCMService — wire via NotificationService façade, or have
NotificationService listen to ConsentService too and own the cascade.

**Order-of-operations note:** SDK `deleteToken()` BEFORE the Firestore
clear is the correct order. Reverse order would briefly leave a token in
Firestore that's already invalid server-side; if a Cloud Function fires a
push in that window, the send fails noisily (and the token doc is then
cleared). The current order leaves a window where Firestore still has a
valid-looking token but Google has invalidated it — same noisy-fail
outcome, just inverted. Either order is acceptable from a leak standpoint;
current order minimizes "we sent a notification AFTER consent was
revoked" exposure, which is the GDPR-relevant failure mode.

**Test infrastructure pattern (BUT-733):** integration tests that
previously stub-deleted Firestore docs from inside mocktail `then(...)`
side-effects should be migrated to **real repository against
FakeFirebaseFirestore + MockAuthRepository for ownership**. The mocktail
side-effect pattern was "mocking the boundary while replicating the
boundary's behaviour" — proves nothing because the assertion observes
the side-effect, not the contract. Real-repo swap exercises actual
`validateOwnership` (currentUserId from MockAuthRepository.setAuthState
must match resourceOwnerId). **Caveat:** FakeFirebaseFirestore does NOT
enforce `firestore.rules` — so this is an SDK-level permission-mixin
test, not a rules test. For rules behaviour, the `firestore-rules-tester`
agent against the emulator is still authoritative.

**PROMPT_CHANGELOG.md scan pattern:** a new `functions/src/llm/*.md`
documentation file is in-scope for security review even though it has no
executable code. Verify: no embedded API keys, no internal endpoint URLs
(only public Linear ticket URLs are fine), no PII/sample user text from
real prompts. PROMPT_CHANGELOG.md ships clean — only public Linear URLs
(`linear.app/butlery/issue/BUT-XXX`), version constants, and commit
SHAs (acceptable; SHAs are not secrets).

### 2026-05-02 — FCM consent-revoke gap closed (BUT-754, M1 of BUT-573 follow-up)

The residual-token gap flagged in the BUT-573 entry above is closed by
this commit. Implementation chose **option B** from the prior note:
NotificationService owns its own ConsentService listener (parallel to
FCMService's), and calls `_tokenManager.clearLocalToken()` on revoke.
Two reasons B beat A (call from FCMService): (1) FCMTokenManager is a
per-user instance held by NotificationService — FCMService is static
and would need ServiceLocator chasing, (2) the lifecycle ownership is
correct: whoever creates the token manager owns its teardown.

**Verified the residual-store map is exhaustive** (no other on-device
store): canonical = SecureStorage `'fcm_token'` + `'fcm_token_timestamp'`
(BUT-457 hardened); legacy SharedPreferences keys are scrubbed
unconditionally on every init by `_migrateFromSharedPreferencesIfNeeded()`
(lines 409-410 — `prefs.remove()` runs even when there's nothing to
migrate, so a pre-BUT-457 install can never leave a plaintext residue
past the first launch); in-memory = FCMService static `_currentToken`
nulled by `_revokePushAccess` and FCMTokenManager `_currentToken` /
`_lastTokenRefresh` nulled by `clearLocalToken`. Three stores total,
all covered.

**Two-listener ordering is fine for GDPR.** FCMService and
NotificationService both subscribe to the same ConsentService. On
revoke, ChangeNotifier dispatches listeners synchronously in
registration order (Flutter foundation guarantee), but both handlers
are `async` — they return their Futures immediately and run
interleaved on the microtask queue. The two cleanups touch disjoint
state (FCMService = SDK token + Firestore profile + static memory;
NotificationService → FCMTokenManager = SecureStorage + instance
memory), so order doesn't matter for correctness or for Art. 17. Both
gate on `ConsentService.checkSafely(...)` re-reading the consent, so
even if the notify fires before the cache invalidates there's no
spurious clear.

**Topic subscriptions post-revoke are NOT a separate Art. 17 gap.**
FCM topic memberships are bound to the token, not the user.
`_messaging.deleteToken()` (called by FCMService on revoke) makes the
token unknown to Google's servers — the topic ACLs that referenced it
are orphaned and broadcasts to those topics no longer reach the
device. Deferring `unsubscribeFromAllTopics()` to logout/cleanup is a
hygiene-only deferral, not a personal-data leak. The user's reasoning
is correct.

**Listener leak audit:** ConsentService and NotificationService are
both `registerLazySingleton` in the SAME user scope (core_module
`configureUserScope` + messaging_module `configureUserScope`). They're
disposed together when the user scope tears down, so ConsentService
cannot outlive NotificationService. The `_subscribedConsentService`
field guards against double-subscribe across re-init cycles, and
`_disposeModules` removes the listener before nulling. Re-entry
during dispose is safe: `_handleConsentChange` short-circuits on
`_subscribedConsentService == null`.

**Minor: dispose-time race on `_tokenManager` is benign.** During
`resetForLogout()`, the call order is `_tokenManager.cleanup()` →
`_disposeModules()` (which removes the consent listener). If a
revoke fires in that window, `_handleConsentChange` could run
`clearLocalToken` concurrently with `cleanup()`. Both methods only
touch SecureStorage delete (independently atomic) and null the same
instance fields (idempotent), so worst case is a redundant delete and
a duplicate "cleared" log. Not worth a guard.

**Test pattern for in-memory secureStore fakes:** the existing
`fcm_token_manager_test.dart` already uses a `Map<String,String>
secureStore` with stubbed `read`/`write`/`delete`. The new
`clearLocalToken` tests reuse this and assert via
`secureStore.containsKey(...)` — straightforward and the right shape
for verifying the keystore-side contract. No new mocktail boundary
needed.

### 2026-05-02 — BUT-753 legacy sharedWith admin cascade + BUT-577 JSON salvage

**Admin-context cascade pattern (BUT-753):** the canonical shape is now
`cleanup<Thing>WithDb(database, userId)` test seam + thin `cleanup<Thing>(userId)`
wrapper that closes over module-level `db = admin.firestore()`. The cascade
runs inside the existing `onUserDeleted` v1 auth trigger pinned to
`europe-west1` (region inherited — no separate hook), uses
`admin.firestore()` (rules bypassed, which is the entire point — owner-or-member
gate at firestore.rules:515-518 blocks the recipient's own client from
scrubbing their flat-array entry), and chunks at BATCH_LIMIT=500 with
`FieldValue.arrayRemove(userId)` (idempotent — no-op when value absent).
Best-effort wrapper: per-chunk `try/catch` around `batch.commit()` logs
warn + resets the batch + continues. Idempotency guarantees re-run safety,
so partial failure beats total failure. **Test seam contract:** export
`cleanupXWithDb` for the in-memory FakeFirestore stub used by
`__tests__/but753-legacy-sharedwith-cascade.test.ts` (501-doc batching
scenario + `failNextCommit` partial-failure scenario both covered).

**Why a top-level `where("sharedWith", "array-contains", userId)` not a
collectionGroup sweep:** only `shared_content` historically used a flat
`sharedWith` array. A collectionGroup query would burn reads on irrelevant
collections without coverage benefit. Document this reasoning in the test
seam doc-comment so a future agent doesn't "improve" it to a CG sweep.

**JSON salvage parser (BUT-577) DoS analysis:** the quote-aware
`extractTopLevelObjects` in `gemini-client.ts:446-496` is bounded by
input length (single forward pass O(n) over a Vertex AI response capped
by `INGREDIENT_LINE_MAX_TOKENS=1000` ≈ ~4KB). Outer loop and inner loop
both advance `i` monotonically — no nested rescan, no backtracking, no
unbounded recursion. String-state machine handles `\\` escape (skip next
char) and unescaped `"` toggles `inStr`, so `}` inside `"med } i strängen"`
or `"escaped \"quote\" inside"` does not perturb depth. Salvage runs only
on `JSON.parse` failure (cold path), and the input is already
schema-constrained by Gemini's `responseMimeType: "application/json"` +
`responseSchema`. Not a DoS vector.

**Untrusted-input boundary note:** Gemini output is technically untrusted
(model could in principle emit anything), but it's bounded both by token
cap and by the structured-output schema enforcement. The salvage parser
treats it as adversarial anyway (no eval, no Function ctor, no regex
backtracking — ReDoS-clean since the only regex `/^\{\s*"ingredients"\s*:\s*\[/`
is anchored and bounded).

**ADR-001 inline cross-reference pattern (BUT-566):** the catch handler
in `structure-recipe.ts:316` carries a comment block that names the ADR,
points to the Dart-side single retry layer (`llm_tier.dart:120-128`,
`RetryHelper.retryNetworkOperation, maxRetries: 2`), and explicitly
forbids server retry. Comment is correctly worded — "Do NOT add
retry/loop logic here — stacking server retries with client retries
multiplies Gemini API load under the same rate-limit window." This is
the right shape: it states the contract AND the failure mode, so a future
agent reading "fix transient errors" won't quietly add a retry loop.

**Best-effort vs all-or-nothing for GDPR cascades:** for Right-to-Erasure
the legal obligation is "delete on request without undue delay." Partial
deletion that re-runs on the next trigger satisfies "without undue delay"
better than total-failure-then-retry. Best-effort + idempotency is the
correct trade-off — and the integration test exercises this explicitly
(`scenario_failedChunkContinues` arms `failNextCommit=true` on the first
of two chunks and asserts the second still commits + total returned
matches all queued docs). Test coverage is sufficient.

---

### 2026-05-04 — LLM enum-drift logging: bound rawValue length (BUT-546)

When emitting `logger.warn` for closed-domain enum drift from LLM responses
(e.g. `validateDifficulty` in `functions/src/llm/gemini-client.ts`), the
`JSON.stringify(value)` fallback for non-string `value` is **unbounded**.
A regressed Gemini response could put a nested object in the `difficulty`
slot and inflate Cloud Logging size/cost. The rest of the diff is fine:

- **PII**: `rawValue` is a closed-domain enum slot, not free-text. Even if
  Gemini drifts to a string, drift values are model vocabulary
  ("advanced", "challenging"), not echoes of user-uploaded recipe text.
  Schema-enforced output makes PII regurgitation in this specific field
  effectively impossible. Same posture as the existing error-logging
  precedent (URL host only, errors truncated to 100 chars, closed-set
  enums) — consistent.
- **Cost**: warn-level logs are persistent in Cloud Logging. Drift events
  are rare (only on prompt regressions or model swaps), so volume is fine
  — but each event being unbounded in size is the actual risk.
- **Fix**: cap the stringified value at ~200 chars before logging:
  `rawValue: (typeof value === "string" ? value : JSON.stringify(value)).slice(0, 200)`
  Same pattern as the 100-char error truncation already in use elsewhere.

Pattern for future LLM observability: enum-drift telemetry is fine; always
bound the raw payload length even when the field is "supposed to be" small.

### 2026-05-04 — `scrubUrlParams` fragment preservation has a transmission-path caveat (BUT-534)

The BUT-534 change preserves URL fragments in both Dart (`pii_scrubber.dart:73`)
and TS (`pii-scrubber.ts:137`) scrubbers, justified by "fragments aren't
transmitted to servers" (RFC 3986 §3.5).

That justification is correct ONLY for HTTP fetches. It is FALSE for the
actual call paths:
- `llm_service.dart:295` passes scrubbed URLs as JSON string fields to
  `httpsCallable` — fragments travel verbatim to Cloud Functions, into
  Cloud Logging (the threat model called out in `pii_scrubber.dart:3-6`),
  and then interpolated into Gemini prompts at `structure-recipe.ts:199/203/211`.
- Server-side `scrubUrlParams` output also feeds Vertex AI prompts.

Residual mitigation: `_scrubValue` runs `scrubPii` AFTER `scrubUrlParams`
(`pii_scrubber.dart:129`), so email/phone/personnummer in fragments are
still caught. The gap is opaque tokens / SPA-router style fragments
(`#token=...`, `#/user/123/recipe/456`).

Rule: when reviewing scrubber changes, trace BOTH the URL-as-target path
AND the URL-as-data-field path. The "fragments don't transmit" axiom
applies only to the former.

Proposed enhancement (not yet applied): split fragment content on `/` and
`&`, run `_looksOpaquePathSegment` over each chunk — keeps `#ingredienser`
intact while stripping opaque tokens. Parity required between Dart and TS.

### 2026-05-04 — BUT-765 closes the BUT-534 fragment-token leak (verified)

Follow-up to the previous entry. BUT-765 added `_scrubFragment` (Dart
`pii_scrubber.dart:99-103`) and `scrubFragment` (TS `pii-scrubber.ts:132-136`)
with identical decision contract:

1. `fragment.length < 16` → return as-is (preserves `#ingredienser`, `#method`).
2. UUID-shaped whole fragment → `:redacted` (catches
   `#550e8400-e29b-41d4-a716-446655440000`).
3. Otherwise replace each 16+ char `[A-Za-z0-9]{16,}` run with `:redacted`
   (catches `#token=eyJhbGc...{long}...` → `#token=:redacted`).

Parity verified: same regex source (`[A-Za-z0-9]{16,}`), same UUID layout,
same length threshold, same replacement token. Threading is symmetric — TS
goes via `parsed.hash.slice(1)` then re-prefixes `#`; Dart uses
`Uri.replace(fragment: ...)`.

Known residual (acceptable): JWT segments containing `_`/`.` outside the
alphanumeric class break the run, so the trailing fragment of a JWT after a
`_` shorter than 16 chars survives (e.g. `_adQssw5c`). This is fine — that
tail alone is not the secret material; the signing-input segments before
the dots are the sensitive part and they redact wholesale. The 16-char floor
is also required to avoid scrubbing meaningful fragment anchors.

Rule reinforcement: when adding scrubber logic to a defence-in-depth pair,
always verify the regex SOURCE STRING is byte-identical between Dart and TS
— Dart raw strings (`r'...'`) and TS regex literals diverge subtly on
backslash handling, and the `caseSensitive: false` flag in Dart vs the `i`
flag in TS must be set on the same regex instances.

### 2026-05-04 — Analytics `'timestamp'` parameter removal is GDPR-neutral (BUT-518)

Removed 9 redundant `'timestamp': clock.now().toUtc().toIso8601String()`
emissions from `firebase_analytics_repository.dart` (importStarted,
importSuccess, extractionError, manualCopyFallback, recipeCreated,
recipeShared, recipeCooked, menuGenerated, recipeDeleted).

Why GDPR-neutral:
- Firebase Analytics auto-stamps every event with a server-side
  `event_timestamp_micros` field independent of any client param.
- Grep across `functions/src/` and `lib/` confirms NO consumer reads
  `params.timestamp` from these analytics events. (The `params['timestamp']`
  hits in `deep_link_service.dart` are deep-link query params, unrelated.)
- The removed param never landed in Firestore, never in audit logs, never
  in user-controlled storage — only in Firebase Analytics' own pipeline,
  which keeps server timestamps regardless.
- `recipeDeleted` retains `'created_at'` (a past-action timestamp meaningful
  for cohort analysis) and only drops the now-time `'timestamp'`. Correct
  asymmetry: `created_at` is data about the deleted entity, `timestamp` was
  redundant with the auto-stamp.

No data-deletion-flow regression: GDPR account-delete already wipes the
Firebase Analytics user via `setAnalyticsCollectionEnabled(false)` +
`User-ID` reset; reducing per-event redundant fields shrinks the surface,
not grows it.

Rule for future analytics-schema reviews: removing client-emitted timestamp
params from Firebase Analytics is always safe; ADDING them is the smell —
they duplicate the platform auto-stamp and create joinable identifiers if
combined with high-cardinality fields.

### 2026-05-04 — `.limit()` defence-in-depth on bounded live streams (BUT-478)

Second sprint in a row a `.limit()` was added purely as defence-in-depth
on a snapshots() stream where the data is naturally bounded by the
business model (BUT-484 was the recipe watcher cap last sprint; BUT-478
is the friend_categories stream and menu_voting watch this sprint). The
pattern has earned a name and a rule.

**The rule: every `.snapshots()` chain in `lib/repositories/` must end
in a `.limit(N)` clause.** Even when the collection is "obviously" small.
The justification is purely defence-in-depth:

1. There is no UI cap on how many docs a user (or a writer with rule
   permission) can produce — the model contract may say "typical user has
   <20 categories" but nothing in code or rules enforces that. A bug, a
   bulk import, or an adversarial peer that has rule-level write access
   (e.g. members of a shared group) can produce arbitrary growth.
2. A `snapshots()` listener pays full snapshot cost on every change. An
   unbounded watch on a 10k-doc collection costs 10k reads on first
   attach and re-reads the whole resultset on resort/filter operations.
3. `.limit()` capping at "an order of magnitude above the realistic
   ceiling" is free in normal operation (the limit never trips) and
   bounds the worst case to a known constant.

**Sizing heuristic (validated 2x now):**
- Per-user bounded surface (friend categories, owned recipes, owned
  shopping lists): `.limit(100)`. Real users have <20.
- Per-group bounded surface (group voting, group menu slots, group
  members): `.limit(200)`. Real groups have <30 members and <10 active
  votes.
- Per-thread bounded surface (chat messages in a single conversation):
  paginate, don't `.limit()` to a constant (use BUT-484 cursor pattern).
- Cross-user collection-group queries (`fetchMemberCategories`,
  collection-group friend lookups): `.limit(200-500)` and accept that
  the upper bound is the right defence — collection-group size is
  unbounded by design.

**Sizes BUT-478 chose and the reasoning:**
- `friend_category_repository.categoriesStream`: `.limit(100)` — owned
  categories, per-user surface, typical <20.
- `firebase_menu_voting_repository.watchVotesForMenu`: `.limit(200)` —
  votes are bounded by group size × open vote slots, typical <50.
- `friend_category_repository.memberCategoriesStream`: `.limit(200)` —
  collection-group query where the user is a member; correctly higher
  than the owned stream because membership can fan out.

**What the limit does NOT replace:**
- It is NOT pagination. If the cap is genuinely reachable in normal use,
  the fix is `loadMore`-style cursor pagination (BUT-484 pattern), not
  a bigger `.limit()`.
- It is NOT a permission check. The repository's `validateRead` /
  Firestore rules still own who-can-read. `.limit()` only bounds the
  payload size for legitimate-but-pathological cases.

**Review heuristic when reading repository diffs:**
- Find `.snapshots()` (or `.snapshots(includeMetadataChanges:`).
- Walk the chain backwards. If there is no `.limit(...)` before the
  `.snapshots()`, that is a finding. Severity = High if the collection
  has any writer that's not strictly the current user; Medium otherwise.
- Don't gate on "is the collection currently small" — the point is
  bounding the worst case, not the median case.

This is an append-only rule for future repository review: assume every
new `.snapshots()` without `.limit()` is a regression unless the diff
explicitly justifies why the writer-set guarantees boundedness.

### 2026-05-04 — DI auth-state read goes through PermissionService, not FirebaseAuth.instance (BUT-510)

`lib/core/di/di_container.dart` Step 2.5 (user-scope-restoration on cold
boot when Firebase has a persisted session) used to read
`FirebaseAuth.instance.currentUser` directly. BUT-510 routed it through
`PermissionService.currentUserId` with an `isRegistered<PermissionService>()`
guard.

**Why it's a security-neutral but correctness-positive change:**
- The auth state being read is identical — `PermissionService` is just a
  thin wrapper exposing `currentUserId` from the same FirebaseAuth
  instance. No new attack surface, no new GDPR surface, no new
  data-source split.
- It enforces the project convention that **only PermissionService is
  the canonical auth surface for app code.** Direct `FirebaseAuth.instance`
  reads scattered across the codebase are a code-quality smell because
  they bypass the seam that mocking and testing rely on.
- The `isRegistered` guard is the right shape for boot-time code: minimal
  test setups (rule-tester harnesses, narrow widget tests) instantiate
  the container without ContentModule, where PermissionService lives.
  Defaulting `hasPersistedUser = false` in that case is correct — those
  tests never have a real user session to restore.

**Pattern for future similar refactors:** any code path reading auth
state outside `lib/services/permission_service.dart` itself should go
through ServiceLocator/DI to fetch PermissionService. The two exceptions
are (a) PermissionService's own implementation and (b) the
FirebaseAuthRepository wrapper — both legitimately wrap the
SDK-level surface.

**Review heuristic:** grep for `FirebaseAuth.instance.currentUser` outside
those two files. Each hit is a Medium finding (correctness/testability),
upgrade to High if the call is in a security-critical decision path
(permission gate, audit log identity, data-export ownership check).

---

### 2026-05-04 — Two consumers of `system/config` have asymmetric fail-modes

The single Firestore doc `system/config` is read by two independent code paths
in functions/src/. They handle "Firestore unreachable" differently — note this
when reviewing changes to either:

1. **Kill switch** (`structure-recipe.ts` `defaultLoadKillSwitch`,
   `runStructureRecipe` outer try/catch at line 335). A Firestore error
   propagates out of the loader and is converted to an `internal` HttpsError
   by the outer catch. **Net: fail closed for the user** (request denied) —
   so operator overrides cannot be silently bypassed by an outage.

2. **Global rate limits** (`rate_limiter.ts` `loadGlobalLimits` at line 302-333).
   A Firestore error is **caught inside the loader**, warn-logged, defaults
   (1000/10000) applied. The caller proceeds normally with the default cap.
   **Net: fail open against operator overrides** — if ops set tighter caps
   during an incident and Firestore reads start failing, cold-start instances
   silently revert to defaults (warm instances keep their cached value).

This is acceptable because (a) `aiEnabled=false` total kill is the primary
incident lever and lives in path #1, (b) global caps are coarse and the
defaults are conservative, (c) a real Firestore outage breaks the
`system/llmLimits` write in `checkGlobalLimit` anyway. But when reviewing
either loader, ask: "would the new behavior change preserve this fail-mode
asymmetry intentionally?" — flipping #2 to fail-closed could deny all LLM
traffic during a Firestore blip, flipping #1 to fail-open could let
operator-killed AI silently restart.

### 2026-05-04 — Module-scope cache lifetime in Cloud Functions

`rate_limiter.ts` `cachedGlobalLimits` is module-scope, never invalidated.
Lifetime equals warm instance lifetime. Runbook (llm-kill-switch-runbook.md)
says "~30 minutes typical" — this is optimistic. In practice Cloud Functions
warm instances live ~15 min idle but several hours under sustained traffic.
Operators flipping caps during a real incident should expect some warm
instances to keep serving the old value for an hour. The kill switch
(`aiEnabled=false`) bypasses this entirely because it gates upstream of
`checkGlobalLimit`. When reviewing similar module-scope caches in the
functions/ codebase, prefer either (a) sub-minute TTL backed by Firestore
read amortization, or (b) explicit "redeploy to refresh" documentation —
not silent indefinite caching.

### 2026-05-04 — admin-only collections need EXPLICIT deny rules + retention coverage (Sprint G review)

Sprint G (BUT-482/483/627) introduced two new server-side collections:
- `audit/ping_rate_limit/entries/{auto}` — written by `ping_onCreate`
  trigger when an over-cap ping is deleted.
- `_internal/rating_debounce/markers/{recipeId}` — debounce markers
  written by `scheduleRatingAggregation`.

Both are admin-only by design. Both are *implicitly* admin-only via
Firestore default-deny. Convention in this codebase is to write an
**explicit** `allow read, write: if false;` for admin-only collections —
see `deletion_audit_logs/{logId}` (rules:434) and `audit_logs/{logId}`
(rules:1378, BUT-424). Reasons:
1. Intent is auditable — grep shows the deny is deliberate, not an
   oversight.
2. A future broad collection-group or wildcard rule can accidentally
   widen access to a default-deny collection. Explicit deny pins the
   ceiling.

**Action when adding a new admin-only collection:** write an explicit
`match` block with `allow read, write: if false;` even though
default-deny would have the same runtime effect.

**Adjacent finding — retention gap:** `audit/ping_rate_limit/entries`
stores `userId` of rate-limit violators but has no purge job. BUT-665
covered `audit_logs/{id}` retention via
`functions/src/audit_logs/purge-expired.ts` but the new `audit/`
top-level collection is not covered by that purger. Pattern: every
new audit-style collection that contains user identifiers must be
listed in the BUT-665 retention sweeper or carry its own `expiresAt`
+ sweeper. Otherwise GDPR Art-15 exports + Art-17 erasure become
incomplete and rows grow unbounded.

**Naming distinction worth noting:** `audit_logs/` (single underscore
collection) is the canonical user-action audit trail with
documented retention. `audit/` (Sprint G addition) is a different
top-level collection with subcollections per category
(`ping_rate_limit/entries`). Don't conflate the two when writing
purgers or rules — each needs its own match block and its own
retention coverage.

---

### 2026-05-04 — Denormalised PII pairs travel together (BUT-466 audit)

`shared_content` docs carry BOTH `sharedByDisplayName` AND
`sharedByAvatarUrl` (written by `recipe_sharing_manager.dart:531-534`,
rendered by `shared_content_card.dart:130-133`). When BUT-466 added a
tombstone cascade for `sharedByDisplayName` in step 12 of
`cleanupUserSocialData`, the avatar URL was missed — recipient UIs
will continue rendering the deleted user's face next to "[Raderad
användare]" after Art 17 erasure. Avatar URLs are themselves linked
PII (Firebase Storage paths or external photo URLs).

**Pattern: when tombstoning denormalised author/sharer metadata,
audit the writer for ALL fields prefixed with the same noun
(`sharedBy*`, `authorName*`, `createdBy*`, etc.) — they're typically
written together and must be cleared together.** Use
`FieldValue.delete()` for the avatar (no neutral string fits) and a
locale-aware tombstone for the name. Idempotency check must verify
ALL fields, not just one.

**Tripwire pattern:** for every new denormalised-PII tombstone
cascade, add a positive assertion in
`account_deletion_residual_test.dart` (BUT-671 style) that fails the
day someone adds a fourth `sharedBy*` field without extending the
cascade. The test should iterate the full set of denormalised fields,
not just the one being added.

---

### 2026-05-04 — Symmetric-difference CEL idiom for self-only set edits (BUT-464)

Pattern that landed in `firestore.rules:333-352` for
`users/{userId}/friend_categories/{categoryId}` non-owner-member
updates:

```
request.resource.data.friendUserIds.toSet()
  .difference(resource.data.friendUserIds.toSet())
  .union(resource.data.friendUserIds.toSet()
    .difference(request.resource.data.friendUserIds.toSet()))
  .hasOnly([request.auth.uid])
```

Reads as: "the symmetric difference of before-state and after-state,
when treated as sets, must be a subset of [auth.uid]." Equivalent to
"only the requesting user's UID may have moved in or out."

**Coverage matrix (verified by reasoning, not yet tests):**
- self-add: `(A\B)={uid}, (B\A)=∅` → pass
- self-remove: `(A\B)=∅, (B\A)={uid}` → pass
- no-op: symdiff=∅, `hasOnly([])` is true → pass (harmless)
- foreign-add: symdiff={foreignUid} → fail
- foreign-remove: symdiff={victimUid} → fail
- self+foreign in same write: symdiff={uid, foreignUid} → fail
- self-swap (remove self, add foreign): symdiff={uid, foreignUid} → fail

**When applying:** combine with `affectedKeys().hasOnly([…])` (already
done in BUT-464) so a malicious member cannot piggy-back arbitrary
field writes onto a legal self-edit. Hand off to
`firestore-rules-tester` to add explicit emulator tests for all seven
matrix cells when the rule is non-trivial — reasoning passes are not
substitutes for emulator-verified behaviour.

**Limitation worth documenting:** because the gate uses
`isInList('friendUserIds')` against `resource.data` (BEFORE state), a
non-member cannot self-add. If a future flow needs "accept invite
without owner write," this rule will reject it — add an invite-token
branch then.

---

### 2026-05-04 — Comment line-number drift in cascade code

`on-user-deleted.ts:143` (BUT-466) references `firestore.rules:515-518`
for the `shared_content` update gate; actual location post-BUT-659 is
`firestore.rules:554-557`. Lines 515-518 are now the friend-request
create rule (account-cooldown). Pattern: comments that pin specific
firestore.rules line numbers go stale every sprint. **Prefer
referencing the rule by collection path + rule type ("the
`shared_content` update gate") rather than line number.** When a line
number is genuinely needed for a code-review breadcrumb, add a
trailing comment so future grep can find it: `// see
firestore.rules match /shared_content/{contentId} allow update`.

### 2026-05-04 — sprint-I review: static test seams, FirestoreBootstrap parity, consent renewal data source

- **Static-class test seams (FCMService BUT-446):** when an all-static
  service can't take constructor injection, the
  `static FirebaseMessaging? _messagingOverride` + `_getMessaging()` fallback
  + `@visibleForTesting setMessagingForTest` pattern is acceptable. Risks:
  (1) `@visibleForTesting` is analyzer-advisory only (Dart doesn't enforce),
  so a malicious or accidental production caller in the same package
  *could* set the override — accept this since the package is solo-dev'd
  and the analyzer warning is enough; (2) the override is process-global
  static state, so parallel tests must serialize or each `tearDown` MUST
  call `setMessagingForTest(null)` to avoid cross-test bleed. Document
  the tearDown contract in the test file.
- **Bootstrap parity (BUT-506 FirestoreBootstrap):** the extracted helper
  preserves the original error-string filter exactly (`INTERNAL ASSERTION` ||
  `Unexpected state`) and the outer try/catch swallow for "settings
  already applied" on hot restart. The web-only `kIsWeb` guard around
  `_recoverWebPersistenceIfCorrupted` is correct — `clearPersistence()`
  on native platforms requires the SDK to be terminated first AND has
  different semantics. Pattern is reusable for other startup-side
  Firestore configuration extractions.
- **Consent renewal data source (BUT-465):** for the renewal *gate* check
  at app startup, reading `userService.currentUserId` is correct because
  the renewal version comparison needs only the auth identity (the
  consent doc keys off uid), not the profile payload. The
  `permissionService.currentUserId` rule applies when doing
  permission/ownership checks; reading auth identity for a "do I have a
  user at all?" gate is fine via UserService since UserService already
  exposes `currentUserId` as a thin auth passthrough. The actual save in
  `ConsentService.saveConsent` re-stamps `consentVersion` (consent_service.dart:111)
  and the FirebaseConsentRepository writes the audit log on the
  repository side (per consent_service.dart:223 comment) — GDPR Art. 30
  trail intact.
- **Auth race in post-frame consent dialog:** `_initializeConsentRenewalCheck`
  reads `currentUserId` once, then awaits `needsConsentRenewal()` which
  itself reads userId again inside `getUserConsent`. If the user signs
  out between those calls, the dialog can still be scheduled via
  postFrameCallback. The dialog itself re-reads consent state before
  saving, so the worst case is a dialog flash for a logged-out user —
  no data leak, but UX nit. Acceptable; document as a known minor race.

### 2026-05-05 — Recipe repo facade extraction (BUT-536)
Three modules carved out of `firebase_recipe_repository.dart`:
`RecipeTagOperations`, `RecipeQueryOperations`, `RecipeGdprExportOperations`.
Pattern verified safe:
- Modules take `String? userId` as parameter rather than reading auth
  state. Repo wrapper passes `currentUserId` (nullable getter). Each
  module method early-returns the empty/zero response on null userId,
  preserving the original "unauthenticated → empty list" semantics
  rather than throwing a Firestore PERMISSION_DENIED.
- All collection access goes through the injected `getCollectionForUser`
  callback — no module can construct a path to another user's
  subcollection. `findBySourceUrl`/`findByTitle`/`fetchRecipesByTagId`
  scope by `getCollectionForUser(userId)` only.
- GDPR module receives `requireCurrentUserId` + `validateOwnership` as
  injected callbacks, and both export methods call `validateOwnership(
  currentUserId: requireCurrentUserId(), resourceOwnerId: userId, ...)`
  BEFORE any Firestore read. The mixin's `validateOwnership` throws
  `PermissionDeniedException` on null currentUserId or mismatch — so
  cross-user export is structurally impossible. Modules are private
  `late final` fields; callers can only reach them via the repo.
- Tag-cascade write paths preserve identical Firestore mutations
  (`FieldValue.arrayRemove([tagId])` + filtered `core.personalTags`
  rebuild). No new write surface, no security-rule implications.
- `validateOwnership` in this codebase does NOT itself emit a
  `logPermissionCheck` audit entry — it only logs a warning on
  mismatch. The CLAUDE.md "every custom permission check must call
  logPermissionCheck" rule applies to the four base validate*Permission
  hooks, which are unchanged here. GDPR export delegates remain
  audit-equivalent to pre-extraction.

---

## 2026-05-06 — BUT-781 / BUT-770 / BUT-773 / BUT-769 sprint review

### Pattern: rate-limit sentinel collections must charge an extra read per create
- /reports create rule uses `exists()` + `get()` against
  `/users/{reporter}/report_throttle/{ownerId}`. Each such rule
  evaluation is billed as 1 doc read; `exists()` then `get()` is two
  reads if both fire. Here the rule shortcircuits with `!exists() ||
  ...get().data...` which still costs 1 read for the exists, plus 1 for
  the get when present — so steady-state legitimate flow is 2 reads per
  /reports create. Acceptable for moderation, but document it on any
  future high-frequency collection.

### Pattern: `request.time` + `duration.value` is the canonical "now − X" check
- `request.time - duration.value(24, 'h')` is the right idiom for rules
  rate-limit windows. Server-time comparison; no client clock skew.
  `request.resource.data.lastReportAt == request.time` on the throttle
  write enforces the same server clock, so the next-create rule reads a
  trustworthy timestamp.

### Pattern: deny-orphan-self-throttle even if parent rule already covers it
- The /reports rule blocks self-reports independently. The throttle
  rule still blocks `ownerId == request.auth.uid` writes — keeps the
  collection structurally clean and avoids "junk doc" grooming work.

### Pattern: subcollection rules must be explicit (no parent inheritance)
- realtime_menus/{menuId}/votes had no rule block before BUT-773;
  default-deny silently masked the missing rule. Whenever a new
  subcollection is added, search for its path in firestore.rules — a
  missing match block is *the* most common rules bug because the
  failure mode is "feature silently broken" not "crash".

### Pattern: `audit_logs` Article-15 export via callable
- audit_logs is admin-only at the rules layer (BUT-424 invariant: a
  compromised account that could read its own log could craft attacks
  around the gaps it sees). Article 15 is satisfied via Admin-SDK
  callable `exportAuditLogs` (functions/src/exports/audit-logs.ts).
  Server-side admin reads on behalf of `request.auth.uid` only — the
  rules invariant is preserved because no user-side direct read path
  was added.
- No App Check on this callable. Rationale documented in the source:
  authenticated session already passed App Check at sign-in; second
  gate doesn't raise the bar against the "user reads their own data"
  threat model. If App Check enforcement becomes mandatory across the
  board (future ops decision), revisit.
- Cursor pagination is server-timestamp-based with `startAfter` on
  `desc` order. Risk: two rows with identical timestamps would get the
  pagination boundary tied to a single timestamp value — `startAfter`
  would skip subsequent rows with the exact same timestamp on the next
  page. In practice audit log writes are server-timestamped on append
  and conflict-resolution is millisecond-fine, so collisions are
  essentially zero. If high-throughput admin-action audit becomes a
  thing, switch to `startAfterDocument(snapshot)` with a doc-id
  tiebreak.

### Pattern: cert pinning fail-loud needs a `throw`, not `assert`
- `assert` is stripped in release. BUT-769 wires a runtime
  `StateError` via `CertPinConfig.assertReleaseModeSafety()` gated on
  `kReleaseMode`. Called before `Firebase.initializeApp` in
  `lib/main.dart`. Debug/profile skipped — devs run with empty pin
  maps regularly.

### GDPR cascade: anonymize, don't delete, when the row is also someone else's evidence
- BUT-781 step 13 anonymizes /reports rows where deletedUid ==
  contentOwnerId. Rationale: the report is the *reporter's*
  Article-15 evidence. Deleting it would erase the reporter's record
  while satisfying the deletee's Article 17 — net negative for the
  reporter. Anonymization (contentOwnerId → null +
  contentOwnerAnonymizedAt tombstone) preserves both rights.
- Generalize: any document that is jointly authored / has
  cross-subject GDPR claims should anonymize the deletee's identifiers,
  not delete the row.

### 2026-05-06 — Storage moderation CF: shouldReplaceLastMessage `>=` is correct for edit-refresh
- BUT-778 server-side conversation lastMessage sync uses `candidate.sentAt.toMillis() >= current.sentAt.toMillis()` so an edit (same sentAt as the original) overwrites the stored snapshot. Strict `>` would silently drop edit-refresh when the original message is still the lastMessage — a real footgun. Idempotent because the projection of the same id+sentAt+content is identical.
- TOCTOU on the delete-recompute path is closed by reading the replacement query inside the same `runTransaction` (read-then-write atomic). Required index `messages(conversationId ASC, sentAt DESC)` is present in firestore.indexes.json.

### 2026-05-06 — Storage upload moderation: fail-open is acceptable when the rule layer is the actual gate
- BUT-780 `moderate-upload.ts` returns silently when `bucket.file(name).download()` throws. Defensible because `storage.rules isValidImage()` is an explicit allow-list (jpeg/png/webp/heic/heif) — the CF only catches MIME spoofing past the rule, never the rule's own invariants. Worst case on download failure: the spoofed-bytes-but-allowed-MIME object survives + no audit row. Mitigation note: ops should monitor `[moderateUpload] failed to read head bytes` warning rate; spike = either bucket permission drift or systematic abuse worth investigating.
- Rule + CF must keep MIME allow-list in sync. Document this contract in BOTH files (already done via mirrored comment).

### 2026-05-06 — `enforceAppCheck` on Firestore/Storage triggers
- `enforceAppCheck` is only meaningful on **callables** and HTTPS endpoints (where a client token is presented). For `onObjectFinalized` / `onDocumentWritten` background triggers, the invocation source is GCP itself — there is no client token to enforce. App Check belongs on the *write path* (callable that produces the trigger event), not the trigger handler. Don't add it to triggers.

### 2026-05-06 — `storage_upload_rejected` audit-log shape (keep PII out)
- Pattern: `userId` = uploader uid (or "unknown" when neither metadata.uploadedBy nor a `users/{uid}/...` path prefix yields one), `operation: 'storage_upload_rejected'`, `granted: false`, `metadata: { bucket, contentType, reason }`. Reason codes: `unsupported_content_type`, `magic_byte_unrecognized`, `magic_byte_mismatch_declared_X_actual_Y`. **No** filename body, **no** byte previews — `resourceId` is the object path (`users/{uid}/recipes/abc.jpg`) which already contains the uid by convention; that's intentional and matches every other audit row's resource format.
- Anonymous-upload edge case: when a malicious actor finds a path that's neither `users/{uid}/...` nor has `metadata.uploadedBy`, `userId='unknown'` is the right tombstone — refusing to write the audit row would be worse (silent rejection). Storage rules currently only permit writes under `users/{uid}/...`, `shared/recipes/{recipeId}/` (uploadedBy required), and `feedback/{uid}/...`, so `unknown` should be effectively unreachable in production; treat any occurrence as a signal of rule drift or admin-SDK upload.

### 2026-05-06 — SDK-state mirror flags: symmetric fail-closed + replay-on-enable

**Pattern:** repositories that mirror an SDK's internal consent/state flag locally
(because the SDK doesn't expose its own state — Firebase Analytics' collection-enabled
is the canonical case; `FirebaseAnalyticsRepository._collectionEnabled` does this for
BUT-786/BUT-803) must handle two failure modes asymmetrically:

1. **Enable path (deny → allow):** only flip the local mirror **after** the SDK
   call succeeds (fail-closed on enable failure — caller is denied until next try).
2. **Disable path (allow → deny):** flip the local mirror **before** the SDK call
   (fail-closed on disable failure — withdrawal is GDPR Art. 7(3); a silent
   SDK-throw must not leave the consent-gated channel open).

**Companion requirement — replay on enable:** any value cached/dropped during the
deny window (e.g. a `setUserId(uid)` call suppressed pre-consent) must be replayed
to the SDK when the local mirror flips to allow. Otherwise the cold-start race
(auth listener fires before consent flip lands) produces a permanent silent drop
until the user signs out and back in.

**Anti-pattern:** placing the local flag mutation outside the `try` block on enable
(opens the channel even when the SDK refused) or inside the `try` block on disable
(leaves the channel open when the SDK throws on revoke).

**Where to apply:** any future telemetry/Crashlytics/Performance/Remote-Config
repository that gates user-tied calls on a locally-mirrored consent flag.

### 2026-05-08 — commitInChunks helper (BUT-816): best-effort vs strict semantics

**Where**: `functions/src/shared/batch-update.ts` adds `commitInChunks(db, items, mutate, {label, strict?})`. Refactor in `functions/src/cleanup/on-user-deleted.ts` migrates 3 GDPR cascade sites.

**Semantics map** (must preserve when reviewing future call sites):
- BUT-466 sharedByDisplayName tombstone — best-effort (`strict` omitted). PII-clean is monotonically idempotent; chunk failures retry on next deletion run.
- BUT-647 notification queue purge — `strict: true`. A partial purge would leave PII-bearing notification rows; cascade abort + retry is the correct contract.
- BUT-781 report contentOwner anonymize — best-effort. Same idempotence rationale as BUT-466.

**API safety**: helper does not select refs or scope queries; mis-use can only happen if a caller hands it a cross-tenant `items` list. Same risk surface as raw `db.batch()`. The mandatory `opts.label` self-identifies every chunked op in logs — good defensive design; keep it required.

**Counting contract**: returns `queued` (items enqueued), not commits succeeded. Matches the prior implementations' "matched and attempted" metric. Don't change to "commits succeeded" without auditing callers — at least the cascade-result reporter uses this count for GDPR-compliance audit lines.

### 2026-05-08 — timestampProvider as test seam in repos: established pattern, not a bypass

`firebase_report_repository.dart` adding `super.timestampProvider` in its ctor and routing `lastReportAt` through `timestampProvider.serverTimestamp()` is the same pattern already in `firebase_comments_repository`, `firebase_deeplink_repository`, `firebase_device_repository`, etc. Default is `ServerTimestampProvider()` → `FieldValue.serverTimestamp()` in prod. No permission/audit bypass — `BaseFirebaseRepository`'s validate*/audit hooks are unchanged. When you see this added to a repo for tests, it's safe by construction.


## Discovered patterns — 2026-05-19

### GDPR export: FirebaseFunctionsException code triage

When a Cloud Function backs a GDPR Art. 15 export (audit logs, etc.) and the call site uses `Future.wait(..., eagerError: true)` to bundle multiple collections, splitting CF errors into transient (return recoverable stub with `error_code` marker) vs fatal (throw → abort bundle) is defensible IF the partial nature is explicitly surfaced in the bundle. Silent partial exports were the BUT-842 root cause.

Transient set (retry-safe, user keeps other 30+ collections):
- `unavailable`, `deadline-exceeded`, `cancelled`, `aborted` — infra/transport hiccups
- `resource-exhausted` — quota wobble; the error_code marker prevents silent rate-limiting from looking like a clean export

Fatal-by-design (must abort whole bundle):
- `permission-denied`, `unauthenticated` — masking these = hiding an authz bug
- `failed-precondition`, `invalid-argument`, `not-found` — contract violations
- `internal` — SDK catch-all for unhandled server exceptions; broken CF deploys would silently ship empty sections to every user otherwise

When the GDPR data source is the repository (not a CF callable), there is no network-transience dimension — all errors are fatal (Art. 7 consent records: a stub `{error: ...}` in the bundle is worse than a clean abort + retry).

`ComplianceExportException.toString()` deliberately omits userId — PII belongs in the structured logger (AppLogger.error → Crashlytics non-fatal), not in stack-trace surfaces that may reach user-visible error UI.

---

### 2026-05-21 — Cross-user cascade audit pattern (BUT-455)

When a Cloud Function triggered by `auth.user().onDelete` cascades writes onto OTHER users' documents (GDPR Art. 17 right-to-erasure), each cross-user mutation needs a paired `audit_logs` row. The proven pattern (see `functions/src/cleanup/cascade-audit-log.ts`):

- **In-batch staging** (`stageCascadeAuditEntry`) is correct transactionality for Art. 17: the auditable claim is "we made this cascade write" — if the write rolled back, there is nothing to audit. A separate best-effort write would create false positives (audit row saying we deleted data we didn't). Loud retry > silent skew.
- **Schema must match existing audit_logs writers** (`storage/moderate-upload.ts`, `triggers/ping_onCreate.ts`): top-level `userId / operation / resourceType / resourceId / granted / timestamp / metadata`. Existing compound indexes (`firestore.indexes.json:122-153`) on `userId+timestamp`, `resourceType+timestamp`, `granted+timestamp`, `resourceType+resourceId+timestamp` cover both client `logPermissionCheck` and system cascade entries — no new index needed.
- **`granted: true`** for system-authorized cascades (not a permission denial). `metadata.actor='system'`, `metadata.reason='gdpr_article_17'`, `metadata.targetUid` = the OTHER user affected. Subject (`userId` top-level) is always the user being deleted.
- **Batch-limit accounting**: each audited write doubles the per-friend op count. When the cascade is `delete + audit`, cap iteration at `BATCH_LIMIT/2 = 250` to stay under Firestore's 500-op-per-batch ceiling. Worst-case 2× more `batch.commit()` calls — still linear, no algorithmic regression, dominated by the `get()` round-trip for users with thousands of friends.
- **Admin SDK bypasses rules** — no `firestore.rules` change required for system cascade writes. `firestore.rules:1443-1446` only gates client-initiated `audit_logs.create` (auth.uid match + rate-limit), which Admin SDK ignores. Confirmed: zero rules update needed for BUT-455.
- **`on-user-deleted.ts` is the single cascade entry point** — the ticket-cited `social_deletion_operations.ts` / `profile_deletion_operations.ts` paths don't exist. When auditing the BUT-886 follow-up (remaining 10 cascades), wire `stageCascadeAuditEntry` into the existing batch loops in this one file. Pattern is uniform: build batch → stage delete/update → stage audit → commit when reaching half-limit.

### 2026-05-21 — commitInChunks lacks ops-per-item awareness (BUT-886 wave-8)

When wiring `stageCascadeAuditEntry` into cascades that go through `functions/src/shared/batch-update.ts::commitInChunks`, the helper counts ITEMS, not OPS — its `batchCount >= BATCH_LIMIT (500)` check assumes one op per item. If the `mutate` callback stages two ops per item (e.g. `batch.delete(doc.ref)` + `stageCascadeAuditEntry`), the batch reaches 1000 staged ops before the first commit fires, blowing Firestore's hard 500-write-per-batch cap.

This is **not** a problem in:

- Hand-rolled batch loops in `on-user-deleted.ts` (e.g. `cleanupReverseFriendships`, `cleanupSocialRequests`, `updateFriendCounts`, `cleanupPresenceRows`, `cleanupFeedback`) — they explicitly set `const X_PER_BATCH = Math.floor(BATCH_LIMIT / 2) = 250`.
- `cascadeArrayRemove` — it computes `perChunkCap = onItemOp ? Math.floor(BATCH_LIMIT / 2) : BATCH_LIMIT` (correct).

It **IS** a problem in `commitInChunks` callers that stage audit + mutation:

- `tombstoneSharedByDisplayNameWithDb` — `shared_content` docs the user authored. Heavy sharers (500+ shares) trigger the overflow; best-effort mode swallows the error so it shows up as silent partial cleanup.
- `cleanupNotificationQueuesWithDb` — `scheduled_notifications` + `notification_send_events` + `notification_opened_events`. Strict mode (`strict: true`), so the 501st item makes the entire `onUserDeleted` cascade throw and the auth.user().onDelete retry loop kicks in indefinitely until the queue is below 500 (which never happens if the cascade itself can't drain it). Active users accumulate analytics events fast — this is the highest-impact one.
- `anonymizeReportsByContentOwnerWithDb` — `/reports` where `contentOwnerId == userId`. Heavily-moderated user could hit 500+.

**Fix shape**: extend `commitInChunks` with `opts.opsPerItem?: number` (default 1) and gate the chunk on `batchCount * opsPerItem >= BATCH_LIMIT`. Callers wiring audit pass `opsPerItem: 2`. The wirings test in `cascade-audit-log-wirings.test.ts` should add a "500-item batch splits at 250" assertion to lock the contract.

**Detection rule for future reviews**: any `commitInChunks(... (batch, item) => { ... })` whose mutate body contains more than one `batch.*` call MUST pass a matching `opsPerItem` once the param exists (or halve the input list manually until then). Grep for `commitInChunks` callers in `functions/src/` after the helper is updated to confirm coverage.

### 2026-05-22 — BUT-788 server-side account deletion: composition pattern with onUserDeleted
- Trigger: CF callable for account deletion (`requestAccountDeletion`) plus existing v1 auth `onUserDeleted` trigger
- Pattern: callable owns OWN-data (cascade + Storage `users/{uid}/`); trigger owns CROSS-USER cleanup (reverse friendships, public_profile, feedback storage `feedback/{uid}/`, friend counts, presence). Boundary is explicit in code comments.
- Re-auth gate: 5-minute `auth_time` window for destructive callables. TOCTOU safe because `admin.auth().deleteUser` is one-shot and idempotent under retry.
- Audit log ordering: write BEFORE `auth.deleteUser`-triggered cross-user cleanup completes is acceptable for Art. 17 — the audit row records the cascade outcome we control synchronously; cross-user cleanup is the trigger's own auditing surface (`writeCascadeAuditEntry`).
- App Check deferral acceptable when re-auth gate + CORS allowlist are present, but only as a temporary bridge to mobile attestation rollout.
- Cascade idempotency rule: every step must be deletes / `arrayRemove` / `set-merge` so retries on partial failure converge. Avoid `arrayUnion` / counter-increment shapes here.

---

### 2026-05-22 — Storage upload error code is NOT PII (BUT-971 review)

`StorageUploadException.code` carries Firebase storage codes like `quota-exceeded`, `unauthorized`, `canceled`. These are bounded enum-shaped tokens with no user identifier content — safe to log to analytics. Same applies to `FirebaseAuthException.code` values surfaced in `sessionTimeoutLogout` analytics events (`user-token-expired`, `user-disabled`, etc.).

The `message` field IS a potential leak surface: Firebase storage SDK occasionally embeds the bucket-relative path (which starts `users/{uid}/...`) into the human-readable message. Rule: log `message` to `AppLogger` only; never to `_analyticsService.logEvent` parameters. The Wave-13 implementation correctly only puts `error_code` (not message) into analytics.

### 2026-05-22 — Bypassing executeServiceOperation for typed-error propagation is safe IF auth is enforced downstream

`StorageService.uploadImageFile` skips `executeServiceOperation` so `StorageUploadException` survives the call boundary (safeExecute would swallow to null). This trades the pre-flight `requiresAuth`/`requiresNetwork` checks for typed-error visibility.

Acceptable because: the repository `_validateUploadPermission` is the *authoritative* auth gate (logs to audit, throws `PermissionDeniedException`). The pre-flight `requiresAuth` check in `executeServiceOperation` was a UX nicety — it converted an unauthenticated call into a localized error early instead of letting the repo throw. Removing it does NOT open new attack surface; the repo gate stands. The only regression is UX: unauthenticated users now see a generic "upload failed" toast (null return) instead of a localized auth-required message. Rate: Medium UX, NOT a security issue.

Network pre-flight: same story — `requiresNetwork` was a fail-fast nicety; without it, Firebase Storage SDK still fails the upload, just with a less specific error.

### 2026-05-22 — AuthService stream-error path has no concurrent-sign-in race

`_handleAuthStreamError` calls `forceSignOut()` (which clears errors in `finally`) then `setError(errorSessionExpired)`. Ordering is intentional and documented. Race concern: could a concurrent `signInWithEmail` complete between forceSignOut and setError, leaving stale error text on a now-authed session?

Analysis: a successful `signInWithEmail` calls `clearError()` at its start AND fires the auth-state stream with the new user. The stream callback overwrites `_currentUser` and notifies. So even if `setError` lands after a concurrent sign-in, the next auth-stream emission clobbers it OR the user sees an error string on a successful session — purely cosmetic, not a security issue. The actual auth state (`_currentUser`, `isAuthenticated`) is driven by the stream, not by `error`.

The real risk is the opposite: if `setError` runs before `forceSignOut`'s `finally`, the error is wiped. The current ordering (`await forceSignOut(); setError(...)`) is correct *because* forceSignOut awaits the entire body including its `finally` before returning.


### 2026-05-28 — BUT-1132 idempotent shared_content create
- **Pattern**: pre-create lookup `.where(sharedByUserId == uid).where(originalRecipeId == X).limit(1)` is SAFE under `shared_content` rules because `allow list: request.auth.uid == resource.data.sharedByUserId` already restricts the result-set to the caller's own docs. The repo-layer guard at line 186 (`sharedRecipe.sharedByUserId != uid -> PermissionDeniedException`) runs BEFORE the query, so the equality filter aligns with the rule's list constraint by construction.
- **Composite index `(sharedByUserId ASC, originalRecipeId ASC)` on `shared_content`**: no PII leak — both fields are already stored on the document and access-gated by the existing per-doc `get/list` rules. Indexes don't bypass rules.
- **Legacy `shared_recipes` index in firestore.indexes.json**: collection has no `match /shared_recipes/{}` block in rules (only `shared_content` and `shared_menus`). Index is inert — Firestore charges nothing for indexes on collections that are never written. Out-of-scope cleanup, safe to defer.
- **Idempotent re-share audit semantics**: when reusing an existing doc, original `sharedAt` + recipe snapshot are intentionally preserved (re-share is treated as "add more recipients to existing share", not "new share event"). `addMember` calls `.set()` on `members/{userId}` which OVERWRITES `addedAt` for already-present members — this is a minor audit fidelity loss (re-add events stamp a new addedAt, losing the original join time). Acceptable for current product semantics but worth flagging if join-time becomes legally relevant (it isn't for GDPR — `sharedToUserIds` retention is the controlling state).
- **`addMember` ownership check is enforced**: `addMember` re-reads the doc and throws `PermissionDeniedException` unless caller is creator. Idempotent path inherits this — non-owners can't piggyback on existing shares.
