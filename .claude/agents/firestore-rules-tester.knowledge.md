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

### 2026-04-25 — initial seed
Knowledge file created from `firestore-rules.test.ts` patterns observed at
agent setup time. Builders, actor conventions, and coverage rules above are
the baseline; future entries should record genuinely new shapes (new
collections, new validators, new actor types).

### 2026-04-26 — moderation-rules.test.ts created (BUT-511 + BUT-728)

New test file `functions/src/__tests__/moderation-rules.test.ts` covers the
admin-delete moderation overrides for four content types:

| Path | Builder | Tests |
|------|---------|-------|
| `users/{uid}/friend_categories/{id}` | `validFriendCategoryBody` | 3 |
| `public_profiles/{uid}` | `validPublicProfileBody` | 3 |
| `unified_shared_shopping_lists/{id}` | `validSharedShoppingListBody(ownerId)` | 3 |
| `cook_snaps/{id}` | `validCookSnapBody(userId)` | 12 |

Wired into `package.json` as `test:rules:moderation` + appended to
`test:rules:all`, and added to the `firestore-rules.yml` workflow path
filters. Uses `PROJECT_ID = "butlery-rules-moderation"` to keep the
emulator namespace clean.

### 2026-04-26 — rate-limit deny pattern via rate_limits subcollection

`rateLimitWrite(collection, seconds)` reads
`users/{auth.uid}/rate_limits/{collection}`. To prove the deny path:

```ts
await env.withSecurityRulesDisabled(async (admin) => {
  await admin
    .firestore()
    .doc(`users/${OWNER_UID}/rate_limits/cook_snaps`)
    .set({ lastWrite: new Date() });
});
// Now any cook_snaps create within 5s by OWNER_UID is rejected.
```

Note: the rate-limit sub-doc must use `lastWrite` as the field name. The
helper does `get(limitsPath).data.lastWrite + duration.value(seconds, 's')`
— mistaking the field name results in a `NoSuchFieldException` that is
treated as "no rate limit doc" and the write succeeds (false negative
for the test). Always use `lastWrite`.

### 2026-04-26 — userId-switch attack pattern for set()-based collections

For collections written via `BaseFirebaseRepository` (full-doc rewrite via
`set()`), the rule pins both `resource.data.userId` AND
`request.resource.data.userId` against `auth.uid`. To prove the deny:

```ts
// Seed with the legitimate owner
await admin.firestore().doc("cook_snaps/x").set(validCookSnapBody(OWNER_UID));
// Owner authenticated, but rewrites the doc with userId = OTHER_UID
const ownerCtx = env.authenticatedContext(OWNER_UID);
await assertFails(
  ownerCtx.firestore().doc("cook_snaps/x").set(validCookSnapBody(OTHER_UID))
);
```

This single test covers both halves of the dual pin — without the
`request.resource.data.userId == auth.uid` clause this assertion would
PASS (incorrectly), which is exactly the regression we want to catch.

### 2026-04-30 — onboarding progress (BUT-675) added to firestore-rules.test.ts

`/users/{userId}/onboarding/{progressDoc}` is a sibling of `consent` and
`acquisition` and follows the same owner-only `request.auth.uid == userId`
pattern. Tests live in `firestore-rules.test.ts` under section banner
`ONBOARDING PROGRESS (BUT-675)` with comment IDs `O1`–`O5`. Five tests:
owner read (O1), owner create+update (O2), unauth read deny (O3),
stranger read deny (O4), stranger write deny (O5). No schema validator
on the rule, so all assertions are identity-scoping checks. No new test
file or `package.json` script needed — covered by `test:rules:recipes-users`.

### 2026-04-26 — Java/emulator gap on Windows dev workstation

The hardcoded fact: this dev machine has no Java on PATH (verified
`java -version` → command not found). `ensure-firestore-emulator.sh`
errors out with `Could not spawn 'java -version'`. The CI workflow
(`.github/workflows/firestore-rules.yml`) sets up Temurin 21 explicitly,
so it's the verification path. Don't waste time trying to coax the
local emulator up — type-check the test (`npx tsc --noEmit src/__tests__/<file>.ts`)
and let CI run the suite.

### 2026-05-01 — menus-rules.test.ts created (BUT-746 + BUT-747)

