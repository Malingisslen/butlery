# Sprint 2026-07-27 — Selection

Backlog scanned: 118 Backlog + 6 Todo + 0 In Progress + 0 Triage, team Butlery (Linear MCP
live). Two backlog items (BUT-677, BUT-722) carry `onboarding-reserved` and were excluded
from scoring entirely, per instruction.

**Ship-state check first.** The 2026-07-26 sprint's own todo.md ended "STAGED AND
UNCOMMITTED" with all Linear transitions HELD. That work has since shipped: commit
`22e960af3` ("shared-list safety and attribution, GDPR erasure and export completeness,
Swedish word boundaries", 2026-07-27) ran nine specialist review passes over the real diff,
fixed 12 blocking defects, and closed BUT-1675/1681/1683/1686/1691/1696/1698 as Done. Verified
by querying each ticket's current status, not by trusting the commit message alone.

**Obsolete:** **BUT-1703** ("SHIP BLOCKER: no specialist has reviewed the 2026-07-26 sprint
diff") — the exact gap it named (zero specialist review before commit) is what `22e960af3`
closed: its own message documents nine specialist passes (code-reviewer,
firebase-backend-security, cloud-functions-specialist, testing-specialist) over the real
diff. Not auto-closed in Linear this pass (Selection phase only) — flagging for the
implementer to close citing `22e960af3`.

**Superseded, not re-selected (left in Todo, not obsolete — each has more precise successor
tickets already filed for its unmet acceptance criteria):**
- **BUT-1697** ("last changed by" attribution) — `22e960af3` fixed the display-name
  placeholder half; the Auth-handle-fallback and removed-member-residual halves are now
  BUT-1705 (selected below) plus BUT-1716/BUT-1718 (deferred to capacity, see below).
- **BUT-1677** (rules coverage measurement) — the coverage script and workflow shipped in
  `22e960af3`; its two failed acceptance criteria are now the sharper BUT-1707 and BUT-1708
  (both selected below).
Re-selecting the vague parents on top of their precise successors would double-implement
the same scope.

**Premise re-verified against current `main`** for every ticket selected below via targeted
grep/read (not just `git log`): `firebase_shopping_repository.dart:131` still calls
`UserService.currentDisplayName` with no Auth-handle guard (BUT-1705, confirmed live);
`functions/scripts/check-test-registration.js` and `rules-coverage-report.js` exist but
have no test file anywhere in the tree (BUT-1709, BUT-1707); `RecipeTextNormalizer._allUnitsRe`
still builds a raw `\b` (BUT-1713); `.github/workflows/` still has zero `USE_EMULATOR`
references (BUT-1695). All still live — nothing here is already fixed.

Every ticket below was Claude-authored (mostly `firebase-backend-security`/`code-reviewer`
findings from the 22e960af3 review pass, plus the still-open half of the 2026-07-24 rules/CI
review), never human-approved — the mandate column records why each is safe to build anyway.

## Agent A — shopping + account (trust & safety, GDPR)
Area: shopping / account. Router: **full-panel** (Trust & Safety, Security Architect,
Privacy/DPO, Software Architect, Product Manager, FinOps, Legal Counsel, Performance
Engineer, Data Analyst/BI, Database Administrator, Vendor/Procurement — `functions/src/account/account-deletion-cascade.ts`
is a high-stakes hit). Files (deliberately overlapping — kept in one batch so all four land
sequentially without cross-worktree conflicts, same reasoning as the 2026-07-26 sprint):
`lib/repositories/firebase/modules/shopping_repository_routing_module.dart`,
`lib/repositories/firebase/firebase_shopping_repository.dart`,
`lib/services/unified/modules/shopping_list_management_module.dart`,
`lib/models/unified/unified_shopping_list.dart`,
`lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart`,
`lib/viewmodels/collaborative_shopping/*` (member-removal/leave path, read-only for this
batch), `functions/src/account/account-deletion-cascade.ts`,
`functions/src/social/on-profile-updated.ts`, `firestore_collections.dart`,
`test/unit/repositories/firebase/modules/shopping_repository_routing_module_test.dart`,
`functions/src/__tests__/request-account-deletion.integration.test.ts`.

- [!] **BUT-1723** [Tier C][build] Personal list conversion loses every item after a
  restart, and deletes the source list before the copy is verified — silent data loss on a
  path the user can reach today. **requiresPlanMode: true** (Urgent + `lib/repositories/`).
  Router: full-panel.
  - Fix: fan the items out to the subcollection in the personal-create branch (or call
    `addItemsBatch` after create); do not delete the source list until the copy reads back
    from Firestore, not the cache.
  - Acceptance:
    1. Converting a shared list with items to personal, then forcing a reload from
       Firestore (not cache), still shows every item.
    2. A test reads back through `readAll()`, not the in-memory cache.
    3. The source list is not deleted before the copy is confirmed readable.
    4. `firebase-backend-security` reviews the diff.

- [!] **BUT-1719** [Tier C][build] `renameList` can resurrect a removed member's edit
  rights from a stale offline cache — the same whole-entity-`set(merge:true)` shape BUT-1683
  already narrowed on the mutate path, missed on the rename path. **requiresPlanMode: true**
  (High + security label + `lib/repositories/`). Router: full-panel.
  - Fix: give `updateCollaborativeList`'s whole-list path the same narrowing
    `ShoppingOfflineWriteModule.cachedBasePayload` already does for item mutations — a
    targeted `update()` restricted to caller-changed keys, or refuse the write when
    `docSnapshot.metadata.isFromCache` is true.
  - Acceptance:
    1. An offline `renameList` by the owner queues a write that carries no `ownerId`,
       `memberPermissions` or `createdAt`.
    2. A test reddens if the write reverts to `set(merge: true)` (mirror the existing
       cached-base-write test in `shopping_repository_routing_module_test.dart`).
    3. `firebase-backend-security` reviews the diff.

- [!] **BUT-1705** [Tier C][build] Shared-list attribution writes the Firebase Auth real
  name (not the profile name) when the profile is unloaded, and a removed member's uid/name
  survive account deletion because the cascade and the residual probe both key on current
  membership only. **requiresPlanMode: true** (High + account/GDPR sensitive domain).
  Router: full-panel.
  - Fix: resolve the stamped name from `userService.currentUserProfile` with no Auth-handle
    fallback (drive a test through the *production* wiring, not an injected resolver, with
    an empty profile). Widen the cascade + residual probe to also match
    `lastActivityByUserId`/`addedByUserId`/`purchasedByUserId == uid` regardless of current
    membership. Treat `''` the same as null in `shopping_sharing_status_dialog.dart`.
  - Acceptance:
    1. The production attribution write path never falls back to the Auth `displayName`,
       proven with an empty-profile test on the real wiring.
    2. The cascade + residual probe reach list- and item-level attribution fields by uid
       match, not membership; a test covers a removed (non-member) deleted user.
    3. `shopping_sharing_status_dialog.dart` shows no empty "Av:" row for a blank name.

- [!] **BUT-1725** [Tier C][build] GDPR erasure misses shared lists the user was REMOVED
  from before deleting their account — their uid and full name stay on every item forever,
  and the residual canary reports clean because it uses the same membership predicate as the
  deleter. **requiresPlanMode: true** (High + GDPR/account sensitive domain regardless of
  tier). Router: full-panel.
  - Fix (recommended option from the ticket): add a denormalized `contributorUserIds`
    array (arrayUnion on every item write), query it with `array-contains` in both the
    deleter and the residual probe, plus a one-off backfill for lists already in this state.
  - Acceptance:
    1. A user removed from a shared list before deleting their account leaves no uid/name on
       that list's items.
    2. `probeResidualData` can see the residual — the deleter stays a strict superset of
       every probe leg.
    3. An emulator test seeds exactly this state (rows added, member removed, account erased).
    4. `cloud-functions-specialist` and `firebase-backend-security` both review the diff.

## Agent B — parsing (Swedish word boundary, remaining sites)
Area: parsing / import. Router: single (Data/Integrations Engineer, FinOps,
Monetization). Files: `lib/services/import/cache/recipe_text_normalizer.dart`,
`lib/services/import/parsers/recipe_section_detector.dart`,
`test/.../content_fingerprint_golden_test.dart`, `docs/architecture/ACCEPTED_DEVIATIONS.md`,
`.claude/rules/accepted-deviations.md` (disjoint from every other batch).

- [x] **BUT-1713** [Tier A][build] Parse-cache fingerprint deletes Swedish letters — the raw
  `\b` in `RecipeTextNormalizer._allUnitsRe` treats `ö`/`å` as word boundaries, so
  `"2 dl mjöl"` normalizes to `"mjö"` and `"vitkål"` to `"vitkå"`, corrupting the parse-cache
  key. **requiresPlanMode: true** (High priority). Router: single.
  - Fix: swap `_allUnitsRe` onto `SwedishWordBoundary` (shipped this cycle at
    `lib/utils/text/swedish_word_boundary.dart`); regenerate the golden fingerprint file in
    the same commit, stating the cache-invalidation consequence in the body.
  - Acceptance:
    1. `_allUnitsRe` uses `SwedishWordBoundary`, not a raw `\b`.
    2. Tests pin `"2 dl mjöl"` → `"mjöl"`, `"vitkål"` → `"vitkål"`, plus one å/ä/ö case per
       single-letter unit (`l`, `g`).
    3. The golden fingerprint file is regenerated in the same commit; the commit body states
       the cache-invalidation consequence.

- [!] **BUT-1714** [Tier A][build-review] Component headings with Swedish letters are
  rejected (`Rödkål:`, `Mjöl:`, `Öl:`) while `Mjölk:` is accepted — same ASCII-`\b` family,
  deliberately left alone by BUT-1691 because the safe fix direction is genuinely ambiguous
  on an allergen app. **requiresPlanMode: true** (High priority + allergen-safety adjacent).
  Router: single.
  - **Signoff reason:** whether a colon-terminated single gluten word (`Mjöl:`, `Råg:`,
    `Öl:`) becomes a stripped heading (consistent with `Mjölk:`/`Deg:`, but moves it out of
    the ingredient list allergen tagging reads) or stays an ingredient line (inconsistent,
    but never strips a gluten source from the tagged list) — a real allergen-safety product
    call. Build the conservative default (keep as ingredient / do not migrate the boundary)
    and record the decision either way.
  - Acceptance:
    1. The decision is recorded in `docs/architecture/ACCEPTED_DEVIATIONS.md` +
       `.claude/rules/accepted-deviations.md` in the same edit, whichever way it goes.
    2. If repaired: a test proves no gluten-bearing line disappears from the flat ingredient
       list for `Mjöl:`, `Råg:`, `Öl:`, `Rödkål:`. If left as-is: the `Mjölk:`/`Deg:`
       inconsistency is documented at the site.
    3. No behavior change to the already-migrated `_noWordAfter` guard from BUT-1691.

## Agent C — backend / CI test-infrastructure (the guard-testing-the-guard chain)
Area: backend (tooling/CI, not `lib/` or `functions/src/` production code). Router: single
(DevOps/SRE, QA/Test Engineer, Release/App-Store Compliance, Vendor/Procurement). Files:
`functions/scripts/rules-coverage-report.js`, `functions/scripts/check-test-registration.js`,
`.github/workflows/cloud-functions-unit.yml`, `.github/workflows/firestore-rules.yml`,
new `.test.ts` files for both scripts, `dart_test.yaml` (disjoint from every other batch).

- [!] **BUT-1707** [Tier A][build] The rules-coverage gate (BUT-1677) is silently
  bypassable: a single-line `match` block parses to zero blocks (invisible to the gate), and
  a brand-new world-readable (`allow read: if true`) block is wrongly exempted alongside a
  genuine constant-deny block. **requiresPlanMode: true** (High priority). Router: single.
  - Fix: fixture-driven test proving both AC2 halves (untested block fails, moved block
    passes); handle single-line `match` blocks in `parseMatchBlocks`; distinguish a
    constant-deny body from a constant-allow body in the exemption; assert the base-ref /
    `fetch-depth: 0` behavior rather than eyeballing it; wire the test into an npm script a
    CI lane runs.
  - Acceptance:
    1. A fixture test proves an added-and-untested match block fails the job, and a
       re-indented/moved existing block does not.
    2. A single-line `match ... { ... }` block is parsed and attributed correctly.
    3. A new constantly-permissive (`allow ...: if true`) block fails the gate regardless of
       `exprTotal`, distinct from a constant-deny block.

- [x] **BUT-1709** [Tier A][build] The check-test-registration guard (BUT-1675) itself has
  no test — three of its four acceptance criteria are unproven negative-path assertions,
  the exact failure mode BUT-1675 was written to prevent, reproduced one level up.
  **requiresPlanMode: true** (High priority). Router: single.
  - Fix: fixture-driven test over synthetic trees asserting non-zero exit + offending
    filename for the missing-`test:*`-script case, the missing-rules-`paths:` case, and the
    unreferenced-`UNREGISTERED_OK` case; assert a clean tree exits 0; wire the guard and its
    test into a lane the guard itself would flag if unwired.
  - Acceptance:
    1. Fixture test asserts non-zero exit + filename for each of the three negative-path
       criteria (AC1, AC2, AC4 from BUT-1675).
    2. The same test asserts a clean tree exits 0.
    3. The guard script and its new test are registered in the lane the guard itself checks.

- [!] **BUT-1708** [Tier A][build-review] The rules-coverage gate only fails on *newly
  added* untested blocks — it says nothing about the standing debt (an unknown share of the
  108 parsed blocks has never been exercised). **requiresPlanMode: false** (Medium, no
  security label; router tier single). Router: single.
  - **Signoff reason:** whether the untested-block count becomes a ratchet (must not
    increase, reddens main on standing debt) or stays report-only for now — a real
    CI-strictness tradeoff. Default to report-only (safer, no new red builds) and flag for
    her call.
  - Acceptance:
    1. Each rules-coverage run prints the absolute untested-block count and the total
       (e.g. "untested blocks: 37 / 108").
    2. The count is persisted per run (job summary or committed JSON) so the trend is
       visible over time.
    3. The ratchet-vs-report-only decision is recorded, defaulting to report-only.

- [!] **BUT-1695** [Tier C][build] The emulator test lane runs in NO CI pipeline — three
  integration tests, including the BUT-1665 concurrent-writer proof, execute zero times ever.
  `FakeFirebaseFirestore.runTransaction` is a no-op passthrough, so the shared-list
  transaction's headline atomicity guarantee is proven only by inspection, never by a real
  emulator. **requiresPlanMode: true** (High priority; touches CI + emulator). Router:
  single.
  - Fix: add a CI leg running `flutter test test/integration --dart-define=USE_EMULATOR=true`
    against the Firestore emulator (harness already exists); confirm the BUT-1665
    concurrent-mutation integration test passes there and genuinely fails when the
    transaction is removed; declare the `firebase` tag in `dart_test.yaml`.
  - Acceptance:
    1. A CI leg runs `test/integration` against the real Firestore emulator.
    2. The BUT-1665 concurrent-writer integration test passes on that leg AND is proven to
       fail when the transaction is stripped (mutation-tested, not just green).
    3. `dart_test.yaml` declares the `firebase` tag; no more tag-warning noise.

## Deferred to capacity (not selected this sprint — clear mandate, held back only because
their files overlap Agent A's already-large fileset and a 5th/6th ticket risks the agent
timeout the automation-proposals rule warns about)

- **BUT-1716** — the OTHER shared-shopping repository (`firebase_shared_shopping_repository.dart`)
  stamps no attribution at all; same file family as BUT-1705/1719. Next sprint's Agent A.
- **BUT-1706** — shared shopping lists have zero rules-test coverage; `_requireSelfOwnedCreate`
  mirrors only 1 of 3 create conjuncts. Same `firestore.rules`/routing-module family.
- **BUT-1718** — a household member cannot leave a shared list (rules deny self-removal) —
  build-review, 3-option product call, needs the rules change reviewed alongside BUT-1706.
- **BUT-1722** — collaborative-screen failed edit still shows nothing (the unified screen
  got this fix, the collaborative one didn't). Small, but same viewmodel family as Agent A.
- **BUT-1724** — three dead/wrong-path reads of the retired `shopping_lists` collection.
- **BUT-1701** — remaining implicit-default GDPR export caps (blocks, memberships,
  categories, reports, pings). Medium priority, well-scoped, no blocker — just capacity.
- **BUT-1720** (parts B & C) — account-deletion accumulate-then-throw needs a failure-
  injection test; two literal-string cleanups. Same `account-deletion-cascade.ts` file.

## Needs your call (not built this sprint — carried forward, comments already on file)

- **BUT-1693** — Let a household member share their allergy list (BUT-1663 Part 2).
  `need-malin`, real feature with a consent/UX layer.
- **BUT-1480** — Unify the two URL import pipelines. `need-malin`, carried forward.
- **BUT-1323** — "Who's eating" per-day presence EPIC (DIFFERENTIATOR). Too large/speculative
  for an autonomous pick; recommend an `/interview` pass.
- **BUT-880, BUT-1502, BUT-1557, BUT-1179, BUT-1368, BUT-863, BUT-1445, BUT-1649, BUT-1636,
  BUT-1361** — the standing `need-malin` manual-QA / compliance-diagnosis backlog, unchanged
  this sprint.

## Post-sprint steps (to run after implementation)

1. `dart analyze --fatal-infos` + `npx tsc --noEmit -p functions` on the full tree.
2. File follow-up Linear tickets for every deferred sub-scope before commit.
3. Commit through the gate: code-reviewer on all `.dart`, firebase-backend-security on
   Agent A's repository/service files, cloud-functions-specialist on Agent A's
   `functions/src` touches, firestore-rules-tester only if `firestore.rules` itself changes
   (it doesn't in this sprint's scope).
4. Push (push does NOT trigger deploy in this repo per `shared-plugin.json` —
   `pushTriggersDeploy: false` — but still the release record).
5. Transition tickets: Tier A build + all-pass → Done. Tier B/C or build-review or any
   failed/unclear criterion → In Review + plain-language comment + PushNotification.
6. Close BUT-1703 citing `22e960af3`'s nine specialist passes as the resolving evidence.
7. Re-check `docs/onboarding/workflow-map.stale` — none of this sprint's flows look
   map-relevant (shopping/account/GDPR internals, parsing internals, CI tooling), but verify
   before commit per CLAUDE.md.

## Outcome — graded 2026-07-28 (STAGED AND UNCOMMITTED)

Legend: `[x]` verified clean · `[!]` code landed but a criterion failed or needs Malin's sign-off.

| Ticket | correctness | data-safety | intent | Disposition | The diff that proves it |
| --- | --- | --- | --- | --- | --- |
| BUT-1713 | pass | pass | pass | **Done** (pending commit) | `recipe_text_normalizer.dart` + re-pinned `content_fingerprint_golden_test.dart`; Swedish letters survive the unit-regex strip |
| BUT-1709 | pass | pass | pass | **Done** (pending commit) | `functions/scripts/__tests__/check-test-registration.test.js` + `test:script-test-registration` present in the 77-suite unit lane; per-criterion negative fixtures |
| BUT-1723 | pass | **fail** | pass | **In Review** | Items fan out to the subcollection on create; `confirmPersistedItemCount` gates the source delete on a non-cache readback. Data-safety fail is *marker coverage only* — `firebase-security-done.marker` pins pre-change blobs and omits `shopping_repository_query_module.dart` |
| BUT-1719 | pass | **fail** | pass | **In Review** | Narrowed `update()` + per-key `FieldValue.delete()`; mutation to `set(merge:true)` reddens 2 tests. Fail: `baseIsCached` checks the freshness of the wrong copy — see BUT-1726 |
| BUT-1705 | pass | **fail** | pass | **In Review** | `profileDisplayName` (no Auth fallback) at both persisting call sites; cascade + residual probe widened to `contributorUserIds`/`lastActivityByUserId`. Fail: reachability depends on a trail absent on all pre-existing lists until the backfill runs — BUT-1731 |
| BUT-1725 | pass | **fail** | **fail** | **In Review** | Contributor trail at the `mutateCollaborativeList` chokepoint + `createCollaborativeList`; new `keepsContributorTrail()` rule; backfill callable. Fails: zero rules tests for the collection (BUT-1728), no reviewer saw the diff, `updateCollaborativeList` unions nothing (BUT-1733) |
| BUT-1714 | **fail** | pass | **fail** | **In Review — product call** | Gluten carve-out in `RecipeSectionDetector` + `swedish_line_classifier` + new `heading_word_lists.dart`. Fails: the twin hinge `TextImportStrategy._ingredientSubHeading` is untouched, so the real OCR path still strips `Råg:`/`Öl:`/`Mjöl:` (BUT-1727). `Rödkål:` became a heading — Malin has not signed that off |
| BUT-1707 | **fail** | **fail** | **fail** | **In Review** | Gate hardening + first tests for `rules-coverage-report.js`. Three holes reproduced (constant-allow with `exprHit>0`, compact formatting, string-unaware `stripComments`) and no moved-block fixture — BUT-1729 |
| BUT-1708 | — | — | — | **In Review — product call** | Untested-block count built as report-only. Whether it becomes a ratchet is a CI-strictness decision only Malin makes |
| BUT-1695 | **fail** | pass | **fail** | **In Review** | Only AC3 landed (`firebase` tag in `dart_test.yaml`). No CI leg passes `--dart-define=USE_EMULATOR=true`; the reproduced `PlatformException` means the flag would redden, not cover. Successor: BUT-1730 |
| BUT-1703 | — | — | — | **Re-scoped, NOT closed** | Declared obsolete in Phase 1; the sweep found every marker in `.claude/state/` is the previous sprint's, pinning stale blob shas. The condition it names is live again on this very diff |

**Ship state:** analyze clean (`No issues found!`, 265 s), 61 files staged, **not committed** — no
specialist reviewer has seen this diff and `firestore.rules` changed, so five gates are
outstanding. Markers deliberately NOT written. See BUT-1703 for the exact unblocking checklist.

**Follow-ups filed 2026-07-28:** BUT-1726 (stale-base member resurrection/revocation),
BUT-1727 (gluten carve-out misses the OCR path), BUT-1728 (shared-list rules tests),
BUT-1729 (coverage-gate holes), BUT-1730 (real emulator lane), BUT-1731 (backfill run +
soak removal), BUT-1732 (Art-15 export gap), BUT-1733 (`updateCollaborativeList` union),
BUT-1734 (member-row tests + sibling dialog), BUT-1735 (conversion message mapping),
BUT-1736 (remaining Auth-name persisters), BUT-1737 (cache parser version),
BUT-1738 (permission-guard tests), BUT-1739 ("ca 2 dl grädde").

---

# Archived — 2026-07-26 sprint (10 tickets, shipped 2026-07-27 in `22e960af3`)

Backlog scanned: 104 Backlog + 4 Todo + 0 In Progress + 0 Triage, team Butlery (Linear MCP
live). No ticket carries `onboarding-reserved` in the selected set (two backlog items —
BUT-677, BUT-722 — carry it and were excluded from scoring entirely, per instruction).

**Obsolete:** BUT-1670 (shopping analytics) — built and shipped partially in `c0989a3a3`/
`38d3a715e`, graded FAIL at Phase 2.7 (AC2 unmet, AC1 half met, zero tests). Its exact
remaining scope was already re-filed with corrected acceptance criteria as BUT-1681.
Closed as Canceled/duplicate-of-BUT-1681, comment posted.

**Premise re-verified against current `main`** for every ticket below via targeted grep
(not just `git log`) before selecting: BUT-1696's `createCollaborativeList` still has no
escalation guard, BUT-1697's `account-deletion-cascade.ts` still only scrubs item-level
fields, BUT-1698's `social_export_manager.dart` still emits no `truncated` key,
BUT-1691's `ingredient_line_detector.dart` still uses raw `\b` over single-letter tokens
(`l`, `g`), BUT-1675/1676/1677's guard scripts don't exist yet, BUT-1685's
`menu_content_widgets.dart` still only branches on `!= singleUser`, BUT-1681's
`addItemsFromRecipe` source tag still has zero production callers and
`recipe_shopping_handler.dart` still calls the unlogged `addItemsBatch`. All still live —
nothing here is already fixed.

Every ticket below was Claude-authored (mostly the BUT-1679 post-hoc specialist review of
the 2026-07-25 sprint, some from the 2026-07-24 test-infra review), never human-approved —
the mandate column records why each is safe to build anyway.

## Agent A — shopping (trust & safety + analytics)
Area: shopping. Files: `lib/repositories/firebase/modules/shopping_repository_routing_module.dart`,
`lib/repositories/interfaces/shopping_repository.dart`, `lib/services/unified/unified_shopping_service.dart`,
`lib/services/unified/modules/shopping_item_management_module.dart`, `lib/models/unified/unified_shopping_list.dart`,
`lib/views/unified_shopping_view.dart`, `lib/viewmodels/unified_shopping_viewmodel.dart`,
`lib/services/shopping/menu_shopping_list_generator.dart`, `lib/views/recipe_detail/handlers/recipe_shopping_handler.dart`,
`functions/src/account/account-deletion-cascade.ts` (disjoint from every other batch).
**Note:** BUT-1681's fix site (`unified_shopping_service.dart`) overlaps BUT-1696's fix
site in the same file — kept in one batch/agent deliberately so the two land sequentially
in one PR instead of conflicting across parallel worktrees.

- [x] **BUT-1683** [Tier C][build-review] Shared shopping list: the offline `_mutateFromCache`
  fallback still allows a lost update (the client-merge BUT-1665 exists to close), and the
  new `updateCollaborativeList` authorization change shipped with no
  firebase-backend-security / firestore-rules-tester review. **requiresPlanMode: true**
  (High priority + security label + `lib/repositories/`). Router: single — Trust & Safety,
  Security Architect, Software Architect.
  - **Signoff reason:** whether to narrow the offline path (reject cache-based edits of an
    existing row, only allow adds) or accept the lost-update window as a documented
    tradeoff in `ACCEPTED_DEVIATIONS.md` — a real availability-vs-consistency product call.
    Default the build to the conservative option (narrow the window) but flag it.
  - Acceptance:
    1. The offline `_mutateFromCache` path either narrows to reject edits of an existing
       item, or is left as-is with a new dated `ACCEPTED_DEVIATIONS.md` entry — not left
       silently undocumented either way.
    2. `updateCollaborativeList`'s privilege-escalation and edit-rights checks get an
       actual firebase-backend-security + firestore-rules-tester review as part of this
       diff's commit gate (not deferred a second time).
    3. The BUT-1665 online transactional concurrent-edit test still passes unchanged.

- [x] **BUT-1696** [Tier C][build] Shared shopping list: a rejected edit silently reverts
  with no message; the offline replay can't tell a permission denial from network noise; a
  dead branch masks a wrong-exception-type bug; `createCollaborativeList` is the one write
  path with no escalation guard.
- [x] **BUT-1681** [Tier A][build] Shopping analytics wiring.
- [x] **BUT-1698** [Tier C][build] GDPR export: `social_export_manager.dart` truncation flags.
- [x] **BUT-1691** [Tier A][build] Swedish word boundary in `ingredient_line_detector.dart`.
- [!] **BUT-1675** [Tier A][build] CI test-registration guard.
- [!] **BUT-1683/1697/1686/1677** graded fail at Phase 2.7 — see outcome table; all shipped
  in `22e960af3` (partial) with sharper follow-ups BUT-1705/1706/1707/1708/1709/1716/1718/1719
  carrying the residual scope, now processed above in the 2026-07-27 sprint.

*(Full ticket bodies, deviation log and outcome table from this sprint trimmed here for
length — see git history of this file for the complete 2026-07-26 record; nothing in the
trimmed portion is still actionable, it is fully superseded by the 2026-07-27 sprint above.)*

---

# Archived — 2026-07-25 sprint (10 tickets + BUT-1679 ship remediation) and 2026-07-23 sprint (BUT-1655)

Trimmed for length — both fully shipped (`38d3a715e`, `c0989a3a3`, `d057b6c2d`). See prior
git history of this file for the complete record if needed.
