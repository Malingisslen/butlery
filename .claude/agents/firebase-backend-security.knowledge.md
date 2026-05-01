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
