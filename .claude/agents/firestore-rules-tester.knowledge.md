# firestore-rules-tester — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it at the start of every invocation and **APPEND** to it when it
discovers a pattern that should inform future runs.

## How the agent updates this file

- **Append-only** — never delete entries; supersede with a newer dated entry.
- **Date every entry** — `### YYYY-MM-DD — short title`.
- **Be terse** — 1–3 sentences plus a code excerpt if needed.
- **One concept per entry** — easier to supersede later.

## Collection → test file map

| Path                                  | Test file                  | npm script                |
|---------------------------------------|----------------------------|---------------------------|
| `/users/{uid}` and recipes subtree    | `firestore-rules.test.ts`  | `test:rules:recipes-users`|
| `/reports/*`                          | `reports-rules.test.ts`    | `test:rules`              |
| Age-gate paths                        | `age-gate-rules.test.ts`   | `test:rules:age-gate`     |
| All of the above                      | (sequence)                 | `test:rules:all`          |

If the diff touches a collection not listed above, **create a new test file**
named `functions/src/__tests__/<collection>-rules.test.ts`, add a matching
`test:rules:<name>` script, append it to `test:rules:all`, and add the
mapping here.

## Actor conventions

```ts
const OWNER_UID = "owner-uid";
const OTHER_UID = "stranger-uid";
const ADMIN_UID = "admin-uid";
```

- Authenticated:   `env.authenticatedContext(uid)`
- Unauthenticated: `env.unauthenticatedContext()`
- Admin grant:     write to `/admins/{uid}` via `env.withSecurityRulesDisabled(...)` during setup.

## Builder shapes

### `validRecipeBody` (firestore-rules.test.ts)

Recipe documents at `/users/{userId}/recipes/{recipeId}` require:

```ts
{
  core: {
    title: string,
    tagResult: {
      tags: [],
      allergenStatus: { [allergen]: "free" | "contains" | "unknown" },
      dietaryStatus:  { [diet]:     "free" | "contains" | "unknown" },
      coverage: 0..1,
      unknownIngredients: [],
      generatedAt: Date,
      generatorVersion: string,
      isPartial: boolean,
      schemaVersion: 1,
    },
  },
}
```

Rules validator may reject unknown fields or out-of-range coverage —
test both happy and malformed shapes when the validator changes.

## Test naming convention

Each `test()` name states the behavior in plain English. Comment IDs above
each test, grouped by collection: `// R1:` for recipes, `// U1:` for users,
`// A1:` for admin/age-gate, etc.

```ts
// R1: owner can create their own recipe with a valid tagResult
test("recipes: owner can create a recipe with valid tagResult", async () => { ... });
```

Section banners between collections:

```ts
// ============================================================================
// RECIPES (8 assertions across 6 tests)
// ============================================================================
```

## Coverage requirement

For each rule branch in the diff, prove **both** the allow path **and** the
deny path. A green `assertSucceeds` without a matching `assertFails` is not
coverage.

Standard deny matrix for ownership-checked collections:
- non-owner authenticated user
- unauthenticated user
- (when applicable) admin without the right claim

---

## Discovered patterns

*Append new dated entries below as the agent learns them.*

### Archived (pre-2026-06-04) — see firestore-rules-tester.knowledge.archive.md

- 2026-04-25→04-30 (6 entries) — seed; moderation-rules (BUT-511/728); rate-limit deny via `rate_limits` subcollection; userId-switch attack pattern for `set()` collections; onboarding progress (BUT-675); Java/emulator gap on Windows.
- 2026-05-01→05-04 (7 entries) — menus-rules (BUT-746/747); recipient self-scrub pattern + paired `removeAll()` anti-griefing (BUT-749); Sprint G defence-in-depth denies (BUT-627/482); symmetric-difference + isInList membership gates (BUT-464); same-actor rate-limit collision gotcha; `members` collection-group catch-all shape (BUT-463).
- 2026-05-28→06-03 (7 entries) — iter102-rules (shared_content list + notification expireAt); Java-on-PATH supersedes the emulator gap; Storage rules + `recipe_comments` imageUrls validator (BUT-1049); EMULATOR PERSISTS DATA ACROSS `npm run` INVOCATIONS (isolation gotcha); Admin-SDK cascade integration (BUT-1009); cascade collectionGroup + shopping item-scrub (BUT-1191).

### 2026-06-10 — map correction: cook_snaps lives in cook-snaps-and-message-mod-rules.test.ts

Supersedes the 2026-04-26 moderation-rules entry's cook_snaps row:
`moderation-rules.test.ts` no longer contains any cook_snaps tests (grep = 0).
Map rows:

| `/cook_snaps/{snapId}` + `/messages` admin-read | `cook-snaps-and-message-mod-rules.test.ts` | run via `npx ts-node src/__tests__/cook-snaps-and-message-mod-rules.test.ts` |

PROJECT_ID `butlery-rules-cook-snaps-and-message-mod`. Note the create rule
includes `rateLimitWrite('cook_snaps', 5)` — but the rate-limit doc is only
written by the app, so multiple create-allow tests by the same actor pass as
long as no test seeds `users/{uid}/rate_limits/cook_snaps`.

### 2026-06-10 — presence-check clauses NEUTRALIZE query-level enforcement (BUT-1214, CRITICAL)

A read rule of the shape `... || (friendGate && (!('field' in resource.data) || resource.data.field != 'secret'))`
does NOT protect list queries. Verified on emulator: for a query that leaves
`field` unconstrained, the engine evaluates `'field' in resource.data` as FALSE
(absent), so the legacy/back-compat disjunct satisfies the rule, the query is
ALLOWED, and — because rules are not filters — real docs WITH
`field == 'secret'` are returned in full. Same hole with
`resource.data.get('field', 'default') != 'secret'` (default kicks in at query
time → allow → leak). The ONLY shape that closes the query path is strict
equality on the safe value: `resource.data.field == 'safeValue'` — unconstrained
query then DENIES, and `where('field','==','safeValue')` ALLOWS. Cost: docs
missing the field become unreadable via that branch (direct get too) → a
backfill must run BEFORE the rules deploy. Rule of thumb: in any read rule,
treat `!('x' in resource.data)` and `.get('x', default)` back-compat clauses as
get-only semantics that OPEN the list path; require strict equality for any
visibility/privacy enum.