New test file `functions/src/__tests__/menus-rules.test.ts` (17 tests),
wired in as `test:rules:menus` and appended to `test:rules:all`. Also
added to the `firestore-rules.yml` workflow path filters (PR + push).
Project id: `butlery-rules-menus`.

Map row to add:

| `/menus/{menuId}` | `menus-rules.test.ts` | `test:rules:menus` |

Builder shape — `validMenuBody(ownerUid, extra?)`:

```ts
{
  sharedByUserId: ownerUid,        // immutable
  menuTitle: "veckomeny v18",
  sharedAt: new Date(),            // immutable
  sharedToUserIds: [],
  ...extra,
}
```

Required fields per `hasRequiredFields` in the create rule:
`['sharedByUserId', 'menuTitle', 'sharedAt']`.

### 2026-05-01 — recipient self-scrub rule pattern (reusable)

Pattern for "recipient may shrink an array to remove themselves but
nothing else" (BUT-747 GDPR scrub on `/menus`). Encoded as the
secondary branch in `allow update`:

```
(resource.data.sharedToUserIds is list
 && request.auth.uid in resource.data.sharedToUserIds
 && !(request.auth.uid in request.resource.data.sharedToUserIds)
 && request.resource.data.diff(resource.data).affectedKeys()
     .hasOnly(['sharedToUserIds']))
```

Coverage requires four deny tests on the recipient branch alone:
1. Recipient mutates a non-`sharedToUserIds` field → blocked by `hasOnly`.
2. Recipient ADDS a UID (still in afterwards) → blocked by `!in`.
3. Recipient removes SOMEONE ELSE's UID (still in afterwards) → blocked by `!in`.
4. Recipient tries to delete the doc → falls through to owner-only delete.

Plus one allow: clean self-removal with no other changes. Same pattern
will recur on any future "leave-a-shared-doc" feature
(`unified_shared_shopping_lists` already has the analog).

### 2026-05-01 — paired removeAll() check closes self-scrub griefing (BUT-749)

The 2026-05-01 self-scrub branch (above) had a gap: a recipient could submit
ANY new array missing themselves, including one that also dropped other
recipients. The `!(auth.uid in NEW)` check passed but did not constrain what
ELSE could change in the array. Fix is a paired `removeAll` sandwich:

```
&& request.resource.data.sharedToUserIds
    .removeAll(resource.data.sharedToUserIds).size() == 0   // no additions
&& resource.data.sharedToUserIds
    .removeAll(request.resource.data.sharedToUserIds)
    .hasOnly([request.auth.uid])                            // only self removed
```

Plus a defensive `request.resource.data.sharedToUserIds is list` to keep CEL
type-safe before calling `removeAll` on it.

Reusable on any "self-leave a list-of-UIDs" rule. Coverage requires two new
deny tests: (1) scrub-self + remove-another, (2) scrub-self + empty-list.
The original "remove someone else WITHOUT scrubbing self" test (M12) is still
covered by the older `!(auth.uid in NEW)` clause (recipient still in NEW),
so it remains a separate assertion.

The `unified_shared_shopping_lists` collection uses a `memberPermissions`
MAP (not a UID list) and has no self-leave branch at all — different shape,
no analogous tightening needed. Any future GDPR-scrub work there must add a
NEW branch and gets its own test cluster.

### 2026-05-04 — Sprint G defence-in-depth deny blocks (BUT-627 + BUT-482)

Top-level wildcard match blocks `/audit/{document=**}` and
`/_internal/{document=**}` set `allow read, write: if false` for paths
written exclusively by Cloud Functions via the admin SDK (admin SDK
bypasses rules). Tests live in `audit-logs-rules.test.ts` under section
banner `SPRINT G — top-level /audit and /_internal defence-in-depth`,
with comment IDs `D1`–`D11`.

Coverage: 4 ops (read/create/update/delete) × 2 paths × authenticated +
1 unauthenticated read per path + 1 precedence regression that proves
the new `/audit/{document=**}` wildcard does NOT shadow the more-specific
`/audit_logs/{logId}` match (Firestore picks most-specific, but a
refactor could swap behavior — pin it).

Patterns worth reusing:

