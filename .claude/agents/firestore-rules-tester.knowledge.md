# firestore-rules-tester — accumulated knowledge

This file is the agent's long-term memory across sessions. The agent **MUST**
read it at the start of every invocation and **APPEND** to it when it
discovers a pattern that should inform future runs.

## How the agent updates this file

- **This file holds PRINCIPLES and is edited in place** — fold a new finding into the bullet it extends. The dated raw entry goes to `firestore-rules-tester.knowledge.archive.md`, which IS append-only (`### YYYY-MM-DD — short title`, never deleted).
- **Be terse** — 1–3 sentences plus a code excerpt if needed.
- **One concept per entry** — easier to supersede later.

## Collection → test file map

| Path                                  | Test file                  | npm script                |
|---------------------------------------|----------------------------|---------------------------|
| `/users/{uid}` and recipes subtree    | `firestore-rules.test.ts`  | `test:rules:recipes-users`|
| `/reports/*`                          | `reports-rules.test.ts`    | `test:rules`              |
| Age-gate paths                        | `age-gate-rules.test.ts`   | `test:rules:age-gate`     |
| `/unified_shared_shopping_lists`      | `shared-shopping-lists-rules.test.ts` | `test:rules:shared-shopping-lists` |
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
- **`conversations/{id}` create binds `metadata.creatorId` to the caller** (`!('metadata' in ...) || !('creatorId' in ...metadata) || ...metadata.creatorId == request.auth.uid`) — closes a spoof where a tampered client forges `creatorId` to a friend of a minor to slip a non-friend group-add past `enforceGroupMinorMembership`'s friend check. Isolate the binding from the minor-DM gate by testing an ADULT 1:1 target (so `passesMinorDmGate` passes regardless) and varying only `creatorId`.

**Distilled from 2026-07-28:**

