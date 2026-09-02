# firestore-rules-tester — archived patterns (pre-2026-06-04, relocated 2026-07-04). Append-only historical record; the live agent reads the main file + consults this when an index line below is relevant.

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

## Archived 2026-07-24 (distilled into principles)

The entries below were moved here verbatim from the live knowledge file during
the 2026-07-24 distillation pass (they were dated 2026-06-10 through
2026-06-21, older than the then-current 2026-06-24 recency cutoff). Their
condensed guidance lives in the `## Principles` section at the top of
`firestore-rules-tester.knowledge.md`. Kept exactly as originally written,
including one out-of-order entry (2026-06-20, filed after a 2026-06-21 entry
in the original log).

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

## Archived 2026-07-24, round 2 (shape-based, not date-based — distilled into principles)

Round 1 (above) archived everything older than a 2026-06-24 recency cutoff. The
coordinator's follow-up correctly identified that the cutoff was the wrong shape:
a live-memory file should hold principles, not a log, regardless of how recently
a pattern was found. This round moves the remaining 15 raw dated entries (originally
2026-06-27 through 2026-07-18) here verbatim; their distilled guidance now lives in
the `## Principles` section of `firestore-rules-tester.knowledge.md` alongside
round 1's. Nothing below is different from how it was originally written.

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

### 2026-07-09 — collection-group-wildcards-rules.test.ts reviewed (BUT-1512, 23/23 green)

Reviewed the new suite covering the five owner-shaped `{path=**}/<name>/{id}`
catch-alls that the dedicated `members` suite (BUT-463) doesn't cover:
`engagements` (DOC-ID gate L2095), `comments` (commentedBy L2102), `ratings`
(ratedBy L2110), `recipes` (isAdmin-only read L2119), `pings` (fromUserId||toUserId
L2128). Rule shapes verified against firestore.rules — test claims match exactly.
Wiring complete: npm `test:rules:collection-group-wildcards`, appended to
`test:rules:all`, in BOTH `firestore-rules.yml` path blocks. Project id
`butlery-cg-wildcards-test`.

Map rows to add:

| `/{path=**}/engagements/{userId}` (doc-id gate) | `collection-group-wildcards-rules.test.ts` | `test:rules:collection-group-wildcards` |
| `/{path=**}/comments/{commentId}` (commentedBy) | `collection-group-wildcards-rules.test.ts` | `test:rules:collection-group-wildcards` |
| `/{path=**}/ratings/{ratingId}` (ratedBy) | `collection-group-wildcards-rules.test.ts` | `test:rules:collection-group-wildcards` |
| `/{path=**}/recipes/{recipeId}` (admin read) | `collection-group-wildcards-rules.test.ts` | (also in admin-dashboard suite) |
| `/{path=**}/pings/{pingId}` (from/toUserId) | `collection-group-wildcards-rules.test.ts` | `test:rules:collection-group-wildcards` |

**Idempotent-without-clearFirestore pattern (worth reusing).** This suite has NO
namespace clear yet is re-run-safe on the persistent emulator because EVERY test
re-`seed()`s its doc via `withSecurityRulesDisabled` before the read/delete under
test (delete tests re-seed then delete). `.set()` overwrites, so a leftover doc
from a prior run is harmless — the persistence gotcha only bites suites whose
create-allow doc ids aren't re-seeded. When a suite is all reads+deletes on
pre-seeded docs, per-run tokens/clearFirestore are unnecessary.

**Small coverage gaps (not blockers), pinned for a future top-up:**
- comments/ratings/pings have no explicit *unauthenticated*-read deny (engagements
  e4 + recipes rec3 do). The `isAuthenticated()` short-circuit branch is trivial
  CEL and the deny is already proven via foreign/missing-field cases, so Low.
- `recipes` catch-all is read-only but has no negative write/delete test proving
  an admin CANNOT write via it (rule comment claims "admins never write here"). A
  regression opening write would go unpinned. Low.

### 2026-07-18 — tag-overrides-log-rules.test.ts created (BUT-1473, 14/14 green)

New top-level collection `/tag_overrides_log/{entryId}` (own-data, append-only
allergen tag-override log feeding the tagging learning loop). Rule is a byte-for-byte
CONTRACT MIRROR of `/parsing_corrections/{correctionId}` directly above it
(firestore.rules L2022–2072): read = owner (`auth.uid == resource.data.userId`) OR
`isAdmin()`; create = authed + `auth.uid == request.resource.data.userId` +
`hasRequiredFields(['id','userId','recipeId','type','tag','direction','timestamp'])`;
`update: if false`; delete = owner only (GDPR Art. 17). Only diff from
parsing_corrections is the required-field list (`recipeId,type,tag,direction` vs
`source`). New test file (14 tests), wired as `test:rules:tag-overrides-log`,
appended to `test:rules:all` (after collection-group-wildcards), and added to BOTH
path-filter blocks in `firestore-rules.yml`. Project id
`butlery-tag-overrides-log-test`.

Map row to add:

| `/tag_overrides_log/{entryId}` (own-data, append-only, admin-read) | `tag-overrides-log-rules.test.ts` | `test:rules:tag-overrides-log` |

**Coverage shape (reusable for any parsing_corrections-style own-data append-only
log):** create {owner-allow, cross-user-deny, unauth-deny, missing-field-deny ×2
different required keys}; read {owner-allow, admin-allow, stranger-deny,
unauth-deny}; update {partial-update-deny, set-on-existing-deny — both, since a
buggy client retry hits the set path}; delete {owner-allow, stranger-deny,
unauth-deny}. Two missing-field denies (tag + direction) so `hasRequiredFields`
covers more than one anchor. Admin seeded via `/admins/{ADMIN_UID}` in setup.

**RULES-SOUND — no gap.** Deny logs pin each write-deny to the exact new rule lines
(create L2061, update L2066, delete L2070) paired with the L2482 global default-deny.
Union-safety: single-segment top-level path can't match any `{path=**}/<name>/{id}`
collection-group catch-all (all end in a named subcollection segment), so no
accidental allow union — the only other matching rule is the L2482 global default.
Create-allow doc ids use a per-RUN `Date.now().toString(36)` token; read/update/
delete tests re-seed via `withSecurityRulesDisabled`, so the suite is re-run-safe
on the persistent emulator without a namespace clear. No firestore.rules edits.

### 2026-07-18 — BUT-1626 public_profiles minor searchability hard-deny + group-minor CF

Reviewed the BUT-1626 (BUT-674 follow-up) diff. Two rule surfaces on
`public_profiles/{userId}`, both fully covered by 5 new tests appended to
`age-gate-rules.test.ts` (all 38/38 green on emulator):
- create: `&& (request.resource.data.isSearchable != true || !accountIsMinor(userId))`.
- update: `&& (!diff.affectedKeys().hasAny(['isSearchable']) || isSearchable != true || !accountIsMinor(userId))`
  — gated on the DIFF so a minor with a legacy true value can still edit name/avatar,
  and a normal isSearchable:false save still corrects.

New helper `accountIsMinor(userId)` = `exists(users/{userId}) && get(...).data.get('isMinor', false)==true`
— the SAME exists-guarded fail-open-on-missing-doc pattern as `otherIsMinor` in the
conversations 1:1 gate (2026-07-01). Missing users doc / absent isMinor reads as
non-minor (adults unaffected). Deny logs pin PP2/PP4 to `false for create @ L614` /
`false for update @ L635` — genuine gate denies, not eval-errors. **PP3 (minor +
isSearchable:false → ALLOW) is the load-bearing contrast** that proves the deny is
the isSearchable:true+minor combination, not a blanket "minor can't write."

**Coverage table addition:** the friendsCount OR-branch (L650) and admin-update
branch (L664) both use `hasOnly([...])` that excludes isSearchable, so neither can
be used to bypass the minor gate — verified by reading, not pinned as a test (Low,
the `hasOnly` makes it structurally impossible).

**Group-minor CF (`enforceGroupMinorMembership`, onDocumentCreated conversations/{id}):**
rules can't iterate a group participant list, so a Cloud Function backstops the 1:1
`passesMinorDmGate`. Pure decision core `computeMinorsToRemove` is unit-tested 6/6
(`test:enforce-group-minor-membership`, auto-discovered by `npm test` via
run-all-tests.js — properly wired). Verified the CF's `data.metadata.creatorId`
field assumption matches the client: `Conversation.group` writes
`metadata:{'creatorId':creatorId}` (conversation.dart L255) — so the fail-safe
"unknown creator → remove all minors" branch is only reachable for legacy/tampered
docs. Friend direction (`users/{minor}/friends/{creator}`) matches the rules gate.

**GAP (Medium):** the CF's I/O wrapper (group-size early return, remaining<2 →
delete vs update, participantDisplayNames/AvatarUrls/lastReadTimestamps FieldValue.delete
cleanup, per-user membership-mirror cleanup) has NO emulator integration test — only
the who-gets-removed core is covered. The safety decision IS tested; the write
mechanics are not. Sibling `sync-conversation-last-message` has the same
pure-core-only shape, so this matches existing convention (not a regression).

Non-rules items in the same diff (verified, no bug): `setLifecycleStage(stage,
{required bool isMinor})` — interface change consistent across firebase/noop/interface
+ test mocks; e2e `_MockAnalyticsRepository` uses `noSuchMethod` so no compile break;
raw setter has NO production caller (real suppression is `UserPropertyBootstrap.emitLifecycle`
gating `profile?.isMinor`), so the required-param gate is pure defense-in-depth.
Feature-flag `audit_log_retention_days` + `auditLogRetentionDays` removal (BUT-1560)
is clean — repo-wide grep finds zero remaining refs beyond the two explanatory comments.

### 2026-07-18 — BUT-1626 follow-up: conversations create binds metadata.creatorId to caller (spoof fix)

Supersedes the "only verified the CF's field assumption" note in the prior 2026-07-18
entry — the create rule now ENFORCES the binding, and it is proven. New clause on
`conversations/{id}` create (firestore.rules ~L1522):
```
&& (!('metadata' in request.resource.data)
    || !('creatorId' in request.resource.data.metadata)
    || request.resource.data.metadata.creatorId == request.auth.uid)
```
Closes a spoof: a tampered client could forge `metadata.creatorId` to a friend of a
minor (or the minor's own uid, hitting the CF's uid===creator skip) and slip a
non-friend group-add past `enforceGroupMinorMembership`'s friend check. Absent
metadata/creatorId → allowed (CF fails closed, removes minor when creatorId absent).

Two tests appended to `conversations-rules.test.ts` (now 7/7 green):
- **C6 (deny):** STRANGER creates `[STRANGER, ADULT]` with `metadata.creatorId=FRIEND` → DENY.
- **C7 (allow):** identical body but `creatorId=STRANGER` (the caller) → ALLOW.

**The C6/C7 pair IS the fail-closed proof** — adult 1:1 target means `passesMinorDmGate`
passes for both, so the ONLY variable is creatorId, isolating the deny to the binding
(not the minor-DM gate or rate limit). C6 deny log pins `false for 'create' @ L1514`
(clean gate deny, not an eval-error). RULES-SOUND, no gap.

The public_profiles minor-searchability tests (PP1–PP5) from the prior entry re-ran
green in the same age-gate run (38/38): PP2 deny `@ L614`, PP4 deny `@ L635`+`@ L664`
(isSearchable-update branch AND admin branch both deny), PP1/PP3/PP5 the allow contrasts.


### 2026-07-28 — BUT-1725 `unified_shared_shopping_lists` append-only contributor trail

New suite `functions/src/__tests__/shared-shopping-lists-rules.test.ts`
(`test:rules:shared-shopping-lists`, PROJECT_ID `butlery-shared-shopping-lists-test`),
**25/25 green**. Registered in `test:rules:all` and in BOTH `paths:` blocks of
`.github/workflows/firestore-rules.yml`.

The rule (firestore.rules L1612-1616, invoked at L1642; create-side bound at L1634):
```
function keepsContributorTrail() {
  return request.resource.data.get('contributorUserIds', [])
           .hasAll(resource.data.get('contributorUserIds', []))
    && request.resource.data.get('contributorUserIds', []).size() <= 200;
}
allow update: if isAuthenticated() && keepsContributorTrail() && ( owner || member-with-edit )
```
`contributorUserIds` is the only handle `account-deletion-cascade.ts` (L227/L521,
`array-contains`) has on a shared list a member has already LEFT. Append-only for
EVERY client writer, owner included; Admin SDK bypasses rules so the cascade's
`arrayRemove` still works (pinned as SSL24).

Client write shapes it must not break (all verified):
- `createCollaborativeList` — `docRef.set({...toFirestore(), contributorUserIds:[uid]})` (SSL1)
- `updateCollaborativeList` — narrowed `docRef.update(payload)`, field untouched (SSL6)
- `mutateCollaborativeList` — `transaction.set(..., merge:true)` with the union computed
  from a Dart **Set**, so ELEMENT ORDER IS NOT PRESERVED (SSL8 — `hasAll` is
  set-semantics, this is why the rule must not be an equality/prefix check)
- `_withContributor` offline replay — `FieldValue.arrayUnion([uid])` (SSL11, SSL10)

**Findings, no rule defect:**
1. (Medium, by design) The bound reads `request.resource` only, so a doc already over
   200 is FROZEN — even an items-only update denies (SSL20 pins it). Reachable only via
   an Admin-SDK write, since the client path can never cross the bound. Fix would be a
   rule change, not a client one.
2. (Low, by design) At exactly 200 a 201st contributor is not merely un-trailed, they
   are fully locked out of editing, because the client unconditionally unions itself
   (SSL19). Bound is inclusive: 200 allows on both create (SSL3) and update (SSL12).

**One false FAIL of my own making**, worth remembering: my `validListBody` stamped
`createdAt: new Date()`, and the member branch (L1647) forbids a non-owner touching
`createdAt` — SSL8 denied for a reason unrelated to BUT-1725 and initially read as a
rule defect. Fixed with a module-level `CREATED_AT` constant; SSL25 now pins the
createdAt-immutability rule so the pairing is self-documenting.

**Emulator debug output reads TWO evaluation passes.** Every authenticated deny printed
`evaluation error at L1642:24 for 'update' @ L1642, ... false for 'update' @ L1642` —
the first pass has no `resource` loaded so anything dereferencing `resource.data` errors;
only the unauthenticated test short-circuited at `isAuthenticated()` and printed a clean
`false`. Pre-existing (the old rule also dereferenced `resource.data` in its first
conjunct), NOT introduced by this diff. Read the second verdict.

**Mutation probe** (in-memory `rules.replace`, throwaway projectIds `but1725-probe-a/b`,
file never touched, probe deleted after):
- A — `keepsContributorTrail() &&` removed from `allow update`: SSL13/14/15/16/17/19/20
  ALL flipped to allowed (7/7).
- B — `.size() <= 200` raised to 100000: SSL4 (create 201) and SSL19 (grow past 200) both
  flipped.
- B initially reported SSL4 "still denied" — **probe bug, not a rule finding**: the
  function's bound and the create rule's bound are byte-identical (`.size() <= 200;`) and
  a non-global `String.replace` patched only the first. `/g` fixed it. Always `/g` when
  mutating a literal that appears more than once in firestore.rules.

### 2026-07-30 — BUT-1746: the read gate's LIST path was the untested branch

Reviewing the shopping/account sprint diff (`shared-shopping-lists-rules.test.ts` +
BUT-1746 client fixes). The diff added SSL26–SSL31, six `get()`-based read tests, and its
own banner comment claimed "it is why an unfiltered collection query is refused outright
rather than over-sharing (BUT-1746)" — an assertion about the QUERY path with no test
behind it. Added SSL37–SSL39 (39/39 green):

- SSL37 — `collection(COL).where('memberPermissions.<EDITOR>','!=',null).limit(200).get()`
  by an edit member SUCCEEDS. Uses the compat API off `ctx.firestore()` (no modular cast
  needed for a plain query — the cast is only required for `getCountFromServer`). Asserts
  `!snap.empty` as a premise, because a query matching nothing would pass vacuously.
- SSL38 — the same collection with NO `where()` is DENIED for the same actor. Seeds a
  `query-foreign` doc owned by STRANGER inside the test so the fixture is load-bearing
  and the suite is runnable standalone.
- SSL39 — the filtered query by an actor who is a member of nothing SUCCEEDS and returns
  empty. **First draft used `STRANGER` and would have failed**: SSL38 seeds a list
  STRANGER owns, and the emulator persists it across runs. Switched to a
  `list-nobody-uid` seated nowhere. Generalisable: an "allowed but empty" query test needs
  an actor that no other test in the file ever puts in a `memberPermissions` map.

Client-side premise verified directly against the pinned SDK
(`cloud_firestore-6.6.0/lib/src/query.dart`): line 659 `if (isNotEqualTo != null)
addCondition(field,'!=',isNotEqualTo)` — a literal null adds nothing; lines 676-682
`isNull: false` → `addCondition(field,'!=',null)`. So `tools/check_null_filter.sh`'s
rationale is exactly right, and `isNull: false` is the spelling to mirror in a rules test.

Also confirmed on this run: `unified_shared_shopping_lists` create requires
`hasRequiredFields(['ownerId','memberPermissions','items','createdAt'])` (L1631) and
delete is `uid == resource.data.ownerId` (L1651) — SSL32–SSL36 pin both correctly, each
one delta from the SSL1 baseline body. The `evaluation error at L1642:24` / `L1651:24`
first-pass noise on every authenticated deny is the pre-existing two-pass artifact; read
the second verdict.

Cross-layer note worth keeping: none of this is provable from the Dart side.
`fake_cloud_firestore` evaluates no rules, so
`shopping_repository_query_module_test.dart` proves the filter SHAPE and says nothing
about whether the server accepts it — the two suites are complements, not duplicates.
Mutation-proof of the Dart half (spelling reverted in-place, restored and
`git hash-object`-verified byte-identical to HEAD): 3 tests redden — the `readAll`
positive and BOTH `collaborativeListsStream` tests. `readAll`'s "member of nothing" test
does NOT redden, because `readAll` catches every error and returns `[]`; the diff's own
comment says exactly that, and it is accurate.

### 2026-07-30 — re-review addendum: `check_null_filter.sh`'s comment filter is path-shape dependent

Re-review pass over the same sprint fileset. The rules suite re-ran green (39/39, emulator
at 127.0.0.1:8080) and the three Dart suites re-ran green (112/112: query module, routing
module, data export). `node functions/scripts/check-test-registration.js` → OK, 118 files,
38 rules suites across both `paths:` blocks. `dart format --set-exit-if-changed` clean on
all nine touched Dart files; `dart analyze` clean on all four touched directories.

One NEW fact, established by exercising the new guard rather than reading it. The
comment-skipping filter in `tools/check_null_filter.sh` is

```
| grep -vE '^[^:]*:[0-9]+:[[:space:]]*(//|\*)'
```

`[^:]*` for the path means the anchor only holds for a path with NO colon in it. Verified
both ways on fixtures:

- relative paths (`lib/...`, what lefthook's `{staged_files}` produces) and MSYS-style
  absolute paths (`/c/Users/...`) → comments correctly skipped, exit 0;
- a drive-letter absolute path (`C:/Users/.../ok.dart`) → the drive colon eats the anchor
  and all three comment lines are reported as violations, exit 1.

That matters here because the ban is *deliberately* named in prose at the fixed sites: 12
comment lines across 6 files (`firebase_comments_repository`, `firebase_data_export_repository`,
`firebase_group_weekly_menu_plan_repository`, `shopping_repository_query_module`, and two
test files) contain the forbidden spelling. So the guard flags its own rationale the moment
it is handed a `C:/`-shaped path. It fails CLOSED (noisy block, never a silent miss), and no
current invocation shape produces such a path, so it is a robustness note, not a defect.
`[^:]*` → `.*` with the line-number group carrying the anchor would remove the assumption.

Also worth keeping for guard-writing generally: the script's no-argument mode is documented
as "the CI / manual shape", but no workflow calls it — grep of `.github/workflows/` finds
only `check_no_inline_adoption_pct.sh`. It is pre-commit-only, same as
`swedish-boundary-guard`, so the precedent exists; the comment simply overstates the wiring.

### 2026-07-30 — Re-review of the shopping/account sprint fixes: 39/39 green, guard probed

Re-reviewed the working tree after automated fixes (BUT-1706 / BUT-1721 / BUT-1732 /
BUT-1746 / BUT-1758). `npm run test:rules:shared-shopping-lists` → **39/39 passed**, up
from 25: SSL26-SSL31 (read gate: owner / edit / view allow, revoked-member, non-member,
unauthenticated deny), SSL32-SSL34 (create conjuncts: unseated `memberPermissions`,
missing `items`, missing `createdAt`), SSL35-SSL36 (owner-only delete), SSL37-SSL39
(the LIST/QUERY path: filtered-allow-non-empty, unfiltered-deny with a foreign doc
seeded in the same test, member-of-nothing allowed-but-empty).

**Mutation probe of the read rule** (in-memory `replace()` to `allow read: if
isAuthenticated();`, fresh projectId, file byte-verified unchanged afterwards): SSL29,
SSL30 and SSL38 all FLIPPED to allow — so none of the three is vacuous, and SSL38's
unfiltered-query deny really is the `uid in resource.data.memberPermissions` predicate
refusing the whole query rather than an index or shape error. Two probe mechanics cost a
run each and are now in the principles: the probe file must live under `functions/src/`
(module + tsconfig resolution), and `firestore.rules` is CRLF so a literal
template-string match silently finds nothing — regex, and assert the match count.

Also verified in the same pass (Dart side, all green): `flutter test` on the two shopping
module suites → 76 passed; `data_export_service_test.dart` → 36 passed;
`test/unit/services/account/export/` → 118 passed; `flutter analyze` on all eight changed
Dart files → clean; `node functions/scripts/check-test-registration.js` → OK, 118 test
files / 38 rules suites / 4 accepted-debt warnings.

`tools/check_null_filter.sh` probed directly rather than read: relative-path arg mode is
correct (flags a real construction site, skips `//` and `*` comment lines); the two
residual false-positive shapes are a colon-containing path argument (`C:/...` flags the
WHY-comments, because the comment-skip anchor is `^[^:]*:[0-9]+:`) and an unbounded `null`
in the pattern (`isNotEqualTo: nullableVar` matches). Both fail CLOSED — noise, never a
missed violation — and lefthook passes repo-relative paths, so pre-commit is unaffected.

### 2026-07-30 — BUT-1706 rescue pass: proving SSL40 (revoked-member update deny) is not vacuous

Reviewed the STAGED diff of `functions/src/__tests__/shared-shopping-lists-rules.test.ts`
only; `git diff --cached -- firestore.rules` was empty (verified) and the file's md5
(`3bda63152c0f3ae2a9a59f82961dfd4b`) was identical before and after every probe.

Suite re-run against the already-listening emulator:
`cd functions && FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 npm run test:rules:shared-shopping-lists`
→ **40/40 passed**, twice, deterministically.

**The claimed proof of SSL40's distinctness was wrong.** The sprint reported that SSL22
(non-member) denies with `evaluation error at L1642:24` while SSL40 (revoked member)
denies with a plain `false for 'update' @ L1642`. It does not — both print, byte for byte:

    evaluation error at L1642:24 for 'update' @ L1642, false for 'update' @ L2549,
    false for 'update' @ L1642, false for 'update' @ L2549

Only SSL23 (unauthenticated) differs, and only because `isAuthenticated()` short-circuits
before `resource` is dereferenced. The first-pass evaluation error fingerprints the RULE
LINE, not the actor, so no verdict-string comparison can ever distinguish two deny tests.

SSL40 is nevertheless genuinely non-vacuous — proved empirically instead (probe under
`functions/src/`, deleted in the same shell call), 6/6 as predicted:

| probe | outcome |
|---|---|
| SSL40 control — revoked member, items-only update | DENY |
| fail-closed — identical doc/id/actor/payload, DEPARTED SEATED as `edit` | ALLOW |
| the REAL replay payload (`items` + `arrayUnion(uid)` on the trail + activity stamp), revoked | DENY |
| the same real payload, seated | ALLOW |
| mutation (member branch granted by `contributorUserIds` instead of `memberPermissions`) — SSL40's actor | FLIPS to ALLOW |
| same mutation — SSL22's actor (stranger, not in the trail) | stays DENY |

The last two are what separates SSL40 from SSL22: the mutation flips one and not the
other, so they are different tests. The third row matters because the client's actual
queued write is `_withContributorTrail(cachedBasePayload/appendPayload)` — `{items,
activity keys, contributorUserIds: arrayUnion(uid)}` — not the bare `update({items})`
SSL40 sends; the richer real shape denies too, and is writable when seated.

**Remaining uncovered branches, ground-truthed by a second probe (all as expected, none a
rule defect — all are MISSING TESTS):** editor promotes self to admin DENY; editor
reinstates a revoked member DENY; editor boots the view-only member DENY; editor seizes
`ownerId` DENY; viewer promotes self DENY; **OWNER revokes a member ALLOW**; **OWNER grants
a new member ALLOW**; stranger/unauth/revoked delete DENY; unauth create DENY; a revoked
member's filtered query ALLOW-but-empty (correct, matches SSL39, not a leak).

The two owner-ALLOW rows are the sharpest gap: SSL29 and SSL40 both need a document in the
revoked state and both reach it only via `withSecurityRulesDisabled`, so nothing in the
suite proves a client owner can perform the revoking write at all. ADR-002 (staged in the
same commit) asserts the rules forbid a non-owner from touching `ownerId`/`memberPermissions`;
of those three privileged keys only `createdAt` (SSL25) had a test.

### 2026-08-01 — BUT-1788 conversations metadata.creatorId immutability: correct guard, wrong CEL spelling

Reviewed the uncommitted BUT-1788 diff (gate never ran on it; surfaced by the sprint's own
completeness sweep as BUT-1802). Two files: `firestore.rules` (+17/-2) and
`conversations-rules.test.ts` (+81, tests C8-C11).

**The conjunct added to `allow update` on `/conversations/{id}` (L1547-1548):**

    && request.resource.data.get('metadata', {}).get('creatorId', null)
        == resource.data.get('metadata', {}).get('creatorId', null)

Intent is right — `affectedKeys()` is TOP-LEVEL, so the pre-existing deny list
['participantIds','createdAt'] let any participant rewrite `metadata` wholesale and
self-promote to creator, then call `leaveGroupConversation` (whose `authorizeDeparture`
trusts `metadata.creatorId`) to evict everyone. Real group-takeover primitive.

**Mutation proof (both directions):** removed the conjunct from the file -> C8 and C9 flip
to FAIL (9/11); restored from a byte-copy backup in the SAME Bash call -> 11/11, md5 equal.
NOTE: `git checkout -- firestore.rules` would have DESTROYED the uncommitted change; always
back up to scratchpad and `cp` back when the change under test is unstaged.

**The defect found — present-but-null defeats `.get(k, default)`.** In rules CEL, `.get(k,d)`
returns `d` only when the key is ABSENT. A key PRESENT with value null returns null, and
chaining `.get('creatorId', null)` onto null is an evaluation error -> the whole update
denies. `ConversationDto.toFirestore` (conversation_dto.dart:143) writes
`'metadata': conversation.metadata` UNCONDITIONALLY, and `message_mutation_module.dart:186-194`
does `batch.set(convRef, ConversationDto.toFirestore(...), merge:true)` atomically with the
message write on EVERY send. So for any conversation whose stored `metadata` is null or
absent, the client's message send is denied — and because the batch is atomic, the message
itself is lost too. Regression proven directly: HEAD rules ALLOW, working-tree rules DENY,
same doc + same payload.

**Corrected 13-case probe, shipped vs candidate (in-memory `rules.replace`, file untouched):**
shipped 3 mismatches (PROD merge-set into metadata:null doc; PROD merge-set into
metadata-ABSENT doc; targeted update on a metadata:null doc), candidate 0 mismatches.
Verified candidate spelling, both sides:

    && (request.resource.data.get('metadata', {}) is map
        ? request.resource.data.get('metadata', {}).get('creatorId', null) : null)
       == (resource.data.get('metadata', {}) is map
        ? resource.data.get('metadata', {}).get('creatorId', null) : null)

It keeps all six takeover denies (self-promote, drop creatorId, null it out, scalar
"pwned", ADD creatorId to an absent-metadata doc, ADD to a null-metadata doc) and restores
all six legitimate paths.

**Why the suite missed it:** C11 asserts "a conversation with no metadata is still
updatable" but sends `update({lastMessage:...})` with NO metadata key — a payload the app
never produces. Under shipped rules that exact case ALLOWS (probe case 5), so C11 is green
and false comfort. Lesson folded into the principles: mirror the DTO's full key set in at
least one allow test per write path.

**Two probe artifacts that cost a run each (both my bugs, not rule findings):**
(1) the payload builder hardcoded `participantIds: [A,S]` against docs seeded `[A,S,F]`, so
three cases denied on the participantIds conjunct instead of the one under test — the
"re-stamped builder" trap from the 2026-07-28 principle, in a new costume; (2)
`set(payload, {merge:true})` DEEP-MERGES nested maps, so a payload omitting `creatorId` did
NOT drop it and the takeover-by-omission case read as a false ALLOW — use `update()` for
omission tests. Also: `initializeTestEnvironment` returns HTTP 500 "UNKNOWN" if the
projectId contains UPPERCASE (I used `...-HEAD-...`); lowercase every label.

**Population / severity.** Client creates can no longer produce the bad shape — probed the
create rule: metadata ABSENT -> ALLOW, `metadata: null` -> DENY (the BUT-1626 create clause
CEL-errors on `'creatorId' in null`), `{creatorId:self}` -> ALLOW. So the frozen set is
bounded: 1:1s created before `createDirectConversation` began stamping creatorId
(commit 8a32b70bd, 2025-10-29) plus anything an Admin-SDK path wrote. It cannot grow from
the client. Side observation, pre-existing at HEAD and NOT part of this diff: the fallback
conversation create in `message_mutation_module.dart:139-159` builds a Conversation with no
metadata, which the DTO turns into `metadata: null` -> denied by that same create clause, so
that fallback has never worked.

### 2026-08-01 — BUT-1788 test side: NULL is a third fixture state, and a merge-set allow test contaminates the fixture it just proved

The `is map` ternary fix was already applied to `firestore.rules` (uncommitted) when I was
asked to fix the SUITE. The suite was green and wrong. Two defects, both about fixture
STATE rather than about actors:

**1. No fixture ever held `metadata` PRESENT-WITH-NULL.** `NO_METADATA_GROUP` seeded the key
ABSENT, which the OLD bare `.get('metadata',{}).get('creatorId',null)` spelling handles
correctly (the default `{}` fires only for a missing key). The production-breaking state is
the one `ConversationDto.toFirestore` writes — `'metadata': conversation.metadata`
unconditionally, i.e. a stored `null`. Added `NULL_METADATA_GROUP`. So this collection has
THREE stored states, not two: absent / null / map, each a different branch of the ternary.

**2. C11's allow payload omitted `metadata`,** certifying the broken case as working. Fixed
by adding `conversationDtoPayload()`, mirroring `conversation_dto.dart:128-145` key for key
(with `lastMessage` mirroring `message_dto.dart:140-165`), sent as `set(..., merge:true)`
exactly as `message_mutation_module.dart:190-197` batches it beside the message write.

**The trap that nearly re-broke it:** C11 sends that payload at `NO_METADATA_GROUP` with
`metadata: null`, and a merge-set WRITES that null. After C11 runs, the absent-metadata
fixture is a null-metadata fixture. A later absent-branch deny test reusing it would have
silently tested the null branch twice. Fixed with a dedicated, write-once fixture
(`NO_METADATA_INJECT_GROUP`). General rule: an ALLOW test that lands a real payload MUTATES
its fixture; any deny test that depends on the pre-write state needs its own document.

**Tests added:** C10B (real DTO payload onto a doc that HAS a creator — the map/map branch,
the commonest production write), C11 (fixed: real DTO onto absent-metadata),
C11B (real DTO onto stored-null — the live defect pin), C12A/C12B (creatorId injection
denied on absent AND on null: two ternary branches, one does not prove the other),
C13A/C13B (metadata written as a string / a number over a stored creatorId — proves `is map`
cannot launder a stored creatorId to null, i.e. no step-one of a two-step takeover),
C14 (group RENAME allowed with creatorId carried through — the tripwire for a future blanket
metadata freeze, which every deny in C8–C13B would survive).

**Runs (real output).** Fixed suite: 18/18 passed.
Mutation (a) — conjunct reverted to the bare spelling: 16/18, the two RED being exactly the
new real-payload allows ("a conversation with no metadata is still updatable by the real
ConversationDto payload" and "...whose stored metadata is null..."). Note the absent-metadata
one now reddens TOO, because the real payload carries `metadata: null` on the REQUEST side —
the request side alone is enough to trigger the CEL error, the stored side need not be null.
Mutation (b) — conjunct deleted entirely: 12/18, RED = C8, C9, C12A, C12B, C13A, C13B (every
takeover deny), allows all still green. `firestore.rules` md5 `963d3028...` before and after
both mutations.

**Chain-wide:** every other rules/integration suite green
(14,39,5,22,8,8,34,19,11,24,21,8,9,7,14 + 29,25,15,18,9,4,9,61,6,13,9,49,18,12,28,14,43,4,5,
plus `recipe-shared-read` ✓-style and `purge-dormant-family-data` "ALL PASS"). The ONLY
non-green link in `test:rules:all` is `comment-images-storage-rules`, which needs the STORAGE
emulator on 9199 (`ECONNREFUSED`); `.claude/hooks/ensure-firestore-emulator.sh` starts
Firestore only. `moderate-upload.integration` detects the same and prints a SKIP banner
rather than failing — so the chain aborts at the storage RULES suite, mid-list, and the
suites after it never run unless invoked individually. Not a regression; do not read it as one.

**Mechanic re-learned the hard way:** `cd functions` earlier in a compound Bash call makes a
later bare `md5sum firestore.rules` miss (the restore `cp` used an absolute path and did land;
only the verification failed). Absolute paths in BOTH halves of a mutation probe.

### 2026-08-12 — conversations/{id}/participants: designing a rule for a parent that does not exist yet (BUT-1482 sprint, item 5/5)

**The gap.** `conversations/{conversationId}/participants/{participantId}` had NO match block —
default-deny. Written by `ConversationParticipantModule.addParticipants` in ONE WriteBatch with
`users/{uid}/conversation_memberships` (item 4 of this sprint), gated on
`enable_subcollection_participants`, default TRUE. Unlike the other four drifts the failure is
NOT swallowed: `addParticipants` has no local catch, so `batch.commit()` throws up through
`createDirectConversation` / `createGroupConversation`.

**The brief's premise was half right, and the real reason is worse.** The brief said the parent
`conversations/{id}` is written "in the same batch", so a `get()` on it cannot work at create
time. Reading the code: the conversation write is a SEPARATE, AWAITED write BEFORE the batch
(`conversation_mutation_module.dart:105-127` for direct, `:156-166` for group), so pre-batch
state would in fact contain it — for DIRECT. For GROUP it never contains it, because
`FirebaseMessagingRepository` mixes in `UserScopedFirebaseRepository`, so `createFn` writes to
`users/{creatorUid}/conversations/{id}` while the roster is written under TOP-LEVEL
`conversations/{id}`. The top-level document only materialises when someone sends the first
message — the same path split `leaveGroupConversation`'s BUT-1795 comment records ("a group
nobody has chatted in has no top-level document at all"). So a parent-attesting rule denies
every GROUP create permanently, not merely during the batch.

**Shipped shape** (nested inside the existing `match /conversations/{conversationId}`, after
`userSettings`, firestore.rules:1651):
- `parentDoc()` = one `get()`, null on missing (the `isRealtimeParticipant` trick, one read,
  cached per request).
- `attestedWriter()` = parent names BOTH `request.auth.uid` AND `participantId`.
- `mayWriteRoster()` = `attestedWriter() || rosterUnclaimed()` (parent == null).
- create = `validParticipant() && mayWriteRoster()`.
- update = `validParticipant()` AND (self + `diff().hasOnly(['lastReadAt'])` — `updateLastRead`)
  OR `mayWriteRoster()` (the re-`set()` path: `addParticipant` sets WITHOUT merge, so a re-add
  and `migrateToSubcollection` are UPDATES in rules terms).
- delete = SELF ONLY, deliberately narrower than create/update:
  `ConversationParticipantModule.removeParticipant` has no caller, and the real remove runs in
  the `leaveGroupConversation` CF under the Admin SDK (which only DELETEs here). Widening it
  would be a pure griefing primitive.
- read = parent-attested OR `exists(.../participants/$(request.auth.uid))` (own row, the
  recipePresence pattern) — the only evidence available for a group that has never been
  messaged in. Neither predicate touches `resource.data`, so the client's whole-collection
  `get()`/`snapshots()` LIST is provable.
- allowlist = exactly `ConversationParticipant.toFirestore` (8 keys, `avatarUrl` optional →
  `hasOnly` 8 / `hasAll` 7), plus `d.conversationId == conversationId` and
  `d.participantId == participantId`, which also makes both immutable on update for free.
  `role` bounded to the enum but explicitly NOT authorization (grep `ParticipantRole`: it never
  leaves the module).

**Residual, documented in the rule and pinned by test P3B:** the UNCLAIMED branch lets anyone
who knows an unchatted group's 20-char auto-id seat a row, and then read that roster. Direct
conversations are immune by construction (their guessable `direct_{a}_{b}` id always has a
parent by roster-write time). Tightening = delete `rosterUnclaimed()` from `mayWriteRoster()`
once BUT-1795 unifies the path; it cannot break stored data, because default-deny means NO
client row has ever existed and the only CF touching the subcollection deletes.

**Tests** — 26 appended to `conversations-rules.test.ts` (P1–P26), suite now 45/45. P24/P25/P26
are the end-to-end ones: the module's REAL batch (3 roster rows + 3 membership rows, no parent
doc) commits; the direct sequence (conversation write, then 2+2) commits; the same batch shape
by a stranger against an existing conversation is denied. A batch is all-or-nothing, so these
are the only tests that prove the two rule blocks cooperate.

**Probe (throwaway, deleted in the same Bash call, rules mutated in MEMORY only):**
- attribution: the stranger's MEMBERSHIP row ALONE is ALLOWED (the deployed sibling rule is
  deliberately cross-user), so P26's deny is attributable to the roster row. Worth doing —
  the emulator printed `false for 'create' @ L552` for the membership inside the failed batch,
  which reads exactly like a second deny and is not one.
