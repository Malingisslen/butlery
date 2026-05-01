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