- **Append-only ARRAY guard** (`/unified_shared_shopping_lists.contributorUserIds`, BUT-1725, GDPR Art. 17 erasure trail): `request.resource.data.get(f,[]).hasAll(resource.data.get(f,[])) && request.resource.data.get(f,[]).size() <= N`, ANDed OUTSIDE the `(owner || member)` parenthesis so the owner is bound too. `hasAll` is SET-semantics — a client rebuilding the array from a Dart `Set` reorders it and must still ALLOW (pin that test; it is the difference between this and an equality check). Rules see the POST-transform value, so `arrayUnion` allows and `arrayRemove` denies with no special handling. The `get(f,[])` default makes both legacy (field-absent) docs and older clients writable. **The bound is on `request.resource` only, so a doc already over N is FROZEN — every update denies, including an items-only one** (Admin-SDK backfills bypass rules and can create that state); pin it as a documented consequence, not a silent one.
- **A guard ANDed onto an existing `allow update` is a blanket-deny risk, not a leak risk** — lead the suite with allow paths (untouched-field update, owner branch, whole-doc write-back, legacy doc) before any deny. **Builder timestamps must be CONSTANTS, not `new Date()`**, whenever the member branch forbids touching `createdAt`: a re-stamped builder makes every whole-document write deny for an unrelated reason and reads as a rule defect (cost one false FAIL here). Emulator PERMISSION_DENIED prints TWO passes; the first is routinely `evaluation error` (first pass has no `resource`, only short-circuits like `isAuthenticated()` avoid it) — read the SECOND verdict, which is the real one.
- **Mutation-probe the guard before reporting green** (`rules.replace(...)` in memory, fresh projectId — never touch the file): removing the predicate must FLIP every deny test. Two mechanics that cost a run each: the probe script must sit UNDER `functions/src/` (from the OS temp dir `npx ts-node` resolves neither `@firebase/rules-unit-testing` nor the tsconfig, so it dies on TS2307 + implicit-any) and delete it in the SAME Bash call — note `cd functions` earlier in that call makes a later `rm functions/src/...` silently miss; and **`firestore.rules` is CRLF**, so a literal template-string `includes()` never matches — use a whitespace-tolerant regex, assert the match COUNT is 1, and re-read the file at the end to prove it is byte-unchanged. Use a **`/g` flag** when the mutated literal appears more than once — the create-side bound and the function's bound are textually identical here, and a non-global replace silently patches only the first, producing a "still denied" that looks like a rule finding but is a probe bug.
- **A PERMISSION_DENIED verdict string can never prove two deny tests are DIFFERENT tests.** On `unified_shared_shopping_lists` a non-member's update and a REVOKED member's update (in `contributorUserIds`, absent from `memberPermissions`) print byte-identical `evaluation error at L1642:24 for 'update' @ L1642, false for 'update' @ L1642` — the first-pass evaluation error is just "no `resource` in pass 1", so it fingerprints the RULE LINE, never the actor. Only two things prove non-vacuity: (a) a **fail-closed probe** — same doc body, same doc id, same actor, same payload, with only the gate satisfied (seat the actor in `memberPermissions`) → must ALLOW; and (b) a **discriminating mutation** — rewrite the gate so the two actors' fates diverge (grant the member branch by `contributorUserIds` instead: the revoked actor FLIPS to allow, the stranger stays denied). Same shape applies to any pair of deny tests separated by document STATE rather than by actor identity.
- **A decision record that asserts a rules predicate is a coverage lead, not evidence.** ADR-002 states "firestore.rules forbids a non-owner from touching `ownerId` or `memberPermissions`" — grep the suite for that predicate before believing it is pinned; there it was not (only the third privileged key, `createdAt`, had a test). For any `!diff(resource.data).affectedKeys().hasAny([a,b,c])` conjunct, coverage is one deny per anchor **plus** the OWNER-branch ALLOW for the same key — the owner branch usually has no diff restriction, so the member-deny and the owner-allow are two different rules and a blanket-deny regression on the key passes every deny test while making the app's grant/revoke flow impossible.
- **A rules suite whose only route into a state is `withSecurityRulesDisabled` has not proven the state is REACHABLE.** Revoked-member tests seeded the revoked document with the Admin SDK, so nothing proved a client owner could actually perform the revoking write.
- **A `get()`-only read suite has NOT tested the read rule.** For any collection whose read gate reads `uid in resource.data.<map>` (`unified_shared_shopping_lists`, BUT-1746), the LIST path is a separate branch: the engine evaluates the predicate per candidate document and refuses the WHOLE query if one fails. So pin three things — the client's exact filter ALLOWED (returning a non-empty result; assert non-emptiness or a broken filter passes vacuously), the UNFILTERED `collection().limit(N).get()` DENIED with a foreign doc seeded in the same test, and the same filter by a member-of-nothing ALLOWED-but-empty. Dart `isNull: false` compiles to `where(f,'!=',null)` (`query.dart:676-682`) — that is the JS spelling to pin; `isNotEqualTo: null` builds NO condition at all (`if (isNotEqualTo != null)`, `query.dart:659`), so the "filter" becomes an unfiltered sweep and the symptom is "my list will not load", never an over-share. Guarded repo-side by `tools/check_null_filter.sh` (pre-commit only, no CI lane; `-H` now forces grep's `path:line:` prefix so the SINGLE-file lefthook case skips comments correctly, but the `^[^:]*:[0-9]+:` anchor still assumes a COLON-FREE path — a `C:/`-shaped argument flags the 12 WHY-comments naming the banned spelling, and the unbounded `null` in its pattern also false-positives on `isNotEqualTo: nullableVar`; both fail closed, probed 2026-07-30). **A query test asserting an EMPTY result needs an actor no other test ever seats** — a sibling deny test's `withSecurityRulesDisabled` fixture persists on the emulator and will make that actor a member.
- **Registering a new rules suite has FOUR mechanical steps** (`functions/scripts/check-test-registration.js` fails the commit otherwise): the `test:rules:<name>` script, an entry in the `test:rules:all` chain, AND the path in **both** `paths:` blocks of `.github/workflows/firestore-rules.yml` (pull_request + push). Verify with `node scripts/check-test-registration.js`.

## When to consult the archive

Grep `firestore-rules-tester.knowledge.archive.md` when: (1) a principle above is
too terse to safely reuse its CEL snippet or emulator command verbatim and you
need the original full wording; (2) you need an exact `PROJECT_ID`, npm script
name, or CI path-filter entry for a specific collection's test file; (3) a new
finding looks like it might be a REGRESSION of a previously-fixed bug (anything
shaped like the BUT-1214 presence-check query leak, an emulator-persistence
false-fail, or an admin-SDK-sentinel-in-rules-test bug) and you want the full
incident writeup, not just the one-line rule; (4) you're asked to justify WHY a
rule is shaped the way it is, for a code review or a founder-facing report.
