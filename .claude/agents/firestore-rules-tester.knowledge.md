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