- `mayWriteRoster()` → `true`: P3 FLIPS to allow.
- `hasOnly([...])` conjunct deleted: P6 (unknown field) FLIPS to allow.
- delete widened to `mayWriteRoster()`: P22 FLIPS to allow.
- `firestore.rules` byte-identical afterwards (compared in-process against the string read at
  probe start).

**Dart guard** `test/unit/security/rules_allowlist_drift_test.dart` gained the entry, deriving
keys from `ConversationParticipant(...avatarUrl: '...')` — the fixture carries a non-null
avatar deliberately, because the guard must compare against the WIDEST set the writer can send.
That also makes the pass self-proving: the parser takes the first `hasOnly(` after the anchor,
and had it grabbed the neighbouring `hasAll(` (7 keys) instead, `avatarUrl` would have been
reported MISSING and the test would have failed. 6/6 green.

Adjacent suites re-run green: `leave-group-conversation.integration` 5/5,
`enforce-group-minor-membership.integration` 4/4.

### 2026-08-12 — Final gate on the staged roster rules: proving a "comment-only" round, and the third deleter

**Q: is the staged `firestore.rules` diff comment-only since the previously reviewed revision?**
Answered mechanically, not by eye. `git fsck --unreachable` + `git cat-file
--batch-all-objects --batch-check` (filter blobs 115–150 KB whose first line matches
`rules_version`) recovered every revision of the file that had ever been staged in this
working copy — 16 of them. The reviewed revision is identifiable by content: `2a8ac2b9` is
the only one carrying the disproved sentence "Scoping the fallback closes it, and closes the
pre-seat residual with it". Comment-stripped (`sed 's|//.*$||'`, after grepping for `://` to
prove no string literal contains a slash pair) both blobs md5 to `5e15ee5a…` → **identical
code, 1328 non-comment lines**. Two intermediate blobs (`3e015ca4`, `4a77744e`) have
DIFFERENT code md5s — a missing `isMuted` in `hasOnly`, and `hasAll` where the file now has
`hasOnly` on `deep_links/clicks`. Those are restored mutation probes, not history; the point
is that the staged blob matches the reviewed one, so they round-tripped.

**P12B mutation probe, without touching the file.** Copied the suite to
`functions/src/__tests__/zz-p12b-probe.test.ts` with `PROJECT_ID` = `butlery-rules-p12b-probe`
and `RULES_PATH = process.env.PROBE_RULES ?? path.resolve(...)` (the `??` matters — dropping
the `path` import makes ts-node die on `noUnusedLocals`, and the first run printed nothing at
all through the grep), pointed it at a scratchpad copy with `parentDoc() == null &&` removed
from the read fallback, `trap`-deleted the probe in the same call. **46/47, P12B alone**, so
the deviation entry's "removing it flips exactly test P12B" is measured, not asserted.
Baseline unmutated: 47/47. `firestore.rules` md5 identical before and after.

**The third deleter nobody named.** The residual paragraph and the deviation entry enumerate
two ways a roster outlives its parent (the eviction CF's collapse branch — closed in code —
and the client `deleteConversation`). There is a third: `functions/src/account/
account-deletion-cascade.ts:1185-1191`, which deletes any conversation with ≤2 participants
whole (`convoDoc.ref.delete()`) after wiping its messages, and never touches
`conversations/{id}/participants`. Two consequences the docs do not state: a shrunk GROUP
deleted this way gets a UUID-id orphan roster that is re-seatable by anyone who knows the id;
and for a DIRECT conversation the `direct_` exclusion in `rosterUnclaimed()` blocks the WRITE
but NOT the read fallback, so the surviving partner keeps LIST on a roster that still holds
the erased user's `displayName` and `avatarUrl` (BUT-1822's stored-data gap becomes a live
read). BUT-1825's stated option 2 — "widen the row delete rule plus cascade" on the client —
cannot reach this deleter, which runs server-side.