- **Seed via `withSecurityRulesDisabled` for read-deny tests.** Reading
  a non-existent doc can pass `assertFails` for the wrong reason
  (missing-doc null vs deny). Always seed the path first so the assertion
  proves the rule, not the absence of the doc.
- **Precedence regression test.** Whenever a wildcard `match /foo/**`
  is added next to a more-specific `match /foo_specific/{id}`, add ONE
  test that the specific path's allow-list still works. Cheap insurance.

No new test file/script needed — extended the existing `audit-logs-rules.test.ts`
(which already owns `audit_logs/{logId}`). Added the file to the
`firestore-rules.yml` workflow path filters so edits to the test file
alone trigger CI; rules-file edits already triggered it.

**Local-run gap remains**: Java not on PATH on this dev workstation
(see 2026-04-26 entry); type-checked the test instead with
`npx tsc --noEmit ...`. CI is the verification path.

### 2026-05-04 — symmetric-difference + isInList membership-gate pattern (BUT-464)

`users/{uid}/friend_categories/{categoryId}` non-owner update rule:

```
allow update: if isAuthenticated()
  && isInList('friendUserIds')                                  // membership gate
  && diff.affectedKeys().hasOnly(['friendUserIds', 'updatedAt']) // foreign-field gate
  && request.resource.data.friendUserIds.size() <= 200           // size cap
  && symmetricDifference(before, after).hasOnly([auth.uid])      // self-only mutation
  && rateLimitWrite('friend_category_member', 5);
```

Required coverage matrix (six branches → six deny tests + allow):
1. **isInList gate** — non-member attempting self-add must DENY.
2. **affectedKeys gate** — member touching any other field must DENY.
3. **size cap** — array > 200 must DENY.
4. **symmetric-difference** — member changing a foreign UID must DENY.
5. **rate-limit** — second write within window must DENY (per 2026-04-26 entry).
6. **Allow** — clean self-add and clean self-remove SUCCEED.

**Subtle allow**: `updatedAt`-only update (no `friendUserIds` change) PASSES because
`{}.toSet().difference({}.toSet())...hasOnly([uid])` evaluates true on empty sets.
Pin this with an explicit allow test or callers will silently rely on undefined behavior.

### 2026-05-04 — rate-limit collision across same-actor tests (gotcha)

When a test uses `rateLimitWrite(collection, N)` and the **same actor** performs
two writes in <N seconds across separate `test()` cases, the second write
DENIES regardless of payload — the rate-limit subcollection at
`users/{auth.uid}/rate_limits/{collection}` persists across test cases
within a single run.

