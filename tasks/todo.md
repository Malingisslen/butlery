# PLAN 2026-08-17 — get the functions deploy through, then remove the dead functions

Approved by Malin in-session (AskUserQuestion, 2026-08-17): "Sätt tak på 10 instanser".
The cleanup half is her follow-up ask ("men kanske också radera gamla engångsgrejer när vi
ändå håller på?") and is scoped below with one question left to her.

## Background — what is actually broken

The `firestore:indexes` deploy succeeded earlier today (19/19 TTL policies ACTIVE, verified).
The `functions` deploy then failed on 53 of 71 functions. Every failure reported
`Container Healthcheck failed`, which reads like broken code and is not — the real line is:

    Quota exceeded for total allowable CPU per project per region.

Measured, not assumed:
- 71 Cloud Run services in europe-west1, every one at `cpu=1`.
- `maxInstances` is set **nowhere** in `functions/src` (grep: 0 hits), and
  `setGlobalOptions` sets only `region`. Unset means the platform default of 100.
- So the project reserves ~7100 vCPU of admission headroom before a single request arrives.
- Nothing was deleted or corrupted by the failed deploy. The three new BUT-1838 group
  callables DID get created and are ACTIVE (`createChatGroup`, `addChatGroupMembers`,
  `removeChatGroupMember`); every other function still runs its previous revision.
- `leaveGroupConversation` is still deployed. Firebase skipped the delete because the
  updates failed ("Deploys failed. Skipping deletes.").

Honest gap: the quota value gcloud reports for `CpuAllocPerProjectRegion` in europe-west1 is
20000, which does **not** obviously conflict with 7100. I could not reconcile the exact
accounting from the quota API, so the deploy itself is the test of the fix rather than a
calculation I can show. If step 1 does not clear it, the fallback is a quota increase
request, and I will say so rather than keep guessing.

## What the review changed (recorded here because two of my claims were wrong)

`cloud-functions-specialist` passed with 0 blocking, having dumped the compiled
`__endpoint` manifest rather than reasoning about the SDK. It corrected two things:

- **70 gen2 services, not 71.** `onUserDeleted` is a gen1 auth trigger — v2
  `setGlobalOptions` cannot configure it and it consumes no Cloud Run CPU. That also answers
  the open question below about its blank `state`: gen1 reports `status`, not `state`, so the
  blank is the API shape, not a failed deploy. The reservation is ~7000 vCPU, not ~7100.
- **"10 concurrent" was the wrong mental model in my own head.** `concurrency` is a separate
  option defaulting to 80 at cpu >= 1, so the real ceiling is ~800 in-flight requests per
  function. Verified there is no fan-out victim: scheduled sweeps get one invocation per tick,
  notification fan-out is in-process (`MAX_PER_RUN = 200` under one `Promise.all`), and the
  two ingredient triggers that could genuinely queue both carry `retry: true`, so throttled
  events are redelivered rather than dropped.

It also found the change was pinned by no test, which turned out to matter more than it
sounded — see below.

## Step 1 — cap the instances (unblocks the deploy)

1. `functions/src/index.ts`: `setGlobalOptions({ region: "europe-west1", maxInstances: 10 })`,
   with a comment stating the RULE (an unset ceiling reserves 100 per function and the wall
   only appears mid-deploy), not just the current numbers.
1b. `functions/src/__tests__/deploy-manifest.test.ts` (new) pins BOTH invariants against the
   compiled deploy manifest: every gen2 export in `europe-west1`, and every one carrying an
   instance ceiling. The region hazard was previously guarded by a comment in `index.ts` and
   nothing else, and a comment does not redden.
   **The first version of this suite contained a vacuous assertion and the mutation probe is
   the only thing that caught it.** `firebase-functions` does not leave an unset
   `maxInstances` as null — it stores a sentinel object whose `toJSON` renders as `null`, so
   `JSON.stringify` printed "null", `"maxInstances" in endpoint` was true, and `x == null` was
   FALSE. The presence check stayed green under a mutant that stripped the option from all 70
   functions. Now tested as `typeof x === "number"`. Do not "simplify" it back to a null check.
   Probed 2026-08-17: healthy 4/4; ceiling removed reddens the presence check naming all 70;
   region changed reddens the region check naming 64; `index.ts` restored byte-identical
   (md5 compared).
1c. `functions/src/ingredients/on-ingredient-soft-deleted.ts:40` said `setGlobalOptions` "sets
   the region and nothing else" — true when written, false as of this change, and it is the
   recorded BUT-1781 rationale for a local timeout. Rewritten to state the rule. Grepped the
   whole tree for the same phrasing: one occurrence, fixed.
   - Per-function options win over global ones, so any function that later needs more
     concurrency raises its own. None sets `maxInstances` today, so nothing is overridden.
   - Pre-launch, zero users: 10 is far above real demand and doubles as a cost ceiling
     (CLAUDE.md cost principles).
2. `npx tsc --noEmit` in `functions/`.
3. `cloud-functions-specialist` review (commit gate for `functions/src`).
4. Commit, push to main.
5. `firebase deploy --only functions --force --project butlery-app-1`.
   `--force` is required for two reasons, both verified as intended:
   - `onIngredientPropertiesChanged` now carries `retry: true`, which is deliberate and
     documented in its own source with an event-age guard bounding the retry window.
   - it auto-confirms deleting `leaveGroupConversation`, removed on purpose in BUT-1838 and
     replaced by the three group callables. Verified zero callers anywhere in the repo.
6. **Verify per-function `state` from the API, not from `functions:list` names** — a deploy
   that removes Cloud Run services can leave a replacement `FAILED` while the name still
   lists (repo lesson, 2026-08-03). Expect 71 ACTIVE and no `leaveGroupConversation`.
   Note `onUserDeleted` reports an empty `state`; confirm whether it is a 1st-gen function
   (which reports `status`, not `state`) rather than treating the blank as a failure.

## Step 2 — delete the dead functions (after step 1 is green)

Proven with a whole-repo grep, not a sample: for every name below, the only hits outside
`functions/src` are in `.claude/agents/*.knowledge.archive.md`, `tasks/scans/…` and
`tasks/todo.md` — notes, never code. `lib/` has zero, and that includes the admin dashboard,
which lives in this repo (`lib/admin_main.dart`, `lib/views/admin/`) rather than a separate
one.

**2a — one-shot migrations, safe to remove:**
`backfillCanonicalRatings`, `backfillRecipeCommentsDenorm`, `backfillSharedListContributors`,
`bulkMarkForRetagging`, `seedSiteConfigs`.

**2b — admin stat/ops callables with no caller — HER CALL, not mine:**
`getAuditLogStats`, `getCorrectionStats`, `getRetagStatus`, `getDeletedIngredientStats`,
`getUnmatchedIngredientStats`, `getSiteConfigStats`, `analyzeCorrections`,
`reviewLearnedAlias`, `revokeLearnedAlias`.
These are uncalled *today*, but they look like endpoints built for admin-dashboard tabs that
were never wired up. Deleting them is cheap to undo (the code stays in git) but it throws
away work. Default if she does not answer: **keep 2b, delete only 2a.**

For whichever set is agreed: remove the export from `index.ts` and delete the source module,
then `functions:delete` the deployed service. Each removal is a separate commit so one bad
call is one revert.

## Open questions

Blast-radius ranked. Only one, and it is deferrable without blocking step 1:

1. **Does 2b go or stay?** Highest blast radius of the two, because it deletes working
   admin tooling rather than spent migrations. Asked after step 1 ships; default is KEEP.

No architecture-changing unknowns. Assumptions stated: (a) `maxInstances: 10` is above any
real pre-launch demand — the app has no users; (b) the failed deploy left production
consistent, which was verified by reading every function's state, not inferred.

## Step 1½ — a red GDPR test, found on the way, fixed here

`test:request-account-deletion` was RED on main before this change (it came in with
`a329de0f5`, today's salvage commit). It is not caused by this work and it is not a
production defect, but it had to be understood before deploying, because the cascade code it
covers is on main and NOT yet in production — the deploy is what would make it live.

Root cause: the suite's local fake Firestore had no `limit()` on its query object, so the
`chat_groups` and `messages` steps threw `where(...).limit is not a function`. The production
code is correct; real Firestore has `.limit`. But the consequence was real — **those two GDPR
erasure steps were being exercised by nothing in that suite**, and the failure was reported as
"step failed", which reads like a broken cascade.

Fixed by giving the fake a `limit()` (the same precedent the file's own `listDocuments` note
records), and by making the assertion print `result.errors` instead of only the collection
names — the old message sent the reader to the whole cascade rather than to the line that
threw. Suite is 4/4 and the full CF lane is 88/88.

## Acceptance criteria

- [x] `npx tsc --noEmit` clean.
- [x] Full CF unit lane green: **88/88 suites (346s)**, up from 87/88 with
      `test:request-account-deletion` red.
- [x] The new deploy-manifest suite is non-vacuous — mutation-probed both ways, `index.ts`
      restored byte-identical (md5 compared).
- [ ] `cloud-functions-specialist` opened the FINAL bytes and passed (the first review graded
      an earlier version; every later edit un-proves it).
- [ ] `firebase deploy --only functions` exits 0 with zero failed functions.
- [ ] Per-function `state` read back from the API: every function ACTIVE, count matches
      source exports, `leaveGroupConversation` gone.
- [x] `onUserDeleted`'s blank state explained: it is gen1, which reports `status` rather than
      `state`. Not a failed deploy.
- [ ] BUT-1792 closed (its two remaining criteria were the TTL deploy, now done).