Resolution (same day): strict-equality fix applied to firestore.rules
cook_snaps friend-read branch; suite green 32/32 incl. the unconstrained-query
deny and the flipped legacy contract test ("legacy snap without visibility is
NOT friend-readable (backfill required)"). Operational invariant: the
backfill (functions/scripts/backfill-cook-snap-visibility.js) MUST run before
any rules deploy, or legacy snaps go friend-invisible in prod.

### 2026-06-10 — probe candidate fixes by patching the rules string in-memory

To verify a proposed rule fix WITHOUT touching firestore.rules (that file is
firebase-backend-security's territory), load the rules file, `rules.replace(
clauseRegex, candidate)`, and pass the patched string to
`initializeTestEnvironment` under a fresh projectId per candidate. Match the
clause with a whitespace-tolerant REGEX (`\s*` between tokens) — literal
template strings silently miss on indentation. Lets the tester report "fix A
verified green, fix B verified leaky" instead of speculating.

### 2026-06-11 — cook-events-rules.test.ts created (BUT-838) + count() aggregate test pattern

New test file `functions/src/__tests__/cook-events-rules.test.ts` (24 tests),
wired in as `test:rules:cook-events`, appended to `test:rules:all`, added to
`firestore-rules.yml` path filters (PR + push). Project id
`butlery-rules-cook-events`.

Map row to add:

| `recipe_cook_events/{userId}/events/{eventId}` | `cook-events-rules.test.ts` | `test:rules:cook-events` |

Rules shape (BUT-838): read/delete gate ONLY on the `{userId}` path segment;
create adds hasAll+hasOnly(['recipeId','cookedAt']) + recipeId string 1..200
+ cookedAt timestamp; `allow update: if false` (append-only log).

**count() aggregate test pattern (first in repo):** the compat API from
`ctx.firestore()` has NO `.count()` — import the MODULAR helpers and cast:

```ts
import { collection, query, where, getCountFromServer, Firestore } from "firebase/firestore";
const db = ctx.firestore() as unknown as Firestore; // unwrapped via getModularInstance
await assertSucceeds(getCountFromServer(query(collection(db, path), where("cookedAt", ">=", ts))));
```

Verified on emulator: a path-segment-only read rule makes the owner's
count aggregate provable (allow), foreign + unauthenticated aggregates DENY.
Coverage triple: owner-allow / foreign-deny / unauth-deny on the EXACT query
shape the client issues, plus a getDocs() pair for the non-aggregate fallback.

**Append-only `update: if false` test subtlety:** prove it with BOTH
`.update(partial)` AND a full-body `.set(validBody)` on an existing doc (the
set-on-existing path is what a buggy client retry would hit). Suffix
create-allow doc ids with the per-RUN token — with update denied outright, a
persisted doc from a prior run turns every create-allow into a guaranteed
false FAIL (bit the cook-snaps suite this run: 30/32 until namespace clear,
then 32/32).

### 2026-06-13 — root-level schemaVersion guard pattern (BUT-1249)

`users/{uid}/recipes/{recipeId}` has NO root-level `keys().hasOnly()` validator.
The only structural gate is `isValidTagResult(core.tagResult)`, scoped to the
nested tagResult map. A root-level `schemaVersion: 1` field (added by BUT-648
to the model) passes the create AND update rules today.

Tests R9 and R10 in `firestore-rules.test.ts` guard this contract: if a future
engineer adds a top-level `hasOnly([...])` to the recipes rule without
including `schemaVersion`, these tests will fail and surface the regression
before it ships. Both verified green on emulator (22/22 passed, including all
pre-existing tests). Doc ids use the per-RUN token to avoid emulator-persistence
collisions. The `validRecipeBody(extra)` builder accepts `{ schemaVersion: 1 }`
in the spread so the root-level field sits alongside `core: {...}`.

### 2026-06-14 — activity-events-rules.test.ts wired + gap-closing additions (BUT-1294)

New top-level collection `/activity_events/{eventId}` (social activity feed).
The test file was authored by the feature author at 17 tests; I wired it into
`functions/package.json` as `test:rules:activity-events` (it had NO npm script),
appended it to `test:rules:all`, and added it to both path-filter blocks in
`firestore-rules.yml`. Project id `butlery-rules-activity-events`.

Map row to add:

| `/activity_events/{eventId}` | `activity-events-rules.test.ts` | `test:rules:activity-events` |

Rule shape: read = actor OR friend-of-actor (`exists(users/{actorId}/friends/{auth.uid})`,
same snap-owner pattern as cook_snaps); create = actor-only +
`hasRequiredFields(['actorId','type','recipeId','createdAt'])` + type/recipeId
string checks + recipeId<=200 + optional recipeTitle<=300 +
`rateLimitWrite('activity_events', 2)`; update = actor-only +
`cannotModify(['actorId','recipeId','createdAt'])`; delete = actor-only.

**Gaps the authored 17 tests left (I added 6, now 23/23 green):**
1. **No update allow-path** — every update test was a deny. A regression of the
   actor check or `cannotModify` to a blanket deny would have passed all of
   them. Added AE12b (actor updates `recipeTitle` → SUCCEEDS). This is the
   load-bearing addition; the `cannotModify`-immutable-field denies are
   worthless without one proof the rule permits a legitimate edit.
2. **Only 1 of 3 immutable fields denied** (actorId). Added AE13b (recipeId) +
   AE13c (createdAt) so each anchor in `cannotModify([...])` has its own proof.
3. **`type` required-field + `is string` branches unproven** — added AE9b
   (missing type) + AE9c (non-string type).
4. **rate-limit clause unproven** — added AE12c using the seed pattern from the
   2026-04-26 entry (seed `users/{RL_UID}/rate_limits/activity_events` with a
   fresh `lastWrite`, dedicated actor so AE5's actor stays clean, create within
   2s → DENIES). Reminder: the rate-limit doc is app-written, so create-allow
   tests by other actors do NOT trip it unless seeded.

Verified 23/23 on emulator after a namespace clear. Reminder for next run:
clear `butlery-rules-activity-events` before fixed-id seed tests (ae-read-*,
ae-update-*, ae-del-* use stable ids — they re-seed via withSecurityRulesDisabled
each run so they're idempotent, but a leftover ae-del-own delete is harmless).

The two Dart files in this diff (`firebase_user_repository.dart`,
`user_root_deletion_mixin.dart`) were COMMENT-ONLY changes (BUT-1287 behavioral
notes about `auditRepository:` persistence) — no rule-testable behavior, nothing
to assert.

### 2026-06-19 — admin-dashboard-rules.test.ts wired + collection-group read shadow note

Admin-dashboard read surface (Phase 3/4). Test file authored by feature author
(15 tests, all green on emulator first run). It had NO npm script and was NOT in
`test:rules:all` — wired both (`test:rules:admin-dashboard`), and added it +
`feedback-rules.test.ts` (which a prior run also missed) to BOTH path-filter
blocks in `firestore-rules.yml`. Project id `butlery-rules-admin-dashboard`.

Map rows to add:

| `/analytics/{document=**}` (admin read) | `admin-dashboard-rules.test.ts` | `test:rules:admin-dashboard` |
| `/metrics/{document=**}` (admin read) | `admin-dashboard-rules.test.ts` | `test:rules:admin-dashboard` |
| `/system_events/{eventId}` (admin read) | `admin-dashboard-rules.test.ts` | `test:rules:admin-dashboard` |
| `/{path=**}/recipes/{recipeId}` (admin collection-group read) | `admin-dashboard-rules.test.ts` | `test:rules:admin-dashboard` |
| `/users/{uid}` read-split + `/parsing_corrections` admin read | `admin-dashboard-rules.test.ts` | `test:rules:admin-dashboard` |

Rule shape: five admin-read additions, all `allow read: if isAdmin()` (where
`isAdmin()` = authed + `exists(/admins/{uid})`). NO write opened anywhere —
verified via throwaway probe that every new path's admin/anon write + delete
falls through to the L2156 default-deny.

**Collection-group read SHADOW (worth pinning):** `match /{path=**}/recipes/{recipeId}
{ allow read: if isAdmin() }` does double duty — Firestore UNIONS matching rules,
so it grants the admin BOTH the `collectionGroup("recipes")` query AND a direct
`get()` on any single `users/{uid}/recipes/{id}` doc, even though the specific
`users/{uid}/recipes` match only allows owner read. The owner's own-recipe read is
unaffected (union, not override) — pinned green in the probe. If a future diff
ever wants admin to query-but-not-direct-get recipes, this collection-group shape
cannot express that; it's all-or-nothing per doc match.

**Authored-test coverage was already complete** for the diff: each of the 5
read additions has admin-allow + non-admin-deny, anon-deny on analytics, and the
`users`/`parsing_corrections` splits keep an owner-still-reads assertion so the
read-split didn't drop the original grant. The only gaps I closed were
infra-wiring (npm script + CI), not test coverage. No firestore.rules edits.

### 2026-06-21 — recipe shared-read widening (memberPermissions key gate)

New `allow read` branch on `users/{userId}/recipes/{recipeId}`:

```
allow read: if isOwner(userId)
  || (isAuthenticated()
      && request.auth.uid in resource.data.get('socialData', {})
                                     .get('memberPermissions', {}));
```

CEL analysis (all four edge-cases verified on emulator):
1. `socialData` absent → `get('socialData', {})` returns `{}` → `get('memberPermissions', {})` returns `{}` → `uid in {}` = false. SAFE.
2. `memberPermissions` absent → same empty-map default path. SAFE.
3. UID is a VALUE, not a key (e.g. `{other-key: uid}`) → CEL `in` on maps checks KEYS only → false. SAFE.
4. Unauthenticated → `isAuthenticated()` short-circuits → false. SAFE.
Chained `.get()` on an intermediate map result is valid CEL — returns the nested value or default.

Write paths (`allow create`, `allow update`, `allow delete`) are all `isOwner(userId)` — unchanged. Admin override `allow read, delete: if isAdmin()` at L264 is unchanged (no write loosened).

Test file: `functions/src/__tests__/recipe-shared-read-rules.test.ts` (6 tests).
Wired as `test:rules:recipe-shared-read`; appended to `test:rules:all`; added to both path-filter blocks in `.github/workflows/firestore-rules.yml`.

Map row to add:

| `users/{userId}/recipes/{recipeId}` (shared-read branch) | `recipe-shared-read-rules.test.ts` | `test:rules:recipe-shared-read` |

**Coverage gaps found in the authored 4-test file (I added 2 to fix):**
- Missing: `unauthenticated` read deny (SR5) — Critical for a privacy-sensitive collection.
- Missing: recipe WITH NO `socialData` field — stranger denied (SR6). Low-risk given CEL default-map analysis, but pinned.
- Remaining uncovered (Low): uid-as-value-not-key attack; owner update-still-works positive. Rule analysis confirms both are safe without explicit test.

### 2026-06-27 — age-gate floor change (13 → 15) boundary-test pattern (BUT-1384)

The `preferences` birthYear rule under `users/{uid}/settings/{settingId}` now
enforces a minimum age of 15 (Dataskyddslag, ADR-0001) on both `allow create`
and `allow update`. Test file: `age-gate-rules.test.ts` (`test:rules:age-gate`).

**Required test triad for any numeric-floor change on a rule:**
1. Allow at exactly the new floor (currentYear-N) — proves the boundary is inclusive.
2. Deny at one year above the floor (currentYear-(N-1)) — proves the boundary rejects the old-but-now-illegal value.
3. Allow on the update branch at the same boundary — without it, a regression that blocks all valid birthYear updates passes the deny-only test.

The update branch has an additional `!('birthYear' in request.resource.data.keys()) || null` backfill clause that must also have an allow test (Test 4). The `null` sub-clause is present but has no named test — Low gap, not a diff-coverage miss when the clause itself is unchanged.

Coverage after this run: 9/9 green. Tests: 3a (create-allow @15), 3b (create-deny @14), 4 (update-allow no-birthYear backfill), 5 (update-deny @14), 5b (update-allow @15, added this run).

### 2026-06-20 — parse_events admin-read added to admin-dashboard-rules.test.ts

New `match /parse_events/{eventId} { allow read: if isAdmin() }` (admin drill-down
from import health to per-attempt failing imports; docs carry `domain`/`success`/
`timestamp`, written server-side by `functions/src/events/log-parse-event.ts` via
admin SDK). Map row to add:

| `/parse_events/{eventId}` (admin read) | `admin-dashboard-rules.test.ts` | `test:rules:admin-dashboard` |

Feature author added 3 cases (admin get, admin domain-query, non-admin deny) +
a seeded `parse_events/pe1` in setup. Suite green 18/18 after namespace clear.
Throwaway probe confirmed admin-read-ONLY: anon read + admin/stranger/anon
create + admin update + admin delete all fall through to the L2162 default-deny
(6/6 denied). No firestore.rules edits, no new file/script/CI wiring needed
(extends the existing admin-dashboard suite).

**Minor coverage note (Low):** the authored non-admin deny uses an authenticated
non-admin only — no explicit anonymous-read deny case in the suite for
parse_events. Consistent with how the sibling metrics/system_events/
parsing_corrections cases are written (anon-deny only spelled out for analytics).
Probe covered the anon path, so it's proven, just not pinned as a named suite test.

### 2026-06-27 — BUT-1386 (ADR-0002) server-authoritative age gate (full REWRITE of age-gate file)

The old self-declared-birthYear contract is GONE. Three rule changes, all proven
on emulator:

1. **NEW helper `isAgeCompliant()`** = `isAuthenticated() && request.auth.token.ageCompliant == true`.
   Fails CLOSED. Seed the claim via the SECOND arg of `authenticatedContext`:
   `env.authenticatedContext(uid, { ageCompliant: true })`. The matrix per gated
   create is THREE cases: claim true → allow; **no claim → deny** (the CEL
   `request.auth.token.ageCompliant` is *undefined* on a claimless token, which
   `== true` evaluates false → deny, NOT an error that aborts); `ageCompliant:false`
   → deny.
2. **birthYear is now CF-ONLY-written** on BOTH homes (`users/{uid}` profile doc
   AND `users/{uid}/settings/{settingId}`). Client create rule:
   `request.resource.data.get('birthYear', null) == null` (must be ABSENT).
   Client update rule: post-write birthYear `==` existing birthYear (add/change/
   remove all denied; all OTHER field edits still allowed). Test matrix per home:
   create-without-allow, create-with-deny, update-add-deny, update-change-deny,
   update-other-field-while-preserved-allow (this last one is the load-bearing
   allow — without it a blanket-deny regression passes every deny test).
3. **Four UGC create paths gained `&& isAgeCompliant()`**: recipe_comments (L1055),
   messages (L1310), social_requests (L553), recipe_ratings (L1484). For messages
   + social_requests, ALSO satisfy `isAccountMatured()` with `email_verified:true`
   in the claim so the age claim is the sole variable.

Test file `age-gate-rules.test.ts` fully rewritten: 25 tests (settings 7 / profile
6 / UGC matrix 12), all green. Uses a fixed `const RUN = "but1386"` literal (NOT
Date.now()) PLUS a REST `DELETE /emulator/v1/projects/<id>/databases/(default)/documents`
namespace clear in setup() — belt-and-suspenders so create-allow doc ids are
always fresh on local re-runs.

**Cross-file fallout (the part that's easy to miss):** turning an existing
create-`assertSucceeds` into an age-gated path makes EVERY claimless authed
create FAIL CLOSED. Grep the whole `__tests__/` dir for the four collections and
add `{ ageCompliant: true }` to their create contexts (deny tests too, so they
deny for their INTENDED reason, not silently on age). This run patched:
- `recipe-comments-rules.test.ts` — 5 create-allow + deny contexts (recipe_comments x4 + recipe_ratings x1). Added `const AGE_OK = { ageCompliant: true }`.
- `account-maturity-rules.test.ts` — 3 create-allow (AM2/AM3/AM5) for social_requests + messages.
- `firestore-rules.test.ts` — U5 ("owner can create settings with valid birthYear") encoded the DEAD contract; flipped to "create WITHOUT birthYear" + suffixed its `settings/preferences` id with `RUN` (was a fixed id → re-run-fragile).

**Two latent pre-existing bugs surfaced while wiring account-maturity into the
suite (it had NO npm script and was NOT in test:rules:all — so it had silently
rotted):**
- It seeded `admin.firestore.Timestamp` objects into the rules-unit-testing
  CLIENT SDK → `invalid-argument` at setup. Fix: use plain `new Date()` (round-trips
  to a Firestore Timestamp; `isAccountMatured()`'s `createdAt.toMillis()` still works).
  Reminder: rules-unit-testing contexts (incl. `withSecurityRulesDisabled`) are the
  CLIENT SDK — never feed them firebase-admin Timestamps.
- Its create-allow tests used FIXED doc ids (req-2/req-3/msg-2) with no per-RUN
  suffix and no namespace clear → false FAIL on the 2nd+ run (create→update→deny).
  Added the same `clearFirestore()` REST-DELETE to its setup.
Wired `test:rules:account-maturity` into package.json + appended to test:rules:all
+ added account-maturity-rules.test.ts AND recipe-comments-rules.test.ts to both
path-filter blocks in `firestore-rules.yml`.

### 2026-06-28 — family-rating-rules.test.ts created (households / diner_profiles / family_ratings)

New test file `functions/src/__tests__/family-rating-rules.test.ts` (49 tests),
wired in as `test:rules:family-rating`, appended to `test:rules:all`, and added
to BOTH path-filter blocks in `firestore-rules.yml`. Project id
`butlery-rules-family-rating`. All 49 green on emulator first run.

Map rows to add:

| `/households/{householdId}` | `family-rating-rules.test.ts` | `test:rules:family-rating` |
| `/diner_profiles/{profileId}` | `family-rating-rules.test.ts` | `test:rules:family-rating` |
| `/family_ratings/{ratingId}` | `family-rating-rules.test.ts` | `test:rules:family-rating` |

**New actor convention — household membership is a DOC-READ gate, not a path
segment.** `isHouseholdMember(hid)` does `get(households/{hid})` then
`auth.uid in doc.data.memberUserIds`. So every diner_profiles / family_ratings
test MUST seed a household via `withSecurityRulesDisabled` first (membership
resolves from the live doc, not from the request). I used one shared
`HOUSEHOLD_ID` with four actors: ADMIN_MEMBER (perm 'admin'), EDITOR ('edit'),
VIEWER ('view'), STRANGER (not in the set). Household *write* is admin-only
(household-admin = `memberPermissions[uid]=='admin'`, NOT the `/admins` app
admin — distinct concept, don't confuse them); diner_profiles + family_ratings
write is ANY member (edit/view perms are irrelevant there — only membership).

**Household create is projection-strict — five deny branches to cover:**
createdBy==auth, auth in memberUserIds, memberPermissions[auth]=='admin',
`memberUserIds.toSet() == memberPermissions.keys().toSet()`, hasRequiredFields.
The inconsistent-projection deny (add a uid to memberUserIds not in
memberPermissions) is the load-bearing one — it's the invariant every
membership lookup trusts. Seed the household with the admin SDK in tests that
need membership (don't re-test create there).

**diner consent invariant (`dinerConsentValid`) — GDPR Art. 9, the highest-value
branch set.** Two independent clauses ANDed:
1. minority gate: `ageBand=='adult' || guardianConsent != null`. Coverage:
   minor-no-consent DENY, minor-with-consent ALLOW, adult-no-consent ALLOW.
2. allergen gate: `!dinerHasAllergenData(data) || guardianConsent.get('includesAllergenConsent', false)==true`.
   `dinerHasAllergenData` = allergenPreferences present AND
   (trackedAllergens.size()>0 OR trackedDietary.size()>0). Coverage:
   tracked-allergen + consent=false DENY, tracked-allergen + consent=true ALLOW.
   Note the `.get(...,false)` default makes a MISSING guardianConsent fail the
   allergen gate too (so allergen data on an adult with no consent map DENIES).
   The same invariant re-runs on UPDATE — proved with an update that ADDS
   allergens with no consent map (DENY) plus a clean rename (ALLOW).

**family_ratings — `enteredByUid == request.auth.uid` write-pin on CREATE only
(not update).** Deny test: a member sets enteredByUid to ANOTHER member's uid →
DENY. `familyStarsValid` (int 1..5) is enforced on BOTH create and update;
boundary coverage 0/6 DENY, 1/5 ALLOW on create, out-of-range DENY + in-range
ALLOW on update. Immutable anchors via `cannotModify(['recipeId','memberId',
'householdId','createdAt'])` — one deny each, plus a stars-change ALLOW so the
deny-only update tests can't pass under a blanket deny.

**Emulator log noise on deny tests references TWO line numbers** (e.g.
`false for 'create' @ L892, false for 'create' @ L2327`): L2327 is the global
default-deny match — it always appears alongside the specific-rule deny because
Firestore evaluates both matches. `evaluation error at Lxxx` on a deny test is
ALSO expected (e.g. a non-member create CEL-errors inside the `get()` of a
household they can't read) — `assertFails` treats both deny and CEL-error as
failure-of-the-write, which is the intended outcome. Not a test bug.

No firestore.rules edits — every branch behaved exactly as the rule intends.

**Local test:rules:all is NOT a reliable green/red oracle here, for two reasons
unrelated to the diff:** (a) the local ensure-emulator hook starts `--only firestore`,
so `comment-images-storage-rules.test.ts` (needs Storage on 9199) crashes the `&&`
chain mid-way; (b) running the all-chain twice without clearing accumulates emulator
state and trips the fixed-id suites (moderation, reports). CI boots a FRESH emulator
WITH storage per job, so test:rules:all is the CI oracle. Locally, verify the
AFFECTED suites individually on freshly-cleared namespaces.

### 2026-06-28 — optional-list validator pattern (attendeeMemberIds on recipe_cook_events)

New clause added to the `allow create` rule for `recipe_cook_events/{userId}/events/{eventId}`:
`attendeeMemberIds` is OPTIONAL; when present it must be `is list && size() <= 50`.
CEL short-circuit form:

```
&& (!('attendeeMemberIds' in request.resource.data)
    || (request.resource.data.attendeeMemberIds is list
        && request.resource.data.attendeeMemberIds.size() <= 50))
```

Coverage triad for any optional-list field of this shape:
- CE14a: present + non-empty valid list → ALLOW
- CE14b: present + empty list `[]` → ALLOW (size 0 <= cap; also proves `[]` is not blocked even if the client never sends it in practice)
- CE14c: present + exactly at cap (50) → ALLOW (boundary inclusive)
- CE14d: present + one over cap (51) → DENY
- CE14e: present + non-list (string) → DENY
- Implicit (CE4): field absent entirely → ALLOW (the `!('field' in ...)` short-circuit)

The absent case is covered implicitly by the baseline create-allow test that uses `validEventBody()` with no extra fields. If a future diff adds similar optional-list fields to this collection (or any other), reuse this five-test cluster (a–e) plus the baseline implicit-absent proof. Suite 29/29 green on emulator, namespace cleared before run.

### 2026-06-30 — NEVER feed admin-SDK `FieldValue` sentinels into a rules-unit-testing context (acquisition CI red)

`acquisition-rules.test.ts` went standing-red after the firebase-admin 12→13
dependabot bump. Three tests failed (1 owner-create-allow, 6 + 9 deny tests)
— the ONLY trait they shared was a CLIENT write carrying
`FieldValue.serverTimestamp()` imported from `firebase-admin/firestore`.

**Root cause (test-harness only, NOT a production bug):** the rules-unit-testing
context's `ctx.firestore()` is the `firebase` CLIENT SDK (v12.x here), not the
admin SDK. The client SDK only recognizes its own sentinel; an admin-SDK
`serverTimestamp()` sentinel is rejected at `.set()` time with
`FirebaseError code:'invalid-argument' — Unsupported field value: a custom
ServerTimestampTransform object`, thrown BEFORE any rule runs. With firebase-admin
12 the two sentinels happened to be interchangeable enough to pass; the 12→13
bump changed the admin sentinel object so the client SDK now throws.

Why it also broke the two `assertFails` deny tests: `invalid-argument` is not
`permission-denied`, and rules-unit-testing's `assertFails` only treats
permission-denied as success → a synchronous `invalid-argument` throw fails the
`assertFails` too. (Test 3, which sends a plain `new Date()`, kept passing — a
legit client value the rule correctly denies.)

**Fix (smallest correct, test layer only):** `import { serverTimestamp } from
"firebase/firestore"` and call the bare `serverTimestamp()` — the established
repo pattern (reports-rules + age-gate already do exactly this). The client
sentinel resolves to `request.time` in the emulator, so Test 1 genuinely
exercises the `firstSeenAt == request.time` allow path and Test 3 still proves
a client-supplied Date is denied. Contract unchanged: 9/9 green on a cleared
`butlery-acquisition-test` namespace. firestore.rules NOT touched (no rules
regression — the acquisition block is correct).

**Production impact: NONE.** Real Flutter clients call the client-SDK
`FieldValue.serverTimestamp()`, which Firestore resolves to `request.time` and
the rule accepts. The breakage was entirely the test importing the wrong SDK's
sentinel.

### 2026-06-30 — llm-response-samples-rules.test.ts created (BUT-1451, deny-all server-only)

New top-level collection `/llm_response_samples/{sampleId}` (scrubbed, TTL'd
`expireAt` paid-LLM input/output samples; Cloud-Functions/Admin-SDK write only).
Rule is the exact `deletion_audit_logs` precedent: `allow read, write: if false`.
New test file `functions/src/__tests__/llm-response-samples-rules.test.ts`
(11 tests, all green on a cleared emulator namespace), wired as
`test:rules:llm-response-samples`, appended to `test:rules:all` (after
audit-logs), and added to BOTH path-filter blocks in `firestore-rules.yml`.
Project id `butlery-rules-llm-response-samples`.

Map row to add:

| `/llm_response_samples/{sampleId}` (deny-all, server-only) | `llm-response-samples-rules.test.ts` | `test:rules:llm-response-samples` |

**Deny-all coverage shape (reusable for any `allow read, write: if false`
server-only collection — same as the SPRINT-G D1–D11 pattern):** matrix is
{read, create, update, delete} × {unauthenticated, authed non-admin, app admin}
plus one Admin-SDK-bypass write that SUCCEEDS (proves the policy doesn't break
the capture path). Seed the existing doc AND the `/admins/{ADMIN_UID}` record via
`withSecurityRulesDisabled` so the app-admin deny is genuine (isAdmin() resolves
true yet still denies — the load-bearing assertion, since the rule comment says a
future relax would go to `isAdmin()` only with DPO sign-off). Read-deny of an
EXISTING doc is stronger than a missing-doc read.

**Union-safety verified for a single-segment top-level deny collection:** the
collection-group catch-alls (`match /{path=**}/recipes|members|comments|...`)
require a trailing named subcollection segment, so a single-segment path like
`llm_response_samples/{id}` cannot match any of them — no accidental allow union.
The only other matching rule is the global `match /{document=**}` (L2341) which is
itself `if false`. Emulator deny logs confirm the double-match `L525 + L2341`
(specific rule + global default), both deny. No firestore.rules edits.

**Reusable rule of thumb:** in ANY `*-rules.test.ts`, server-value sentinels
(`serverTimestamp`, `increment`, `arrayUnion`, `deleteField`, etc.) used inside
a `ctx.firestore()` / `withSecurityRulesDisabled` write MUST come from
`firebase/firestore`, never `firebase-admin/firestore`. Grep
`from "firebase-admin/firestore"` across `__tests__/*-rules.test.ts` after any
firebase-admin major bump — that import in a rules test is the smell. (Admin
SDK sentinels are correct only in the `*.integration.test.ts` files that drive
the admin SDK directly against the emulator.)

### 2026-07-01 — BUT-1418 + BUT-1419: three UGC-create gates added (cook_snaps, activity_events, recipe_comments)

Three `allow create` rules gained a gate, verified on emulator:
1. **cook_snaps create** (L1262) `+ isAgeCompliant()` — `cook-snaps-and-message-mod-rules.test.ts`, 34/34.
2. **activity_events create** (L1364) `+ isAgeCompliant()` — `activity-events-rules.test.ts`, 25/25.
3. **recipe_comments create** (L1177) `+ isAccountMatured()` (already had `isAgeCompliant()`) — `recipe-comments-rules.test.ts`, 24/24 (was 20/22 broken pre-fix).

**The cross-file fallout is the whole job.** Adding a gate to an EXISTING
create rule fails-closed every prior create-allow test whose auth context didn't
mint the newly-required claim. This is identical to the 2026-06-27 BUT-1386
fallout entry — the pattern recurs on EVERY gate-tightening of an existing
create. Checklist when a gate is ADDED to an existing create rule:
- Grep the owning test file for `authenticatedContext(<actor>)` on that
  collection's creates and add the required claim to ALL of them (allow AND deny
  contexts, so denies fail for their INTENDED reason, not silently on the new gate).
- Add the NEW allow/deny pair for the gate itself.

**`isAccountMatured()` needs email_verified OR a seeded old user doc.** Cheapest:
mint `{ email_verified: true }` in the claim (bypasses the 60-min wait). The
fresh-account DENY must use `email_verified:false` AND a uid with NO seeded
`users/{uid}` doc, so BOTH maturity branches are false. **Trap:** the pre-fix
baseline showed `recipe_ratings: non-blocked user can rate` PASSING with only
`{ageCompliant:true}` and no maturity — a false pass caused by a `users/AUTHOR_UID`
doc PERSISTED in the emulator from a prior run satisfying the createdAt branch.
recipe_ratings has required maturity since BUT-659; that test was only green by
persistence luck. Made it (and all comment creates) mint `AGE_OK_MATURED =
{ageCompliant:true, email_verified:true}` so it's correct on a cleared namespace.
Reinforces the 2026-06-03 persistence gotcha: a green create-allow that reads a
`get()`-gated user doc can be lying if the emulator wasn't cleared.

**Fail-closed proof for a gate-deny (do this every time).** A deny test that
denies for the WRONG reason is a false pass. Prove the deny is gate-only by
running the IDENTICAL body+id with the gate satisfied and asserting it SUCCEEDS
(throwaway probe, deleted after). Did this for all three: cook_snaps + activity
deny-bodies succeed with `ageCompliant:true`; recipe_comments fresh-account
deny-body succeeds when `email_verified:true`. If the probe had failed, the deny
was denying on body/id/persistence, not the gate.

**Gotcha this run:** `curl -X DELETE .../databases/(default)/documents` from the
Bash tool — the literal `(default)` parens are shell-globbed and the request
never lands (exit 7, `000`). Let each test file's own `clearFirestore()` in
setup() handle it, or single-quote/escape the path. Also added a `clearFirestore()`
+ `http` import to `cook-snaps-and-message-mod-rules.test.ts` (it had fixed-id
create tests and NO namespace clear — was re-run-fragile). No firestore.rules,
package.json, or CI edits needed: all three files were already wired into
`test:rules:all` and both `firestore-rules.yml` path-filter blocks.

### 2026-07-01 — conversations-rules.test.ts created (BUT-674, 1:1 DM minor gate)

New test file `functions/src/__tests__/conversations-rules.test.ts` (5 tests,
5/5 green on a cleared emulator namespace), wired as `test:rules:conversations`,
appended to `test:rules:all` (after family-rating), and added to BOTH
path-filter blocks in `firestore-rules.yml`. Project id
`butlery-rules-conversations`. **This run DID edit firestore.rules** (the task
explicitly directed the rule change + proof — a scoped exception to the usual
"tester never edits rules" rule; noted in the report).

Map row to add:

| `/conversations/{conversationId}` (create, 1:1 minor gate) | `conversations-rules.test.ts` | `test:rules:conversations` |

**Rule shape (BUT-674).** Conversation-create is the chokepoint for 1:1 DMs:
`participantIds` is set at create and immutable after (update rule blocks
`participantIds`/`createdAt` via `hasAny`), and message read/create keys off
`get(conversations/{id}).data.participantIds`. New helpers near
`rateLimitWrite`:
- `otherParticipant(ids)` = `ids[0]==auth.uid ? ids[1] : ids[0]` (list indexing).
- `otherIsMinor(uid)` = `exists(users/{uid}) && get(users/{uid}).data.get('isMinor', false)==true`. **The `exists()` guard is load-bearing** — a bare `get(...).data.get(...)` CEL-errors if the profile doc is missing; guarding with `exists()` makes a missing doc fail-open (non-minor). `isMinor:true` is written server-side by `verifySignupAge` for a compliant 15–17-year-old.
- `creatorIsFriendOf(uid)` = `exists(users/{uid}/friends/{auth.uid})` — the same directional friend pattern as cook_snaps read (~L1250) and activity_events read (~L1354): `friends/{OTHER's friend}` under the OTHER user's tree.
- `passesMinorDmGate(ids)` = `ids.size()!=2 || !otherIsMinor(otherParticipant(ids)) || creatorIsFriendOf(otherParticipant(ids))`. Added to `allow create` between `hasRequiredFields` and `rateLimitWrite` so the `get()` cost only fires on a 1:1 create.

**Group (size>2) is DELIBERATELY ungated** — rules cannot iterate a participant
list, so there's no way to find the minor among N participants. C5 PINS this as
an ALLOW (non-friend creates a size-3 conversation including a minor → succeeds
today). If C5 ever flips to FAIL, the group path got gated — reconcile with the
rule comment (group-minor protection is deferred to default-private profiles +
a planned CF, not this rule).

**Fail-closed proof pattern (reusable for any "X is allowed only if a seeded
relationship doc exists" gate).** A deny test alone can pass for the WRONG
reason (rate limit, missing field, bad shape). Prove the deny is the
RELATIONSHIP gate by re-issuing the IDENTICAL actor+body with the relationship
doc seeded and asserting SUCCESS. Built into the suite as the C1(deny)/C2(allow)
pair (same body shape, only the friend doc differs) AND re-verified this run with
a throwaway probe: same STRANGER+body DENIES with no friend doc, SUCCEEDS after
seeding `users/{minor}/friends/{stranger}`. C4 adds order-sensitivity coverage
(minor at index 0, non-friend creator at index 1 → still DENY) so
`otherParticipant()` is proven to pick the non-creator regardless of array order.

**Rate-limit note:** `conversations` create carries `rateLimitWrite('conversations',10)`,
but the rate-limit doc `users/{uid}/rate_limits/conversations` is app-written
only — never seeded here — so C3 and C5 (both by STRANGER within 10s) do NOT
trip it. Consistent with the standing rule-of-thumb: create-allow tests share an
actor safely as long as no test seeds the rate_limits subdoc.

### 2026-07-01 — BUT-674: isMinor write-protection on users/{uid} profile doc (mirrors birthYear)

The `users/{uid}` profile create/update rules gained an `isMinor` guard exactly
mirroring the existing `birthYear` one (firestore.rules ~L326–333):
`allow create: ... && request.resource.data.get('isMinor', null) == null;`
`allow update: ... && request.resource.data.get('isMinor', null) == resource.data.get('isMinor', null);`
`isMinor` is server-authoritative (only `verifySignupAge` sets it via Admin SDK,
which bypasses rules); a client writing `isMinor:false` would un-gate itself from
the DM-to-minor protection. Rule change was applied by the task author — the
tester only added the proof (no firestore.rules edit this run).

Added 4 tests to `age-gate-rules.test.ts` in a new PROFILE DOC isMinor block
(IDs `IM1`–`IM4`), parallel to the birthYear `P1`–`P6` block:
- IM1 create carrying `isMinor:false` → DENY (`get('isMinor',null)==null` fails).
- IM2 create WITHOUT isMinor → ALLOW (subject to the same birthYear-absent condition).
- IM3 update flipping a CF-seeded `isMinor:true`→`false` → DENY (immutability clause).
- IM4 update flipping `isSearchable` while isMinor is PRESERVED → ALLOW. **Load-bearing:**
  proves the protection is isMinor-SPECIFIC and does NOT block the Q1 discovery
  opt-in (a minor may still toggle isSearchable). Without IM4, a blanket-deny
  regression of the update rule would pass every isMinor deny test.

**Fail-closed confirmed via emulator deny logs:** IM1 denies at `L326:24` (the
create rule carrying the isMinor clause), IM3 at `L329` (the update rule with the
immutability clause) — the exact rule lines, not an unrelated failure. Same
seed/fixture pattern as the birthYear tests: seed the CF-set `isMinor:true` via
`withSecurityRulesDisabled`, then attempt the client mutation. No per-actor
collision (each test uses a unique `prof-*-${RUN}` uid + the namespace is cleared
in setup).

**Pre-existing unrelated red surfaced (NOT BUT-674):** `recipe_comments:
age-compliant author can create a comment` (C1) fails standing —
`Property email_verified is undefined on object` at L1222. The recipe_comments
create rule now also requires `isAccountMatured()` (per the 2026-07-01 BUT-1418
entry), but C1's `AGE_OK` claim lacks `email_verified`. Baseline is 24/25 without
my change, 28/29 with it (delta = exactly my 4 passing isMinor tests). Not fixed
here (fixing it is outside BUT-674 scope and would edit an unrelated allow test);
surfaced to the author. C1's `AGE_OK` should become `AGE_OK_MATURED` when someone
touches that section.

### 2026-07-01 — BUT-674: isMinor write-protection extended to users/{uid}/settings/{settingId}

Second half of the BUT-674 isMinor guard: the same create-absent + update-immutable
clauses were added to the `settings/{settingId}` rule (firestore.rules ~L534–548),
mirroring the birthYear pair already there and the profile-doc isMinor pair from the
prior 2026-07-01 entry. Rationale: the CF now mirrors `isMinor` into
`users/{uid}/settings/preferences` (client reads it for analytics minimization), so a
client that could forge `isMinor:false` there would defeat the minimization. Rule edit
was applied by the task author; the tester only added proof (no firestore.rules edit).

Added 4 tests to `age-gate-rules.test.ts` in a new "SETTINGS — isMinor immutability"
block (IDs `SM1`–`SM4`), placed between the birthYear settings block (S1–S7) and the
profile birthYear block, parallel to S2/S1/S5/S6:
- SM1 create carrying `isMinor:false` → DENY.
- SM2 create WITHOUT isMinor (normal settings write) → ALLOW.
- SM3 update flipping a seeded `isMinor:true`→`false` → DENY (immutability clause).
- SM4 update editing `notificationsEnabled` while isMinor PRESERVED → ALLOW (load-bearing;
  proves the guard is isMinor-specific, not a blanket update block).
All 4 green on emulator. Deny logs pin SM1/SM3 to the settings create/update rule lines,
not an unrelated failure — fail-closed and isMinor-specific.

**Combined-rules compile confirmed:** conversations suite 5/5 green this run, which
proves the whole firestore.rules parses with all three BUT-674 surfaces present
(settings isMinor + profile isMinor + conversations minor-DM gate helpers).

**Pre-existing unrelated red still standing (NOT BUT-674):** age-gate suite is 32/33 —
the single fail is still C1 (`recipe_comments: age-compliant author can create a comment`,
`Property email_verified is undefined`), the BUT-1419 `isAccountMatured()` staleness from
the prior entry. My +169-line working diff is all test insertions; the failure predates it
and is outside BUT-674 scope. Delta from my change = exactly my 4 passing SM tests.

### 2026-07-03 — canonical-stats-rules.test.ts created (pooled ratings "Butlery-betyget", decision 10)

New test file `functions/src/__tests__/canonical-stats-rules.test.ts` (12 tests,
all green on the running emulator), wired as `test:rules:canonical-stats`,
appended to `test:rules:all` (after conversations), and in BOTH path-filter
blocks of `firestore-rules.yml`. Project id `butlery-canonical-stats-test`.

Map rows to add:

| `/users/{userId}/canonical_rating_events/{poolKey}` (owner-read, CF-only writes) | `canonical-stats-rules.test.ts` | `test:rules:canonical-stats` |
| `/canonical_recipe_stats/{poolKey}` (any-authed read, CF-only writes) | `canonical-stats-rules.test.ts` | `test:rules:canonical-stats` |

**Rule shape (decision 10, two server-authoritative pooled-ratings homes):**
- `canonical_rating_events`: `read: isAuthenticated() && auth.uid==userId` (owner
  only — GDPR export + future "my votes" UI); `create,update,delete: false`
  (Stage-A mirror CF via Admin SDK is the only writer; doc-ID = poolKey).
- `canonical_recipe_stats`: `read: isAuthenticated()` (any signed-in user reads
  the anonymous {count, average}); `create,update,delete: false` (Stage-B
  aggregator CF). Exact `recipe_social_stats` precedent. Doc-ID = opaque poolKey,
  no rater identity.

**Union-safety confirmed independently.** The collection-group catch-alls
(`match /{path=**}/members|friend_categories|engagements|comments|ratings|recipes|pings`)
end in a NAMED segment — none is `canonical_rating_events` or `canonical_recipe_stats`,
and there is NO recursive `match /users/{userId}/{...=**}`. So the only rules that
match these two paths are the specific matches + the L2451 global default-deny. No
broad grant unions in a client write. Deny logs pinned each write-deny to the
exact new rule lines (events L1941, stats L2419), each paired with L2451.

**Gaps I closed in the authored 10-test file (added 2, now 12):**
1. **Unauthenticated events read** — the only events-read deny was an authed
   STRANGER; added an `unauthenticatedContext()` deny (`isAuthenticated()` short-circuit).
2. **Collection-group leak guard** — `collectionGroup("canonical_rating_events").get()`
   by a non-owner must DENY (the engine cannot prove every matched doc satisfies
   `auth.uid==userId` for an unconstrained collection-group query). This is the
   load-bearing cross-user leak guard: if a future catch-all matching this
   subcollection is ever added, this test flips red before rater votes leak.
   `ctx.firestore().collectionGroup(name).get()` works on the compat SDK — no
   modular import needed.

No firestore.rules edits (rules authored by the task author, verified correct + minimal).