Mitigation options:
1. Use a different `auth.uid` per test (preferred — most isolated).
2. Clear the rate-limit doc with `withSecurityRulesDisabled` between tests.
3. Use distinct parent `categoryId`s per test if the rate-limit key
   discriminates by parent (it does NOT for `friend_category_member` —
   it's keyed only by collection name).

This bites tests that look semantically independent but share the actor.
Audit any sprint that adds rate-limit predicates: the test file's first
test "can add self" and second test "can remove self" with same actor
will trip this on a real emulator run.

### 2026-05-04 — `members` collection-group catch-all coverage shape (BUT-463)

`match /{path=**}/members/{memberId}` with `allow read, delete` requires
TWO test categories beyond the basic auth/identity matrix:

1. **Canary test** — seed `userId: bob` at any path, read as bob, assert
   SUCCESS. Documents that the catch-all gates ONLY on `userId == auth.uid`,
   not on path. Failure of THIS test signals a parent-path rule has been
   added that overrides the catch-all (which may or may not be intentional).
2. **Path-agnostic allow** — seed at a never-before-used path, read as
   owning user, assert SUCCESS. Failure signals the catch-all has been
   accidentally narrowed.

Both must coexist; they prove different aspects of "the catch-all is the
only gate". Comment IDs `M1`–`M5` recommended.

Delete path requires its own allow + deny pair; read-only coverage misses
the delete branch entirely.

### 2026-05-28 — iter102-rules.test.ts created (shared_content list + notification expireAt)

New test file `functions/src/__tests__/iter102-rules.test.ts` (14 tests),
wired in as `test:rules:iter102` and appended to `test:rules:all`. Project id:
`butlery-rules-iter102`. Covers the iter-102 sprint diff.

Map rows to add:

| `/shared_content/{contentId}` (list) | `iter102-rules.test.ts` | `test:rules:iter102` |
| `/notification_delivery/{id}` (create) | `iter102-rules.test.ts` | `test:rules:iter102` |
| `/notification_engagement/{id}` (create) | `iter102-rules.test.ts` | `test:rules:iter102` |

Diff was three branches:
1. `shared_content allow list` gained a recipient branch
   (`auth.uid in resource.data.sharedToUserIds`).
2/3. `notification_delivery` + `notification_engagement` create rules added
   `expireAt` to their `keys().hasOnly([...])` allowlists (90-day TTL field).

**`allow list` recipient-branch test pattern (reusable):** A `list` rule that
gates on `auth.uid in resource.data.<arrayField>` is evaluated PER candidate
document. To exercise it you MUST run a query whose `where(...)` filter
guarantees every matched doc satisfies the rule — e.g.
`.where("sharedToUserIds", "array-contains", uid)`. The critical leak-guard
deny is: query for ANOTHER user's array value (`array-contains` other-uid) as
the requester → must `assertFails` because the requester is neither sharer nor
in those docs' arrays. Also pin: (a) unfiltered `.collection().get()` must
DENY (proves the branch didn't make the collection openly listable), and
(b) the pre-existing sharer branch still lists (regression guard).

**`expireAt` / TTL allowlist test pattern:** When a field is added to a create
rule's `keys().hasOnly([...])`, the coverage triad is: allow-with-field,
allow-without-field (back-compat / subset since hasOnly permits subsets when no
hasRequiredFields forces it), and deny-unknown-field (proves hasOnly was
extended by one explicit key, not loosened). Plus the standard impersonation
deny.

**Subtlety — `in` on a missing field:** `shared_content` create does NOT
require `sharedToUserIds` (only sharedByUserId/contentType/sharedAt). A doc may
lack the field; `auth.uid in resource.data.sharedToUserIds` would CEL-error on
such a doc, but since the recipient query filters by `array-contains` it only
matches docs that have the field, so the live path is safe. Verdict: diff is
SAFE.

Local-run gap persists: Java still not on PATH (emulator hook fails with
"Could not spawn java -version"). Type-checked instead with
`npx tsc --noEmit ... iter102-rules.test.ts` (EXIT 0). CI is the verification
path.

### 2026-06-03 — Java NOW on PATH; emulator runs locally (supersedes 2026-04-26 + iter102 gap)

`java -version` → OpenJDK 21.0.11 LTS is installed on this workstation now.
The "no Java, type-check only" gap from 2026-04-26 and the iter102 entry is
**stale** — the Firestore emulator (and Storage emulator) start and the suites
run green locally. Verification is real now, not CI-only.

### 2026-06-03 — Storage rules testing (BUT-1049 comment images)

First STORAGE rules test in the repo:
`functions/src/__tests__/comment-images-storage-rules.test.ts`
(`test:rules:comment-images-storage`, appended to `test:rules:all`).
Project id `butlery-rules-comment-images`.

Map row to add:

| `users/{authorId}/comment_images/{imageId}` (storage.rules) | `comment-images-storage-rules.test.ts` | `test:rules:comment-images-storage` |

Patterns:
- **Init storage, not firestore:** `initializeTestEnvironment({ projectId, storage: { rules, host, port: 9199 } })`. `firebase.json` maps storage emulator to 9199.
- **Storage client API:** `import { ref, uploadBytes, getBytes } from "firebase/storage"`; act with `ctx.storage()`. Set content type via the third `uploadBytes(ref, bytes, { contentType })` arg so `isValidImage()` is exercised. Tiny valid bytes: `new Uint8Array([0xff,0xd8,0xff,0xd9])`.
- **Seed for read tests** via `withSecurityRulesDisabled(ctx => uploadBytes(...))` so a read-deny proves the rule, not a missing object.
- **Most-specific match wins in Storage too:** a narrow `match /users/{authorId}/comment_images/{imageId}` overrides the broad `match /users/{userId}/{allPaths=**}`. PIN this with two tests: (a) a different authenticated user CAN read the comment image (only possible if the specific match wins over the owner-only wildcard read), and (b) a regression guard that a sibling path (`users/{uid}/recipes/...`) is STILL owner-only read (proves only the comment_images subtree was opened).
- **CI must start storage too:** `firebase emulators:start --only firestore,storage`. The storage emulator answers HTTP 501 to a bare `GET /` — check connectivity (`curl -s -o /dev/null`), not a 2xx, in wait loops. Updated `.github/workflows/firestore-rules.yml` accordingly and added `storage.rules` + the test file to path filters.

### 2026-06-03 — recipe_comments imageUrls validator (BUT-1049)

The `recipe_comments` create rule uses `hasRequiredFields` (`hasAll`, a SUBSET
check) — NOT `keys().hasOnly([...])`. So a new field like `imageUrls` is
accepted with zero rule change but ZERO validation. To bound it, add a
conditional validator clause (present-only, for back-compat):

```
&& (
  !('imageUrls' in request.resource.data)
  || (request.resource.data.imageUrls is list
      && request.resource.data.imageUrls.size() <= 3)
)
```

Coverage: allow <=3, allow empty list, allow absent (back-compat), deny >3,
deny non-list type, plus the unchanged author/impersonation/blocking denies
still hold with a valid imageUrls payload. **CEL gap:** there is no clean way
to assert every list element is a string element-wise — `is list` + `size()`
is the enforceable bound; a list containing a non-string passes the rule.
Documented as a known Medium gap, not a test miss.

### 2026-06-03 — EMULATOR PERSISTS DATA ACROSS `npm run` INVOCATIONS (critical isolation gotcha)

`env.cleanup()` only closes clients — it does NOT wipe stored documents. The
emulator stays up between separate `npm run test:rules:*` calls, so documents
written in run N are still there in run N+1 (per PROJECT_ID namespace). Two
failure modes this causes, both LOOK like rule regressions but are test
isolation bugs:

1. **`assertSucceeds(set(fixedId))` becomes an UPDATE on the 2nd+ run.** The doc
   already exists, so the engine evaluates the `update` rule, not `create`.
   recipe_comments' update rule only permits text/counter changes → a full-body
   re-set is DENIED. Fix: suffix every create-allow doc id with a per-run token
   `const RUN = Date.now().toString(36)` (e.g. `recipe_comments/c-img-ok-${RUN}`).
   Deny tests are immune (deny-on-update is still deny). This bit BOTH new and
   pre-existing create-allow tests (`c-create-allow`, `n-allow`) in
   recipe-comments-rules.test.ts.
2. **Rate-limit docs persist** (the older 2026-05-04 entry) — same root cause.

CI is unaffected because it boots a FRESH emulator per job. To reproduce/clear
locally: `curl -X DELETE
"http://127.0.0.1:8080/emulator/v1/projects/<PROJECT_ID>/databases/(default)/documents"`.
When debugging "N/22 failed locally but passed in CI", suspect persisted
emulator state FIRST — clear and re-run before touching rules or tests.

The real PROJECT_IDs (grep `PROJECT_ID =` across `src/__tests__/*.ts`) do NOT
follow a guessable pattern (e.g. reports = `butlery-rules-test`, recipes-users =
`butlery-rules-recipes-users`). Grep them, don't guess, when clearing.

### 2026-06-03 — Admin-SDK cascade integration test against emulator (BUT-1009)

First emulator-backed test that exercises a Cloud Functions CASCADE (not rules):
`functions/src/__tests__/request-account-deletion.integration.test.ts`
(`test:integration:account-deletion`, appended to `test:rules:all` and the
`firestore-rules.yml` path filters along with `functions/src/account/**`).
Project id `butlery-acct-deletion-integration`.

This is a different harness shape from the rules tests — it does NOT use
`@firebase/rules-unit-testing`. The cascade (`account-deletion-cascade.ts`)
runs on the **Admin SDK** (`admin.firestore.Firestore`, `FieldValue.arrayRemove`,
`.count()`, `commitInChunks`). To point the Admin SDK at the emulator:

```ts
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080"; // BEFORE importing admin
process.env.GCLOUD_PROJECT = PROJECT_ID;
import * as admin from "firebase-admin";
admin.initializeApp({ projectId: PROJECT_ID });
```

Key differences vs rules tests:
- Admin SDK **bypasses security rules**, so seed with plain `db.collection().set()`
  — there is no `withSecurityRulesDisabled` (that's a rules-unit-testing concept).
- `auth` + `storage` deps are injected NO-OP fakes — the cascade's auth-delete
  and storage-wipe are already covered by the contract test
  (`request-account-deletion.test.ts`); the integration test isolates the
  FIRESTORE cascade only.
- Run the cascade ONCE in `run()` before the assertion loop; each `test()`
  reads post-cascade state. Capture the result envelope in a module-level var
  so a final test can assert `failedCollections.length === 0`.
- Isolation: same emulator-persistence gotcha applies. Clear the namespace via
  the REST `DELETE /emulator/v1/projects/<id>/databases/(default)/documents`
  (done with a raw `http.request` in setup AND teardown) AND suffix all uids
  with a per-RUN token. Belt-and-suspenders because a re-run that didn't clear
  would otherwise re-delete already-deleted docs (idempotent, but control docs
  would accumulate).

**Cascade behavior verified == ticket spec (no bugs found).** 21/21 green:
own-data collections delete (recipes top+sub, menus sub+own, shopping_lists,
ratings hard-delete) with control docs (other uid) retained; inbound menu +
inbound shared_content keep the doc and scrub uid from `sharedToUserIds`;
`group_weekly_menu_plans` deletes the now-empty plan and scrubs the populated
one (participantUserIds + participants array + memberPermissions key all
cleaned); `recipe_comments` anonymized to `authorId:'deleted'` /
`isDeleted:true` (NOT deleted — thread structure preserved); 1:1 conversation
deleted, >2-participant conversation arrayRemove'd + retained.

**Reusable pattern for any future cascade/trigger integration test:** inject
the live emulator Firestore as `deps.db`, fake the non-Firestore deps, prove
each step with a POSITIVE (own data gone / scrubbed) + NEGATIVE (control doc by
another uid untouched) pair. A green delete WITHOUT a control-retained
assertion does not prove scope — it could be deleting everything.

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

### 2026-06-03 — cascade collectionGroup + shopping-list item-scrub coverage (BUT-1191)

Extended `request-account-deletion.integration.test.ts` (21→31 tests) for two
cascade surfaces the BUT-1009 seed missed. Both verified CORRECT — no erasure
gap found, 31/31 green on the emulator. Author-field map is the load-bearing
detail (these are NOT `userId`):

| collectionGroup | author field queried | cascade action |
|-----------------|----------------------|----------------|
| `pings`         | `fromUserId`         | hard delete (`deletePingsByUser`) |
| `comments`      | `commentedBy`        | hard delete (`deleteCommentsAndRatings`) |
| `ratings`       | `ratedBy`            | hard delete (`deleteCommentsAndRatings`) |

Note the trap: top-level `recipe_comments` keys on `authorId` and is ANONYMIZED,
while the collectionGroup `comments` (subcollection, any parent) keys on
`commentedBy` and is HARD-DELETED. Different field, different verb, same step.
Seed collectionGroup fixtures under a NON-recipe parent (used `group_feed/*/pings`
and `cook_snaps/*/comments|ratings`) so the assertion proves the path-agnostic
collectionGroup walk, not a path-scoped query. Control doc by OTHER under the
same parent must survive.

`unified_shared_shopping_lists` item-level scrub (`deleteShoppingLists`, lines
183-213): query is `where('memberPermissions.{uid}', '!=', null)` then rewrites
the `items` array in place. Per item, two INDEPENDENT blocks: if
`item.assignedToUserId === uid` → null `assignedToUserId/assignedToDisplayName/
assignedAt`; if `item.purchasedByUserId === uid` → null `purchasedByUserId/
purchasedByDisplayName/purchasedAt`. List doc RETAINED (shared, not owned).
Coverage needs three item fixtures to prove field-level precision: (i) assigned
AND purchased by target → both blocks null, (ii) assigned to OTHER → fully
untouched, (iii) purchased by target but assigned to OTHER → only purchased
block nulled, foreign assignment kept. A single "target item scrubbed" assertion
would not catch a too-greedy rewrite that also wiped a co-member's authorship.
