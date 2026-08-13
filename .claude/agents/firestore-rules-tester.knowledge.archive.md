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