Other deleters checked and cleared: `leaveGroupConversation` never deletes the parent (it
`arrayRemove`s and deletes the leaver's own roster row); `admin/reset-user-data.ts` deletes
subcollections before the doc (`deleteDocRecursive`); no TTL policy on `conversations`; no
`{path=**}/participants/{id}` collection-group catch-all, and `git log -S
"participants/{participantId}" -- firestore.rules` is empty, which is what makes "default-deny
since it was written, so no client row exists" true.

**Claims verified against code:** UUIDv4 (`Conversation.group` → `const Uuid().v4()`, 122
random bits); `enable_subcollection_participants` defaults `true`
(`feature_flag_service.dart:47`); the "seven assertions across three tests" roster count in
`enforce-group-minor-membership.integration.test.ts` is exactly 2 + 4 + 1; every conversations
rule gates on `uid in participantIds`, so the zero-member shell is genuinely locked.

**Stale by one round:** the block comment still says "the only Cloud Function that touches the
subcollection (leaveGroupConversation) only DELETES" — this sprint's own CF fix made
`enforceGroupMinorMembership` a second toucher, and `resetUserData` a third. All three still
only delete, so the safety argument survives; the enumeration does not. Also one surviving
"auto-id" (line 1650) after three were corrected to UUIDv4.

**Environment note:** a parallel session was rewriting `clearRosterStrict` in the working tree
during this review (`listDocuments()` → bounded `.limit(N+1).get()`, "fails loudly" → "never
throws, reports"), i.e. the CF bytes the staged deviation entries describe are already
diverging. Rules review is scoped to the staged blob; whoever commits must re-check those two
sentences.

### 2026-08-13 — Closing pass on the conversations roster cluster: comment-only diff proven, C7B mutation-probed

**Scope.** Re-review of the staged `firestore.rules` + `conversations-rules.test.ts` after
three corrections (two of my own Lows, one from `testing-specialist`).

**Comment-only proven, not eyeballed.** `git cat-file --batch-all-objects --batch-check`
filtered to blobs of 138–152 KB whose first 20 bytes are `rules_version`, recovered SIX
previously-staged revisions of `firestore.rules` (`047548ca`, `91f2b51b`, `9893a7bc`,
`e8820358`, staged `abc79c25`, plus HEAD `38b1796f`). Comment-stripped md5
(`sed 's|//.*$||' | tr -d ' \t\r' | grep -v '^$' | md5sum`) is IDENTICAL — `aeb77636…` — for
all five staged revisions and differs only for HEAD. `grep '://' firestore.rules` is empty,
so the naive comment strip is safe on this file. Line-diff of the immediately prior revision
(`e8820358`) against the staged one shows a single hunk, five comment lines.

**The corrected claim, verified against the CF's own line.**
`functions/src/messaging/enforce-group-minor-membership.ts:318-319` is
`const isGroup = data?.isGroup === true || rawParticipantIds.length > 2;` then
`if (!isGroup || rawParticipantIds.length <= 2) return;`. So `isGroup: false` alone never
decides — a false flag with >2 participants does NOT return early. Both the app fallback
(`message_mutation_module.dart:167-187`: `participantIds: [senderId, ?otherUserId]`, and
`otherUserId` stays null for a UUID group id because it is parsed only from a `direct_` id)
and BUT-1830's hand-rolled squat payload trip BOTH halves, so the escape is real but the
general reading was wrong. All four sites now say so.

**C7B mutation-probed (the claim repeated in four documents).** Probe per the established
recipe: `sed` a copy of the suite to `zz-c7b-probe.test.ts` with a fresh PROJECT_ID and
`RULES_PATH = process.env.PROBE_RULES ?? <original>`, point it at a mutated COPY in the
scratchpad, `rm` under `trap ... EXIT INT TERM`. Mutation = the "harmonise for consistency"
edit, i.e. replace the create rule's
`!('metadata' in …) || !('creatorId' in ….metadata) || ….metadata.creatorId == uid` with the
UPDATE rule's `is map` ternary spelling. `perl` reported `SUBS=1`. Result: **47/48, the single
FAIL being `conversations: a create carrying metadata: null is denied`** — exactly C7B, nothing
else. `firestore.rules` md5 identical before/after; probe file gone; `git status --porcelain`
clean of artifacts. Unmutated run: 48/48.

**Residual noted, non-blocking.** `ACCEPTED_DEVIATIONS.md:1267-1269` still pairs
"`isGroup: false`" with "would return early on it" without the both-halves qualifier that
appears eleven lines later at :1279-1281. True of that payload (one participant), so not a
false claim — just the shape of the misread, surviving in the one document that also corrects it.

**"Reads as a bound" sweep.** Every surviving occurrence of the creator/only-thing-stopping
claim is rebutted inside its own paragraph or bullet: `firestore.rules:1794-1820` (claim →
"WHY only the creator is not what it looks like" → "NOT a security bound" → "so nobody reads
… as a rule"), `conversations-rules.test.ts:230-233`, `message_mutation_module.dart:146-166`,
`.claude/rules/accepted-deviations.md:288-295`, and the back-pointer
`ACCEPTED_DEVIATIONS.md:1307` ("in the honest-client model described above — and only there").

### 2026-08-13 — BUT-1822 comment-only diff: proving it, and verifying a comment against another file's code

Task: review the working-tree `firestore.rules` change for BUT-1822 (the roster bootstrap
block, ~lines 1826-1856), asserted to be comment-only.

**Proving comment-only, two ways.** `git diff -U0 -- firestore.rules | grep -E '^[+-]' |
grep -vE '^(\+\+\+|---)' | grep -vE '^[+-][[:space:]]*//'` returned EMPTY (14 added / 6
removed lines, all `//`). The md5 method needed a fix the knowledge file did not have: the
naive `sed 's|//.*$||' | md5sum` MISMATCHED, because stripping comment text from a diff that
changes the line count leaves a different number of empty lines. Adding
`grep -vE '^[[:space:]]*$'` (and `tr -d '\r'` — the file is CRLF) made HEAD and the worktree
identical at `658e2ba54c28d6d600bcb174ec8270a8`, 1328 non-comment non-blank lines on both
sides. `grep -c '://'` was 0 in both, so the comment strip was safe. Behaviour is therefore
provably unchanged, which is a STRONGER statement than a green suite run — the suite was not
run, deliberately, and the report said so rather than implying coverage.

**Verifying the new comment's claims against `account/account-deletion-cascade.ts`.** The
comment now says case 3 (the GDPR cascade) is CLOSED. Four claims, each read in its own body,
not inferred:
1. `deleteMessages` calls `tryClearRoster(db, convoDoc.id)` at :1264 and gates
   `convoDoc.ref.delete()` at :1266 on its return — true; the `false` branch takes
   `buildGroupDepartureUpdate` in a transaction and sets `complete = false`.
2. `deleteOwnRosterRows` (:1391-1410) is
   `collectionGroup(Collections.participants).where("participantId","==",uid)
   .limit(MAX_ROSTER_SWEEP_ROWS + 1)`, called at :1333 BEFORE the `conversationFailures`
   early-return, so a per-conversation failure cannot skip the sweep.
3. "reaches case-1 orphans naming the erased user" — true by collectionGroup semantics
   (an orphan row's absent parent is irrelevant to the query).
4. "cannot reach a case-1 orphan naming SOMEONE ELSE" — true, and it is the ONLY residual,
   which required reading `tryClearRoster` itself.

**The check that could have gone the other way.** The rules comment says the whole roster is
cleared. If `tryClearRoster` derived its rows from `participantIds` (as the surrounding
trigger's other uid lists do), a planted bootstrap row naming a third party under a
<=2-participant NON-`direct_` conversation would survive the clear and be orphaned by the
parent delete — a case-3 orphan the comment denies exists. It does not: the function does a
plain `.collection('conversations/{id}/participants').limit(MAX_ROSTER_ROWS + 1).get()`
(`enforce-group-minor-membership.ts` :193-196), ENUMERATED, and its own docstring at :177-185
says why ("a row can exist that no uid list here can name"). So "whole roster" is the
accurate word and the comment holds. Generalisation: when a rules comment claims a CF cleans
a subcollection, check whether the cleanup ENUMERATES or DERIVES — derived cleanup always
leaves the rows the bootstrap branch let a stranger plant.

Constants cross-checked so the sweep is not a silent no-op (the wrong-path-read bug class):
`Collections.participants === "participants"` (`shared/collections.ts:22`) matches
`CONVERSATION_PARTICIPANTS === "participants"` (`enforce-group-minor-membership.ts:71`), which
matches the `conversations/{id}/participants` path in the rules. Also confirmed :1266 is the
ONLY conversation delete in the cascade — :1480 in `anonymizeSystemMessagesAboutUser` builds a
conversation ref but only `tx.update`s `lastMessage.content`.

**Tests: nothing invalidated, and that was the honest answer.** Read all 1142 lines of
`conversations-rules.test.ts`. No test asserts anything about who deletes the parent; P12B's
comment names only the eviction CF (closed 2026-08-12) and stays accurate. `account-deletion-
cascade.test.ts` already pins both BUT-1822 legs and the ordering invariant. No new rules test
was written, because a comment cannot change a rule branch and the code md5 proves it.

Non-blocking observation reported: `.claude/rules/accepted-deviations.md` :279-321 (the
2026-08-12 entry) still reads "only the last is fixed" about the three deleters, which the
RESOLVED 2026-08-13 entry at :323-341 supersedes without back-pointing at it. That matches the
repo's supersede-don't-delete convention, so it was reported as an observation, not a finding.

### 2026-08-14 — BUT-1838: group chat becomes a first-class object (conversations create is direct-only, group history cut-off, roster lock, new `chat_groups` block)

Rules diff: `git diff firestore.rules` = 241 insertions / 192 deletions, entirely between
:1520 and :1982 (verified by grepping every `match /(conversations|messages|chat_groups)` —
only :517 user-scoped copy, :1522, :1879, :1910; `L2962` in every emulator verdict is the
global `match /{document=**} { allow read, write: if false; }` catch-all, not a second block).

Six changed branches, all proven both directions:

1. **`conversations` create is DIRECT-ONLY and id-bound.** New conjuncts `participantIds is
   list`, `toSet().size() >= 2`, caller in list, `directIdBinds(p)` (`p.size() == 2 && (id ==
   'direct_'+p[0]+'_'+p[1] || id == 'direct_'+p[1]+'_'+p[0])`), and — replacing the old
   three-way `!('metadata' in d) || !('creatorId' in d.metadata) || … == uid` — a bare
   `request.resource.data.metadata.creatorId == request.auth.uid`, i.e. the creator must now be
   PRESENT. Closes BUT-1830's squat by removing the capability: a client cannot create a group
   conversation at all.
2. **`conversations` update deny-list gains `memberSince` and `groupId`.** The rule is a
   DENY-list, so without them any group member could lower their own history cut-off (read the
   whole backlog) or raise someone else's (blank their history). Caught by the plan revision,
   not the first draft.
3. **Roster:** `rosterUnclaimed()` DELETED and the textually separate parentless own-row READ
   fallback DELETED in the same edit (removing only the write half would have left the pre-seat
   residual alive). `mayWriteRoster()` = `attestedWriter() && !('groupId' in parentDoc().data)`
   — a GROUP roster row is Admin-SDK-only.
4. **`messages` read gains the group history cut-off**, scoped on `'groupId' in` the
   conversation, spelled `.get('memberSince', {}).get(uid, request.time)` (fail-closed twice).
   `allow read, delete: if isAdmin()` stays a SEPARATE allow and bypasses it.
5. **`messages` create requires the sender to be in `participantIds`** (one extra doc read per
   message, accepted in the plan's step 5).
6. **NEW `chat_groups/{groupId}`**: member read, `isAdmin()` read, admin-only update limited to
   `hasOnly(['name','updatedAt'])` with a 1..100-char string name, `create, delete: if false`.

**Results.** `npm run test:rules:conversations` 77/77 (60 tests before this run);
`npm run test:rules:chat-groups` 27/27 (new file). `node scripts/check-test-registration.js`
-> "OK — 128 test files registered, 39 rules suites triggered by 2 paths blocks";
`npm run test:script-test-registration` -> 20/20. `npx tsc --noEmit` clean.

**Four mutation probes, all by env-var against a mutated COPY** (`PROBE_RULES_PATH` /
`PROBE_PROJECT_ID` seams shipped in both suites; `firestore.rules` md5
`12baab43171d9e22722a97072017e3f7` before and after every probe, and `git diff --stat` unchanged
at 241/192 — the file was never written, so byte-identity is by construction rather than by a
restore step a timeout can skip):

| Mutation | Result |
|---|---|
| delete the `memberSince` conjunct from the `/messages` read rule | 74/77 — exactly M2 (pre-join message), M3 (participant with no stamp), M3B (no `memberSince` map at all) |
| drop `memberSince` from the `conversations` update deny-list | 74/77 — exactly U1 (lower own), U2 (raise another's), U3 (replace whole map) |
| delete the create-side `metadata.creatorId` conjunct | 74/77 — exactly C6, C6B, C7B |
| **harmonise** the create-side spelling with the update rule's `is map` ternary | **77/77 — NOTHING reddens** |

That last row is the finding. `firestore.rules` :1577-1582 and the C7B comment both claim
"making the two spellings agree is the edit that disarms it — do not". That was TRUE of the old
conjunct, whose `||` hatches allowed an absent creator so only the CEL null-error stood in the
way; it is FALSE of the bare equality, because a ternary resolving `null` still fails
`null == uid`. The deny is still real and attributable (emulator prints
`Null value error. for 'create' @ L1565`) and is now a STRONGER bound — a CEL accident binds our
own client, a presence requirement binds a tampered one — but the stated danger is stale, and
the plan's "two invariants must not be cleaned" premise (Etapp 2) rests on it. Reported as a
non-blocking comment-accuracy finding; `firestore.rules` not edited (not this agent's file).
The test's own comment was corrected in place with both probe results quoted.

**The vacuity sweep was the bulk of the work.** Every legacy create test (C1-C7) denied under
the new rule for the NEW reason — `directIdBinds` fires above the minor gate and above the
metadata conjunct — so all eight were given a conforming `direct_<a>_<b>` id and a conforming
metadata map, each on its OWN peer uid (`peer(tag)`, an unseeded uid: `otherIsMinor()` is
`exists()`-guarded and fails open to adult, so an unseeded counterparty is a valid adult target,
and a per-test uid keeps every create test on its own document id so an earlier ALLOW never
turns a later create into an update). Same problem on the roster: P5-P11 ran against the
PARENTLESS fixture, which now denies on attestation before `validParticipant()` is reached, so
they were re-pointed to an attested parent with no seeded rows (`P_CREATE`) to stay CREATEs.

**Five intended flips**, each documented at its own site as the ticket's signal: C5 (client
group create), P1 (bootstrap seat), P3B (pre-seat residual), P14 (own-row read fallback), P24
(the client's old create-group WriteBatch). P3B's SECOND job — fail-closed control for P3 — had
to be replaced (P3D: same actor, same body, same id shape, attested parent -> ALLOW), or every
attestation deny in the file would have been unattributable.

**New coverage worth reusing.** P27/P28 are a discriminating pair for the `!('groupId' in …)`
lock: two byte-identical conversations differing only in that one key, same actor, same payload
— one denies, one allows. P30 pins that the lock does NOT reach the roster's `(u1)`
self-`lastReadAt` branch (it never calls `mayWriteRoster()`), which is the one client write a
group member still makes and reads like it "should" deny. M9 makes M8's non-participant
message-create deny attributable by having the SAME actor with the SAME claims succeed in a
conversation they are in. G5/G6 pin the `chat_groups` LIST path in both directions
(`array-contains` filter allowed and non-empty; unfiltered sweep denied with a foreign group
seeded), because `resource.data.get('memberIds', [])` is exactly the presence-tolerant shape
that leaked `cook_snaps` in BUT-1214. G25 (name of exactly 100 chars ALLOWS) is the boundary's
passing side, without which a tightening to `< 100` would keep G24 green.

**Documented consequence, stated rather than hidden (M3B):** a conversation carrying `groupId`
but NO `memberSince` map has no readable messages for ANY member — `.get('memberSince', {})`
returns its default and `request.time` beats every stored `sentAt`. That is the intended
fail-closed behaviour, and it makes `createChatGroup` writing the map atomically with the
conversation load-bearing rather than merely tidy.

**Coverage gap left open, reported:** the DELETE half of the `/messages` moderation branch
(`allow read, delete: if isAdmin()`) is unproven — testing it destroys the fixture the read
tests share, and delete is not what BUT-1838 changed. Low.

**Working-copy note:** a parallel session held files STAGED in this shared checkout
(notification-preferences work, `testing-specialist` knowledge, `workflow-map.html`). Nothing of
this run's was staged, nothing was committed, and `functions/package.json` +
`.github/workflows/firestore-rules.yml` already carried that session's BUT-1838 CF-side
registration edits (leave-group-conversation removed, `functions/src/groups/**` added) — this
run appended to them rather than rewriting.

### 2026-08-14 — BUT-1838 re-verification pass on `chat_groups`: every assertion attributed by mutation probe

Second look at `functions/src/__tests__/chat-groups-rules.test.ts` (27 tests, 27/27 green against
the shipped `firestore.rules` :1888-1913), this time proving non-vacuity by measurement instead of
by argument. Sixteen mutants, each a COPY of `firestore.rules` in the scratchpad, run through the
suite's own `PROBE_RULES_PATH`/`PROBE_PROJECT_ID` seam; the real file's md5 was
`7b2d13dc9bfe47d548b80937419523b2` before and after.

Probe -> flip map (this is the artifact worth keeping; a pass count is not):

| mutation | reddened |
|---|---|
| membership read branch -> `if false` | G1, G5 |
| read -> `if true` | G2, G3, G6 |
| drop `isAuthenticated()` from read only | NOTHING |
| drop `uid in resource.data.get('memberIds', [])` | G2, G6 (G3 stays green) |
| `allow read: if isAdmin()` -> `if false` | G4 |
| `allow create, delete: if false` -> `if isAuthenticated()` | G7, G8, G9, G10 |
| drop `uid in resource.data.get('adminIds', [])` | G13, G14, G15 |
| drop `.hasOnly(['name','updatedAt'])` | G16, G17, G20, G21, G22, G23 |
| drop BOTH of the above | the eleven update denies, incl. G18, G19 |
| `hasOnly` -> `hasAll` | G12 |
| drop `name.size() <= 100` | G24 |
| `<= 100` -> `< 100` | G25 |
| drop `name.size() > 0` | G26 |
| drop `name is string` | NOTHING |
| drop all three name conjuncts | G24, G26, G27 |
| `allow update: if false` | G11, G12, G25 |

Two NOTHING rows are the finding. Both are MASKING, not vacuity: `request.auth.uid in …` raises a
CEL evaluation error on null auth, so the unauth read deny (G3) rides on the membership conjunct
and cannot be attributed to `isAuthenticated()`; `.size()` on an int errors the same way, so the
non-string-name deny (G27) rides on the length conjuncts. Both flip under the smallest combined
mutation, which is how they were attributed. G18/G19 are the third case of the same shape at the
actor level — a non-admin changing `memberIds`/`adminIds` is refused twice over, so only the
joint drop moves them.

Also confirmed by probe rather than by reading: G7-G10 cannot be flipped by REMOVING anything
(`if false` denies by construction), so they were probed by OPENING the rule to
`if isAuthenticated()` — that is the regression they guard, and all four flip together.

**Mechanic that cost three runs.** Running probes back-to-back in a `for` loop makes
`loadFirestoreRules` return `{"error":{"code":500,"status":"UNKNOWN"}}`, which reads exactly like a
rules COMPILE error: the run prints the suite banner and dies before test 1, so a `grep FAIL`
reports "nothing reddened" for a run that never happened. It is emulator flake — PUTting the same
mutant to `/emulator/v1/projects/<pid>:securityRules` returned 200 with only pre-existing
`Unused function` warnings, and every mutant then passed when re-run one or two per shell call.
Read the summary line's PRESENCE, not just the FAIL lines.

**Uncovered branch, reported not fixed:** `rateLimitWrite('chat_group_rename', 5)` on the update
rule. It is `!exists(users/{uid}/rate_limits/chat_group_rename) || …`, no test seeds that doc, and
no Dart writer creates one anywhere in the repo (only the `userRateLimits` constant exists), so the
conjunct is inert in the suite AND in production — the repo-wide P3-13 pattern, pre-existing, not
introduced here. Medium: its removal would redden nothing.

**Second uncovered edge, Low:** the rename `allow update` currently has no client caller at all —
`FirebaseChatGroupRepository` exposes read/watch/create/addMembers/removeMember and no rename — so
the "send the DTO's REAL payload" rule cannot be applied to G11 yet. When a rename path is built,
re-check G11's payload against it.

Nothing was staged, committed or edited by this pass; `functions/src/__tests__/chat-groups-rules.test.ts`
was already staged by the earlier session in this shared checkout and was left byte-identical, which
is what keeps the reviewed bytes and the staged bytes the same object.

### 2026-08-16 — poll_votes + message receipts + shared_content create (BUT-1832/BUT-1812)

Reviewed `firestore.rules` (whole file, read in four chunks) and the new
`functions/src/__tests__/poll-votes-rules.test.ts`. Suite is registered correctly (script,
`test:rules:all`, BOTH `paths:` blocks — `node scripts/check-test-registration.js` OK) and runs
21/21 green against the live emulator.

**BLOCKING (Critical).** The new `hasRequiredFields([... 'sharedToUserIds'])` conjunct on
`shared_content` create (firestore.rules:768) denies the MENU and SHOPPING-LIST share flows.
The rules comment claims "All three writers (recipe, menu, shopping list) already stamp it" —
false. Only `firebase_shared_recipe_repository.dart:260-263` passes `initialSharedToUserIds`;
`firebase_shared_menu_repository.dart:200`, `firebase_shared_shopping_repository.dart:201` and
`base_social_coordinator.dart:166` call `createSharedContent(entity)` with no initial list, and
neither `BaseSharedContentModel.getCommonFirestoreFields()` (:52-62) nor the three models'
`toFirestore()` emits the field (`createSharedContent` only sets it `if
(initialSharedToUserIds != null)`, base_shared_content_repository.dart:134-136). Proved on the
emulator with the exact SharedMenu key set: DENY without the field, ALLOW with it (control).
Same BUT-1482 class as the `configRevision` incident — a rules `hasRequiredFields`/`hasOnly`
change is a WRITER change, and the writers must be grepped per COLLECTION, not per feature.

**Mutation-probe map** (env-var seam `PROBE_RULES_PATH`/`PROBE_PROJECT_ID` present in the new
suite, so no file was ever written; `git status` confirms `firestore.rules` byte-unchanged):
- receipt `allow update` statement → `if false`: R1, R2 redden (allow proven).
- receipt `affectedKeys().hasOnly([...])` dropped: R3, R6 redden.
- receipt membership conjunct dropped: R4 alone reddens.
- `pollIsOpen()` dropped (both create+update, /g): V7 alone.
- `uid == voterId` dropped: V3 alone. `voterId == <path>` dropped: V4 alone.
- vote `keys().hasOnly` dropped: V10 alone.
- **poll_votes `allow update` → `if false`: NOTHING reddens.** Every vote after the first is an
  UPDATE in rules terms (`transaction.set` on the voter's existing row,
  message_mutation_module.dart:542) — the live path has no allow test.
- `optionIds is list && size() <= 20` dropped: nothing reddens.
- `'sharedToUserIds'` dropped from hasRequiredFields: nothing reddens; `is list` dropped alone:
  nothing reddens; BOTH dropped: S2 reddens. S2 guards the PAIR — the absent-key CEL error in
  `is list` masks the required-field conjunct.

**Live probe of the three-state map on `pollIsOpen()`** (throwaway script under `functions/src/`,
deleted in the same Bash call): `metadata: null` → vote DENY (CEL error through
`.get('metadata', {}).get('poll', {})`), `metadata` ABSENT → ALLOW, `metadata: {poll: null}` →
DENY, populated → ALLOW; READ is unaffected in all four (the read rule never calls `pollIsOpen`).
`MessageDto.toFirestore:127` emits `'metadata': message.metadata` unconditionally on a nullable
field, so the stored shape for a plain message is present-with-null — i.e. the rules comment at
:2060-2065 describes the ABSENT case only and its "AND unreadable" half is wrong outright. Not a
live break: a poll message always carries `metadata: {'poll': …}` (messaging_service.dart:603).

### 2026-08-16 — BUT-1832/BUT-1812 fix-round review: five mutation probes on poll_votes, message receipts and shared_content

Reviewed `firestore.rules` + `functions/src/__tests__/poll-votes-rules.test.ts` as they stood
after the automated fix round. Suite green 26/26 against the real rules
(`npm run test:rules:poll-votes`). Probes run via the `PROBE_RULES_PATH` / `PROBE_PROJECT_ID`
seam (real rules file md5-unchanged, mutants written to the scratchpad):

- M1 — receipt `allow update` (rules L2035-2038) neutralised by rewriting its
  `affectedKeys().hasOnly([...])` to `hasOnly(['zzzDisabled'])`: 24/26, reds = R1 (read receipt)
  and R2 (delivery receipt) exactly. The new statement is load-bearing and covered.
- M6 — dropped `request.auth.uid in convOf(resource.data.conversationId).data.participantIds`
  from the SAME statement (anchored on the following `&& request.resource.data.diff` line, since
  the identical text also appears in the read rule at L1981): 25/26, red = R4 (stranger stamps a
  receipt) exactly. Roster gate covered.
- M2 — `poll_votes` `allow update` → `if false`: 25/26, red = V13 exactly. This closes the gap
  recorded in the previous round ("mutating allow update to if false reddened 0/21").
- M3 — dropped `request.auth.uid == voterId` from `poll_votes` `allow create` ONLY: 26/26 GREEN.
  Cause: `seed()` pre-creates `poll_votes/{OTHER_MEMBER_UID}`, so V3's `.set()` is an UPDATE and
  is refused by the update limb's copy of the same conjunct. M3b (dropped from BOTH limbs)
  flipped V3 to "Expected request to fail, but it succeeded" — so V3 guards the PAIR, and the
  create limb's identity check has no test of its own. Reported Medium.
- M4 — dropped `request.resource.data.sharedToUserIds is list` (rules L779): 26/26 GREEN. Both
  malformed shared_content tests (S2, S6) delete the key outright, which `hasRequiredFields`
  already denies, so the type conjunct is masked. Reported Medium. Mechanical note: the literal
  `request.resource.data.sharedToUserIds is list` occurs TWICE in the file (L779 and L890 under
  `/menus`) — the mutator's count==1 assertion caught it; anchor on the preceding
  `'sharedAt', 'sharedToUserIds'])` line.

Cross-checks done on the fix round's claims rather than trusting the comments:
`MessageMutationModule.votePoll` writes exactly `{voterId, optionIds, votedAt}` to
`messages/{id}/poll_votes/{voterId}` (matches `voteBody`); `updateMessageStatus` /
`batchMarkAsDelivered` write exactly `{status, updatedAt, readAt|deliveredAt}` (matches the
receipt rule's four-key `hasOnly` and R1/R2's payloads);
`BaseSharedContentRepository.createSharedContent` now stamps
`sharedToUserIds = initialSharedToUserIds ?? [uid]` unconditionally, and none of the three
models' `toFirestore` emits the field — so the rewritten rules comment at L769-775 is accurate
where its predecessor ("all three writers already stamp it") was not. `getCommonFirestoreFields`
and `SharedMenu.toFirestore` key sets match the S4/S5 payloads verbatim.
`node scripts/check-test-registration.js` → OK, 40 rules suites across both `paths:` blocks.

Uncovered branches left standing (all Medium/Info, none blocking): `optionIds is list` and
`optionIds.size() <= 20`; the create-limb voter identity check (above); `sharedToUserIds is list`
(above); the receipt statement carries no `memberSince` clause, so a late-joining group member may
stamp receipts on messages predating their join (write-only, no disclosure).

### 2026-08-17 — BUT-1832 poll_votes + message receipts: first real review of a HELD batch

Context: the sprint ledger recorded `firestore.rules` and `poll-votes-rules.test.ts` as
passed WITHOUT the files being opened. This was the first actual read.

Suite result: **26/26 pass** (`npm run test:rules:poll-votes`).

RULE VERDICT — sound. 13 behavioural probes, all matching prediction:
- separate `allow update` statements (L2014 sender / L2035 receipt) evaluate independently;
  the emulator prints both verdicts, confirming no `||` sinking.
- `match /poll_votes/{voterId}` exists; no `{path=**}` catch-all covers `poll_votes`;
  everything else falls to the default deny at L3094.
- a participant CANNOT seat another member's vote row (probe F), CANNOT rewrite
  `metadata` via the receipt branch (probe L), CANNOT vote on a closed poll.
- `poll_votes.voterId` has a COLLECTION_GROUP index (firestore.indexes.json:751), so
  `deletePollVotes` (account-deletion-cascade.ts:1560) can actually run.
- deleted helpers `isDocumentOwner` / `isAddingSelfToList`: zero live callers repo-wide;
  the emulator log's own "Unused function" WARNINGs corroborate.

COVERAGE GAPS found by mutation probe (each mutant left the suite fully green):
- `request.auth.uid == voterId` dropped from `allow create` only -> 26/26. V3's target row
  is pre-seeded by `seed()`, so V3 lands on UPDATE.
- `.hasOnly([...,'metadata'])` on the receipt branch -> 26/26. See the principle added
  for why this is the expensive one.
- `optionIds is list` dropped -> 26/26. `optionIds.size() <= 20` dropped -> 26/26.
Mutants that DID redden (so these are genuinely pinned): poll_votes `allow update: if false`
-> V13; receipt participant check -> R4; receipt allow-list + `content` -> R3 and R6.

THE NULL-METADATA FINDING (trap 1, present but benign):
`pollIsOpen()` uses the naive `pollMessage().data.get('metadata', {}).get('poll', {})...`
chain, NOT the `is map` ternary BUT-1788 established. `MessageDto.toFirestore`
(message_dto.dart:127,157) emits `'metadata': message.metadata` unconditionally, so every
ordinary message stores `metadata: null` — a PRESENT key, so `.get('metadata', {})` returns
null and the next `.get` is a CEL error. Measured: probe A (metadata NULL) DENIES a vote,
probe B (metadata ABSENT — the shape the suite seeds) ALLOWS one. Opposite verdicts, neither
tested. Benign today because a real poll message always carries a metadata map, but (a) the
rules comment at L2070-2075 asserts the chain "keeps the branch evaluable", which is false
for every message the app writes, and (b) the same comment claims a missing metadata would
make the poll "unreadable" — `allow read` never calls `pollIsOpen()`, and probe E confirms
the read succeeds. Two false sentences in one comment beside a correct rule.

Minor, measured: `status` accepts any string on the receipt branch (probe K); the receipt
branch has no `memberSince` cut-off, unlike the message read rule, so a late-joining group
member can stamp receipts on messages they cannot read; `votedAt` is optional (probe I);
a participant can create junk `poll_votes` rows on any metadata-ABSENT non-poll message.

Mechanics that cost time: the mutator's replacement string must contain NO newline escape —
`String.replace` does not interpret `\n`, and the emitted literal `\n` produced
"Error compiling rules: Unexpected 'n'" twice. Rewrote every mutant as a same-line
substitution (`&& X` -> `&& true`) with the preceding line captured to disambiguate the
create limb from the update limb. Also: a git-bash `/c/Users/...` path is not readable by
node — pass `C:/Users/...`. `firestore.rules` was never written (env-var probe seam);
verified comment-stripped md5 identical, 1378 non-comment lines both sides.

### 2026-08-17 — poll_votes fix-round re-review: absent vs null metadata carry opposite verdicts

Re-reviewed the five tests + comment rewrite answering the BUT-1801 review findings
(`functions/src/__tests__/poll-votes-rules.test.ts`, comment-only edit to `firestore.rules`).
Baseline 31/31. Six single-token mutants built in the scratchpad and run through the
`PROBE_RULES_PATH` / `PROBE_PROJECT_ID` seam; `firestore.rules` never written
(md5 6c659fe7b6eed1f0aea050f74d4879d2 before and after every probe).

Attribution measured, each mutant reddening exactly one test (30/31):
- widen receipt `hasOnly` with `'metadata'` -> R3b alone. Proves R3b denies on the
  allow-list, not on the roster conjunct and not via the sender branch (under the
  mutant the write SUCCEEDS, so `metadata` is provably in `affectedKeys()`).
- drop `optionIds is list` -> V10b alone. drop `size() <= 20` -> V10c alone.
- drop `request.auth.uid == voterId` from the CREATE limb only -> V3b alone.
- `is map ? … : {}` repair of `pollIsOpen()` -> V10d alone; `is map ? … : null` -> 31/31.

The finding the probes surfaced: a throwaway probe voting on three message shapes in one
conversation returned ABSENT metadata -> ALLOWED, NULL -> denied, real open poll -> ALLOWED,
identically under the current chain and under the owed `: null` ternary. So the defaulting
chain's only reachable effect on a non-poll message is to permit a `poll_votes` row, the
rules comment defends those defaults as preventing an unwanted deny three lines above
calling that same deny "the outcome we want anyway", and the absent branch has no test.
Low product harm (own-uid row, membership-gated read, swept by the Art. 17 cascade); the
cost is that the owed repair will read as closure it does not deliver.

Comment claims checked against the cited files: `MessageDto.toFirestore`:127 does emit
`'metadata'` unconditionally (true). `message_query_module.dart`:174 is
`if (optionIds is! List) continue;`, so V10b's "the hydration iterates it" is false — the
real consequence is `message_mutation_module.dart`:510's `as List<dynamic>?` cast on the
writer. `MessageDto.toFirestore`:133 already emits a top-level `reactions` key and
`reactions` appears 0 times in `firestore.rules`, so R3b's "a reactions ticket would write
`metadata`" names the wrong key and leaves the plausible widening unpinned. `isValidVote()`
contains no `request.auth.uid`, so V3b's comment names the wrong masker (it is the UPDATE
limb's own uid conjunct). `allow read` genuinely never calls `pollIsOpen()`, so the removed
"unreadable" claim was rightly removed.

Comment-only verified two ways: `git diff -U0` non-comment lines empty, and code-only md5
identical index vs worktree (1720ff7e4e0d8c5f1c823b3e215ab096, 1378 lines both sides; the
file contains no `://` so the strip is safe).

### 2026-08-17 — BUT-1832 poll_votes, third review round: the FOURTH metadata shape [Bug found] [Pattern discovered]

Third pass over the staged `firestore.rules` + `poll-votes-rules.test.ts`. Suite: **32/32**
green against the real rules (`npm run test:rules:poll-votes`). `firestore.rules` never
written — all four mutants were scratchpad COPIES driven through the suite's
`PROBE_RULES_PATH` / `PROBE_PROJECT_ID` seam; md5 `a3ea115f0fc9367debb6b76c3229018f` at both
ends of the session.

Probes run (each mutant a copy, fresh projectId, one per shell call):
- `is map ? … : null` (the repair the comment names) → **32/32 green**. V10e (absent-metadata
  ALLOW) does NOT redden.
- `is map ? … : {}` → **31/32**, V10d (null denies) alone reddens. Confirms the rules
  comment's stated measurement on the current 32-test suite.
- A repair that also CLOSES absent (`is map && 'poll' in metadata && …`) → **31/32**, V10e
  alone reddens. So the V10e pin costs the repair exactly one deliberate line and blocks
  nothing.
- Drop `request.auth.uid == voterId` from the CREATE limb only → **31/32**, V3b alone
  reddens. The new create-limb test is non-vacuous and correctly attributed.

**The finding.** `pollIsOpen()`'s defaulting chain has FOUR shapes, not the three the rules
comment tabulates. A standalone throwaway probe (written under `functions/src/__tests__/`,
deleted in the same Bash call, `zz-` count verified 0 afterwards) seeded a message whose
`metadata` is a MAP WITH NO `poll` KEY — `writeGroupSystemMessage`'s exact shape — and the
vote was **ALLOWED**. Grepping the writers then showed the same shape is written by three
ordinary CLIENT factories: `Message.recipeShare`, `Message.menuShare`,
`Message.shoppingListShare` (`lib/models/messaging/message.dart`:212/242/273), each storing
`{'recipeId': …}`-style maps. So:
- "The FIRST row is the real gap" is false by exclusivity — the map-without-poll shape is
  live, needs no tampered client, and is far more common than an absent key.
- "the common non-poll message denies" is false for every share card in every chat.
- An `is map` guard cannot close it: a map without the key IS a map.
Harm is still low (row keyed to the caller's own uid, read membership-gated, `isValidVote`
bounds it to 3 keys / ≤20 optionIds, and `deletePollVotes`' collectionGroup sweep on
`voterId` erases it wherever it sits) — so "pin, don't fix, on a salvage commit" remains the
right call. What must change is the DESCRIPTION, and the pin should sit on the shape
production actually writes (a `recipeShare`-metadata fixture), not on the absent key.

Two further false sentences, both in the test file:
- V10e: "this test will demand the decision by going red" — measured false for the repair the
  rules comment names (`: null` → 32/32, V10e green). It registers a decision once made; it
  does not demand one.
- V10d: "the rule's own comment claims the `{}` defaults prevent exactly this" — stale. The
  rules comment now explicitly RETRACTS that claim two paragraphs above the function.

Mechanics confirmed this round: `withSecurityRulesDisabled` is a try/finally around an
"owner"-token context (`@firebase/rules-unit-testing/dist/index.cjs.js`:224-242), so V3b's
pre-`assertFails` existence check propagates a throw as a loud FAIL and can never turn a
failing assertion into a pass; and because it passed, `snap.exists` behaved as a compat
BOOLEAN (the modular API's `exists` is a function and would always be truthy, i.e. always
throw), so the guard is live rather than vacuous.

### 2026-08-17 — BUT-1832 final gate: verifying a four-row comment table, and the memberSince parity claim

Third and final review pass over the staged `firestore.rules` (comment-only) +
`functions/src/__tests__/poll-votes-rules.test.ts`. Suite: **33/33**.

**The rules diff was provably comment-only.** Five distinct blobs of `firestore.rules`
exist in the object store carrying the poll_votes rules, at 155433 / 156104 / 157298 /
157622 / 158492 bytes — one per review round — and ALL FIVE share the comment-stripped
md5 `1720ff7e4e0d8c5f1c823b3e215ab096` (1378 code lines). Cross-checked with
`git diff -U0 <prev-blob> <staged> | grep '^[+-]' | grep -v '^[+-][[:space:]]*//'`, empty.
Note the size filter: the file is stored CRLF, so it is ~158 KB, not the ~85 KB an
LF-era filter finds — an earlier sweep at `70000<size<90000` returned only ancient
revisions and looked like "no prior version exists".

**The four-row `pollIsOpen()` table was verified two ways.** (1) Every row has a green
assertion pointing at it in the same file — row 1 absent/V10e, row 2 null/V10d, row 3
map-without-poll/V10f, row 4 real poll/V1+V2. That is what makes a transcription error
unhideable, and it is the property to demand of any table a comment draws. (2) A
standalone probe measured ELEVEN shapes, not four:

```
ALLOW  metadata ABSENT                    DENY   metadata: "a string" (non-map)
DENY   metadata: null                     DENY   metadata: {poll: null}
ALLOW  metadata: {recipeId,recipeTitle}   ALLOW  metadata: {poll: {}}  (no isClosed)
ALLOW  metadata: {poll:{isClosed:false}}  DENY   metadata: {poll: "notamap"}
DENY   metadata: {poll:{isClosed:true}}   DENY   metadata: {poll:{isClosed:"true"}}
                                          ALLOW  metadata: {} (empty map)
```

Every unenumerated state either falls inside row 3's already-named class (a map with no
usable poll → ALLOW) or fails CLOSED. Notably `isClosed:"true"` DENIES, so a tampered
client cannot force the branch open with a non-bool. The table is correct and complete
for the decision it exists to inform.

**Writer claims re-verified at source** (not from the prose): `Message.recipeShare`
(`lib/models/messaging/message.dart`:212), `menuShare` (:242) and `shoppingListShare`
(:273) each store a two-key map with no `poll`; `writeGroupSystemMessage`
(`functions/src/groups/group-system-message.ts`:80) stores `{systemEvent, subjectUserId}`.
Row 3 is live on four writers.

**Three mutation probes, all via `PROBE_RULES_PATH` against copies in the scratchpad —
`firestore.rules` md5 `37acb535…` identical before and after, by construction:**

| mutant of `pollIsOpen()` | result | what it proves |
|---|---|---|
| the OWED repair (`is map && 'poll' in metadata && …`) | **31/33, exactly V10e + V10f** | both known-gap tests are non-vacuous AND keyed on poll-PRESENCE; the real repair breaks nothing else |
| `is map ? metadata : null` (the ternary the comment names) | 33/33 | comment's "stays green" is true |
| `is map ? metadata : {}` | 32/33, exactly V10d | the else branch is the security decision, as claimed |

Probing the OWED repair (not only the forbidden one) is what converts "these tests
document a gap" from a promise into a measurement. It also retired the last pass's
blocking finding: the comment no longer claims the tests go red on their own.

**One blocking finding, and it is a comment, not a rule.** `inPollConversation()` is
introduced as "the same membership test the message read rule uses, one document further
out". Measured against a group conversation whose `memberSince` postdates the poll:

```
DENY   late joiner reads the POLL MESSAGE       (memberSince cut-off, BUT-1838)
ALLOW  late joiner reads the POLL_VOTES TALLY   (inPollConversation only)
ALLOW  late joiner CASTS a vote on it           (inPollConversation only)
```

The membership test *is* the same; the sibling rule's history cut-off is not, so the
sentence reads as parity beside a measured divergence, with no record of it anywhere in
the file. The WRITE half is new — earlier passes framed this as a read leak only, and a
late joiner voting in a pre-join poll is the part a read-focused reading misses.
Deferring the RULES change is right (salvage scope); shipping the parity sentence beside
it is not.

**Low:** the V10e/V10f comment says the `: null` spelling leaves "the suite … 32/32".
Measured 33/33 — the count went stale the moment V10f was added, and it is
self-inconsistent (a 33-test suite cannot stay 32/32 while its 33rd test stays green).
Name which tests redden, never how many pass.

**Fixture check:** `SHARE_META_MSG_ID` disturbs nothing. It is referenced only at its
declaration, in `seed()`, and in V10f; the suite contains no collection-group query and no
`collection("messages")` scan, and the tally tests (V11/V12) address
`messages/{POLL_MSG_ID}/poll_votes` alone. The vote row V10f leaves behind is never read.

### 2026-08-17 — BUT-1832 poll_votes final gate pass: re-verifying a decision record's quoted figures [Pattern discovered]

Final review round on the staged `firestore.rules` + `functions/src/__tests__/poll-votes-rules.test.ts`.
Both prior findings had been taken (the `inPollConversation()` parity sentence rewritten; the stale
`32/32` replaced by a per-test list), and two dated deviation entries had been added to
`.claude/rules/accepted-deviations.md` and `docs/architecture/ACCEPTED_DEVIATIONS.md` quoting THIS
agent's measurements. The task was to check whether the records misstate what was measured.

Suite: **33/33 passed** (`npm run test:rules:poll-votes`), emulator 127.0.0.1:8080.

Every figure in the records re-measured against the CURRENT 33-test file, all via
`PROBE_RULES_PATH` pointed at mutated COPIES in the scratchpad — `firestore.rules` md5
`45e5a55f36762d34f36e02c7807a7922` before and after, never written:

| mutant on `pollIsOpen()` | result | record says |
| -- | -- | -- |
| `is map && 'poll' in metadata && …` (owed repair) | 31/33, FAIL = V10e + V10f only | 31/33, exactly V10e+V10f ✓ |
| `is map ? … : null` | 33/33 | 33/33, gap stays open ✓ |
| `is map ? … : {}` | 32/33, FAIL = V10d | 32/33, reddens V10d ✓ |
| receipt `hasOnly([… ,'metadata'])` | 32/33, FAIL = R3b | R3b's own comment ✓ (R3b is load-bearing) |

The records' figures had been WRITTEN against a 31-test run and restated as `/33` after V10b/V10c
were added. The restatement was arithmetic; it happened to hold, because neither added test moves
under any of these mutants. Re-running is what turned it into a measurement.

`memberSince` divergence re-measured with a throwaway probe (deleted in the same Bash call, `trap
… EXIT INT TERM`, `ls | grep -c zz` = 0): group conversation carrying `groupId` + a `memberSince`
map whose stamp for the late joiner postdates the poll →

```
late joiner reads the poll MESSAGE: DENIED
late joiner reads the TALLY:        ALLOWED
late joiner CASTS a vote:           ALLOWED
CONTROL early member reads MESSAGE: ALLOWED   <- proves the deny is the cut-off, not the roster
```

The control is the part worth copying: without it the first line is just "a deny", and the whole
entry rests on WHY it denied.

Cross-file claims in the records, each checked in its own file rather than believed:
- four writers of a `poll`-less metadata map — `Message.recipeShare` (`{recipeId, recipeTitle}`),
  `Message.menuShare` (`{menuId, menuTitle}`), `Message.shoppingListShare` (`{listId, listTitle}`),
  and `writeGroupSystemMessage` (`metadata.subjectUserId`). ✓
- "no UI renders it": `MessageQueryModule._isPoll` = `message.metadata?['poll'] is Map`, and only
  polls get hydrated, so a junk row on a share card is never read back. ✓
- Art. 15/17 asymmetry: `FirebaseDataExportRepository._hasPoll` = `metadata['poll'] is Map`
  (export skips the junk row) while `deletePollVotes` sweeps
  `collectionGroup('poll_votes').where('voterId','==',uid)` regardless of parent shape (erasure
  reaches it). ✓ — capped at `MAX_POLL_VOTE_SWEEP_ROWS` with a decline-and-report-incomplete path,
  which the harm bound does not overstate.
- `BUT-1835` in the rules comment is the erasure ticket, not a typo for 1832/1801. ✓
- BUT-1833's helper removals (`isDocumentOwner`, `isAddingSelfToList`) leave no references; the
  ruleset compiles, which the emulator load proves independently of grep.

Verdict: nothing in either deviation entry misstates the measurements. Remaining uncovered
branches are the ones the records already name (the `reactions` key on the receipt allow-list; the
`memberSince` cut-off on read + create/update), plus an unauthenticated TALLY-read test that does
not exist (V6 covers unauth create, V12 covers an authenticated stranger's read) — Low.


### 2026-08-17 -- knowledge-diet restructuring migration: "Principles (durable guidance, not a log)" section, pre-restructuring text, verbatim

Migrated verbatim during the BUT-1858-era knowledge-diet pass applied to this agent (mirrors the firebase-backend-security and cloud-functions-specialist restructures). This is the exact pre-restructuring "## Principles" section body -- the grouped date-range distillations that had accumulated in the live knowledge file -- byte-identical to what shipped in the file before this pass. The knowledge file now carries only the re-organized, sharpened principles distilled from this text; every fact below is preserved for the raw multi-round narrative it summarizes (the individual dated incidents it distills are themselves already archived above under the "Archived 2026-07-24" and per-date headings).

## Principles (durable guidance, not a log)

Every dated entry this file has ever accumulated is distilled below and archived
verbatim in `firestore-rules-tester.knowledge.archive.md` — nothing is lost, only
relocated (round 1 = pre-2026-06-24 entries; round 2 = the rest, both under
"Archived 2026-07-24" headings). Distillation is by SHAPE now, not recency: fold
a new dated entry into a principle at write time rather than letting it accumulate
as a story-of-the-day log.

**Distilled from 2026-04-25 → 2026-06-03 (20 entries):**
- Seed conventions; moderation-rules (BUT-511/728); rate-limit deny via `rate_limits` subcollection (seed field name must be `lastWrite`); userId-switch attack pattern for `set()` collections (pin both resource.data and request.resource.data userId in one test); menus-rules (BUT-746/747) recipient self-scrub + paired `removeAll()` anti-griefing (BUT-749, reusable on any "leave a shared list-of-UIDs" rule); Sprint G defence-in-depth denies (seed via `withSecurityRulesDisabled` before any read-deny test); symmetric-difference + isInList membership gates (BUT-464); same-actor rate-limit collisions (use a distinct uid per test); `members` collection-group catch-all needs both a canary-user test and a path-agnostic test (BUT-463).
- `allow list` recipient-branch rules must be exercised with a query whose `where()` guarantees every matched doc satisfies the rule (e.g. `array-contains`); an unfiltered `.collection().get()` must still deny. Storage rules pattern: `initializeTestEnvironment({storage:...})`, modular `firebase/storage` client, most-specific match wins; `recipe_comments` imageUrls validator can bound list size/type but not per-element type (documented gap, not a miss). **EMULATOR PERSISTS DATA ACROSS `npm run` INVOCATIONS** — suffix every create-allow doc id with a per-run token or a 2nd run silently becomes update-not-create and fails wrong; CI is unaffected (fresh emulator per job), so "fails locally, green in CI" means clear-and-retry, not a regression. Admin-SDK cascade integration: point `FIRESTORE_EMULATOR_HOST` at the emulator before importing `firebase-admin`, no `withSecurityRulesDisabled` needed (Admin SDK bypasses rules), always pair a positive delete/scrub with a negative control-doc-untouched assertion; author field differs by collection (`pings.fromUserId`, `comments.commentedBy`, `ratings.ratedBy`) and top-level `recipe_comments.authorId` is anonymized while collectionGroup `comments` is hard-deleted — same-verb assumption across fields is the trap.

**Distilled from 2026-06-10 → 2026-06-21:**

- **Verify the actual collection→test-file map before reusing an old pointer** — a prior note routing `cook_snaps` to `moderation-rules.test.ts` was stale; it lives in `cook-snaps-and-message-mod-rules.test.ts` (project `butlery-rules-cook-snaps-and-message-mod`). `rateLimitWrite('cook_snaps', 5)` is app-written only, so repeated creates by the same actor pass unless a test seeds `users/{uid}/rate_limits/cook_snaps`.
- **CRITICAL (BUT-1214) — back-compat presence-check clauses in a READ rule open the collection-group/list query path even when they look safe on a single `get()`.** `!('field' in resource.data)` and `.get('field', default)` both evaluate their fallback branch as satisfied for an unconstrained query, so Firestore ALLOWS the query and returns real docs whose `field` holds the secret value — rules aren't filters. The only shape that closes the query path is strict equality (`resource.data.field == 'safeValue'`). Cost: docs missing the field become unreadable via that branch too, so any such fix needs a **backfill run BEFORE the rules deploy** (see `functions/scripts/backfill-cook-snap-visibility.js`). Treat any `!('x' in ...)` / `.get('x', default)` clause in a visibility/privacy-enum read rule as a leak candidate and demand a collection-group-query deny test, not just a `get()` deny test.
- **Probing a candidate rules fix without touching `firestore.rules`:** load the rules text, `rules.replace(clauseRegex, candidate)` with a whitespace-tolerant regex (literal template strings miss on indentation), pass the patched string to `initializeTestEnvironment` under a fresh projectId per candidate — lets you report "fix A verified green, fix B verified leaky" instead of speculating.
- **`count()` aggregate rule tests need the MODULAR `firebase/firestore` helpers** (`getCountFromServer`, `collection`, `query`, `where`) cast over `ctx.firestore()` — the compat API has no `.count()` (first seen on `recipe_cook_events`, BUT-838). Append-only `update: if false` collections need proof with BOTH a partial `.update()` and a full-body `.set()` on an existing doc — the set-on-existing path is what a buggy client retry hits.
- **A collection with no root-level `keys().hasOnly()` validator silently accepts new top-level fields** (e.g. `users/{uid}/recipes/{recipeId}`'s `schemaVersion`, BUT-1249) — pin a regression test that fails if a future `hasOnly([...])` is added without the field, rather than relying on the absence of a validator to stay noticed.
- **Coverage checklist for an actor-gated collection with `cannotModify` immutable fields** (activity_events, BUT-1294, and the general shape): (1) at least one update-ALLOW test, not just cannotModify-denies — a blanket-deny regression passes every deny test with zero allow proof; (2) one deny per immutable-field anchor, not just the first; (3) required-field-present AND is-string branches each proven; (4) the rate-limit clause proven via a seeded `users/{uid}/rate_limits/{collection}` doc (app-written only, so other actors' creates don't trip it unless seeded).
- **Collection-group read rules UNION with the specific match they overlay, all-or-nothing per doc** — `match /{path=**}/recipes/{recipeId} { allow read: if isAdmin() }` grants admin BOTH the `collectionGroup("recipes")` query AND a direct `get()` on any single owner-scoped recipe doc; there's no way to express "admin can query but not direct-get" with this shape (admin-dashboard-rules, 2026-06-19).
- **Chained `.get(field, default)` on a nested map is safe-by-construction against an absent parent map, and CEL `in` on a map checks KEYS only (not values)** — verified for the `socialData.memberPermissions` shared-read gate (2026-06-21); still pin an explicit unauthenticated-deny and a missing-parent-field stranger-deny for any privacy-sensitive read-widening of this shape, since the "safe by CEL analysis" argument is not itself a test.
- **`/parse_events` admin-read** (import-health drill-down) lives in `admin-dashboard-rules.test.ts`, `allow read: if isAdmin()` only — confirmed via probe that anon read + any non-admin write/delete all fall through to the global default-deny.

**Distilled from 2026-06-27 → 2026-07-18:**

- **Numeric-floor change on a rule** (e.g. `settings/{settingId}` birthYear minimum age 13→15, BUT-1384): needs allow-at-floor, deny-at-floor+1, AND an update-branch allow at the same boundary — a create-only deny test lets a blanket-deny update regression through unnoticed.
- **`isAgeCompliant()`** = `isAuthenticated() && request.auth.token.ageCompliant == true` — fails CLOSED (no claim → CEL undefined → `==true` is false → deny, not an error). Seed via `authenticatedContext(uid, {ageCompliant:true})`. `birthYear` is CF-only-written on BOTH `users/{uid}` and `users/{uid}/settings/{settingId}`: create requires `get('birthYear', null) == null` (absent); update requires the value unchanged. Four UGC create paths carry `&& isAgeCompliant()`: recipe_comments, messages, social_requests, recipe_ratings (last two also need `isAccountMatured()` + `email_verified:true`). **Adding a gate to an existing create rule fails closed every prior create-allow test lacking the new claim** — grep `authenticatedContext(<actor>)` for that collection whenever a gate is added (recurred at BUT-1418/1419). rules-unit-testing contexts are the CLIENT SDK — seed `new Date()`, never admin Timestamps.
- **Fail-closed proof for any gate-deny test**: re-run the IDENTICAL body+id with the gate satisfied (throwaway probe) and assert SUCCESS — if the probe also fails, the deny was about body/id/persistence, not the gate. `isAccountMatured()` needs `{email_verified:true}` OR an aged `users/{uid}` doc; a fresh-account deny test needs BOTH `email_verified:false` AND no seeded profile doc, or a doc persisted from a prior run makes the deny pass by accident. `curl -X DELETE .../databases/(default)/documents` from Bash silently no-ops (parens glob-expand, exit 7) — use each test file's own `clearFirestore()` helper.
- **Household membership** (`households`, `diner_profiles`, `family_ratings`) is a DOC-READ gate: `isHouseholdMember(hid)` = `get(households/{hid})` + `auth.uid in doc.data.memberUserIds` — not a path segment, so every test must seed the household first. Household-admin (`memberPermissions[uid]=='admin'`) is separate from the app-level `/admins` isAdmin(). Create is projection-strict: `memberUserIds.toSet()==memberPermissions.keys().toSet()` is the load-bearing deny. **`dinerConsentValid` (GDPR Art. 9)** ANDs a minority gate (`ageBand=='adult' || guardianConsent != null`) with an allergen gate (`!dinerHasAllergenData(data) || guardianConsent.get('includesAllergenConsent', false)==true` — the default fails a MISSING consent map too); both re-run on update. `family_ratings` pins `enteredByUid == request.auth.uid` on CREATE only. A deny test's CEL `evaluation error` is an expected `assertFails` pass, not a bug.
- **Optional-list field validator shape**: `!('field' in request.resource.data) || (request.resource.data.field is list && request.resource.data.field.size() <= N)` (e.g. `attendeeMemberIds<=50` on `recipe_cook_events`). Reusable 5-test cluster: present+valid, present+empty (size 0), present+at-cap (boundary inclusive), present+over-cap (deny), present+wrong-type (deny) — the absent case is already covered by the baseline create-allow test.
- **Never import server-value sentinels (`serverTimestamp`, `increment`, `arrayUnion`, `deleteField`) from `firebase-admin/firestore` in a `*-rules.test.ts`** — `ctx.firestore()` there is the CLIENT SDK; an admin sentinel throws `invalid-argument` at `.set()` before any rule runs, which ALSO fails `assertFails` deny tests. Always `import {serverTimestamp} from "firebase/firestore"`. Broke on a firebase-admin 12→13 bump (pure test-harness bug, zero prod impact — real clients always use the client SDK). Grep `from "firebase-admin/firestore"` across `__tests__/*-rules.test.ts` after any firebase-admin major bump.
- **Deny-all server-only collection shape** (`allow read, write: if false`, e.g. `/llm_response_samples`, BUT-1451; same as SPRINT-G D1–D11): matrix {read,create,update,delete} × {unauth, non-admin, admin} — admin-still-denied is the load-bearing case — plus one Admin-SDK-bypass write that succeeds. A single-segment top-level collection can't match any `{path=**}/<name>/{id}` collection-group catch-all (those require a trailing named subcollection segment) — check the catch-all list for union-safety rather than reading the new rule in isolation.
- **1:1 DM minor gate on `conversations/{id}` create (BUT-674)**: `passesMinorDmGate(ids)` = `ids.size()!=2 || !otherIsMinor(otherParticipant(ids)) || creatorIsFriendOf(otherParticipant(ids))`. `otherIsMinor(uid)` = `exists(users/{uid}) && get(users/{uid}).data.get('isMinor', false)==true` — **the `exists()` guard is load-bearing**, a bare `get().data.get()` CEL-errors on a missing profile; guarding it fails OPEN as non-minor (same pattern reused for `accountIsMinor` on `public_profiles`). **Group conversations (size>2) are deliberately ungated** — rules can't iterate a participant list; group-minor protection is the separate `enforceGroupMinorMembership` Cloud Function, not this rule — don't file a "group DM has no minor gate" finding. Reusable pattern for any "allowed only if a seeded relationship doc exists" gate: pair a no-relationship-doc deny with the identical actor+body succeeding once the doc is seeded.
- **`isMinor` write-protection mirrors `birthYear`** on BOTH `users/{uid}` (profile) and `users/{uid}/settings/{settingId}`: create requires `request.resource.data.get('isMinor', null) == null` (absent — CF-only via `verifySignupAge`, Admin SDK bypasses rules); update requires the post-write value equal the pre-write value (immutable). **Load-bearing test**: an update touching an unrelated field (`isSearchable`, `notificationsEnabled`) while `isMinor` is preserved must ALLOW — without it, a blanket-deny regression of the update rule passes every isMinor-immutability deny test.
- **Server-authoritative pooled-ratings homes** (`users/{userId}/canonical_rating_events/{poolKey}`, `canonical_recipe_stats/{poolKey}`, decision 10): both `create,update,delete: if false` (CF/Admin-SDK-only); read is owner-only for events (`auth.uid==userId`), any-authed for stats (anonymous aggregate). **Collection-group leak guard is the load-bearing test for any owner-scoped subcollection**: `collectionGroup(name).get()` by a non-owner must DENY — the engine can't prove every matched doc satisfies the owner predicate for an unconstrained collection-group query, so a single-doc deny test alone is not proof.
- **Five owner-shaped `{path=**}/<name>/{id}` collection-group catch-alls** beyond the `members` suite (BUT-463): `engagements` (doc-ID), `comments` (`commentedBy`), `ratings` (`ratedBy`), `recipes` (isAdmin-only read), `pings` (`fromUserId||toUserId`). **Idempotent-without-clearFirestore pattern**: a suite that only reads/deletes pre-seeded docs (re-`seed()` via `withSecurityRulesDisabled` every test) is re-run-safe on a persistent emulator with no namespace clear — the persistence gotcha only bites suites with un-reseeded create-allow doc ids.
- **`/tag_overrides_log/{entryId}` (BUT-1473) is a byte-for-byte contract mirror of `/parsing_corrections`**: owner-or-admin read, owner-only authed create + `hasRequiredFields`, `update: if false` (append-only), owner-only delete (GDPR Art. 17). Reusable coverage shape for any such own-data append-only log: create {owner-allow, cross-user-deny, unauth-deny, missing-field-deny × 2 keys}, read {owner-allow, admin-allow, stranger-deny, unauth-deny}, update {partial-deny AND set-on-existing-deny — a buggy client retry hits the set path}, delete {owner-allow, stranger-deny, unauth-deny}.
- **`public_profiles/{userId}` minor-searchability**: create denies `isSearchable:true` for a minor (`accountIsMinor(userId)`, same exists-guarded pattern as `otherIsMinor`); update gates on the DIFF (`!diff.affectedKeys().hasAny(['isSearchable']) || isSearchable!=true || !accountIsMinor(userId)`) so a minor can still edit unrelated fields. **Load-bearing contrast**: minor + `isSearchable:false` must ALLOW, proving the deny is the true+minor combination, not a blanket write-block. Group-minor protection is the separate `enforceGroupMinorMembership` CF — its decision core is unit-tested, its I/O wrapper (delete-vs-update, field cleanup) has no emulator integration test (Medium gap, matches sibling-trigger convention).
- **`conversations/{id}` create binds `metadata.creatorId` to the caller** (`!('metadata' in ...) || !('creatorId' in ...metadata) || ...metadata.creatorId == request.auth.uid`) — closes a spoof where a tampered client forges `creatorId` to a friend of a minor to slip a non-friend group-add past `enforceGroupMinorMembership`'s friend check. Isolate the binding from the minor-DM gate by testing an ADULT 1:1 target (so `passesMinorDmGate` passes regardless) and varying only `creatorId`. **The UPDATE half (BUT-1788) is where the landmine is: `.get('k', default)` returns the default ONLY when the key is ABSENT — a key PRESENT with a null value returns null, and chaining `.get()` onto that null is a CEL error, i.e. a blanket deny of every update.** `ConversationDto.toFirestore` emits `'metadata': conversation.metadata` unconditionally, so the client sends `metadata: null` on every message send (`batch.set(convRef, dto, merge:true)`, atomic with the message write — the deny kills the message too) and freezes every doc whose stored metadata is null or absent. Verified spelling that survives it: `(x.get('metadata', {}) is map ? x.get('metadata', {}).get('creatorId', null) : null)` on BOTH sides — 0/13 mismatches vs 3/13 for the naive chain. Treat any `a.get(k, d).get(k2, d2)` in a rules diff as a deny-everything candidate until probed with a PRESENT-BUT-NULL parent. **A subcollection rule that attests via `get(parent)` must first be checked against WHERE the parent is actually written** (2026-08-12, `conversations/{id}/participants`): `FirebaseMessagingRepository` mixes in `UserScopedFirebaseRepository`, so a GROUP's conversation doc lands on `users/{creator}/conversations/{id}` and the TOP-LEVEL doc does not exist until the first message (BUT-1795) — a parent-attesting rule denies every group create permanently, not just during the batch. Shipped shape, reusable for any "roster written before its parent is visible" path: `attestedWriter()` (parent names writer AND subject) OR `rosterUnclaimed()` (parent == null, bootstrap), with READ falling back to `exists(.../{own uid})` (recipePresence pattern, safe for LIST since it touches no `resource.data`), DELETE deliberately NARROWER than create (self-only — no caller deletes another's row, and the CF does it under the Admin SDK), and the payload's id fields pinned to the path so they are immutable on update for free. Prove such a design with the writer's REAL WriteBatch (roster rows + membership rows in one commit): a batch is all-or-nothing, so it is the only test that proves two rule blocks cooperate — and when it denies, attribute the deny with a probe, because the emulator prints a `false for 'create'` verdict for EVERY document in a failed batch, including ones that are allowed on their own. **A branch keyed on `parentDoc() == null` reads DESTROYED as NOT-YET-CREATED, so reviewing it means enumerating EVERY deleter of the parent — client `allow delete`, each CF, AND the GDPR account-deletion cascade, which is the one everybody forgets (`account-deletion-cascade.ts` deletes ≤2-participant conversations whole and never touches the subcollection). Rules cannot fix any of them; only code can, and a residual paragraph that names two deleters out of three under-states its own hole.** Scope note: a `direct_`-style id exclusion added to the WRITE branch does not exist on the READ branch, so a deleted DM still hands its roster to whoever holds a row — check both verbs when an id-shape exclusion is the control. **A rules COMMENT asserting what a Cloud Function does with the document is a claim about another file's boolean — read that line, not the prose**: `enforceGroupMinorMembership` computes `isGroup = data.isGroup === true || len > 2` and returns on `!isGroup || len <= 2`, so "returns early on `isGroup: false`" is true only because the payload ALSO has one participant; a false flag with >2 does not. Same cluster, verified 2026-08-13: the create rule's `!('creatorId' in …metadata)` denies `metadata: null` by CEL evaluation error, and harmonising it to the update rule's `is map` ternary reddens EXACTLY one test (47/48, C7B) — that is what "mutation-proven" has to mean before a comment may claim it, and the deny is a bound on OUR client only, never on a tampered one.

**Distilled from 2026-07-28:**

- **Append-only ARRAY guard** (`/unified_shared_shopping_lists.contributorUserIds`, BUT-1725, GDPR Art. 17 erasure trail): `request.resource.data.get(f,[]).hasAll(resource.data.get(f,[])) && request.resource.data.get(f,[]).size() <= N`, ANDed OUTSIDE the `(owner || member)` parenthesis so the owner is bound too. `hasAll` is SET-semantics — a client rebuilding the array from a Dart `Set` reorders it and must still ALLOW (pin that test; it is the difference between this and an equality check). Rules see the POST-transform value, so `arrayUnion` allows and `arrayRemove` denies with no special handling. The `get(f,[])` default makes both legacy (field-absent) docs and older clients writable. **The bound is on `request.resource` only, so a doc already over N is FROZEN — every update denies, including an items-only one** (Admin-SDK backfills bypass rules and can create that state); pin it as a documented consequence, not a silent one.
- **A guard ANDed onto an existing `allow update` is a blanket-deny risk, not a leak risk** — lead the suite with allow paths (untouched-field update, owner branch, whole-doc write-back, legacy doc) before any deny. **Builder timestamps must be CONSTANTS, not `new Date()`**, whenever the member branch forbids touching `createdAt`: a re-stamped builder makes every whole-document write deny for an unrelated reason and reads as a rule defect (cost one false FAIL here). Emulator PERMISSION_DENIED prints TWO passes; the first is routinely `evaluation error` (first pass has no `resource`, only short-circuits like `isAuthenticated()` avoid it) — read the SECOND verdict, which is the real one.
- **Mutation-probe the guard before reporting green** (`rules.replace(...)` in memory, fresh projectId — never touch the file): removing the predicate must FLIP every deny test. Two mechanics that cost a run each: the probe script must sit UNDER `functions/src/` (from the OS temp dir `npx ts-node` resolves neither `@firebase/rules-unit-testing` nor the tsconfig, so it dies on TS2307 + implicit-any) and delete it in the SAME Bash call — note `cd functions` earlier in that call makes a later `rm functions/src/...` silently miss; and **`firestore.rules` is CRLF**, so a literal template-string `includes()` never matches — use a whitespace-tolerant regex, assert the match COUNT is 1, and re-read the file at the end to prove it is byte-unchanged. **Probe WITHOUT touching the file at all**: `sed` a copy of the suite into `functions/src/__tests__/zz-<probe>.test.ts` whose `PROJECT_ID` is fresh and whose `RULES_PATH` is `process.env.PROBE_RULES ?? <original>` (keep the `??` fallback — dropping the `path` import trips `noUnusedLocals` and the run dies silently under a `grep`), point it at a mutated copy in the scratchpad, and `rm` the probe in the same call under a `trap ... EXIT INT TERM`. That is how "removing X flips EXACTLY test Y" gets measured (verified: dropping `parentDoc() == null` → 46/47, P12B alone). **A "comment-only" rules diff is provable, not eyeballable**: `git fsck --unreachable` + `git cat-file --batch-all-objects --batch-check` recovers every previously-staged revision of `firestore.rules`, so you can diff against the exact bytes a prior review saw; then strip `//` comments from both (`sed 's|//.*$||'`, safe only after grepping the file for `://`) and compare md5s. **Strip BLANK lines too (`grep -vE '^[[:space:]]*$'`) and `tr -d '\r'`** — any comment edit that changes the LINE COUNT (14/6 is typical) leaves a different number of now-empty lines, so the naive strip reports a mismatch on a diff that is provably comment-only; print the surviving line count alongside the md5 so "identical" is visibly non-vacuous. Cheap independent cross-check, worth running as the pair: `git diff -U0 | grep '^[+-]' | grep -v '^[+-][[:space:]]*//'` must come back EMPTY. Two agreeing methods beat one, because each fails differently (the md5 catches a reordering the line filter would miss; the line filter catches a `//` inside a string literal the md5 strip would mangle). Distinct code-md5s among those blobs are RESTORED MUTATION PROBES, not history — confirm the staged blob matches the reviewed one. Use a **`/g` flag** when the mutated literal appears more than once — the create-side bound and the function's bound are textually identical here, and a non-global replace silently patches only the first, producing a "still denied" that looks like a rule finding but is a probe bug.
- **A PERMISSION_DENIED verdict string can never prove two deny tests are DIFFERENT tests.** On `unified_shared_shopping_lists` a non-member's update and a REVOKED member's update (in `contributorUserIds`, absent from `memberPermissions`) print byte-identical `evaluation error at L1642:24 for 'update' @ L1642, false for 'update' @ L1642` — the first-pass evaluation error is just "no `resource` in pass 1", so it fingerprints the RULE LINE, never the actor. Only two things prove non-vacuity: (a) a **fail-closed probe** — same doc body, same doc id, same actor, same payload, with only the gate satisfied (seat the actor in `memberPermissions`) → must ALLOW; and (b) a **discriminating mutation** — rewrite the gate so the two actors' fates diverge (grant the member branch by `contributorUserIds` instead: the revoked actor FLIPS to allow, the stranger stays denied). Same shape applies to any pair of deny tests separated by document STATE rather than by actor identity.
- **A decision record that asserts a rules predicate is a coverage lead, not evidence.** ADR-002 states "firestore.rules forbids a non-owner from touching `ownerId` or `memberPermissions`" — grep the suite for that predicate before believing it is pinned; there it was not (only the third privileged key, `createdAt`, had a test). For any `!diff(resource.data).affectedKeys().hasAny([a,b,c])` conjunct, coverage is one deny per anchor **plus** the OWNER-branch ALLOW for the same key — the owner branch usually has no diff restriction, so the member-deny and the owner-allow are two different rules and a blanket-deny regression on the key passes every deny test while making the app's grant/revoke flow impossible.
- **A rules suite whose only route into a state is `withSecurityRulesDisabled` has not proven the state is REACHABLE.** Revoked-member tests seeded the revoked document with the Admin SDK, so nothing proved a client owner could actually perform the revoking write.
- **A `get()`-only read suite has NOT tested the read rule.** For any collection whose read gate reads `uid in resource.data.<map>` (`unified_shared_shopping_lists`, BUT-1746), the LIST path is a separate branch: the engine evaluates the predicate per candidate document and refuses the WHOLE query if one fails. So pin three things — the client's exact filter ALLOWED (returning a non-empty result; assert non-emptiness or a broken filter passes vacuously), the UNFILTERED `collection().limit(N).get()` DENIED with a foreign doc seeded in the same test, and the same filter by a member-of-nothing ALLOWED-but-empty. Dart `isNull: false` compiles to `where(f,'!=',null)` (`query.dart:676-682`) — that is the JS spelling to pin; `isNotEqualTo: null` builds NO condition at all (`if (isNotEqualTo != null)`, `query.dart:659`), so the "filter" becomes an unfiltered sweep and the symptom is "my list will not load", never an over-share. Guarded repo-side by `tools/check_null_filter.sh` (pre-commit only, no CI lane; `-H` now forces grep's `path:line:` prefix so the SINGLE-file lefthook case skips comments correctly, but the `^[^:]*:[0-9]+:` anchor still assumes a COLON-FREE path — a `C:/`-shaped argument flags the 12 WHY-comments naming the banned spelling, and the unbounded `null` in its pattern also false-positives on `isNotEqualTo: nullableVar`; both fail closed, probed 2026-07-30). **A query test asserting an EMPTY result needs an actor no other test ever seats** — a sibling deny test's `withSecurityRulesDisabled` fixture persists on the emulator and will make that actor a member.
- **An ALLOW test must send the DTO's REAL payload, not a minimal hand-written one.** A hand-written `update({lastMessage: ...})` omits keys the app always writes, so it can pass while the identical production write denies — BUT-1788's C11 ("no-metadata doc is still updatable") went green on a payload with no `metadata` key while the app's own `ConversationDto.toFirestore` always includes it and was denied. Read the DTO/`toFirestore` for the collection and mirror its FULL key set in at least one allow test per write path (send + mark-as-read), and note that `set(..., merge:true)` DEEP-MERGES nested maps — a payload "dropping" a nested key does not drop it, so a takeover-by-omission test must use `update()`, not a merge-set, or it proves nothing.
- **A nullable map/field has FOUR stored states — absent, present-with-null, present-as-a-map-WITHOUT-the-key-you-chain-into, and fully populated — and each is a separate rule branch needing its own fixture.** The third is the one a three-row comment omits and the one PRODUCTION writes most often: `Message.recipeShare/menuShare/shoppingListShare` and the Admin-SDK `writeGroupSystemMessage` all store `metadata` as a map with no `poll` key, so `pollIsOpen()` defaults its way to ALLOW on every share card and every "X har lagts till i gruppen" row (measured 2026-08-17, standalone probe). Enumerate the shapes by GREPPING THE WRITERS of the field, never from the two shapes a null-safety discussion suggests — and note an `is map` guard does nothing for this state, because a map without the key IS a map. Absent is the state a suite reaches for by habit and the one a naive `.get(k, default)` handles CORRECTLY, so an absent-only fixture set goes green over a live blanket-deny (BUT-1788, `conversations.metadata`: the app writes `null`, never absent). **The two "empty" states can carry OPPOSITE VERDICTS, so covering one hides the other (measured 2026-08-17, `poll_votes.pollIsOpen()`).** In a defaulting CHAIN `d.get('metadata',{}).get('poll',{}).get('isClosed',false) == false`, ABSENT cascades the defaults to a falsy leaf and the predicate comes back TRUE — i.e. ALLOW, a vote seated on a message with no poll at all — while NULL dies on a CEL error and denies. A suite that pins only the null case reads as coverage and leaves a live allow. Pin absent AND null on every defaulting chain, and state each verdict, because "both are empty" is the intuition that loses. **Corollary for the `is map` repair: the ELSE branch is the security decision, not the `is map` guard.** `… is map ? …get('isClosed',false) : null` keeps the null deny (probe: 31/31 green); `… is map ? … : {}` re-defaults to falsy and flips null to ALLOW (probe: the null test alone reddens). Neither closes the ABSENT hole, so a comment calling the ternary "the repair" promises a closure it does not deliver — probe both spellings before any comment names one. Pin the allow on the null doc AND the deny (e.g. creatorId injection) on BOTH the absent and the null doc. Under a request-side-triggered CEL error the *request* payload's null is enough on its own — a real-DTO allow test on the ABSENT doc also reddens, which is a bonus, not a substitute. **Corollary that bites: an ALLOW test landing a real payload MUTATES its fixture** — a merge-set carrying `metadata: null` turns the absent-metadata doc into a null-metadata doc, so any deny test that depends on the pre-write state needs its own write-once document, not the one the allow test just overwrote. **When a comment TABULATES these states, demand two things before believing it (2026-08-17):** every row must have a green assertion in the same file pointing at it (that is what makes a transcription error unhideable), and the UNENUMERATED states must be swept once by probe — eleven shapes measured on `pollIsOpen()`, and every state outside the table either falls in an already-named row's class or fails CLOSED (`{poll: null}`, a non-map `metadata`, and even `isClosed: "true"` all DENY, so a tampered client cannot force the branch open). **Probe the OWED repair, not only the forbidden edit** — mutating `pollIsOpen()` into the real fix (`is map && 'poll' in metadata && …`) reddened EXACTLY the two known-gap tests and nothing else, which is what turns "these tests document a gap" from a promise into a measurement; a comment claiming a suite COUNT (`stays 32/32`) goes stale the day a test is added, so name which tests redden instead. **A DECISION RECORD that quotes probe figures inherits that staleness at one remove** — a record written against a 31-test run and later restated as `/33` is arithmetic, not measurement, so re-run every quoted mutant against the CURRENT file before signing the record off (2026-08-17, all three reproduced: owed repair 31/33 reddening exactly V10e+V10f, `: null` 33/33, `: {}` 32/33 reddening V10d; a fourth, widening the receipt `hasOnly` with `'metadata'`, reddens exactly R3b). A cross-file claim inside such a record is a claim like any other: verify the WRITERS it names (all three `Message.*Share` factories and the group system-message CF store a metadata map with no `poll` key) and the readers it exonerates (`_isPoll`/`_hasPoll` both test `metadata['poll'] is Map`, so a junk row is never hydrated or exported).
- **A per-key immutability guard needs an ALLOW that changes a NEIGHBOURING key in the same map** (BUT-1788 C14: rename the group via `metadata.title` with `creatorId` carried through). Every deny in the cluster survives a future blanket freeze of the whole map; only that allow reddens. State in the test's comment which key is pinned and that the rest stays mutable — otherwise the next reader reads the deny cluster as "this map is protected".
- **`test:rules:all` is not runnable from the Firestore hook alone**: `comment-images-storage-rules` needs the STORAGE emulator (9199) and hard-fails `ECONNREFUSED`, aborting the `&&` chain mid-list so every later suite silently never runs — check WHERE the chain stopped before reporting a pass count, and re-run the tail individually. (`moderate-upload.integration` probes and prints a SKIP banner instead; the rules suite does not.)
- **A rules change that TIGHTENS an existing gate silently makes every OLDER test on that path vacuous, and the deny tests are the ones that hide it** (BUT-1838, conversations/messages/roster). When a new conjunct is added ABOVE the one a test was written for, that test still denies — for the new reason — and would stay green with its original target deleted. Mechanical sweep after any tightening: for every deny test on the touched path, ask which conjunct now fires FIRST, and give the test a payload/id/fixture that satisfies everything except its own target. Here that meant a conforming `direct_<a>_<b>` id and a conforming `metadata` map on all eight legacy create tests, and re-pointing seven roster-validator tests from a now-denied parentless fixture to an attested one. **The intended FLIPS are the cheap part** (allow→deny: C5 group create, P1 bootstrap seat, P3B pre-seat, P14 own-row read, P24 group batch) — write the flip's reason at its own site, name it as the ticket's intended signal, and say what a future re-flip would mean. **The expensive part is that a flipped test usually had a SECOND job**: P3B was also P3's fail-closed control, so flipping it left every attestation deny unattributable until a replacement allow (same actor, same body, same id shape, attested parent) was added.
- **A MUTATION PROBE THAT REDDENS NOTHING IS THE MOST VALUABLE RESULT** — it means a comment, not the code, is wrong. Probing the edit `firestore.rules` explicitly forbids ("harmonising the create rule's `metadata` spelling with the update rule's `is map` ternary would disarm test C7B") came back 77/77 GREEN: the warning was true of the pre-BUT-1838 conjunct (`!('metadata' in d) || !('creatorId' in d.metadata) || … == uid`, whose `||` hatches allowed an absent creator, so only the CEL null-error stood in the way) and is stale against the bare-equality replacement, where a ternary resolving `null` still fails `null == uid`. Deleting the conjunct outright reddened exactly three (C6, C6B, C7B), which is what proves the assertion is load-bearing. So: run BOTH the "forbidden edit" probe AND the "delete it" probe — the first tests the COMMENT, the second tests the TEST. Never let a rules comment's claim about a mutation stand unrun.
- **Probe by ENV VAR, not by a copied test file.** Ship `const PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "<real>"` and `RULES_PATH = process.env.PROBE_RULES_PATH ?? <real>` in the suite itself, mutate a COPY of `firestore.rules` in the scratchpad, and run `PROBE_RULES_PATH=… PROBE_PROJECT_ID=… npx ts-node <suite>`. `firestore.rules` is never written (md5 identical by construction, not by a restore that a timeout can skip), no `zz-*.test.ts` can be left behind, and a fresh projectId keeps the mutant's writes out of the real namespace. The mutator asserts its match COUNT is 1 and prints a `diff` of the mutant against the original, so a regex that silently matched nothing cannot be read as "the rule holds".
- **A single-conjunct probe that reddens NOTHING can mean the conjunct is MASKED, not that the test is vacuous.** In `A && B`, if B raises a CEL evaluation error whenever A is false, dropping A changes no verdict: on `chat_groups` (BUT-1838) dropping `isAuthenticated()` from the read rule reddened 0/27 (`request.auth.uid in …` errors on null auth), and dropping `name is string` reddened 0/27 (`.size()` on an int errors). Neither test is dead — both flip under a COMBINED mutation (`read: if true`; drop all three name conjuncts). So attribute a masked test with the smallest mutation that DOES flip it, and report it as "guards the pair", never as "proven load-bearing on its own". The same probe run also fingerprints the split between guards that ARE independent (drop `uid in adminIds` → exactly the three rename-actor denies; drop `hasOnly` → exactly the six admin-actor diff denies; the two membership-lock tests whose actor is a non-admin need BOTH dropped) — that map is the report, not a pass count. A deny against `allow x: if false` is unflippable by removal by construction: probe it by OPENING the rule (`if isAuthenticated()`), which is the regression those tests actually guard.
- **`{"error":{"code":500,"status":"UNKNOWN"}}` from `loadFirestoreRules` is emulator flake, not a rules syntax error** — it fires when several probe runs load rulesets back-to-back under fresh project ids, and it looks exactly like a compile failure (the run prints the suite banner, then dies before test 1). Disprove it in one command by PUTting the same file to `/emulator/v1/projects/<pid>:securityRules`: a 200 with only `severity: WARNING` issues means it compiles. Space probes at one or two per shell call; a retry loop inside the same call does NOT clear it. Never read the aborted run as "nothing reddened" — grep for the summary line's absence, not just for `FAIL`.
- **A `rateLimitWrite(...)` conjunct appended to a new rule is invisible to the whole suite** unless a test seeds `users/{uid}/rate_limits/{collection}` (it is `!exists(limitsPath) || …`, and no Butlery client writes those docs). Its removal reddens nothing, so it needs an explicit seeded-doc deny test or it must be reported as an uncovered branch — silence there is not coverage.
- **A conjunct ADDED to `hasRequiredFields`/`hasOnly` is a claim about EVERY writer of that COLLECTION, and the rules comment beside it is not evidence.** BUT-1812 added `'sharedToUserIds'` to the `shared_content` create allow-list under a comment saying "all three writers already stamp it"; only the RECIPE repo does (`initialSharedToUserIds`), while the menu, shopping-list and social-coordinator paths call `createSharedContent(entity)` and no `toFirestore()` emits the field — so menu and list sharing were denied outright (BUT-1482's disease, second occurrence). Grep the WRITERS by collection constant before believing the sentence, and prove the verdict with a probe that sends the writer's REAL key set plus a same-payload control carrying the new field. **Two new conjuncts can also MASK each other**: dropping the required-key alone reddened nothing because the neighbouring `x is list` CEL-errors on the absent key — a suite whose only malformed test is "field missing" pins the PAIR, so add a WRONG-TYPE case to pin `is list` on its own.
- **An `allow update` that is textually identical to its `allow create` still needs its own allow test** — a client `set()` on an existing doc is an UPDATE, so a toggle/edit path lives entirely there. On `poll_votes` (BUT-1832) mutating `allow update` to `if false` reddened 0/21 while every vote after the voter's first goes through it; a later revision added that allow test (V13) and the same probe now reddens exactly 1/26. Probe every verb of a new subcollection with the `if false` mutation; the one that reddens nothing is the uncovered one. **The mirror trap on the DENY side (re-verified 2026-08-17, still open): when create and update carry the SAME conjunct, a deny test whose target document is PRE-SEEDED by `seed()` lands on UPDATE, so it proves nothing about the create limb** — dropping `request.auth.uid == voterId` from `allow create` alone reddens 0/26. A cross-actor deny must therefore exist twice, or once against a path no fixture has written (a participant seeded into `participantIds` but never given a row). Same run: a `X is list` conjunct sitting next to `hasRequiredFields([... 'X'])` is MASKED by every "field missing" test (removing it reddened 0/26), and so is a neighbouring `size() <= N` cap — the wrong-TYPE and over-cap payloads are the only things that pin either. **Both were added 2026-08-17 and each reddens ALONE (30/31), because a STRING has `.size()` in CEL: with `is list` gone, `"opt-a".size()==5 <= 20` passes, so the cap never catches a wrong type and the two tests are genuinely independent — do not drop one as redundant.** The reserved-fixture fix for the create-limb trap works (a poll seeded with no vote rows makes the seat-a-row deny redden alone under a create-only mutation) but its create-ness is CONVENTION: `clearFirestore()` plus a per-run id token close the cross-run hazard, while nothing stops a future test writing into the fixture, after which the deny silently lands on UPDATE and still passes. Make it self-checking — assert the row does not exist via `withSecurityRulesDisabled` before the `assertFails`.
- **An `affectedKeys().hasOnly([...])` allow-list needs one deny test PER KEY THE APP MIGHT PLAUSIBLY ADD, not one per key a test happened to try.** The messages RECEIPT branch (BUT-1832) is pinned only against `content`: widening it to `[... , 'metadata']` — a one-token edit a future "let participants react" ticket would make — leaves 26/26 GREEN while handing every participant the poll question, `isClosed`, and `metadata.poll.options[].voterIds`, i.e. the entire inline vote store the ticket existed to abandon. `hasOnly` is TOP-LEVEL, so a nested rewrite is caught only because the parent key is listed; that protection is invisible to a suite that never names the parent. Enumerate the top-level keys the collection actually stores and pin the privileged ones by name.
- **A comment saying a rule uses "the same test as" a SIBLING RULE is a parity claim, and parity is measured, never read** (2026-08-17, `poll_votes`). `inPollConversation()` was introduced as "the same membership test the message read rule uses, one document further out": the membership half is identical, but the `messages` read rule also carries BUT-1838's `memberSince` cut-off, and the subcollection does not. Measured on a group conversation whose `memberSince` postdates the poll — late joiner DENIED the poll message, ALLOWED the tally read, and ALLOWED to CAST a vote in it. **Check the WRITE verb too**: a read-focused reading of this divergence names the tally leak and misses that the same predicate gates `create`. Generalises the older "a rules comment asserting what a Cloud Function does is a claim about another file's boolean" — a sibling rule ten lines away is exactly as unread as another file. A parent rule and its subcollection are two rules; enumerate every conjunct on the parent and ask which the child dropped.
- **A "comment-only" rules diff is provable across MANY rounds at once**: `git cat-file --batch-all-objects` finds every previously-staged revision, and all of them sharing one comment-stripped md5 proves the code never moved through the whole review. Size-filter on the CRLF size (~158 KB here, not the ~85 KB an LF-era guess finds) or the sweep silently returns only ancient revisions and reads as "no prior version exists".
- **Registering a new rules suite has FOUR mechanical steps** (`functions/scripts/check-test-registration.js` fails the commit otherwise): the `test:rules:<name>` script, an entry in the `test:rules:all` chain, AND the path in **both** `paths:` blocks of `.github/workflows/firestore-rules.yml` (pull_request + push). Verify with `node scripts/check-test-registration.js`.

## 2026-08-18 — comment-drift sweep on `isAccountMatured()`: name corrected, value re-verified

Nightly comment sweep changed exactly one word in `firestore.rules`:
`kAccountMaturityMinutes` -> `kAccountMaturityWindow` in the comment above
`isAccountMatured()`. Gate review, no emulator run (no rule change to prove).

Mechanical comment-only proof (both methods from the principles file):
- `git diff -U0 -- firestore.rules | grep '^[+-]' | grep -v '^[+-][+-]' | grep -v '^[+-][[:space:]]*//'`
  -> empty.
- Comment-stripped + CRLF-stripped + blank-stripped md5 of `HEAD:firestore.rules` vs
  worktree: identical (`1720ff7e...`), 1378 surviving lines on both sides, so the
  equality is visibly non-vacuous.

Name claim: `kAccountMaturityMinutes` matches NOWHERE in the repo after the edit (rg,
whole tree). `lib/services/auth/account_maturity_helper.dart:8` declares
`const Duration kAccountMaturityWindow = Duration(minutes: 60)` — path in the comment
is correct.

Value claim (the part a name-only fix would have missed): rules use
`>= 60 * 60 * 1000` ms = 60 min; Dart is `Duration(minutes: 60)`. Agree. A THIRD mirror
the comment does not name also agrees:
`functions/src/ratings/canonical-rating-aggregation.ts:67`
`export const kAccountMaturityWindowMs = 60 * 60 * 1000`. Had any of the three
disagreed, the corrected comment would itself have been false and the sweep would have
had to BLOCK rather than commit a tidier-looking lie.

Lesson merged into the principles file (Rule parity / comments bullet): a "kept in sync
with X" comment asserts both the SYMBOL and the VALUE; a drift sweep that repairs only
the symbol can leave the stronger claim broken.

Verdict: PASS, 0 blocking.

---

## 2026-08-22 — BUT-1831: conversations update deny-list (C11C/C11D/C11E)

Scope: ONE file, `functions/src/__tests__/conversations-rules.test.ts`.
`firestore.rules` unchanged (`git status --short firestore.rules` empty, re-verified
after the probe). Three tests added to close a stated gap: every prior update test built
`conversationDtoPayload(null)` with FIXTURE_CREATED_AT against fixtures seeded with the
same FIXTURE_CREATED_AT, so `createdAt` was never varied on the update path and
`participantIds` was never attacked there at all — the two keys BUT-1831's client defect
turned on.

Run: 87/87 pass. C11C, C11D, C11E all green by name.

Mutation probe (env-var seam, mutant copy in scratchpad, real file byte-identical
throughout): drop `'participantIds', 'createdAt'` from the conversations update
`.hasAny([...])` deny-list -> 85/87, reddening EXACTLY C11C and C11D; C11E stays green.
So both denies are attributable to the deny-list and the ALLOW control is not a
by-product of it. First mutator attempt produced `[memberSince, groupId]` — bash ate the
single quotes inside a `node -e '...'` string, yielding undefined CEL identifiers, i.e. a
deny-everything mutant that would have "reddened" plenty and proved nothing. Caught by
diffing the mutant; write the mutator to a heredoc FILE, and diff before running.

Fixture isolation (asked, and load-bearing): a direct id is a pure function of its two
uids, so DIRECT_CONVO could only be safe if no other fixture names the same pair. Grepped
every `conversations/` path in the file: DIRECT_CONVO appears at exactly three sites (the
seed, C11D, C11E). Every other `directId()` call pairs STRANGER/MINOR/FRIEND/ADULT or a
`peer("cNN")` tag; neither `dm-init` nor `dm-recip` recurs, and both uids embed RUN. The
in-file comment records that the FIRST draft reused ADULT_UID/STRANGER_UID, collided with
`seedMessageFixtures`' MSG_DIRECT (seeded later in `run()`), and the overwrite made the
ALLOW control deny — verified as mechanism: MSG_DIRECT stores no `metadata` key, so the
control's `{creatorId: ...}` would resolve non-null == null and deny. Accurate.

C11E does control for C11D: same actor, same document, same merge-set, same `createdAt`,
same `metadata`; the ONLY difference is the array order, and `updatedAt` (not deny-listed,
not read by any conjunct). Single-variable. C11B is the equivalent control for C11C.

THREE FALSE SENTENCES FOUND AND STRUCK in the diff's own new/rewrapped comment text.
All three were claims about rules or Cloud Function behaviour, none was a code defect:

1. C7B: "a hand-rolled create carrying a real metadata map is allowed today and ends the
   window irreversibly (BUT-1830)". Refuted by C5 and C5B IN THE SAME FILE, both passing:
   `directIdBinds` requires `p.size() == 2` and an id derived from the pair, so a client
   cannot create a group conversation at any id. `firestore.rules` says so itself ("not
   merely bounded, it is unreachable"), and the same comment contradicts it four
   paragraphs later ("refused by the presence requirement ... binds a tampered one too").
   The diff had also deleted the sentence that gave "the window" its antecedent, so the
   phrase dangled.
2. C7B: the `enforceGroupMinorMembership` harm paragraph — "trips BOTH halves of the
   trigger's guard (`isGroup: false` AND a single participant)" and "`onDocumentCreated`
   cannot fire twice". The live function is `onDocumentWritten` on `chat_groups/{groupId}`
   with neither guard; its own file header calls the `onDocumentCreated` trigger on
   `conversations/{id}` the OLD one, in the past tense. Present-tense claim about a live
   symbol that has not behaved that way since BUT-1838.
3. C11C: "the one deny-listed key this section never moved". The deny-list holds four keys
   and, pre-diff, the BUT-1788 section moved NONE of them — `participantIds` least of all,
   since it is the second key this very commit adds a test for (C11D, eight lines below).
   The same sentence's "nothing in the file varied `createdAt` at all" is an unscoped
   quantifier falsified by `convBody`'s `createdAt: new Date()` on the create path.

All three struck rather than reworded: a truer count would have needed measuring, and
(2) would have needed a new claim about what the OLD trigger did, sourced from git
history. Re-ran after the edits: 87/87.

Verdict: PASS, 0 blocking (the three defects were fixed in this run, not left open).

---

## 2026-08-22 — BUT-1831 re-verify: `firestore.rules` comment-only diff (conversations)

Second pass on the same ticket, this time with `firestore.rules` in the diff. Nine lines,
all comment, in two hunks: the `allow create` limb of `match /conversations/{conversationId}`
and the `participants` roster read-rule comment. Both struck sentences named
`MessageMutationModule`'s deleted fallback in the present tense.

**Inertness, proven two ways** (the principle held, no change needed): `grep -c '://'` = 0,
so `//`-stripping is safe; comment-stripped + blank-stripped + CR-stripped HEAD vs worktree
gave md5 `9442377d4eb0e38b260852f067f3ca39` on both sides over 1380 surviving code lines,
and `git diff -U0 | grep '^[+-]' | grep -v '^[+-][[:space:]]*//'` came back empty. Index
matched HEAD (` M`), so HEAD→worktree is the whole shippable change.

**The replacement text judged.** "A create carrying `metadata: null` denies here, and test
C7B pins it. The assertion rests on a TAMPERED client: BUT-1831 deleted the app's only
writer of that shape, so no shipped code sends it any more."
- Deny is real: the conjunct is a bare `request.resource.data.metadata.creatorId ==
  request.auth.uid`, and `.creatorId` on null is a CEL error.
- "C7B pins it" is attributable, not vacuous: C7B's fixture uses `directId(STRANGER_UID,
  peer("c7b"))`, so `directIdBinds` passes and the metadata conjunct is the failing one;
  C7 is its single-variable ALLOW control. The recorded probe (delete the conjunct → C6,
  C6B, C7B redden) agrees.
- It does NOT re-introduce the sentence I struck last run ("a hand-rolled create carrying a
  real metadata map is allowed today"). It makes no claim about what a tampered create is
  ALLOWED to do — only about who can still emit the denied shape.
- The fallback really is gone: `message_mutation_module.dart` now throws
  `ResourceNotFoundException` on `conversation == null`.

**The one soft spot, and the new principle.** "the app's only writer of that shape" is a
quantifier over writers, so I measured it — four `ConversationDto.toFirestore` call sites:
`conversation_mutation_module.dart:111` (create, ships `metadata: {'creatorId': user1Id}`),
`firebase_messaging_repository.dart:101` (base-class override, path-rewritten by
`UserScopedFirebaseRepository` to `users/{uid}/conversations/{id}`, a different rule block),
a doc comment, and `message_mutation_module.dart:140` — a `set(..., SetOptions(merge: true))`
which is an UPDATE only while the document exists. Firestore evaluates a merge-set against
an ABSENT document as a CREATE, so a read-then-delete race still routes shipped code into
the create rule with `metadata` = whatever was stored (null on a legacy pre-BUT-1830 row;
`chat-group-writes.ts:154` stamps a map on every group conversation, and the create rule
forces one on every new direct, so live nulls are legacy-only). Doubly conditional, fails
closed, and identical in substance to the wording already accepted in the test file's own
C7B comment last run — reported as an observation, not a block. Generalised into
"Proving a deny test is not vacuous" in the knowledge file: a merge-set is a create when
the doc is absent, so "no shipped code sends X on create" must enumerate merge-sets too.

**The orphaned paragraph.** With its "Still true:" lead-in struck, the roster block's
"NOT still true, and corrected above on the same day: that the create and update rules must
keep DIFFERENT null-metadata spellings…" stands alone and reads correctly; "corrected above"
resolves to the create-limb `CORRECTED 2026-08-13` paragraph, and "the same day" to the
2026-08-13 dates in the paragraph immediately above it. Ragged line wrap only.

**Run:** `npm run test:rules:conversations` → 87/87, reproducing the founder's figure.

**Deferral confirmed as correct.** The update rule's `request.auth.uid in
resource.data.participantIds`, plus `allow read` and `allow delete` on the conversation
document, still have no deny test anywhere (every C8–C14/U1–U6 actor is a participant; no
test reads or deletes a conversation document). Pre-existing, untouched by a comment-only
diff, and the ticket needs allow controls built alongside the denies — `read` and `delete`
have neither today.

Verdict: PASS, 0 blocking.

## 2026-08-22 — BUT-1831 third pass: the rewritten create-limb comment, and its un-swept twin

Same ticket, same file, now STAGED. The soft spot from the previous entry ("BUT-1831 deleted
the app's **only** writer of that shape") has been rewritten; my recorded coverage was against
the pre-rewrite bytes, hence a third pass.

**Inertness, re-proven at the staged bytes.** `git show HEAD:firestore.rules` vs
`git show :firestore.rules`, both CR-stripped, `//`-stripped and blank-stripped: md5
`6cf1210c689e2c7143c3cf21104a2369` on both sides over 1380 surviving lines. `grep -c '://'`
= 0 on the index copy, so the naive strip is sound. `git diff --cached -U0 | grep '^[+-]' |
grep -v '^[+-][[:space:]]*//'` returned nothing. Twelve changed lines, all comment, two hunks.

**The replacement text judged: accurate, and not an overcorrection.** It now reads "…the
assertion mainly binds a tampered client now — but do not read it as unreachable by shipped
code: a `merge: true` set is a CREATE when the document is absent, so any merge-set carrying
a null metadata still arrives at this limb. It fails closed either way."
- The mechanism is real and reachable at the current bytes:
  `MessageMutationModule.sendMessage` step 2 merge-sets the WHOLE conversation document
  (`ConversationDto.toFirestore(updatedConversation)`, `SetOptions(merge: true)`), and
  `toFirestore` emits `'metadata': conversation.metadata` unconditionally with
  `Map<String, dynamic>?` nullable — so a conversation stored with a null metadata (the very
  population BUT-1788's `is map` ternary exists for) yields a payload carrying `metadata:
  null`. If the document is deleted between the module's existence read and the batch commit,
  that merge-set lands on `allow create` and is denied. The module's own new comment names
  that race ("the other party deleting the thread while this one is open").
- It states a RULE (merge-set-is-a-create) rather than naming one call site, so it does not
  rot when the call site moves. No count, no "only", no line number, no suite total — nothing
  that would need re-measuring. Hedged with "mainly", which is the honest quantifier.
- `conversation_mutation_module.dart`'s merge-set is the harmless twin: it ships
  `metadata: {'creatorId': user1Id}`, so it satisfies the limb rather than tripping it. The
  comment correctly does not claim otherwise.

**The finding this round: the same claim survived in the TEST file.** C7B's comment in
`functions/src/__tests__/conversations-rules.test.ts` is NEW text in this staged diff and
says "It no longer stops OUR client, because our client no longer sends it… The assertion
stands on the tampered-client case alone, which is why it is not weakened by that deletion."
That is the struck sentence's claim, verbatim in substance, in the file that pins the rule.
Reported as non-blocking (a comment, not logic — same severity call as the rules-side
sentence last round) with a STRIKE, not a rewrite: a truer version would have to re-measure
the merge-set population, and the corrected explanation already lives at the rules limb.
Generalised into the knowledge file: a reachability claim about a rule lives in TWO files,
and a finding filed against one is half-fixed until the other is swept.

**The orphaned paragraph, re-checked at the staged bytes.** "NOT still true, and corrected
above on the same day: that the create and update rules must keep DIFFERENT null-metadata
spellings…" stands alone correctly; "corrected above" resolves to the create-limb
`CORRECTED 2026-08-13` block in the same match. Ragged wrap only, no dangling referent.

**Run:** `npm run test:rules:conversations` → 87/87, unchanged.

**Gap carried, not re-filed:** no non-participant deny on the conversations `update`/`read`/
`delete` rules — six tests, not three, since `read` and `delete` have no ALLOW controls
either. On BUT-1831 as follow-up #4.

Verdict: PASS, 0 blocking.

---

## 2026-08-22 — BUT-1831, coverage re-read #3: the twinned claim, resolved by strike-and-point

**Scope.** Staged diff, `firestore.rules` + `functions/src/__tests__/conversations-rules.test.ts`.
Both opened with Read in full. Re-review of my own prior finding after it was actioned.

**Retired verbatim from the knowledge file** (superseded in place by the bullet quoting this
entry; kept here because the archive is the audit trail):

> **A reachability claim about a rule usually exists in TWO files — the rules comment and the
> pinning test's comment — so a finding filed against one is only half-fixed until the other
> is swept: BUT-1831's rules-side sentence was struck while the identical claim rode into the
> same commit at test C7B.** Grep the test file for the claim's keywords whenever a rules
> comment is corrected, and the reverse.

**What was actioned.** C7B's comment now reads: "BUT-1831 deleted the `MessageMutationModule`
fallback that built a creator-less `Conversation` with no metadata and staged a top-level
create. The corrected account of who can still reach this limb lives at the rule itself; do
not restate it here, where nothing keeps the copy honest." Struck, not reworded: both
sentences I flagged ("It no longer stops OUR client, because our client no longer sends it";
"The assertion stands on the tampered-client case alone…") are gone.

**Judgment 1 — new unmeasured claims?** None. Three claims, each directly readable from the
staged Dart diff, none requiring a count:
- "BUT-1831 deleted the `MessageMutationModule` fallback" — the whole `if (conversation ==
  null) { … conversation = Conversation(…) }` block is removed in
  `lib/repositories/firebase/modules/message_mutation_module.dart`.
- "creator-less … with no metadata" — the deleted constructor call passes id,
  participantIds, participantDisplayNames, participantAvatarUrls, lastReadTimestamps,
  isGroup, createdAt, updatedAt. No `metadata:` argument, and the deleted comment beside it
  said so explicitly ("DO NOT give this conversation a `metadata.creatorId`").
- "staged a top-level create" — the fabricated conversation flowed into the atomic batch's
  merge-set on `conversations/{id}`, which is a CREATE when the document is absent, i.e.
  exactly C7B's case.

This also resolves the cloud-functions gate's Low on the same paragraph without inheriting
it: the old text rendered the deleted code as `Conversation(participantIds: [senderId],
isGroup: false)`, which was only the branch where the id fails to split (the real list was
`[message.senderId, ?otherUserId]`). "Creator-less" drops the spelling entirely rather than
correcting it — the right move, since the correct spelling was a thing you had to read the
deleted code to write, and it would rot the moment anyone described the branch differently.

**Judgment 2 — does the pointer resolve?** YES, and this is the part worth generalising. The
account is at the `allow create` limb of `match /conversations/{conversationId}` (immediately
above `request.resource.data.metadata.creatorId == request.auth.uid`, inside the create
statement that runs lines 1592–1623 at these bytes — cited by match pattern, not line):
"A create carrying `metadata: null` denies here, and test C7B pins it. BUT-1831 deleted the
branch that sent that shape deliberately, so the assertion mainly binds a tampered client
now — but do not read it as unreachable by shipped code: a `merge: true` set is a CREATE when
the document is absent, so any merge-set carrying a null metadata still arrives at this limb.
It fails closed either way."

Re-checked that this is still true after the Dart deletion, since the deletion is what could
have hollowed it: `conversation_mutation_module.dart:107-113`
(`createDirectConversation`) still merge-sets the conversation after a swallowed
existence-read, but ships `metadata: {'creatorId': user1Id}` — the harmless twin, satisfying
the limb rather than tripping it. The rules comment does not claim a specific live null-
metadata caller; it states the merge-set RULE and refuses to assert unreachability, which is
the safe direction and needs no re-measuring. Hedge "mainly" is the honest quantifier.

**Judgment 3 — rules unchanged since the last pass.** Proven two independent ways rather than
eyeballed, per the probe-mechanics principle and the 2026-08-22 parallel-session lesson (a
reverted file also shows as `M `):
- Comment-only: `git show HEAD:firestore.rules` vs `git show :firestore.rules`, CR stripped,
  `//` comments and blank lines removed → **1380 surviving lines on both sides, md5
  `9442377d4eb0e38b260852f067f3ca39` on both**. Grep for `://` first returned nothing, so no
  URL inside a string literal was eaten by the comment strip.
- Line filter: `git diff --cached -U0 | grep '^[+-]' | grep -v '^[+-][[:space:]]*//'` → empty.
- Worktree == index (`git diff --stat` on both files → empty), and the two corrected
  passages were confirmed BY CONTENT during the Read, not inferred from the status letter.
The staged rules diff is exactly the two comment hunks I passed last round: nothing touched
it this round.

**Run.** `npm run test:rules:conversations` → **87/87 passed**, zero failures. 87 `test("`
declarations in the file, so nothing was skipped; the three BUT-1831 tests (C11C re-stamped
createdAt deny, C11D reversed participantIds deny, C11E its single-variable ALLOW control)
are among them and green.

**Durable rule extracted.** The sweep of a twinned claim is a STRIKE-AND-POINT, not a matching
correction written into both files. Correcting both is what created the twin in the first
place: two copies of one measured fact, each free to rot separately, and the second copy is
the one nobody re-checks. The repair keeps ONE canonical site (the rule, where the code that
falsifies it lives) and makes the other a pointer that carries no claim. The pointer itself
needs verifying — open the named limb and confirm it actually carries the account — or a
false claim has merely become a dangling one.

**Gap carried, not re-filed (third time):** no non-participant deny on the conversations
`update`/`read`/`delete` rules — six tests, not three, since `read` and `delete` have no
ALLOW controls either. On BUT-1831 as follow-up #4. Pre-existing, out of this diff's scope.

Verdict: PASS, 0 blocking.

---

## 2026-08-26 — BUT-1904: the `duplicateBlocked` freeze on the messages sender update

**Diff.** One conjunct on the `match /messages/{messageId}` sender `allow update`:
`&& resource.data.get('type', 'text') != 'duplicateBlocked'`, plus an eight-line comment.
`guardDuplicateMessage` now empties a duplicate (`content: ""`) and stamps
`type: "duplicateBlocked"` in place instead of `tx.delete` (ADR-0009). Decision records read
first: `.claude/rules/accepted-deviations.md`, `docs/architecture/ACCEPTED_DEVIATIONS.md`,
`docs/org/adr/ADR-0009-the-duplicate-guard-marks-instead-of-deleting.md`.

**Three questions asked, all answered by measurement.**

1. *Does the OR'd receipts branch give a route to `content` or `type`?* No.
   `affectedKeys().hasOnly(['status','deliveredAt','readAt','updatedAt'])` is TOP-LEVEL and
   both fields are top-level, so a receipt payload carrying either drops out of the
   allow-list while the sender branch is already refusing the row. Pinned four ways
   (recipient+content, sender+content, recipient+type, and the receipt-only ALLOW that keeps
   the four denies from being vacuous). Receipt-only updates DO stay allowed on a blocked
   row, for the sender and for a recipient — the intended reading of the split.
2. *Is the `'text'` default right for legacy rows?* Yes, and it is load-bearing. The
   `default-blocked` mutant (`get('type', 'duplicateBlocked')`) reddens exactly ONE test —
   the no-`type`-field row. `MessageDto.toFirestore` has always written `type`, so the
   population is pre-DTO rows only, but the mutant shows nothing else guards them.
3. *Does anything else in the rules read `messages.type`?* No. `grep` finds two hits: this
   conjunct and an unrelated `activity_events` validator. The only cross-document read of a
   message anywhere in the file is `poll_votes`' `pollMessage()`, which reads `metadata`.

**Measured CEL behaviour of `resource.data.get('type','text') != 'duplicateBlocked'`** —
probe over six stored states, sender editing `content`: absent ALLOW, null ALLOW, number 42
ALLOW, map ALLOW, `'text'` ALLOW, `'duplicateBlocked'` DENY. A single `.get()` against a
literal answers in every state; the present-null CEL error that bites `a.get().get()` chains
(BUT-1788) does not reach it. Fail-open on every malformed shape, which is the right
direction here — an error would freeze an ordinary message on a field nobody validates.

**Deny attribution.** Every denial on this path prints the byte-identical string
(`evaluation error at L2111:24 ... false for 'update' @ L3241`) — a stranger editing an
ordinary message and the sender editing a blocked one are indistinguishable in the emulator
output. Confirmed by probe before trusting any deny. The existing single-variable ALLOW
control is what carries the attribution.

**Mutation probes** (three, each against a COPY in the scratchpad via new `PROBE_PROJECT_ID`
/ `PROBE_RULES_PATH` env hooks added to the suite; `firestore.rules` md5-verified unchanged,
diff still exactly the 9 added lines):

- `drop` the conjunct → 5 red (the freeze deny, the sender's receipt-smuggle, both unstamp
  cases, and the self-stamp case's second assertion).
- `default-blocked` → 1 red, the legacy no-`type` row. Sole guard.
- `request-side` (`resource.data.get` → `request.resource.data.get`) → 3 red, and **the
  three tests that shipped with the diff all survived it**. Their payload is `{content:...}`,
  which leaves the post-state `type` at `duplicateBlocked`, so the mutant still denies. Only
  a payload that MOVES `type` (`{type:'text'}`) tells pre-state from post-state. This is the
  durable rule extracted below.

**Tests added** — B4-B17 in `cook-snaps-and-message-mod-rules.test.ts`, taking it from 37 to
51. Receipts-branch allow + three smuggle denies; two unstamp denies; three defaulting-state
allows (absent / null / number); non-participant and unauthenticated denies; the deny half of
"sender can delete a blocked message"; and the two behaviour-as-it-is cases — a client may
stamp its OWN message `duplicateBlocked` (`type` is in neither `cannotModify` nor the create
rule) and may create one already stamped. Those two are pinned as they BEHAVE, so a later
ticket constraining `type` flips them rather than passing silently.

**Neighbours re-run after the tightening** (older deny tests on a tightened path go vacuous
silently): `test:rules:conversations` 87/87, `test:rules:poll-votes` 33/33. No suite outside
this one seeds a `duplicateBlocked` row, and the two integration suites that write the value
use the Admin SDK, which bypasses rules.

**Adjacent, not filed as findings.** `poll_votes` gates on `metadata.poll`, never on `type`,
so a row a client self-stamps stays votable after every client has stopped drawing it — inside
what the BUT-1832 accepted deviation already covers. And `conversations.lastMessage` is a
client-writable denormalised copy that now has one more value it can carry; that field's
update rule is the pre-existing hole BUT-1903's entry already names and tickets.

**Durable rule extracted.** A conjunct on `resource.data.<f>` is proven only by a payload that
MOVES `<f>`. Both spellings read as "the message's type" in English, so the pre-state/post-state
mixup is the likeliest wrong edit, and a suite whose denies all leave the field alone stays
green with the guard testing the attacker's own input instead of the stored document.

Verdict: PASS, 0 blocking.

---

## 2026-08-26 — BUT-1904 follow-up review: the two comment-only edits to `cook-snaps-and-message-mod-rules.test.ts`

**Diff reviewed** (staged, 4 files, 12 insertions): a two-line comment edit in my own suite,
a `grep -H` fix in `scripts/check_test_real_time.sh`, and two count strikes (a doc line and a
Dart test comment). `firestore.rules` NOT in the diff.

**Scope correction, measured first.** The task described TWO comment changes to my file. Only
ONE is staged. The other — striking "dismissing the notice is the one thing they are meant to
be able to do with it" from the delete case and the matching clause above B15 — landed in
commit `9cfecf1a5`, already in HEAD. Verified with `git show HEAD:<file>` and
`git show 9cfecf1a5 -- <file>`. A description of a diff is not the diff; measure the scope
before reviewing to it.

**Comment-only proven mechanically, not by eye.** Comment-stripped md5 identical HEAD vs
worktree (`b0dc103a086d64e7b232adeea90ba638`, 815 surviving lines both sides), and
`git diff --cached -U0 | grep '^[+-]' | grep -v '^[+-]\s*//'` empty. Coverage unchanged:
51/51 on my own run of `test:rules:cook-snaps-and-message-mod`, allow/deny pairs untouched.

**Blocking finding — the reachability sentence is broader than what was measured.** The
comment above "the sender can still delete a blocked message" reads: *"Says nothing about
dismissing the notice: no screen in the app reaches this delete (ADR-0009)."* The pointer
RESOLVES — ADR-0009 and the ACCEPTED_DEVIATIONS entry both carry the account, and the
mechanism is real: `MessageBubble.build` returns a `SystemMessageWidget` for
`type == duplicateBlocked` before the `GestureDetector` that installs `onLongPress`, so the
per-message action menu never opens for a blocked row (and `ChatActionHandler` has no `'menu'`
case anyway). But the measurement covers ONE affordance, while the sentence quantifies over
every screen. A second route reaches the same `allow delete` from the client:
`conversations_list_view.dart:430` -> `ConversationsViewModel.deleteConversation` ->
`MessagingService.deleteConversation` -> `deleteAllMessages`, which calls
`messagingRepository.deleteMessage(message.id)` for every row where
`senderId == currentUserId`. The blocked row is in that set:
`MessageQueryModule.searchMessages` filters with `content.toLowerCase().contains(lowerQuery)`
and an empty query matches an emptied row. So a screen DOES reach this delete — just not as a
per-row dismissal. ADR-0009's own bolded "**the sender cannot remove the row from inside the
app**" and the identical sentence in the ACCEPTED_DEVIATIONS entry are broad in exactly the
same way; those two are a decision record and an accepted deviation, so they are superseded
with a dated entry and surfaced to Malin, never silently edited.
Recommended repair in MY file: STRIKE the reachability clause and keep only the pointer — the
test pins that the RULE allows the delete and can pin nothing about screens; ADR-0009 is the
canonical site. Do not reword it to a narrower quantifier; the narrow version is another
sentence nobody re-measures.

**Second finding — a count strike that left an unmeasurable claim behind.** The staged hunk
replaces "was the fourth carrier of a sentence struck in three other files in the same commit"
with "was a further carrier of a sentence struck elsewhere in the same commit". The numeral is
gone, but the provenance claim survives and is not checkable from the repository: in
`9cfecf1a5` — the commit that struck the sentence here — the only two removals of it are BOTH
in this file (`git show 9cfecf1a5 | grep '^-' | grep -i dismiss` returns exactly those two).
In `ee372d3cf` the sentence was never struck at all; the corrected wording landed there
first-time in ACCEPTED_DEVIATIONS.md and ADR-0009 as parenthetical "*Corrected ... before this
landed*" notes, so the strike happened during authoring and left no git trace. "The same
commit" therefore resolves to a false reading and an unverifiable one. Softening a count to a
vague quantifier is a REWORD, not a strike: the whole provenance clause should go, leaving
"An earlier version of this comment claimed it did."

**Verified clean in the same pass.** The other three files' edits are honest strikes: "Both
are pre-existing consequences" -> "These are" (the numeral was falsified by a third consequence
added to the same paragraph), and "passed all 67 tests" -> "passed the whole suite". The
`grep -rEnH` fix is correct — GNU grep omits the filename when handed exactly one FILE, and
the awk baseline is keyed on `path:line:`, so a single staged `*_test.dart` made every
baselined occurrence report as an error down the `Binary file` branch, which is what the
error message then blamed. Noted, not filed: the Dart comment the diff touches still carries
"THE TWO PLACEMENT CASES" and "the three cases above" — same insertion seam, another agent's
file.

**Durable rule extracted.** A reachability claim is scoped to the AFFORDANCE it was measured
on. Before passing one, enumerate every client caller of the verb — a bulk path filters on the
ACTOR and never on the state the comment is about, so it is invisible to a measurement that
started from the feature's own screen.

Verdict: FAIL, 1 blocking.

**Re-review, same day.** Blocker closed correctly and by strike, not reword: the test comment
now reads only "Says nothing about DISMISSING the notice — this test pins what the RULE allows
and can pin nothing about screens. See ADR-0009." Both the reachability clause and the
provenance clause are gone. ADR-0009 and the ACCEPTED_DEVIATIONS entry each carry a dated
`Superseded 2026-08-26` block quoting the measured path, with the original text left standing —
the decision-record exception applied properly. The guard comment's branch attribution was
wrong in my first pass too and is now right: a filename-less line fails the `:[0-9]+:` parse at
the top of the awk body and takes the unreadable-file branch, so the baseline is never consulted
at all. Re-measured: `grep -rEn` on one file prints `70:       createdAt = ...` and `-H` prints
the path — the comment's own example line reproduces byte-for-byte. Suite 51/51 on my own run,
comment-stripped md5 still identical to HEAD.
**The one thing outstanding is mechanical: the repairs were in the WORKTREE and not in the
INDEX.** `git status` showed `MM` on all four files, and `git diff --cached` still carried both
false sentences — committing at that moment would have shipped exactly what the round removed.
A worktree fix that never reached the index is indistinguishable from one that did if you read
only the file. Re-read the STAGED diff, never the file, when a coordinator reports a fix.

**Fifth carrier, and a count of my own retired.** `firestore.rules` itself carried the claim,
directly above the `messages` sender `allow update`: "though no screen in the app currently
reaches that delete, for a reason unrelated to this rule (ADR-0009)". Struck to "Deleting a
blocked row stays allowed below." — which is readable from the `allow delete` two statements
down and claims nothing a rules comment cannot know. Found by the `cloud-functions-specialist`
gate, not by me: my own sweep grepped the string "no screen in the app reaches" and this copy
said "reaches that delete", so the phrasing shift hid it. Grep the CLAIM, not a sentence.
Retired verbatim from the knowledge file, superseded in place because this round falsified its
count: *"A reachability claim about a rule usually exists in TWO files — the rules comment and
the pinning test's comment — so a finding filed against one is only half-fixed until the other
is swept: BUT-1831's rules-side sentence was struck while the identical claim rode into the
same commit at test C7B."* BUT-1904 had carriers in the rules file, the rules test, ADR-0009,
`docs/architecture/ACCEPTED_DEVIATIONS.md`, `.claude/rules/accepted-deviations.md` and
`message_bubble.dart` — "two" was wrong, and the replacement states no number.
Rules diff verified comment-only two ways (comment-stripped md5 identical across HEAD and the
staged blob, 1381 surviving lines; no non-comment changed lines; the file contains no `://`, so
the strip is not vacuous). Sender update conjunct, receipts `hasOnly` and `allow delete` all
byte-identical. Suite: exit 0, 51 PASS, 0 FAIL.

**Final pass, same day — PASS, 0 blocking.** Re-verified after `testing-specialist` struck the
numeral in my MESSAGES section header ("the branches the three cases above do not reach" -> "the
branches the cases above do not reach"). Both files re-proven against the INDEX blob, not the
worktree file: `firestore.rules` at `6c2e707b`, comment-stripped md5 `829b56f5…` identical to
HEAD's blob at 1381 surviving lines, no `://` anywhere so the strip is not vacuous; the suite at
`e799b3c2`, 816 surviving lines identical to HEAD under a strip written to PRESERVE its one
`https://example.com` literal (the naive `s://.*::` recipe would have eaten it). No changed line
in either file is a non-`//` line. `duplicateBlocked` conjunct, receipts `hasOnly` and `allow
delete` byte-identical. Suite exit 0, 51/51. Registration intact (41 rules suites, 2 `paths:`
blocks). Scope re-measured at verdict time and it HAD moved — 418 -> 447 insertions while I read,
all of it `cloud-functions-specialist.knowledge.archive.md` appending its own entry; same 15
files, my two untouched.

**Non-blocking finding, and it is a new shape of the same disease.** The strike-and-point repair
is correct and the pointer resolves — ADR-0009 carries the account — but the ACCOUNT AT THE
TARGET names the wrong symbol: "since `ChatActionHandler` has no `'menu'` case". It has one, at
`chat_action_handler.dart:177`, inside `handleAttachment` (the weekly-menu SHARE). The switch
that is actually dead is `handleMessageAction`, whose cases are reply/edit/delete/copy/report;
`chat_message_stream.dart:383` dispatches `onMessageAction(message, 'menu')` through
`chat_view_facade.dart:114` into it, hits `default:` and logs "Unknown message action". So the
CONCLUSION is true and the SYMBOL is false — a future reader greps the named class, finds the
case, and concludes the ADR is wrong about a live affordance. Fix is one word, in place, no
measurement: `ChatActionHandler` -> `handleMessageAction`. Not blocking because the sentence sits
in a parenthetical already superseded below it, and the live text ("that menu is dead for every
message type anyway") is true and independently pinned. The same imprecision is in MY archive
entry above, which is where the ADR's wording came from — append-only, so it stays as the record
of how it propagated. Verified in the same pass: `deleteAllMessages` has no caller in `lib/`
besides `deleteConversation`, and no `leaveGroup` on any of the five paths touches messages, so
the superseding block's live claims hold.

Durable rule, merged into the pointer clause rather than added as a bullet: verifying a pointer
RESOLVES is not enough — read the SYMBOL the account names. The account can be right about
behaviour and wrong about which function has it.

**CLOSED, same day — the non-blocking finding above is fixed; do not read that entry as open.**
ADR-0009 now names `handleMessageAction`, with a parenthetical recording that `ChatActionHandler`
DOES carry a `'menu'` case in `handleAttachment` (the weekly-menu share) so a reader greping the
class is not sent to a live affordance. The `code-reviewer` gate corrected a second symbol in the
same paragraph on its own: the reached method is `MessageManagementOperations.deleteAllMessages`,
not the `MessagingService` facade — which has no caller of its own, so the qualified name is the
one that resolves.

One further comment-only edit to my suite after that: B4's "the allow half that makes the FOUR
denies below mean something" -> "the denies below". Verified the strike was warranted rather than
cosmetic — 9 `assertFails` calls sit below B4 (8 deny-named tests, B5–B9 and B13–B15, plus B16's
trailing deny), or 3 scoped to the receipts route B4 is the allow half of (B5, B6, B9). Wrong
under both readings, and "eight" would have carried the identical insertion seam, so no numeral
replaced it. Re-proven against the NEW index blob `8175e8eb`: no changed line is a non-`//` line
across all three hunks, and the comment-stripped md5 is still `4defc1b8…` at 816 lines — the same
value measured before the edit, so test logic is unmoved. `firestore.rules` still `6c2e707b`,
stripped md5 `829b56f5…` at 1381 lines, conjunct read back verbatim from the index blob. 51/51,
exit 0.

Method note worth keeping: every proof in this round was taken from `git show :<path>`, never the
worktree file. The scope moved three times while I read (418 -> 484 -> 642 insertions, always the
same 15 files, twice by other gates appending archives and once by me). Re-stat at verdict time.

## 2026-08-27 — `weekly-menu-plans-rules.test.ts` adversarial non-vacuity review (BUT-1961 follow-up)

New suite, 9 cases (W1-W6 `weekly_menu_plans`, G1-G3 `group_weekly_menu_plans`);
`firestore.rules` unchanged in the commit. Reproduced every claim independently with
env-var probes against mutated COPIES of the rules file (real file md5-verified identical
before and after: `6cdc26dac450938ddf169a3b19dfbf55`).

Probe harness note: the suite does NOT ship `PROBE_RULES_PATH`/`PROBE_PROJECT_ID` seams,
so probing required generating a temp copy of the TEST file under
`functions/src/__tests__/__probe-<label>.test.ts` with two `sed` substitutions
(project id -> `probe-<label>-$RANDOM`, `RULES_PATH` -> `process.env.PROBE_RULES_PATH ??
path.resolve(...)`), deleted via `trap ... EXIT INT TERM`. Writing the env read as a bare
`as string` instead of `??` re-triggered the known TS6133 (`'path' declared but never
read`) — `noUnusedLocals` aborts ts-node and the exit code reads like a red assertion.

Probe results (baseline 9/9 on a fresh project id):
- M1 `cannotModify(['userId','createdAt'])` -> `(['userId'])`: exactly W2 reddens.
- M2 group `cannotModify(['groupId','createdAt'])` -> `(['groupId'])`: exactly G1 reddens.
  (Both confirm the file header's own probe claim.)
- M3 -> `cannotModify(['createdAt'])` (drop `userId`): NOTHING reddens. `userId` is
  masked by `uid == resource.data.userId && uid == request.resource.data.userId`; W4
  guards the pair, not the immutability key.
- M4 group update permission `in ['edit','admin']` -> `in ['view','edit','admin']`:
  exactly G3 reddens. G3 is single-conjunct attributable, and `view` is a real wire value
  (`GroupMenuParticipant.toMap` writes `permission.name` from `SharedListPermission`).
- M5 -> `in ['admin']`: NOTHING reddens. The `edit` grant — the whole point of a
  collaborative plan — has no test.
- M6 weekly `allow read` prefix conjunct -> `false`: NOTHING reddens. W6 (stranger deny)
  has no owner-read ALLOW control, so it would survive `allow read: if false`.
- M7 `allow create: if false`: W1 reddens, so W1 does exercise CREATE today — but only on
  a fresh emulator project. The suite has no `clearFirestore()` and W1's id
  (`wmp-owner-uid_2026-W19`) has no per-run token, so a second local run on a live
  emulator silently turns W1 into an UPDATE (which the rules also allow) and M7 would stop
  reddening. CI is unaffected.
- M8 weekly update prefix conjunct -> `true`: NOTHING reddens. W5 is over-determined —
  the stranger's payload carries `userId: OWNER_UID`, so
  `uid == request.resource.data.userId` denies independently. W5's comment clause "even
  though the body would otherwise be valid for them" is refuted by this probe; blocking
  finding, fix by striking the clause and/or moving W5 to a CREATE at an unwritten
  `OWNER_UID_2026-W20` carrying `userId: STRANGER_UID`, which isolates the prefix conjunct
  exactly and also covers the create limb for a stranger.

Registration verified mechanically: `node scripts/check-test-registration.js` -> OK,
42 rules suites across both `paths:` blocks; `test:rules:weekly-menu-plans` present and
in the `test:rules:all` chain.

Uncovered branches recorded for follow-up: weekly owner READ allow, weekly DELETE limb
(all four actors), weekly stranger CREATE, group CREATE limb entirely (incl. its
`hasRequiredFields`), group READ (member allow + non-member deny), group DELETE
(admin-only), the group `edit` permission grant, and the admin-only membership-change
branch (`affectedKeys().hasAny(['participants','participantUserIds','memberPermissions'])`
with a non-admin editor).

---

## 2026-08-27 — `weekly-menu-plans-rules.test.ts` re-review (BUT-1961 follow-up)

Second pass over the reworked suite. 13/13 green on the real `firestore.rules`
(byte-identical md5 before and after every probe). Probed with a sed-generated copy of the
suite (`zz-probe-wmp.test.ts`, deleted in the same Bash call) because this suite, unlike
`chat-groups`/`conversations`/`poll-votes`/`cook-snaps`, ships no
`PROBE_PROJECT_ID`/`PROBE_RULES_PATH` hooks.

Mutants, each a single-line diff against the real file, each run under its own project id:

| Mutant | Edit | Reddens |
|---|---|---|
| M5  | group update `in ['edit','admin']` -> `== 'admin'` | G4 only |
| M6  | personal `allow read` -> `if false` | W6 only |
| M8  | personal `allow create` prefix conjunct dropped | W5 only |
| M9  | group `allow read` -> `if false` | G5 only |
| M12 | personal `cannotModify(['userId','createdAt'])` -> `(['userId'])` | W2 only |
| M13 | group `cannotModify(['groupId','createdAt'])` -> `(['groupId'])` | G1 only |
| M14 | group `allow read` -> `if isAuthenticated()` | G6 only |
| M15 | personal `allow read` -> `if isAuthenticated()` | W7 only |
| M4B | personal `cannotModify` loses `'userId'` | NOTHING (13/13) |
| M10 | personal `allow update` prefix conjunct dropped | NOTHING (13/13) |
| M11 | group `allow update` membership conjunct dropped | NOTHING (13/13) |

So the previous round's B1 (W5's false attribution) is genuinely closed — and closed by
rebuilding the test, not by striking the clause. W5 is now a stranger CREATE at an unwritten
id carrying the stranger's own `userId`, so only the doc-id prefix can deny, and M8 proves
it. W6/W7 and G5/G6 are true single-variable ALLOW/DENY couples (same doc, same payload,
actor the only difference), and M14/M15 prove each DENY fires on the conjunct it names
rather than on anything upstream. G3/G4 differ only in the stranger's permission value
(`view` vs `edit`); the payloads move only `entries` + `lastModifiedAt`, so the membership
branch of the update rule is not what decides them.

`clearFirestore()` in `setup()` runs before the first test (awaited in `run()`) and breaks
no fixture — every test seeds what it reads, and the two tests that depend on ABSENCE
(W1's create at `_2026-W19`, W5's at `_2026-W21`) are the ones it protects.

M4B confirms W4's corrected comment: `'userId'` in the personal `cannotModify` is dead,
masked by the two `uid == …userId` conjuncts (BUT-1967).

### The blocking finding this round

The rewritten header describes the fresh-`createdAt` hazard over BOTH `WeeklyMenuPlan.empty`
and `GroupWeeklyMenuPlan.empty`, then says "The constructor half is pinned in Dart, by
`weekly_menu_plan_test.dart`'s 'empty starts on a Monday with no entries (clock-pinned)'".
That test exists (`test/unit/models/menu/weekly_menu_plan_test.dart:136`) and does assert
`plan.createdAt == t` under `withClock` — for the PERSONAL constructor only.
`GroupWeeklyMenuPlan.empty` has exactly two tests
(`test/unit/models/menu/group_weekly_menu_plan_test.dart`, "seeds the creator as sole admin…"
and "uses the caller-supplied participant list verbatim"); neither is clock-pinned and
neither reads `createdAt`. So the constructor half is pinned for one of the two collections
the file covers, and G1's stated premise is unguarded.

Everything else in the header measured true: both `empty` factories stamp `clock.now()`
(`weekly_menu_plan.dart:221`, `group_weekly_menu_plan.dart:139`), both `copyWith` carry
`createdAt` through, both repositories write with a non-merge `.set`
(`firebase_weekly_menu_plan_repository.dart:131`,
`firebase_group_weekly_menu_plan_repository.dart:121`), and the "dropping `createdAt` from
either collection's `cannotModify` reddens exactly that collection's test" claim is M12/M13.

### New uncovered branches (not BUT-1966/1967/1968)

- Personal `allow update`'s doc-id prefix conjunct (M10) reddens nothing — masked by
  `uid == resource.data.userId`. Only reachable for an Admin-SDK-seeded doc whose id prefix
  disagrees with its `userId`. Same family as BUT-1967's dead `cannotModify` key.
- Group `allow update`'s `uid in resource.data.memberPermissions` conjunct (M11) reddens
  nothing — masked because the next conjunct indexes the same map and CEL-errors on a
  missing key. There is no non-member group WRITE deny test at all; G3 is a view-MEMBER.

### Superseded text, retired verbatim from the knowledge file

> Verify the pointer RESOLVES: open the
> named limb and confirm it carries the account, or you have replaced a false claim with a
> dangling one

## 2026-08-27 — `weekly-menu-plans-rules.test.ts`, third review round (BUT-1961)

Third gate pass on the same file. Prior rounds each found one false sentence in the
header paragraph; this round found none.

Re-run: 13/13 green against the real `firestore.rules`
(md5 `6cdc26dac450938ddf169a3b19dfbf55`, byte-identical before and after all probing).

Seven mutants, each a verified single-line edit, run through a `sed`-derived probe copy
of the suite (the file ships no `PROBE_*` env hooks):

| mutant | edit | red tests |
|---|---|---|
| m1 | personal `cannotModify(['userId','createdAt'])` -> `(['userId'])` | W2 only |
| m2 | group `cannotModify(['groupId','createdAt'])` -> `(['groupId'])` | G1 only |
| m3 | personal `cannotModify` -> `(['createdAt'])` | none (13/13) |
| m4 | personal `allow read: if false` | W6 only |
| m5 | group update `in ['edit','admin']` -> `== 'admin'` | G4 only |
| m6 | group `allow read: if false` | G5 only |
| m7 | personal create, prefix conjunct removed | W5 only |

m1/m2 confirm the header's "reddens exactly that collection's test and nothing else".
m3 confirms W4's own comment that `'userId'` is structurally unreachable in that list.
m4/m5/m6/m7 attribute each of the four cases added since the first review to one conjunct.

Header verified clause by clause against source: both `empty` factories stamp
`clock.now()` (`weekly_menu_plan.dart` 221/227, `group_weekly_menu_plan.dart` 139/155);
both `copyWith` preserve `createdAt` (309 / 219); both repositories' `save()` uses a
non-merge `.set` (`firebase_weekly_menu_plan_repository.dart:131`,
`firebase_group_weekly_menu_plan_repository.dart:121`) while
`removeRecipeFromAllPlans` does a partial `batch.update` on the same collection — which
is why the clause is now scoped to `save()`.

B2 (last round's blocker) is closed at the root, not by striking: the header's two named
Dart tests both exist and assert what the sentence says. `weekly_menu_plan_test.dart`
"empty starts on a Monday with no entries (clock-pinned)" asserts `plan.createdAt == t`
under `withClock(Clock.fixed(t))`; `group_weekly_menu_plan_test.dart` "stamps a FRESH
createdAt from the clock" does the same for the group factory. `git show HEAD:` on the
group test confirms it had no `clock` import and no `empty`-createdAt assertion before
today, so "the group one was added 2026-08-27 — until then that half was unguarded" is
true. `git diff --cached` shows 23 insertions, that test.

Two new probe mechanics learned, merged into the principles file:
- an uppercase letter in a probe project id makes the run emit NO test lines, which is
  indistinguishable from green when grepping for `FAIL`;
- `resource\.data\.` matches the tail of `request.resource.data.`, so a pre-state mutant
  silently counts the create limb — anchor on `&& resource.data`, and slice the rules
  text by `match /<collection>` when the shape is shared repo-wide.

Registration verified: `test:rules:weekly-menu-plans`, the `test:rules:all` chain, and
both `paths:` blocks of the workflow; `check-test-registration.js` returns OK.

Verdict: pass, 0 blocking. The two coverage gaps (group non-member update deny; the dead
personal update prefix conjunct) stay filed as BUT-1969.

## 2026-08-27 — superseded in place (BUT-1961 follow-up, round 4)

Retired verbatim from `firestore-rules-tester.knowledge.md`, struck because the commit that
carried the round-2 finding also closed it — the group constructor gained a clock-pinned test
in the same change, so the measurement below stopped being true before it was committed:

> the group `empty` has two tests, neither clock-pinned nor touching `createdAt` (measured
> 2026-08-27).

The principle it illustrated ("Resolve a pointer per symbol, or you have replaced a false
claim with a dangling one") survives without it, and the full worked example is preserved in
the round-2 entry above. Found by the `integration-reviewer` gate as the fourth
assert/deny pair in one commit — this one inside an auto-loading knowledge file, i.e. the
Step-0 read for the gate that would next audit that suite.

## 2026-08-29 — BUT-1971, `group_weekly_menu_plans` read limb: `resource` is null on an absent doc

Reviewed the staged fix `allow read: if isAuthenticated() && (resource == null ||
request.auth.uid in resource.data.memberPermissions)` plus its one new test, G7. Suite
14/14 green on the emulator.

**Confirmed for the author, all three questions.**

1. *Can the null arm widen anything beyond existence?* No. `resource == null` holds only
   when the document does not exist, so there is no content to disclose, and the arm is
   FIRST in the `||` so it short-circuits before any dereference. It does not reach `list`
   (a candidate doc in a query always exists, so the membership arm still decides, and an
   unconstrained collection query stays unprovable), and it does not reach create/update/
   delete, which read `request.resource` or an existing `resource`. One sharpening: the
   oracle runs in BOTH directions, not just the direction the comment illustrates — allow
   implies absent, deny implies present-and-caller-not-a-member — so a signed-in user who
   knows a conversation id can enumerate which weeks that conversation has plans for. Still
   exactly EXISTENCE, which is what the deviation says; the example sentence is narrower
   than the leading claim, not false.

2. *Write limbs untouched?* Yes, byte-verified against the staged diff: one hunk, the read
   limb and its comment. The rules test file gains only G7.

3. *The sweep — other read limbs with the same shape.* ~25 of them. The shape alone is not
   the finding; the discriminator is whether the CLIENT DERIVES the doc id and READS BEFORE
   CREATING. Collections reached by query (`cook_snaps`, `activity_events`,
   `recipe_comments`, `social_requests`, `shared_content`, `menus`, the six
   `{path=**}` collection-group limbs) are unaffected by construction. Path-gated reads
   (`weekly_menu_plans`, `user_notification_preferences`, `report_throttle`,
   `canonical_rating_events`) never touch `resource`. That leaves the deterministic-id
   collections, and one of those is a live instance:

   - **`conversations`** — `allow read: if isAuthenticated() && request.auth.uid in
     resource.data.participantIds`, and `ConversationMutationModule` does a get-before-create
     on `conversations/direct_<sorted a>_<sorted b>` to see whether the DM already exists. For
     a brand-new pair that read is DENIED, not empty. It does not surface because the probe
     sits in its own `try/catch` whose handler logs "No existing conversation found, creating
     new one" — the denial is indistinguishable from absence, by construction. Filed, not
     blocking: the outcome is correct today and the fix is a rules change with its own ticket.
   - `blocks/{blocker}_{blocked}` and `user_fcm_tokens/{userId}_{deviceId}` are the same
     shape with no confirmed read-before-write caller.
   - `realtime_recipes` / `realtime_menus` are worth noting for contrast: their SUBCOLLECTION
     helper `isRealtimeParticipant` is null-guarded (`get()` then `parentDoc != null`) while
     the parent's own read limb is not — the guard for this exact hazard already exists one
     line away, in the same block.
   - `poll_votes` is the shipped precedent for the fixed behaviour: its read limb tests the
     parent message and never `resource`, so an absent vote row already reads as absent.

**Adjacent, pre-existing, NOT introduced by this diff, and reported to the author:** the
`group_weekly_menu_plans` create limb binds `planId` to the caller's OWN submitted `groupId`
and requires the caller in their OWN submitted `memberPermissions`, with no check against the
conversation. Any signed-in user can therefore create `<anyConversationId>_<week>` seating
themselves as admin, which the real members then cannot read, update or delete. The read fix
does not create this, but it turns blind squatting into targeted squatting by supplying the
"which weeks are unplanned" oracle. No test covers it — the file's create coverage is G1–G4,
all on a seeded doc the actor already belongs to.

A false lead worth recording: `Grep` rendered several `//` comment openers in
`conversation_mutation_module.dart` as a bare backslash, which reads exactly like the
control-byte corruption of BUT-1901. `Read` on the same lines shows ordinary `//`. It was
the tool's output escaping, not the file — check with `Read` before filing a text-integrity
finding from a grep excerpt.

Verdict: pass, 0 blocking.

## 2026-08-29 — BUT-1971 re-review of the staged `group_weekly_menu_plans` read limb

Re-read the staged bytes of `firestore.rules` and
`functions/src/__tests__/weekly-menu-plans-rules.test.ts` after three comment/actor
changes landed on top of the earlier pass.

Verified against the staged bytes:
- Oracle direction now stated correctly in BOTH comments: ALLOW ⇒ `resource == null` ⇒ the
  week is unplanned, so a DENY ⇒ a plan EXISTS. Confirmed the id chain that makes it
  reachable: `messaging_service.dart:1127` passes `groupId: conversation.id` into
  `GroupWeeklyMenuPlan.docIdFor`, and a DM conversation id is
  `direct_${sortedIds[0]}_${sortedIds[1]}` (`conversation_mutation_module.dart:59`), so two
  uids fully determine the doc id.
- App-reachability sentences are gone from both artefacts; what survives in the test file is
  an EXISTENCE claim about `GroupWeeklyMenuPlanService.readOrBuildWeek`, which resolves
  (`group_weekly_menu_plan_service.dart:102`).
- G7's actor is `STRANGER_UID`.

Runs (emulator 127.0.0.1:8080):
- `npm run test:rules:weekly-menu-plans` → 14/14 passed on the staged bytes.
- Mutant A, null arm removed (`&& request.auth.uid in resource.data.memberPermissions`):
  13/14, ONLY G7 red, verdict `Null value error ... for 'get'`. The "reddens THIS test
  alone" claim survives G7's actor change from OWNER to STRANGER.
- Mutant B, membership arm widened (`&& (resource == null || true)`): 13/14, ONLY G6 red,
  G7 green. Confirms G6 is the control against the arm buying more than existence.
Both mutants were scratchpad COPIES of the rules file; the probe test copies were deleted in
the same Bash call and `git status` shows the two staged files byte-unchanged.

Finding (non-blocking, comment accuracy): the rules comment reads "group ids are random, so
DM pairs are the guessable surface." Measured, group conversation ids have TWO mints —
`createChatGroupWithDeps` uses `groups.doc()` (auto-id, random) but `ensureCategoryChat`
supplies `categoryChatId(ownerId, categoryId) = sha256("ownerId:categoryId")[:20]`
(`functions/src/groups/ensure-category-chat.ts:85`), a DERIVED id, not a random one. The
safety conclusion still holds because `categoryId` is a v4 UUID
(`friend_categories_operations.dart:90`) an attacker does not hold, so the residual is not
understated. Recommended repair is a STRIKE of "group ids are random, so", leaving
"Content, membership and names stay closed; DM pairs are the guessable surface."

Sweep finding from the earlier pass (the live `conversations` null-`resource` shape masked by
`catch { AppLogger.debug('No existing conversation found, creating new one') }` in
`conversation_mutation_module.dart:78-80`, plus the unbound create limb) re-confirmed present
and untouched by this diff; both are carried on BUT-1971 as their own tickets.

New durable rules extracted into the principles file: (1) an "unguessable id" comment is a
claim about every minting path, and a collection usually has more than one; (2) a sed-derived
probe copy that substitutes `RULES_PATH` orphans the `path` import and dies on TS6133 before
any test runs, which greps like a green suite.

## 2026-08-29 — BUT-1971 re-confirm of the `group_weekly_menu_plans` read residual (round 5)

Staged diff: `firestore.rules`, comment lines only. Proven mechanically two ways, not by eye:
`git diff --cached -U0 | grep '^[+-]' | grep -v '^[+-][[:space:]]*//'` returns EMPTY, and the
comment-stripped, CR-stripped, blank-stripped md5 of `git show :firestore.rules` equals that of
`git show HEAD:firestore.rules` (`fb48930240371cbe9c7bda335670edeb`, 1382 surviving lines each,
so the comparison is visibly non-vacuous; `grep -c '://'` on the stripped file is 0, so the `//`
strip cannot have eaten a URL inside a string literal). `npm run test:rules:weekly-menu-plans`
= 14/14 passed.

The DM strike is CORRECT as far as the shipped client goes: `messaging_service.dart:910`
branches on `conversation?.isGroup`, sending non-group conversations to
`_appendWinnerToWeeklyPlanAndShare` (personal collection), and `_appendWinnerToGroupPlan` is the
only caller of `readOrBuildWeek`. Caveat worth knowing but NOT worth a sentence in the file:
`Conversation.isGroup` is documented at `conversation.dart:145` as "an ordinary client field"
(only `groupId` is server-written), so the routing is a client-side property, not a rules-level
one.

BLOCKING finding — the replacement paragraph is understated again, in the departure direction.
It says the oracle discloses to "a participant added to the chat AFTER the group's first plan
week". Measured: `_appendWinnerToGroupPlan` seeds `memberPermissions` from
`conversation.participantIds` AT BUILD TIME (messaging_service.dart:1108-1117) and
`readOrBuildWeek` returns a stored plan untouched, so membership is a snapshot per week. A
DEPARTED member is the mirror case and is not covered by the sentence: `removeChatGroupMember`
writes nothing to any plan document (grep of the file shows `Collections.groupWeeklyMenuPlans`
only inside `deleteGroupMenuPlans`), and `deleteGroupMenuPlans` is called from ONE place,
`deleteEmptyGroup` (line 397), i.e. only when the LAST member leaves. So for every week planned
after they left, an ex-member is absent from `memberPermissions`, still knows the deterministic
`{conversationId}_{ISO week}` id, and gets the same allow/deny existence oracle. Weeks planned
BEFORE they left are a different matter entirely — they are still in that document's
`memberPermissions` and simply read the plan.

Recommended repair, per the strike rule: DELETE the enumeration ("Who that discloses to is not
'any member' … probe week by week."). Writing a two-class version means measuring a second
population under a review that is reading it — the exact move that produced rounds 2-4. Keep
the direction sentence, "Content, membership and names stay closed.", and Malin's decision line
(a decision record, superseded but never silently deleted).

Not measured, offered as a question rather than a finding: the create limb requires only that
`planId` prefix-match the caller's OWN submitted `groupId`, so whether a failed create
distinguishes ALREADY_EXISTS from PERMISSION_DENIED — a second, write-side existence oracle for
a non-member who holds the id — was not probed this run.

Durable rule extracted into the principles file: naming who an existence oracle discloses to is
an exhaustive quantifier over every way a uid falls out of a denormalised membership snapshot;
a join-shaped answer covers half of them, so enumerate the snapshot's writers AND its
non-writers (removal paths, cascades) first.

## 2026-08-29 — BUT-1971 confirm of the applied strike (round 6)

Staged diff: `firestore.rules`, comment lines only, 4 insertions / 7 deletions in the
`group_weekly_menu_plans` read-limb comment. Proven mechanically two ways, not by eye:
`git diff --cached -U0 | grep '^[+-]' | grep -v '^[+-][[:space:]]*//'` returns EMPTY, and the
comment-stripped, CR-stripped, blank-stripped md5 of the working file equals that of
`git show HEAD:firestore.rules` (`552dc5538c639f06e610411d96a3cb62`, 1382 surviving lines each,
so the comparison is visibly non-vacuous; `grep -c '://'` on the file is 0, so the `//` strip
cannot have eaten a URL inside a string literal). Note the md5 differs from round 5's figure
because HEAD moved between the two runs — an md5 quoted in an archive entry fingerprints a
commit, not the file, so never compare one across entries.

The round-5 blocking finding is applied as specified: the enumeration sentences are DELETED,
not reworded. What survives is the mechanism paragraph, the direction sentence, "Content,
membership and names stay closed." and Malin's dated decision line. No replacement population
was written, so there is no new measured claim to re-measure. Swept the repo for surviving
carriers of the struck wording (`guessable surface`, `DM pairs`, `closed a meal poll that
week`) across rules/ts/dart/md: none outside this append-only archive, which must keep it.
`weekly-menu-plans-rules.test.ts` G7 carries the direction sentence only, matching the rules
file, and no enumeration.

`npm run test:rules:weekly-menu-plans` = 14/14 passed, including G6 (non-member denied on an
existing plan) and G7 (any signed-in user allowed on an absent week) — the allow/deny pair for
the null arm.

Non-blocking observation, deliberately filed WITHOUT a prescribed rewrite: the surviving
sentence "an ALLOW now means the week is unplanned" is unqualified and holds for a NON-MEMBER;
a member also gets ALLOW on a plan that exists. It predates this diff and has survived five
review rounds. Recording it rather than opening a sixth round on the same paragraph — the only
safe action on it is a strike, and it is not worth one.

No new durable rule this run; the departure/late-joiner principle from round 5 already covers
the case and needed no edit.

## 2026-08-29 — BUT-1971 independent re-verification of round 6 (second reviewer pass)

A second invocation re-ran the round-6 review from scratch on the same paragraph. The diff
was committed as `717947656` mid-review, so the comment-only property was proven twice, on
both objects: old-HEAD vs index before the commit, and `HEAD~1` vs `HEAD` after. Both times
the non-comment line filter came back EMPTY and the comment-stripped md5 was identical over
1382 surviving lines.

The digest differed from the one round 6 recorded (`fb48930240371cbe9c7bda335670edeb` here
vs `552dc5538c639f06e610411d96a3cb62` there) over the SAME bytes and the SAME 1382 lines,
because the two runs stripped `\r` at different points in the pipeline. Round 6 warned that
an md5 fingerprints a commit; it also fingerprints the pipeline. The line count is the only
figure that survives between entries — recorded as a principle edit, in place.

MUTATION-PROBED this run rather than read: dropping `resource == null` from the
`group_weekly_menu_plans` read limb (match count asserted 1, mutant diffed before running)
reddens G7 ALONE — 13/14, the other thirteen green, G5 and G6 untouched. That is the direct
measurement behind the two surviving mechanism sentences, so they are no longer taken on the
comment's word. The mutant was written to a repo-local `_probe.rules`, not `/tmp`: Node and
Git Bash resolve `/tmp` to different directories on Windows, so the first attempt wrote a
file the shell could not see. The `trap` cleanup then MISSED, because its paths were relative
and the call had `cd functions` in it — the exact hazard the probe-mechanics bullet already
names; artefacts were removed by absolute path afterwards.

"Content, membership and names stay closed" verified against the whole file, not the block:
`group_weekly_menu_plans` has no subcollection rules, no collection-group catch-all matches
it (the seven are members/friend_categories/engagements/comments/ratings/recipes/pings), and
the terminal `{document=**}` denies. A non-member learns allow-vs-deny and nothing else.
Malin's decision line matches `tasks/but-1971-gruppmeny-regelfix-plan.md` ("en extra läsning
per regelutvärdering … för alltid"), which is the approved plan the shipped rule came from.

Non-blocking, and deliberately filed with NO prescribed rewrite, matching round 6's handling
of the sentence beside it: "The per-user collection above … never touches `resource`" is
unqualified and true of the read/create/delete limbs; `weekly_menu_plans`' UPDATE limb does
read `resource.data.userId`. Operative reading (the read rule, which is what the paragraph is
about) is correct. Recording it instead of opening a seventh round — the only safe action on
such a sentence is a strike, and it does not earn one.

## 2026-08-29 — BUT-1971 `group_weekly_menu_plans.editTrail` 50-row cap (review, verified)

Diff: `groupMenuTrailWithinCap()` = `request.resource.data.get('editTrail', []).size() <= 50`,
conjoined onto BOTH the `create` and `update` limbs. Tests G8-G11 added to
`weekly-menu-plans-rules.test.ts`.

Verified this run (not assumed):
- Suite: 18/18 pass.
- Mutant `request.resource.data.editTrail.size()` (bare dereference): 3 FAIL — "a group edit
  that preserves createdAt is allowed" (G2), "an edit member can write a group plan" (G4),
  "a save that carries no trail at all is allowed" (G11). Emulator prints
  `Property editTrail is undefined on object.` Two of the three are PRE-EXISTING tests, i.e.
  the collection's ordinary save path. Same failure mode as the read rule fixed in 562cf5ee0.
- Mutant dropping the conjunct from the CREATE limb: G8 alone fails (flips to ALLOW). That
  flip is also the only proof the create limb's OTHER conjuncts are satisfied — the suite
  contains NO group-create ALLOW test.
- Mutant dropping it from the UPDATE limb: G9 alone fails.
- `firestore.rules` md5 byte-identical before and after probing
  (65d70911295d223ff341360e95756d2e); mutants ran from scratchpad copies with per-mutant
  project ids; `check-test-registration.js` OK (42 rules suites).

Per-type probe against the REAL rules, `editTrail` set to each shape on an update:
list(50) ALLOW · map 50 keys ALLOW · map 500 keys DENY · string 10 chars ALLOW ·
string 500 chars DENY · int DENY · bool DENY · null DENY · timestamp DENY.
So the missing `is list` conjunct is a SHAPE gap, not a bound gap — the accepted-deviation
call to document it is correct. The rules comment's sentence "a map with <= 50 keys
satisfies `.size()` too" is measured TRUE, and nothing in the suite keeps it true.

Admin-gate interaction: none. `editTrail` is absent from the update limb's
`affectedKeys().hasAny(['participants','participantUserIds','memberPermissions'])` list, and
the cap is ANDed OUTSIDE that OR, so a non-admin `edit` member writing 50 trail rows is
ALLOWED and 51 DENIED (both measured). That edit-member path is the real production writer
(`GroupWeeklyMenuViewModel._edit`) and is untested in the suite.

Client side: `GroupWeeklyMenuPlan.toFirestore` writes `if (editTrail.isNotEmpty)`, so it
OMITS the field rather than sending null — the null-deny is latent, not live.
`maxEditTrailRows = 50` agrees with the rules literal (checked, no cross-reference between
the two spellings exists).

Coverage gaps left open, none blocking: no group-create ALLOW test (G8 provable only by
mutation, and it goes vacuous on the next create-limb tightening); no test pins the
edit-member trail write; no test pins any non-list shape, in either direction.

## 2026-08-30 — BUT-1971 re-review: the edit-trail cap is unproven for the actor that writes it

Re-ran `test:rules:weekly-menu-plans` against the current `firestore.rules`: 21/21 pass.

Re-probed the cap after the two new allow tests landed (mutants built in the scratchpad,
`firestore.rules` never written):

- M1 — drop `groupMenuTrailWithinCap()` from the CREATE limb: kills exactly
  "a create carrying more than 50 trail rows is denied" (20/21).
- M2 — drop it from the UPDATE limb: kills "an update carrying more than 50 trail rows is
  denied" AND "an explicit null trail is denied" (19/21). The second kill is the useful
  one: it ATTRIBUTES the null deny to the cap function rather than to `cannotModify` or
  the membership conjuncts, which the emulator's `evaluation error at L1007` cannot.
- M3 — loosen `<= 50` to `<= 51`: kills both over-cap denies, neither at-50 allow (19/21).
  The boundary is exact on both limbs.
- M4 — scope the cap to admins (`memberPermissions[uid] == 'admin' ? size <= 50 : true`):
  **21/21 GREEN.** Both over-cap denies are sent by the admin owner, and the new
  "a non-admin editor may write a trail within the cap" is an ALLOW, which survives a
  mutant that only loosens the rule for non-admins. So the edit member — the actor the
  interactive remove/undo path runs as — can write an unbounded trail with the whole suite
  green, and that test's comment ("the cap is ANDed outside the admin gate, and nothing
  proved that") is still unproven after it. One deny test (edit member, 51 rows) closes it.

Two comment defects measured in the same pass:

- The test file's `.claude/rules/accepted-deviations.md` pointer for the `.size()` type gap
  does not resolve — grepped both deviations files; the BUT-1971 block there carries the
  forgeable-provenance, non-durability, Art. 15 and open-uid entries and nothing about the
  cap's type behaviour. ADR-0010 only records that a written type gap was REQUIRED. The
  account actually lives in the `firestore.rules` comment and in
  `_redactGroupPlan`'s container arm (verified: that arm exists and fails closed).
- The banner range "G8-G11" now spans seven trail tests, three of which carry no ID, and
  the "discriminating control for both … the two denials above" sentence sits above the
  CREATE at-50 allow, which M1/M2 show controls the create denial only.

Verdict: fail (1 blocking) on the M4 gap.

## 2026-08-30 — BUT-1971 re-review: the editor's over-cap deny kills M4, and one comment detached

Re-ran `test:rules:weekly-menu-plans` against the current `firestore.rules`: 22/22.

Re-probed the four mutants on the CURRENT file (probe copy under
`functions/src/__tests__/_probe_wmp.test.ts`, mutant rules in the scratchpad, deleted in the
same call):

- M1 — drop `&& groupMenuTrailWithinCap()` from the CREATE limb: 21/22, kills
  "a create carrying more than 50 trail rows is denied".
- M2 — drop it from the UPDATE limb: 19/22, kills the 51-row update deny, the new
  "a non-admin editor is also bound by the cap", and "an explicit null trail is denied".
- M3 — `.get('editTrail', [])` -> bare `request.resource.data.editTrail`: 19/22, kills three
  ordinary-save allows ("a group edit that preserves createdAt is allowed", "an edit member
  can write a group plan", "a save that carries no trail at all is allowed"). The defaulting
  `.get()` is load-bearing, measured.
- M4 — cap scoped to admins
  (`resource == null || resource.data.memberPermissions[uid] != 'admin' || size <= 50`):
  20/22 — DEAD, where the previous pass had it surviving 21/21. The two kills are the 51-row
  CREATE deny (the `resource == null` arm unbinds create) and the new editor over-cap deny.
  So the conjunct's placement OUTSIDE the admin gate is now measured, and the allow/deny pair
  at the editor actor is what measures it — the allow alone survived the mutant by
  construction.

Verified the four strikes: the accepted-deviations pointer for the `.size()` type gap is gone
and the replacement claim ("absorbed downstream: the export's redaction helper fails closed on
a non-list trail") is TRUE — `_redactGroupPlan` in `content_export_manager.dart` has a
container arm that replaces a non-list `editTrail` with `const []`; the `G8`–`G11` range labels
are struck without renumbering (G1–G7 intact); the stacked control comment above the at-cap
create test now reads only "The create denial's own ALLOW control."; and the duplicated
read-rule account in the test file now points at the read rule in `firestore.rules` and makes
no claim of its own.

One non-blocking finding: inserting the new test between a comment and its test detached
them. The paragraph beginning "A present `null` is not an absent field" now heads
"a non-admin editor is also bound by the cap", and "an explicit null trail is denied" carries
no comment. Repair is a MOVE of those four lines down one test, not a rewrite. Principle added
to the knowledge file under rule parity/comments.

## 2026-08-30 — BUT-1971 final round: the two downstream citations, and the allow test's justification clause

Re-review at the post-comment-move bytes. `firestore.rules` byte-identical to the previous
round (`git diff HEAD -- firestore.rules` shows only the BUT-1971 cap hunks, unchanged).
Suite re-run rather than taken: 22/22.

**Comment move verified.** The null-tripwire paragraph now heads `an explicit null trail is
denied`, and `a non-admin editor may write a trail within the cap` carries its own. The Low
from last round is closed.

**Citation 1 — the cascade's outright delete of a non-list `entries`/`editTrail`
(`account-deletion-cascade.ts`).** Accurate at these bytes. Each clause checked separately:
the non-list value IS skipped by the scrub (`Array.isArray(trailRaw) ? … : []`, and the
spread arms are themselves `Array.isArray`-gated, so nothing is written back); the rules cap
IS `.get('editTrail', []).size() <= 50` with no type conjunct, and the create limb carries no
`keys().hasOnly` and does not name `editTrail` in `hasRequiredFields`, so a hand-rolled client
can seat a ≤50-key map — "the shape is reachable" holds; and "no writer produces it" holds
against `GroupWeeklyMenuPlan.toFirestore`, which omits the field when empty and writes a list
otherwise.

**Citation 2 — the export's `_redactGroupPlan` container arm.** Accurate. The rule fragment
is quoted verbatim, the per-type fact is mine, and the counterfactual ("without this arm such
a value skips the filter and ships whole") is structurally true: the helper copies the whole
map and only the `is List` branch filters, so an unfiltered non-list stays in `copy`.

**New finding (Low, non-blocking).** The comment above `a non-admin editor may write a trail
within the cap` reads "— the cap is ANDed outside the admin gate, and nothing proved that."
Both halves are now false OF THAT TEST: an allow cannot measure the conjunct's placement (my
own principle), and the deny below it does prove it and says so. The sentence was TRUE when
written and was falsified by the deny that a review round asked for — the same insertion-seam
shape as a comment that counts the tests below it. Reported as a STRIKE from the em-dash, not
a reword.

**Carrier count for the polymorphic-`.size()` fact, measured by grep rather than recalled:
six files** — `firestore.rules`, `weekly-menu-plans-rules.test.ts`,
`account-deletion-cascade.ts`, `request-account-deletion.integration.test.ts`,
`content_export_manager.dart`, `content_export_manager_test.dart`. Each states it to justify
its own fail-closed arm, which is why strike-and-point does not apply here. Two of the six are
self-verifying (their fixtures ARE a map trail).

**The `is list` conjunct — my call: its own ticket, and it does NOT retire the downstream
arms.** My earlier note said the conjunct "would shut both halves at the source and let the
export's container arm retire". Narrowing that at these bytes: a rules tightening binds future
WRITES and never cleans STORED documents, and both downstream arms read stored data, so
retiring either on the strength of the rule would be unsound. What the ticket really costs is
a wrong-type deny per type at ≤50, a fresh mutation probe, and a six-file sweep of the
sentences above — in a change that is otherwise complete at 22/22 with the gap documented
per-type and absorbed by both consumers. Harm bound while it waits: a ≤50-key map that no
writer produces and that both consumers already fail closed on.

Verdict: pass, 0 blocking.

---

## 2026-08-30 — BUT-1971 re-review at the moved bytes (comment-only test delta)

Re-invoked because the test file moved after a `READY TO MERGE`. `firestore.rules` staged
diff byte-identical to the previous pass (the `groupMenuTrailWithinCap()` helper ANDed onto
both the create and the update limb, `.get('editTrail', []).size() <= 50`); confirmed by
reading the block at `match /group_weekly_menu_plans/{planId}` rather than trusting the
"unchanged" claim. Both files are fully staged (`git status` second column blank), so the
worktree bytes I read ARE the staged bytes — worth checking before a Read stands in for a
`git show :<path>`.

The strike landed correctly. The comment above `a non-admin editor may write a trail within
the cap` now reads only "The production writer is an EDIT member, not the admin every other
trail test uses. The deny below is what measures the conjunct's placement; this is its allow
control." The retired clause ("the cap is ANDed outside the admin gate, and nothing proved
that") survives ONLY here in the archive and as the principle at
`firestore-rules-tester.knowledge.md`'s numeric-floor bullet — grepped repo-wide for both
fragments, no restatement anywhere in `functions/` or `firestore.rules`. The pointer
resolves: "the deny below" is the immediately following test, and the two differ in exactly
one variable (50 vs 51 rows, same seed, same actor, same verb), so "its allow control" is
directly readable rather than measured. The surviving "admin gate" mention sits in the DENY's
own comment, where it is the claim the 20/22 mutant kill measured.

Suite re-run on these bytes, not taken: 22/22. Emulator deny signatures worth recording —
the editor over-cap deny and the view-only deny both print `evaluation error at L1007:24 for
'update'`, i.e. byte-identical fingerprints for two structurally different actors, which is
exactly why the admin-scoping mutant (measured 2026-08-30, dies 20/22 with this deny as one
of the two kills) is the attribution and the emulator text is not. `an explicit null trail is
denied` prints `Null value error.`, matching the per-type table.

The `is list` call stands as I left it: its own ticket, and the ticket promises retiring
neither downstream arm, because a rules tightening binds future writes and never cleans
stored documents. Both arms are in this change and both fail closed — `_redactGroupPlan`'s
container arm on export, and the cascade's `FieldValue.delete()` arms on erasure, the latter
pinned by a `gp-malformed` fixture carrying map-typed `entries`/`editTrail`.

No new reusable rule; the principle this round would have produced is already the last two
sentences of the numeric-floor bullet. Archive-only per the contract.

Verdict: pass, 0 blocking.

---

## 2026-08-30 — BUT-1971 verdict re-record against the current staged bytes (rounds landed elsewhere)

Re-invoked purely to record a verdict against the bytes the commit gate is about to see:
three rounds of edits landed elsewhere in the change set while neither reviewed file moved.
Confirmed by reading, not by trusting the claim, and by three independent checks that agree:

1. `git diff` of worktree against index is EMPTY for both files, so the bytes I opened with
   `Read` are the staged bytes.
2. The staged `firestore.rules` hunks are confined to lines 967-1018 — the
   `groupMenuTrailWithinCap()` helper and its two `&&` conjuncts on the create and update
   limbs of `match /group_weekly_menu_plans/{planId}`. Read the WHOLE file (3284 lines, in
   three chunks) rather than the diff, so "nothing else moved" is a read rather than an
   inference from hunk headers.
3. My own previous archive entry quotes the post-strike comment above `a non-admin editor
   may write a trail within the cap` verbatim; the freshly-read file matches it word for
   word, and the suite is still 22 tests. A prior entry's verbatim quotation is a usable
   corroboration of an "unchanged since your last read" claim — cheaper than recovering
   blob revisions, and it fails loudly if a round did touch the text.

Fourth, weaker but free: the emulator's deny SIGNATURES reproduced exactly across the two
runs — `evaluation error at L1007:24 for 'update'` for both the view-only deny and the
editor over-cap deny, `Null value error.` for the explicit-null test. Those fingerprint the
rule LINE, so an unchanged set across runs is consistent with unmoved rules bytes. It is
corroboration only, never the proof: it cannot see a comment-line insertion that shifts no
rule, and it cannot distinguish two actors (which is the whole reason the admin-scoping
mutant, not the emulator text, is the attribution for that deny).

Suite re-run on these bytes: 22/22.

The cascade file DID move in this commit (`account-deletion-cascade.ts`: the ACL probe leg
now logs a constant label instead of the `FieldPath`, because the logger JSON-stringifies
the path and would have written the full uid). Out of scope here and it touches no rule —
recorded because a rules reviewer asked "did anything move" should say which neighbouring
file did and why it is not a rules question.

Both downstream citations re-checked as still in the change set and still failing closed:
`_redactGroupPlan`'s container arm on export, and the cascade's `FieldValue.delete()` arms
on erasure, the latter pinned by the `gp-malformed` fixture. The `is list` conjunct stays
its own ticket, with the caveat unchanged: a rules tightening binds future writes and never
cleans stored documents, so it retires neither arm.

No new reusable rule. The principle this round would have produced is already carried by the
"Proving a comment-only rules diff is mechanical, not eyeballable" bullet; the archive-quote
corroboration above is a technique note, not a rule worth spending principle budget on.
Archive-only per the contract.

Verdict: pass, 0 blocking.

## 2026-08-30 — BUT-1971 third verdict pass: the struck `participantUserIds` gating header

Scope: verdict on the CURRENT bytes of `firestore.rules` + `weekly-menu-plans-rules.test.ts`
after a comment-only change to the `group_weekly_menu_plans` block header. Index and
worktree byte-identical (`git diff --quiet` clean). Suite re-run: 22/22 passed.

**The strike is correct, and the reason a presence grep would have got it wrong.**
The struck header claimed "Access is gated by the denormalised `participantUserIds` list +
the nested `participants[].permission` field". Both field names DO appear inside the match
block — `participants`/`participantUserIds` in the create limb's `hasRequiredFields([...])`,
and both again in the update limb's
`!request.resource.data.diff(resource.data).affectedKeys().hasAny(['participants',
'participantUserIds', 'memberPermissions'])` admin-escalation guard. So `grep participant`
inside the block answers YES on six lines. What none of them do is DECIDE ACCESS: every
access decision on all four verbs (`read`, `create`, `update`, `delete`) tests
`memberPermissions` and nothing else, and `participants[].permission` is read nowhere in the
file — no top-level or block-scoped function touches it. Required-on-create is a SHAPE
conjunct; a protected key in a diff guard is an immutability conjunct. Neither is the
membership predicate the struck sentence described. Lesson generalised into the principles
file: the test for a false gating claim is "does any limb DECIDE ACCESS on X", never "does
any limb mention X".

**Not an over-strike.** The one true fragment inside the struck text — the
`'view' | 'edit' | 'admin'` value set mirroring `SharedListPermission` — survives verbatim
six lines below, correctly attached to `memberPermissions`, in the block-level comment at
`match /group_weekly_menu_plans/{planId}`. Nothing true was lost with the removal.

**The "helpers are inlined" sentence carried nothing.** It justified inlining "because the
participant-permission lookup is specific to this collection's shape" — there is no
participant-permission lookup helper, inlined or otherwise, and after BUT-1971 the block
contains exactly one declared function (`groupMenuTrailWithinCap()`), which is block-scoped
rather than inlined and has nothing to do with participant permissions. Both halves of the
sentence were false. Writing a replacement convention note ("keep helpers block-scoped
here") would have been a new unmeasured claim; correctly omitted.

**The replacement's one measurable clause, measured.** "The access gate is described on the
match block below, which is the only place it is enforced." `group_weekly_menu_plans` occurs
exactly once in `firestore.rules` (the `match` at the block). The seven `{path=**}/X/{id}`
collection-group overlays all name a different trailing segment (`members`,
`friend_categories`, `engagements`, `comments`, `ratings`, `recipes`, `pings`), so none
matches this top-level collection; the `match /{document=**}` catch-all is
`allow read, write: if false` and grants nothing. True as measured. The client-side
`FirebaseGroupWeeklyMenuPlanRepository` permission check is not a counterexample — its own
class comment says "Access control is the domain of firestore.rules" and the call site is
labelled "Belt-and-braces". Recorded as an insertion seam, not a defect: the day a second
match block or an overlay touches this collection the clause goes false silently. No
rewrite recommended — the sentence is true, and rewording a true sentence is how one
finding becomes a chain.

**Surviving co-carrier, outside the staged set.** `git status` shows
`test/integration/firebase/repositories/group_weekly_menu_plan_repository_test.dart`
unmodified and unstaged; line 245-247 is a test NAME reading "should persist the
denormalised `memberPermissions` + `participantUserIds` fields so Firestore rules can
enforce per-user access". Same false framing as the struck header, for
`participantUserIds`. Half-true by accident: the field must be persisted or the create limb
denies the write on `hasRequiredFields` — but that is a shape requirement, not per-user
access enforcement. Reported as Low, non-blocking, own follow-up. The mechanical lesson: a
claim sweep anchored on comment syntax cannot see a claim living in a test's NAME string,
and this is the second BUT-1971 round where the last carrier sat somewhere the previous
sweep's grep shape could not reach.

Also noted and NOT touched: `.claude/worktrees/wf_a173466e-c2e-19/firestore.rules:937` still
carries the pre-strike text. That is a parallel session's worktree.

Verdict: pass, 0 blocking.

---

## 2026-08-30 — BUT-1971: a rules comment that POINTS AT A DRIFT GUARD (comment-only diff)

Reviewed a three-line-for-two comment replacement beside `groupMenuTrailWithinCap()` in
`group_weekly_menu_plans`. Old text: "Nothing derives one from the other: lowering the Dart
constant diverges silently, raising it denies every save." New text: "50 is also
`GroupWeeklyMenuPlan.maxEditTrailRows`; the two are compared by
`test/unit/security/rules_numeric_bound_drift_test.dart`."

**Comment-only proof (mechanical).** `git diff --cached -U0 | grep '^[+-]' | grep -v
'^[+-][[:space:]]*//'` empty; comment+CR+blank-stripped staged vs HEAD both 1387 surviving
lines with identical md5 within the run (b2de31c…, valid only for this run's strip
pipeline).

**Pointer resolution, measured rather than read.** Replicated the guard's own extraction in
Python over the comment-stripped rules text: `function\s+groupMenuTrailWithinCap\s*\(\s*\)
\s*\{[^}]*?\.size\(\)\s*<=\s*(\d+)` captures `50` from the span
`function groupMenuTrailWithinCap() { return request.resource.data.get('editTrail',
[]).size() <= 50`, there is exactly ONE definition of that function, and `50` appears 6
times in the stripped file — so the capture is the function's literal and not an adjacent
one. Dart side: `GroupWeeklyMenuPlan.maxEditTrailRows = 50`. `flutter test
test/unit/security/rules_numeric_bound_drift_test.dart` green (1/1). The guard runs in CI:
`.github/workflows/test.yml` runs `flutter test test/unit`. It asserts nothing else — its
own header explicitly scopes out the both-limbs question.

**The struck half was an overstatement, confirmed.** `_withTrailRow` prunes to
`maxEditTrailRows` keeping the newest rows, and the rule reads
`.get('editTrail', []).size() <= 50` off the submitted payload. Raising the Dart constant to
N > 50 therefore denies only saves of a week whose trail has already grown past 50 rows;
every shorter week saves normally. Striking beat rewording — the true wording is a scope
that has to be measured.

**Surrounding block re-verified against the rules language, not taken from the prompt.**
`hasRequiredFields([...])` on the create limb omits `editTrail` and there is no `hasOnly`,
so "create requires no `editTrail` and rejects no extra fields" holds and the both-limbs
justification stands (cap present at both `allow create` and `allow update`; `allow delete`
has no `request.resource` and needs none). The `.size()`-polymorphism sentence ("a map with
<= 50 keys satisfies `.size()` too") matches the per-type measurement already in the
knowledge file. The 1 MB sentence is a fact about Firestore, not a claim about this rule,
and the "do not cite as a DoS control" line is advisory.

**Re-ran the emulator suite anyway: 22/22 passed.** A comment cannot change CEL evaluation,
so the re-run is not owed for behaviour — but it is cheap and it does disprove the one thing
a comment edit CAN break, an unterminated/typo'd comment that stops the ruleset compiling.
Worth doing whenever the rules file itself is edited, even for comments.

Low, non-blocking: the comment now carries a cross-language file PATH, which goes stale
silently on a rename with no test to catch it (the Dart guard has no reciprocal pointer back
to the rules comment). Not worth a rewrite today.

Verdict: pass, 0 blocking.

---

## 2026-08-31 — BUT-1971 follow-up: `group_weekly_menu_plans.contributorUserIds`
### (append-only erasure handle, mirroring `unified_shared_shopping_lists.keepsContributorTrail`)

Reviewed `git diff -- firestore.rules functions/src/__tests__/weekly-menu-plans-rules.test.ts`
plus `test/unit/security/rules_numeric_bound_drift_test.dart` and
`lib/models/menu/group_weekly_menu_plan.dart`. Emulator: 32/32 (the suite grew from 30 to 32
mid-review — a parallel session added the two MEASUREMENT read-surface tests at 09:49).

**Split verdict.** Correct and faithful to the precedent. `hasAll` on update only is right:
create has no `resource`, and a create only happens on an absent document, so there is no
prior array to preserve. The cap ANDed on BOTH limbs is required because the create limb
uses `hasRequiredFields`, not `hasOnly`, so an extra oversized field would otherwise ride in
(re-read the create limb to confirm — same structure as the `editTrail` cap's justification).
Both conjuncts sit at the TOP level of the update limb, outside the
`(participants-unchanged || admin)` parenthesis, so an admin is bound too — the same placement
SSL14 exists to pin on the shopping lists.

**Read surface: none added, and now measured in-suite.** The read limb still gates only on
`memberPermissions`. Firestore refuses a list query it cannot prove readable for every
returnable document, so `where('contributorUserIds','array-contains', uid)` is denied even to
a CURRENT member — the suite's two MEASUREMENT tests pin exactly that plus the
`memberPermissions.<uid>` control. `FirebaseGroupWeeklyMenuPlanRepository.probeLeftGroupPlans`
is written knowing this: `.limit(1)`, and its own comment says the refusal IS the product.
The only new disclosure to remaining members is a uid that survives in the array after its
other traces are gone (cascade `arrayRemove` runs Admin-SDK, so this is narrow).

**Four probes against the REAL rules** (throwaway sed-copy of the suite, deleted in the same
Bash call; `firestore.rules` never written to, md5 unchanged): whole-doc `set()` OMITTING the
field on a doc that has one -> DENY; preserving -> ALLOW; same set in DIFFERENT ORDER -> ALLOW
(set semantics); a doc already at 205 -> FROZEN even for an unrelated `lastModifiedAt` update.
A fifth: same-size SUBSTITUTION `['a','b'] -> ['a','z']` -> DENY.

**Two surviving mutants — the coverage finding.** Both left the suite 32/32 green:
1. `request.resource.data.get('contributorUserIds', resource.data.get('contributorUserIds', []))`
   — defaulting the REQUEST side to the prior array. This is the plausible future "make older
   clients work" fix, and it is caught only by the whole-doc `set()`-omits case. That verb is
   production here: `FirebaseGroupWeeklyMenuPlanRepository.save` writes the whole document with
   a non-merge `set`.
2. `.size() >= resource.data.get('contributorUserIds', []).size()` replacing `.hasAll(...)` —
   caught only by a same-size substitution.
The existing drop/clear/editor denies kill neither. Same shape as the shopping-list suite's
SSL17/SSL18 (set-drop + fail-closed control), SSL8 (reorder) and SSL20 (frozen) — all four
absent here.

**Drift guard.** Current raw-string concatenation form is right. Replicated its extraction
independently over the comment-stripped file: it captures 200 from `groupMenuContributorsWithinCap`
(one of SEVEN `<= 200` in the file) and 50 from `groupMenuTrailWithinCap` (one of SIX `<= 50`),
so the function-name anchor is what makes it discriminating; `\s*\(` after the name also blocks
a prefix collision with a future `…CapV2`. `flutter test test/unit` runs it in CI, +2 green.
While replicating it I reproduced the very decay its comment describes, through bash instead of
Dart: a heredoc collapsed `\s` to `\s` inside a JS string literal, giving `functions+` and NO
MATCH. Build such patterns from regex LITERALS.
One false clause found: the contributor test's "raise the Dart constant and every suite stays
green while the server denies the write". Nothing in `lib/` reads `maxContributorUserIds` —
`contributorUserIdsForWrite` does not prune to it (unlike `maxEditTrailRows`, which
`GroupWeeklyMenuPlanService` prunes to) — so raising it changes no write and denies nothing.
Strike the causal clause; the guard itself still earns its place.

**Residual, informational only:** an admin can `delete` and re-`create` the plan, which resets
the array; and a >200-contributor plan is permanently unsavable with no client-side prune. Both
are inherited from the precedent and adjacent to already-decided BUT-1971 deviations.

Verdict: pass, 0 blocking.

## 2026-08-31 — BUT-1971 re-review: both blockers killed, mutants re-measured by me

Re-review of `functions/src/__tests__/weekly-menu-plans-rules.test.ts` (37 tests),
`firestore.rules`' `group_weekly_menu_plans` block, and
`test/unit/security/rules_numeric_bound_drift_test.dart`.

Real suite: 37/37. Drift guard: 2/2.

Re-ran both blocking mutants myself rather than accepting the reported figures, through a
throwaway `sed`-derived suite copy (project id lowercased, `RULES_PATH` repointed, the
orphaned `import * as path` deleted) against mutant rulesets built in the scratchpad by a
node mutator that slices on `indexOf('match /group_weekly_menu_plans')` and asserts a match
count of exactly 1:

- Mutant A — request side defaults to the STORED array
  (`request.resource.data.get('contributorUserIds', resource.data.get('contributorUserIds', []))`),
  i.e. the "let old clients through" fix: **36/37, sole kill = "a whole-document set() that
  OMITS the field is denied"**.
- Mutant B — `hasAll` rewritten as `size() >= size()`: **36/37, sole kill = "a SAME-SIZE
  substitution is denied"**.

`firestore.rules` was never written to; both mutants were separate files.

Mediums taken and verified present: the reorder ALLOW (production writes come from a Dart
`Set`, order unstable) and the already-over-cap freeze at 205 contributors, the latter
labelled a documented consequence rather than a guard.

Low: the drift test's contributor comment was struck and replaced. The replacement claim
("nothing in `lib/` reads this constant, unlike `maxEditTrailRows` which the service prunes
to") is a MEASUREMENT, so I grepped it: `maxContributorUserIds` appears once in `lib/`, the
declaration itself; `maxEditTrailRows` is read by
`GroupWeeklyMenuPlanService._withTrailRow`; `contributorUserIdsForWrite` unions and never
truncates. Verified true.

Superseded verbatim from the knowledge file (the drift-guard bullet's residual), now false
because `GroupWeeklyMenuPlan.maxContributorUserIds`/`maxEditTrailRows` docstrings name the
guard and `firestore.rules` names it at both caps:

> Residual worth one Low line: such a comment carries a cross-language PATH that a rename
> breaks silently, with no reciprocal pointer back (BUT-1971, `groupMenuTrailWithinCap` ->
> `rules_numeric_bound_drift_test.dart`).

Sentinel question, answered: `arrayUnion`/`arrayRemove` owe nothing here. Rules evaluate the
resolved post-state, so a client sentinel is an alias of writes already pinned; the
leave-path CF's `arrayUnion` in `cutGroupMenuPlanAccess` runs under the Admin SDK and never
evaluates rules, so a rules suite cannot observe it at all.

New this round: `cutGroupMenuPlanAccess` pushes an `adminPromoted` row onto the trail
without pruning, so an Admin-SDK write can leave a stored trail at 51 rows, which
`groupMenuTrailWithinCap` then refuses on every client save. Not permanent — `_withTrailRow`
prunes to the newest 50 on every append, and every live `save()` path appends — so it heals
on the next interactive edit. The contributor cap has no prune by design, so its freeze IS
permanent, which is what the new freeze test documents. Two caps in one collection with
opposite verdicts.

Also checked: the two MEASUREMENT tests support the Art. 15 conclusion they were used for.
The deny is sent by a CURRENT member of the only matching document, so a leaver is strictly
weaker and denied too, and the `memberPermissions` control rules out "list queries fail
here". One refinement, in the safe direction: a membership-CONSTRAINED query IS allowed, but
it can only ever return weeks the requester is still a member of — never a week they left —
so removing the export probe is right on either reading.

`node functions/scripts/check-test-registration.js`: OK, 134 files, 42 rules suites.

## 2026-08-31 — BUT-1971, final review: the cross-language cap pin

`weekly-menu-plans-rules.test.ts` gained "the Cloud Function's copies of both caps match
the rules literals", importing `MAX_TRAIL_ROWS` (50) and `MAX_CONTRIBUTOR_UIDS` (200) from
`functions/src/groups/remove-chat-group-member.ts` and asserting each templated substring
appears in the rules text the suite already reads. Third copy of each number; the Dart guard
`test/unit/security/rules_numeric_bound_drift_test.dart` cannot see a TS literal, and the CF's
own suite `chat-group-callables.test.ts` imports the same constants, so it is self-referential
and stays green under drift. The pin is therefore genuinely the only tie — the motivation is
sound.

Suite re-run green (38/38); Dart guard 2/2. Two blocking findings, both measured:

1. **The contributor needle is not unique.** Counted over `firestore.rules`:
   `.get('contributorUserIds', []).size() <= 200` appears 3x — line 1010 in
   `group_weekly_menu_plans`, lines 2362 and 2380 in `unified_shared_shopping_lists`. So the
   scenario the guard exists for — the GROUP cap moving to 150 together with its Dart twin,
   which keeps `rules_numeric_bound_drift_test.dart` green — leaves the pin matching the
   shopping-list copy and green forever, while the CF unions to 200 and bricks weeks the rule
   caps at 150. The `editTrail` needle is unique (1x) today, i.e. anchored by luck. Remedy:
   slice by `indexOf('match /group_weekly_menu_plans')` up to the next `match /` and assert
   the occurrence count inside the slice == 1.
2. **A false clause in the test's own comment.** "the CF writing past a cap … writes a
   document no client can ever save again" ranges over both caps. True for
   `contributorUserIds` (nothing prunes it client-side; pinned by "a document already OVER the
   cap is frozen"). FALSE for `editTrail`: `GroupWeeklyMenuPlanService._withTrailRow`
   (`group_weekly_menu_plan_service.dart:321-322`) prunes to the newest
   `GroupWeeklyMenuPlan.maxEditTrailRows` on EVERY append, so the next interactive edit heals
   it — the opposite-verdicts-on-two-caps asymmetry already in the principles file, arriving
   again as a comment. Strike the clause (the true wording needs measuring, so it is not a
   correct-in-place case).

Non-blocking: the raw `includes()` is comment-blind — measured by commenting the trail cap out
in memory, the pin stayed true — whereas the sibling Dart guard strips `//` first for exactly
that reason. Behavioural over-cap denies in the same suite reddens on a commented-out cap, so
the SUITE is not vacuous; the pin alone is. Also, both thrown messages assert which side
drifted ("remove-chat-group-member.ts prunes the trail to 50, which is not the bound in
firestore.rules"), which prints falsely if the rule is merely reflowed across two lines — the
same "guard fails accusing production" shape this ticket already paid for in Dart.

Verdict on the instrument itself: a substring IS the right choice over a second parser here.
The Dart guard already parses, this repo has a recorded regex-decay incident on that very
pattern, and `includes` has no escaping failure mode. It needs the anchor, not a rewrite.

Confirmed for the downstream citation: the two MEASUREMENT tests still say what
`content_export_manager.dart` cites them for — the `array-contains` query on
`contributorUserIds` is denied to a CURRENT member of a matching week, with the
`memberPermissions` query allowed as the control, so the bundle's unconditional
left-group sentence stands.

## 2026-08-31 — BUT-1971 final gate: certifying the anchored cap pin, and the map case

Frozen-bytes review of `firestore.rules` (`group_weekly_menu_plans`) +
`functions/src/__tests__/weekly-menu-plans-rules.test.ts`. 39/39 re-run by me on the
frozen bytes; no blocking findings.

**The anchored pin, measured (not taken on report).** The previous round's blocker was a
`rulesText.includes(".get('contributorUserIds', []).size() <= 200")` that matched three
times whole-file. The fix ships `groupPlanRulesBlock()` — comment-strip, then slice from
`match /group_weekly_menu_plans` to the next `match /` — with the in-slice occurrence count
asserted `=== 1` per cap. I replicated that function verbatim in node over mutated buffers
(pure string work; no emulator involved) and ran four mutants:

| mutant | editTrail hits | contributor hits | verdict |
|---|---|---|---|
| pristine | 1 | 1 | guard green |
| group contributor cap 200→150 | 1 | 0 | FIRES |
| group trail cap 50→40 | 0 | 1 | FIRES |
| group contributor cap commented out | 1 | 0 | FIRES (comment-blindness closed) |
| shopping-list copies 200→150 (group untouched) | 1 | 1 | correctly silent |

Whole-file counts: contributor needle 3 (rules L1010 in the group block; L2362 and L2380
inside `unified_shared_shopping_lists`, block start L2348), trail needle 1. So the test
comment's three factual claims — "NOT unique in the file", "the shopping list carries the
same literal at the same cap", "the trail needle happens to be unique today" — are all
measured-true. Non-vacuous for BOTH caps.

**The Dart guard is anchored differently and better.** `rules_numeric_bound_drift_test.dart`
matches on `function\s+groupMenuContributorsWithinCap\s*\(\s*\)\s*\{[^}]*?\.size\(\)\s*<=\s*(\d+)`
— a FUNCTION NAME, unique by construction, which cannot reach the shopping list's inline
copies. No slice needed. Its docstring's pointer ("whether the capped function is applied to
both limbs is proven by the rules suite") resolves for every symbol it ranges over: the suite
holds create-deny + update-deny for both caps.

**Drift triangle closed, three languages:** Dart 50/200 (`GroupWeeklyMenuPlan`), rules 50/200,
CF 50/200 (`MAX_TRAIL_ROWS`/`MAX_CONTRIBUTOR_UIDS`, `remove-chat-group-member.ts` L562/L573).
CF↔rules by the new rules test (which imports the CF constants), Dart↔rules by the Dart guard.
A change in any one language reddens something.

**The map case.** `a MAP-shaped editTrail with 50 keys is ALLOWED by the cap` — passes. What
the four downstream carriers actually cite is specifically "a 50-key MAP is accepted by
`.size() <= 50`", so a map-at-50 rules-layer case discharges all four:
`account-deletion-cascade.ts` L1411, `request-account-deletion.integration.test.ts` L346,
`content_export_manager.dart` L486, `content_export_manager_test.dart` L1048. The cascade's
own map fixture (`editTrail: { rogue: TARGET }`) is seeded through the Admin SDK, which
bypasses rules, so it was never a rules-layer proof — the claim "no committed case held it"
was true. Two scoping notes, neither blocking: the comment says "list, map and string" while
the case holds map only (string is measured in this archive, not in a committed test), and only
the ALLOW direction is pinned (a 51-key map deny is uncovered). The case's single kill is a
future `is list` hardening — which is the point: it turns silent six-sentence drift into one
red test.

**Claims verified against source rather than read:** the export redaction fails closed at the
CONTAINER (`copy['editTrail'] = const []`, `content_export_manager.dart` L484-491) with its own
map-shaped test; the cascade DELETES a non-list trail outright (L1413-1415) with its own
fixture; `contributorUserIdsForWrite` unions and never prunes, so the contributor freeze IS
permanent while the trail self-heals (the struck "no client can ever save again" clause was
correctly scoped to the contributor array); `save()` is a bare `.set()` with no `SetOptions`
on the deterministic id; the leave path rewrites `participants`/`participantUserIds`/
`memberPermissions` and unions the departing uid, so "your name stays on the dishes" holds; the
cascade's `arrayRemove` runs under the Admin SDK.

**Taken on the record, not re-measured this round:** G7's three quoted mutant attributions
(drop the null arm → this test alone; drop the membership arm → G5; widen it to `true` → G6).
The rule text they describe is unchanged since they were measured.


### 2026-08-31 — correction to the Admin-SDK-past-a-cap bullet [measurement]
The worked example in that bullet was falsified by the code shipping in the same commit, and
it failed the bullet's own closing instruction ("Trace the prune before writing 'frozen
forever' or 'self-healing'"). Caught by the `integration-reviewer` gate — the only pass that
reads a knowledge file and the code it cites together.

Retired verbatim:

> The leave-path CF appends an `adminPromoted` trail row without pruning, so a
> 50-row trail becomes 51 and every client save is then refused — except that
> `_withTrailRow` prunes to the newest 50 on every append, so the next interactive edit
> heals it.

Measured: `cutGroupMenuPlanAccess` prunes in the same branch that appends the row
(`remove-chat-group-member.ts`, `trail.slice(trail.length - MAX_TRAIL_ROWS)`), and
`chat-group-callables.test.ts`'s "the promotion row prunes the trail rather than pushing it
over the cap" asserts the stored trail comes back at exactly 50 with the oldest row dropped.
So the 51-row state the example reasoned about cannot arise, and the "heals on the next
interactive edit" mechanism describes a state that does not exist. The sibling
`cloud-functions-specialist.knowledge.md` taught the opposite in the same commit.

The bullet's HEADLINE survives — an Admin-SDK write can pass a cap the rules enforce, and
permanence is a question about a client-side prune — as does the `contributorUserIds` half,
where there is no prune by design and the freeze is permanent.


### 2026-08-31 — correction to the corrected Admin-SDK-past-a-cap bullet [count]
The repair itself carried a count. "Both writers of the trail prune it" ranges over writers
of `editTrail`, and there are THREE: `_withTrailRow`, `cutGroupMenuPlanAccess`, and the
account cascade, which filters or deletes and prunes nothing. The paired entry in
`cloud-functions-specialist.knowledge.archive.md` counts three, so the numeral was the one
thing the two files still spelled differently. Caught by the `integration-reviewer` gate.

Retired verbatim:

> Both writers of the trail prune it — the client in `_withTrailRow`
> and the leave-path CF in the same branch that appends its `adminPromoted` row — so no
> over-cap trail is ever stored.

The operative claim was never in doubt: no over-cap trail is ever stored. The replacement
ranges over APPENDERS, which is the set the prune has to cover, and names them.

---

## 2026-09-02 — BUT-1971 final ledger pass: the sliced cap pin, certified

Re-review at frozen bytes (`git diff --stat` empty; index == worktree). Suite: 39/39 on
`npm run test:rules:weekly-menu-plans`.

**The un-anchored-needle blocker from the previous pass is closed.** `groupPlanRulesBlock()`
strips block and line comments (`/(^|[^:])\/\/.*$/gm`, the `[^:]` keeping `://` out of it),
slices from `match /group_weekly_menu_plans` to the next `match /`, and the test asserts each
needle occurs exactly ONCE in that slice.

Certified with the four text-only mutants the principles file prescribes, replicating the
slicer in `node` over a mutated buffer (no emulator needed):

| mutant | editTrail | contributorUserIds |
|---|---|---|
| cap changed INSIDE the block | fires (hits=0) | fires (hits=0) |
| cap commented out | fires (hits=0) | fires (hits=0) |
| copies changed OUTSIDE the block | stays green (n=0 copies) | stays green (n=2 copies) |

Whole-file vs in-slice needle counts on these bytes: `editTrail` 1/1, `contributorUserIds`
3/1. So the slice is load-bearing for the contributor cap exactly as predicted, and the trail
needle is anchored by luck plus the slice. Each mutant names its OWN field, so neither anchor
covers for the other. The comment strip is what converts the commented-out mutant from a
survivor into a kill — that was the previous pass's Low and it is measured shut.

Third language confirmed live, not a test-only literal: `MAX_TRAIL_ROWS = 50` and
`MAX_CONTRIBUTOR_UIDS = 200` in `remove-chat-group-member.ts` are read by the CF's own prune
(`trail.slice(trail.length - MAX_TRAIL_ROWS)`) and union guard
(`known.length < MAX_CONTRIBUTOR_UIDS`). The Dart-vs-rules guard
(`rules_numeric_bound_drift_test.dart`, 2/2) anchors on the rules FUNCTION NAMES, which cannot
match the shopping list's inline copy, and its `[^}]*?` cannot cross a `}` — safe by
construction, and its pointer resolves for both symbols.

**The map case says what the four downstream carriers cite it for.** `cascade:1412`,
`request-account-deletion.integration.test.ts:346`, `content_export_manager.dart:486` and
`content_export_manager_test.dart:1058` all cite the MAP specifically ("a 50-key map is
accepted"), and `firestore.rules` says "a map with <= 50 keys satisfies `.size()` too" — a
50-key map ALLOWED discharges every one of them. The list arm is committed by the surrounding
50-allow/51-deny cases. The STRING arm remains measured-but-uncommitted.

**New durable rule (merged into the principles file):** the new case's own comment says "Three
comments in this repo cite this as measured on the emulator and no committed case held it".
That count does not resolve on these bytes — four carriers outside this file, five including
`firestore.rules`. A count in a comment that discharges carriers is not derivable from the case
and competes with the `grep polymorphic` instruction, so a later `is list` hardening stops at
the stated number. Strike the numeral. Filed Low, not blocking.

Also verified this pass, so it is not re-derived: `GroupWeeklyMenuPlan.toFirestore` still writes
`if (editTrail.isNotEmpty)` — the live half of the explicit-null deny — and writes
`contributorUserIds` UNCONDITIONALLY, which is what makes the OMITS-the-field deny a production
shape rather than a hypothetical.

Non-blocking observation on `firestore.rules`' contributor account: the struck "ONLY handle"
over-claim left "without this array those uids are reachable by nothing" standing. The cascade
runs FOUR discovery legs (`participantUserIds`, `lastModifiedBy`, `memberPermissions`,
`contributorUserIds`), so a departed member who happens to be the document's `lastModifiedBy`
IS reachable without the array. Narrow (that field names one person and is overwritten by the
next save) and the sentence's operative point — Firestore cannot query inside an array of maps
— is true. If it is ever touched, the fix is a strike of the "reachable by nothing" clause, not
a reworded quantifier.
