# SALVAGE 2026-08-17 — finish BUT-1801, re-review the held batch, ship the five that passed

**Approved by Malin, 2026-08-17: "rädda och arbeta enligt din plan."** She was shown the
state first: five tickets verified 3/3, one failed 3/3, everything loose in the working tree
with a byte-identical copy in `stash@{0}` / `5a19f29bc`, plus a third copy as patch files
outside the repo. She was also told, before deciding, that the review ledger shows several
files were passed by reviewers that never opened them — that is why step 3 below is not
optional.

## What the held batch contains

One batch, six tickets, 28 changed files. Verification verdicts from the run:

| Ticket | Verdict | What it does |
| -- | -- | -- |
| BUT-1832 | pass 3/3 | poll votes move to `messages/{id}/poll_votes/{voterUid}` |
| BUT-1835 | pass 3/3 | erasure reaches the new vote shape |
| BUT-1833 | pass 3/3 | two dead rules helpers deleted |
| BUT-1792 | pass 3/3 | four TTL policies incl. `activeUsers.expiresAt` |
| BUT-1812 | pass 3/3 | auto-id `shared_content` rows per share |
| BUT-1801 | **fail 3/3** | recipe reads on a collection that does not exist |

## Step 0 — the verifier's verdict re-derived, because it is a hypothesis

The verifier failed BUT-1801 saying "only 1 of the 6 named sites was fixed". Checked each
named site against `git show HEAD:` rather than trusting either the ticket or the verdict:

- `admin/bulk-retag.ts` — already `collectionGroup("recipes")` at HEAD. **Correct shape; the
  ticket is stale here.**
- `analytics/compute-feature-retention.ts:351` — already `users/{userId}/recipes` at HEAD.
  **Stale.**
- `ratings/canonical-rating-aggregation.ts:157` — already `users/{uid}/recipes/{recipeId}`
  at HEAD. **Stale.**
- `recipe_gdpr_export_operations.dart` — **fixed by this batch**, and the fix is larger than
  the ticket described: the top-level probe threw `permission-denied` inside the SAME
  try/catch as the personal-recipes read, so every Art. 15 bundle lost its whole recipe
  section to `recipes-export-failed`. Removing it makes the export work at all.
- `account/account-deletion-cascade.ts:477-478` — **untouched, and this is the real
  remainder.** Line 477 reads `users/{uid}/recipes` and does erase the recipes, so Art. 17
  itself is NOT broken; the verifier's data-safety conclusion overstates it. Line 478 is a
  dead read of the non-existent top-level collection.

So three of six were never broken, one is fixed, and the true defect is one the ticket does
not name:

**`probeResidualData` counts `recipes` on the top-level collection.** The post-cascade
residual check loops a fixed list of collections with `.where("userId","==",uid).count()`,
and `"recipes"` is the first entry. That collection has no documents, so the probe returns
zero every time — a permanent all-clear that is true by accident and would stay true if the
deletion ever stopped working. The file's own comment two blocks down names this exact class
("the realtime_recipes wrong-field trap"). A blind safety net is worse than none.

## The work

1. **`deleteRecipes`** — drop the dead top-level read (line 478). Correctness-neutral, one
   fewer query per deletion, and it removes the line the probe was copied from.
2. **`probeResidualData`** — take `"recipes"` out of the userId-keyed loop and probe
   `users/{uid}/recipes` directly with `.count()`. Deliberately NOT a
   `collectionGroup("recipes")` query: that would need a COLLECTION_GROUP index this repo
   does not declare for `userId`, and it assumes recipe documents carry a top-level `userId`
   field, which is not established. A direct subcollection count needs no index and no field
   assumption.
3. **Re-review the WHOLE staged diff with the real specialists** — not the sprint's ledger.
   The run recorded that `code-reviewer` and `integration-reviewer` each passed 12 files
   they never opened, `firebase-backend-security` 4, and `firestore-rules-tester` 2
   (including `firestore.rules` itself). Those verdicts do not cover the bytes about to
   ship. Batch to ≤3 files per agent per the repo's own advisory.
4. **Re-review the fix from step 1-2 on its own diff** — the fix round is the last thing to
   touch the bytes and therefore the least reviewed.
5. **Commit and push.** One commit; the five that passed plus BUT-1801 now complete.

## Acceptance

1. `functions/src/account/account-deletion-cascade.ts` has no read of a top-level `recipes`
   collection anywhere, `deleteRecipes` or probe. Proven by grep, pasted.
2. A test proves the residual probe SEES a recipe left behind — i.e. it reddens if the
   deletion step is removed. A probe that cannot fail is the bug being fixed.
3. `npx tsc --noEmit` clean and the CF unit suite green, counts pasted.
4. `dart analyze --fatal-infos` clean on the changed Dart files.
5. Every gated file named in a specialist review that actually opened it.

## Open questions

None architecture-changing. Assumptions stated and checkable: recipes live only at
`users/{uid}/recipes` (established by `firestore.rules` having no top-level `recipes` match
block, and by three call sites at HEAD already using that path); and the residual probe is
meant to be a real check rather than a formality (established by the file's own comment
about the wrong-field trap it was written to avoid).

## Explicitly NOT in this salvage

The nine tickets three of the four sprint agents never built (BUT-1869, BUT-1870, BUT-1857,
BUT-1853, BUT-1872, BUT-1873, BUT-1874, BUT-1860) and the BUT-1780 rebuild. They have no
code in the tree; rebuilding them is a separate run, not part of rescuing this batch.

---

# SPRINT 2026-08-16 (continued) — the stalled sprint's decisions, now applied

Phase 1 (Selection) only. Linear is up. This is a re-selection, not a fresh scan: the
previous run today selected 11 tickets, built one (BUT-1780) badly, shipped nothing, and
stashed everything. Malin then answered every open question on all 11 tickets plus their
five review-round offshoots, in comments on the tickets themselves (dated 2026-08-16
18:07-18:10, titled "Malins beslut" / "Grönt ljus från Malin" — distinguished from the
sprint's own "Sprintnotis" comments by content, since Linear attributes every comment to
her account regardless of author). This run reads those decisions and turns them into a
buildable plan. **15 tickets, 4 batches, N sized above the usual 6-10 because today's
backlog volume is genuinely this large — a stalled sprint's full decided backlog, not
padding.**

## Step-0 obsolete check

- **BUT-1845** — confirmed **Done** in Linear already (measured mid-vocabulary option,
  closed 2026-08-16 18:28, commit `8343d74e5`). No action.
- **BUT-1838** — NOT obsolete, NOT closeable. See `alreadyDecided` below — one of its three
  decisions is still unexecuted and needs console access.

## Already decided (Malin's comments, applied verbatim)

Full quotes live on the tickets; this table is the summary. All fifteen are `build` —
she resolved every open design question, so none of the code choices below are this
session's judgment call.

| Ticket | Her call | Applied as |
|---|---|---|
| BUT-1780 | `showOnCards` default → **false**; badges on Mina Recept list + ingredient search ONLY (not grid, not archive import); UNKNOWN filtered in `CompactAllergenRow` too; test must find the rendered badge, not read a constructor flag | build |
| BUT-1869 | Fold into the BUT-1780 rebuild — "Ta den här" | build (same batch) |
| BUT-1870 | Must be resolved before BUT-1780 grows the file further | build (same batch) |
| BUT-1832 | Move votes to `messages/{messageId}/poll_votes/{voterUid}`; ship WITH BUT-1835 in one change | build |
| BUT-1835 | Same change as BUT-1832; cascade leg must target the new subcollection shape, not the old inline array | build |
| BUT-1833 | Delete `isDocumentOwner` + `isAddingSelfToList`; ship with BUT-1832/1835 (same file, same gate) | build |
| BUT-1801 | Green light, same reply as BUT-1835/1833; build the six-site fix per the ticket's own 3 ACs | build |
| BUT-1792 | All four TTL policies including presence (`activeUsers.expiresAt`, not `expireAt`); never `false`, never `--force` | build |
| BUT-1812 | Option 2 — auto-id `shared_content` docs, not a widened rule; coordinate migration with BUT-1809, don't run it here | build |
| BUT-1857 | (no design question — just unbuilt; corrected file paths recorded on the ticket) | build |
| BUT-1853 | (no design question — security bug, unbuilt) | build |
| BUT-1872 | Filed by the post-sprint sweep after BUT-1853's deviation log named it | build |
| BUT-1860 | (no design question — test-only, unbuilt) | build |
| BUT-1873 | **No price field** — remove `_priceController` from both dialogs entirely | build |
| BUT-1874 | (no design question — real bug, `copyWith` null-means-unchanged trap) | build |
| BUT-1838 | Decisions 1+2 (group-as-object, memberSince) confirmed built. **Decision 3 (delete pre-existing group conversations) still open** — waits on an admin count of `conversations` docs + her disposal call | **blocked**, see below |

**BUT-1838 detail (blocked, not built, not re-asked):** her 2026-08-16 18:29 comment is
explicit: count `conversations` documents (and how many lack `groupId`), show her the
number, get her decision (delete now vs. leave until launch) in writing, then execute and
re-verify. That's Tier D (needs production/console access) — no code to write here. Left
exactly as-is: still Backlog, still open, not transitioned, not closed. Do not apply the
BUT-1839 "app isn't live, it's all test data" reasoning to this by analogy — her own
comment calls that out as the exact shortcut to avoid.

## Needs Malin (genuinely undecided, not touched this round)

- **BUT-1480** — unify the two URL-import pipelines. Six separate comments back to
  2026-07-22, every one hers, every one "not yet, real regression risk, no urgency." No
  comment reverses that. Recommendation unchanged: worth doing as its own dedicated,
  tested migration pass; not a sprint drive-by. Left in Todo where it's sat for weeks;
  not rebuilt, not re-asked.
- **BUT-1875** (new today, follow-up to BUT-1845) — import writes English meal-type
  values, edit screens offer Swedish. This is the same "what vocabulary, and how tolerant"
  product question BUT-1845 flagged for the closed-enum follow-up, now needing its own
  answer for the import side. Recommend: fold into whatever follow-up ticket eventually
  picks the closed-enum vocabulary for BUT-1845's tolerant fix, rather than deciding the
  import half in isolation.

## Agent A — backend-rules-social (6 tickets, Tier C, full-panel router tier)

Router: `firestore.rules` + `account-deletion-cascade.ts` → full-panel (Security
Architect, Trust & Safety, DBA, Privacy/DPO, Legal, Product, Software Architect, FinOps,
Vendor/Procurement, Customer Support). `panelPolicy: park` — build it, land in In Review,
let the specialist gates + Malin's own review substitute for the panel an unattended run
can't convene. `requiresPlanMode: true` on all six (full-panel).

**All six share `firestore.rules` and/or `account-deletion-cascade.ts` — one batch, one
worktree, sequenced commits inside it.** BUT-1812 was originally scoped to a separate
agent, but its rules rewrite (confirmed in the ticket body and Malin's own comment) touches
the same file, so it moved in here to keep batches file-disjoint.

- [ ] **BUT-1832** — Poll voting denied for everyone but the creator.
  Files: `firestore.rules`, `lib/repositories/firebase/modules/message_mutation_module.dart`,
  `functions/src/__tests__/*-rules.test.ts`.
  Change: move votes to `messages/{messageId}/poll_votes/{voterUid}` (doc id == voter);
  separate `allow update` statements per branch, never OR'd; `metadata` read via
  `.get(k,{}) is map ? ... : null` (the BUT-1788 null-trap); ship
  `markMessageAsRead`/`batchMarkAsDelivered` in the same change (same rule, same trap).
  Acceptance:
  1. Any participant can cast a poll vote (not just the creator); writes land in
     `messages/{id}/poll_votes/{voterUid}`, doc id == voter uid.
  2. `markMessageAsRead` and `batchMarkAsDelivered` succeed for non-sender participants.
  3. A rules test proves a voter cannot delete or overwrite another voter's vote doc.
  4. No `allow update` branch is combined with another via `||`.

- [ ] **BUT-1835** — Poll voter uids survive account erasure. Ships in the SAME change as
  BUT-1832 (her explicit instruction — splitting them widens the leak in between).
  Files: `functions/src/account/account-deletion-cascade.ts`.
  Change: cascade rewrites `metadata.poll.creatorId` → `"deleted"` and removes/anonymises
  the deleted user's `poll_votes/{uid}` docs — against the NEW subcollection shape BUT-1832
  ships, not the old inline `voterIds` array.
  Acceptance:
  1. Account deletion removes/anonymises the deleted user's `poll_votes` doc(s) across every
     poll they voted in.
  2. `metadata.poll.creatorId` is rewritten to `"deleted"` when the creator's account is
     erased.
  3. A CF test seeds a vote in the shipped `poll_votes` subcollection shape (not the old
     array) and asserts it's gone/anonymised post-deletion.

- [ ] **BUT-1833** — Two dead rules helpers, one a trap. Ships with BUT-1832/1835 (same
  file, same gate, one deploy instead of two — her instruction).
  Files: `firestore.rules`.
  Change: delete `isDocumentOwner` (~line 68) and `isAddingSelfToList` (~line 83).
  Acceptance:
  1. Neither helper appears in `firestore.rules` afterward.
  2. Full rules test suite still passes (no behaviour change).

- [ ] **BUT-1801** — Six sites read recipes from an empty top-level `recipes` collection.
  Files: `functions/src/admin/bulk-retag.ts`, `functions/src/analytics/compute-feature-retention.ts`,
  `functions/src/ratings/canonical-rating-aggregation.ts`,
  `functions/src/account/account-deletion-cascade.ts`,
  `lib/repositories/firebase/modules/recipe_gdpr_export_operations.dart`,
  `firestore.indexes.json`.
  Acceptance (ticket's own three, verbatim):
  1. All six sites read a path that real recipe documents exist at.
  2. A seeded test proves the GDPR export returns a recipe and the deletion cascade deletes
     one.
  3. Any index the rewritten queries need is declared in `firestore.indexes.json`; each
     rewritten path is checked against `firestore.rules` for a real `match` block.

- [ ] **BUT-1792** — Three more `expireAt` collections + presence, no TTL policy.
  Files: `firestore.indexes.json`, `functions/src/__tests__/firestore-ttl-policies.test.ts`,
  `functions/src/notifications/record-notification-opened.ts`.
  Acceptance:
  1. `fieldOverrides` with `"ttl": true` declared for `notification_opened_events`,
     `report_processing_markers`, `system_ip_audit_caps`, AND `activeUsers.expiresAt`
     (correct field name — not `expireAt`); `EXPECTED_TTL_GROUPS` updated in the same
     change.
  2. No entry anywhere in the diff sets `"ttl": false`; deploy never runs with `--force`.
  3. The stale "Manual setup required" heading in `record-notification-opened.ts` is
     replaced.
  4. `[run]` `gcloud firestore fields ttls list --project=butlery-app-1` shows ACTIVE for
     all four post-deploy, pasted as evidence; document counts for all four collections
     captured before deploy.

- [ ] **BUT-1812** — Re-sharing a recipe silently adds nobody.
  Files: `lib/services/unified/operations/modules/recipe_sharing_manager.dart`,
  `firestore.rules`, `functions/src/__tests__/*-rules.test.ts`.
  Change: Option 2 (Malin's decision) — stop reusing `recipeId` as the `shared_content` doc
  id; each share writes its own auto-id document (matching `social_menu_operations` /
  `shopping_social_share_module`). Rewrite the rule for the new shape. Do NOT implement
  Option 1 (widening `allow update` with `sharedToUserIds`) — explicitly declined.
  Acceptance:
  1. A second sharer re-sharing a recipe someone else already shared writes a NEW auto-id
     `shared_content` doc; their recipients gain read access via `sharedToUserIds`.
  2. `firestore.rules` is rewritten for the auto-id shape with an allow/deny rules-test
     pair.
  3. Existing `recipeId`-keyed rows are left untouched by this change — no migration is
     executed here; note explicitly in the PR that migration coordinates with BUT-1809.

## Agent B — recipe-safety-ui (3 tickets, Tier B, single router tier)

Router: `recipe_card.dart` → single (Creative Director/Brand Lead). `requiresPlanMode:
true` for BUT-1780 (single + priority High); `false` for BUT-1869/1870 (single, priority
Low/Medium, no security label) — but they ship in the same batch/commit as BUT-1780
regardless, since they're the same files and she asked for that explicitly.

- [ ] **BUT-1780** — Allergen/dietary badges never render on any card.
  Files: `lib/widgets/common/content_card.dart`, `lib/widgets/recipe/recipe_card.dart`,
  `lib/views/mina_recept/recipe_card_widget.dart`,
  `lib/views/ingredient_search/ingredient_search_view.dart`,
  `lib/widgets/tagging/tag_result_display.dart`, the `UserAllergenPreferences` model,
  `test/widget/common/content_card_test.dart`.
  Acceptance:
  1. `UserAllergenPreferences.showOnCards` default changes from `true` to `false`.
  2. Badges render (flag true + tracked allergen/diet) on Mina Recept's list view AND
     ingredient search ONLY — not the grid layout, not archive import.
  3. `CompactAllergenRow` filters UNKNOWN the same way its sibling widget already does.
  4. A widget test renders a card with a tracked allergen and finds the rendered badge
     widget in the tree — not a constructor-flag read. (This is the exact gap the verifier
     failed the previous attempt on; re-derive the test, don't reuse the stashed one as-is.)

- [ ] **BUT-1869** — Empty allergen selection leaves a dead gap on every card.
  Files: same as BUT-1780.
  Acceptance:
  1. Derivation uses `userAllergenPrefs?.isNotEmpty ?? false` (content), not a non-null
     check.
  2. A widget test covers an empty (all-unchecked) preference set and shows no spacing row
     is drawn.

- [ ] **BUT-1870** — `content_card.dart` at 503 lines, no `ACCEPTED_LARGE_FILES` entry.
  Files: `lib/widgets/common/content_card.dart`, optionally
  `docs/architecture/ACCEPTED_LARGE_FILES.md`.
  Acceptance:
  1. File under 500 lines (prefer trimming the duplicated dartdoc at ~60-96/175-194) OR a
     justified `ACCEPTED_LARGE_FILES.md` entry.
  2. The size guard does not fire on the next write to the file (i.e. after BUT-1780/1869
     land in the same commit).

## Agent C — social-messaging-client (3 tickets, Tier A/B, single router tier)

Router: `sync-conversation-last-message.ts` → single (Vendor/Procurement — a generic hit;
treat as ordinary CF review). `requiresPlanMode: true` on all three — BUT-1857/1853 are
priority High, BUT-1872 carries the security label.

- [ ] **BUT-1857** — Gruppinfo from the conversations list crashes.
  Files: `lib/views/messaging/conversations_list_view.dart` (~517-523),
  `lib/core/router/modules/social_deferred_module.dart`.
  **Corrected paths from the last attempt's post-mortem:** the router is
  `lib/core/router/app_router.dart` (not `core/navigation/...`, which doesn't exist), and
  it has no named group route — the working in-chat path pushes a `MaterialPageRoute`
  directly. Copy that shape; don't register a new named route.
  Acceptance:
  1. Gruppinfo from the conversations list opens the SAME screen as Gruppinfo from inside
     the chat, no cast error.
  2. A navigation test asserts the pushed screen + argument type from both entry points and
     fails if they diverge.

- [ ] **BUT-1853** — Missing `sentAt` makes the chat-history cut-off fail OPEN.
  Files: `functions/src/messaging/sync-conversation-last-message.ts` (~119-135).
  Change: skip the projection (or clear `lastMessage`) when the delete-recompute path's
  surviving message has no `sentAt` — matching the create/update path's existing guard
  (~142-149).
  Acceptance:
  1. A message with no `sentAt` cannot become a conversation's `lastMessage` via the
     delete-recompute path.
  2. A CF test covers the delete-recompute path with a `sentAt`-less survivor and is
     mutation-proven (goes red when the guard is removed) — put it in the emulator-backed
     integration suite, per the ticket's own note about coverage gaps.
  3. A comment at `canReadMessageAt` records both inputs now fail in the same (closed)
     direction.

- [ ] **BUT-1872** — Raw `conversationId` logged (`direct_` = two uids in clear text).
  Files: `functions/src/messaging/sync-conversation-last-message.ts`.
  Change: both `logger.warn` calls → `logSafeConversationId(conversationId)`.
  Acceptance:
  1. No `logger.*` call in the file sends a raw `conversationId`.
  2. Grep for `conversationId,` in the file's log objects returns zero hits outside the
     helper.

## Agent D — shopping-dialogs (3 tickets, Tier A/B, single router tier)

Router: `shopping_item_dialogs.dart` + `unified_shopping_item.dart` → single (Software
Architect, Product Manager). `requiresPlanMode: true` per the mechanical formula
(single + priority ≤ 2) for all three, including BUT-1860 — it's test-only in production
impact, but its priority is High, so the formula still fires; document that in the risk
note rather than skip it. **Order inside the batch matters: fix BUT-1873 and BUT-1874
first, then write BUT-1860's tests against the corrected dialog** — writing tests against
soon-to-be-removed price UI would waste the work.

- [ ] **BUT-1873** — No price field is wired up; the product answer is "remove it."
  Files: `lib/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart`.
  Change: delete `_priceController` and its two save-time reads (~256-258, ~394-396) from
  both dialogs. Do not add a price input field.
  Acceptance:
  1. `_priceController` and both save-time reads are gone from both dialogs.
  2. `estimatedPrice` on the model is left alone unless another live reader/writer is found
     (check, don't assume).

- [ ] **BUT-1874** — A cleared note field doesn't save as cleared.
  Files: `lib/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart`,
  `lib/models/unified/unified_shopping_item.dart`.
  Change: give the edit dialog a real "clear" signal for `note` instead of relying on
  `copyWith`'s null-means-unchanged semantics (build the object explicitly for that field,
  or add a `clearNote` parameter).
  Acceptance:
  1. A widget test empties the note field and saves; the saved item has `note == null`.
  2. Mutation-proof: reverting the fix turns that test red.

- [ ] **BUT-1860** — The real shopping-item dialog has zero tests.
  Files (new): `test/widget/views/unified_shopping/shopping_item_dialogs_test.dart`,
  a unit-test file for `_CategorySuggester`.
  DI rig to copy: `test/widget/views/recipe_form_meal_type_dropdown_test.dart`.
  Acceptance:
  1. A widget test proves a written name and note survive save (add + edit flow) — price
     assertion dropped per BUT-1873's decision.
  2. Unit tests cover `_CategorySuggester.suggest`, explicitly including the known false
     positives (Kycklingfilé→mejeri via "fil", Rostbiff→"ost", Krossade tomater→fruit/veg)
     in a clearly labeled false-positive group.
  3. Removing BUT-1874's `copyWith`-note fix turns the new note-survives-save test red
     (mutation-proof pasted as evidence).
  4. No production file outside BUT-1873/BUT-1874's scope is touched by this ticket.

## Post-sprint (mandatory)

1. Full `dart analyze --fatal-infos`.
2. File follow-up tickets for anything deferred mid-batch, before commit.
3. Commit through the gates in `shared-plugin.json → reviewGates`. Agent A's batch
   triggers `firebase-backend-security`, `firestore-rules-tester`, and
   `cloud-functions-specialist` at minimum (full-panel router tier, `panelPolicy: park`).
   Agent C's batch triggers `cloud-functions-specialist` (BUT-1853/1872 touch
   `functions/src`).
4. Push (`ship.pushTriggersDeploy: false` — push does not auto-deploy here).
5. Transition: Tier A build + all-pass → Done. Tier B/C, or any failed/unclear criterion →
   In Review + plain-language comment + PushNotification. Given the full-panel router tier
   on Agent A and the design-decision weight on BUT-1780/BUT-1812, expect most of this
   round to land In Review rather than auto-Done, by design (`panelPolicy: park`).
6. Do NOT transition BUT-1838 (blocked) or BUT-1480/BUT-1875 (needs-Malin) — leave exactly
   as found.
7. Report written for Malin: plain-language paragraph per shipped ticket, and an explicit
   note on BUT-1838's still-open decision 3.

## Deviation log

(append here as execution diverges from plan)

---

# ARCHIVE — SPRINT 2026-08-16 — Agents C & D (0 delivered), poll/GDPR selection, and earlier archives

Everything below is prior history, kept for record. The section immediately below (Agents
C & D outcome + the poll/GDPR selection it drew from) is what today's "already decided"
table above is built from — Malin's decisions quoted there are now on the tickets
themselves, not only in this file.

# SPRINT 2026-08-16 — Agents C & D: recipe-safety-ui + social-messaging-client

Plan section for THIS run, written before any work starts. This is the record the sprint is
graded against. 4 tickets, 2 agents, 2 area-clusters (separate worktrees — no file overlap
between them).

**Heading note:** the run was told to use the heading `# SPRINT 2026-08-16`, but the previous
section (immediately below) already opens with that exact string, so a bare heading would not
identify this run. The agent/area suffix above is the disambiguator; grade against this
section, not the one below it.

**Criteria-availability note:** this run was told BUT-1780 and BUT-1853 carry fewer than two
gradable acceptance criteria. Read against Linear, that is not the case — BUT-1853 has an
explicit `## Acceptance` block with three checkable items, and BUT-1780's Finding/Suggested Fix
sections state four. All criteria below are the ticket's own wording; none were softened and
none were invented to reach the two-criteria floor.

## Agent C — recipe-safety-ui (1 ticket)

Area: `lib/widgets/common/content_card.dart` + `lib/widgets/recipe/recipe_card.dart` and a new
widget test. Client-only, no Firestore/rules/CF surface.

- [ ] **BUT-1780** — Allergenmärkena visas aldrig på receptkorten — inställningen är på som
  standard men flaggan når aldrig fram.
  **Blast-radius tier (recorded on the ticket):** `Tier: single — Creative Director / Brand
  Lead`. The ticket adds that the allergen-safety framing makes a product-side look worth
  having before the "clean cards by default" intent is overridden.
  **What changes:** add `showAllergenBadges` / `showDietaryBadges` passthrough parameters to
  `ContentCard` (constructor at `content_card.dart:184-207`, which has no such parameter today)
  and forward them into the `RecipeCard(...)` call at `content_card.dart:246` — or derive them
  from `userAllergenPrefs != null` / `userDietaryPrefs != null`, which
  `lib/views/mina_recept/recipe_card_widget.dart:53-58` already populates from
  `allergenPrefs.showOnCards`. The gates being unblocked are `recipe_card.dart:223` (allergen)
  and `:232` (dietary); the defaults at `:80` / `:82` are what nothing in the repo ever sets.
  **Acceptance criteria (from the ticket):**
  1. A recipe card in a list or grid renders its allergen badge when the current user's
     `allergenPrefs.showOnCards` is true and the recipe has a tracked allergen.
  2. A recipe card renders its dietary badge under the same condition for tracked diets.
  3. A widget test renders a card with a tracked allergen and asserts the badge is present,
     pinning the regression.
  4. The hidden-UNKNOWN-badge mockup departure in `.claude/rules/accepted-deviations.md` is
     left untouched — only CONTAINS/FREE rendering is fixed.

## Agent D — social-messaging-client (3 tickets)

Area: chat client navigation, the `sync-conversation-last-message` Cloud Function, and
shopping-dialog tests. BUT-1853 touches `functions/src`, so the Cloud Functions review gate
fires for this batch; BUT-1860 is test-only.

- [ ] **BUT-1857** — Gruppinfo from the conversations list crashes — wrong argument, wrong
  screen.
  **Blast-radius tier:** none recorded on the ticket. Client navigation only.
  **What changes:** fix `ConversationsListView._navigateToGroupInfo` (and its route
  registration) to push the chat's group detail screen — not the social-group detail view —
  with the same argument shape the working in-chat Gruppinfo navigation already uses, instead
  of passing a `Map` to a handler that casts the argument `as String?`.
  **Acceptance criteria (from the ticket):**
  1. Gruppinfo from the conversations list opens the same screen as Gruppinfo from inside the
     chat, with the same argument shape and no cast error.
  2. A navigation test asserts the pushed route name and its argument type from both entry
     points, and fails if the two diverge.

- [ ] **BUT-1853** — A missing `sentAt` makes the chat history cut-off fail OPEN.
  **Blast-radius tier:** none recorded on the ticket; it does record that the fix is
  server-side and "belongs behind the Cloud Functions gate rather than in the client DTO"
  (labels: social, security).
  **What changes:** in `projectLastMessage`
  (`functions/src/messaging/sync-conversation-last-message.ts`, delete-recompute path at
  `:119-135`), skip the projection — or clear `lastMessage` outright — when the surviving
  message's `sentAt` is missing, so `Conversation.canReadMessageAt`'s two inputs
  (`memberSince`, `lastMessage.sentAt`) fail in the same, closed direction instead of opposite
  ones. Today `message_dto.dart:94-95` turns an absent stamp into `clock.now()`, which is true
  against every stamp and renders the pre-join preview. Whether that DTO's `?? clock.now()`
  should become `?? null` is explicitly a wider blast radius and stays out of this ticket.
  **Acceptance criteria (from the ticket's `## Acceptance`):**
  1. A message document with no `sentAt` cannot become a conversation's `lastMessage` via the
     delete-recompute path.
  2. A CF unit test covers the delete-recompute path with a `sentAt`-less survivor and is
     mutation-proven — it goes red when the guard is removed.
  3. A comment at `canReadMessageAt` records that both of its inputs now fail in the same
     direction.

- [ ] **BUT-1860** — Inköpslistans riktiga varudialog har noll tester — 579 nåbara rader,
  inklusive en bugg som redan varit ute en gång.
  **Blast-radius tier:** none recorded on the ticket. Test-only (labels: autonomous, shopping,
  test-gap).
  **What changes:** add widget tests for the add/edit flow of
  `lib/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart` (name, note and price
  survive save) and unit tests for `_CategorySuggester.suggest`. The DI rig to copy is
  `test/widget/views/recipe_form_meal_type_dropdown_test.dart` (BUT-1845).
  **Acceptance criteria (from the ticket):**
  1. A widget test proves a written name, a note and a price all survive save, through both the
     add and the edit flow.
  2. Unit tests cover `_CategorySuggester.suggest` over a handful of representative item names.
  3. Removing the `copyWith` line at `:239-259` that preserves note/price — the previously
     shipped bug the comment there remembers — turns the new test red; the mutation-probe
     output is pasted as evidence.
  4. No production file is modified; this ticket is test-only.

## Utfall, 2026-08-16 — 4 valda, 0 levererade, körningen stoppade sig själv

Ingen av de fyra rutorna ovan är ikryssad, och ingen ska kryssas. `git rev-parse HEAD` stod
kvar på sprintbasen `7b8ca0ec3` när körningen slutade; ingenting committades, ingenting
pushades, ingen Linear-övergång gjordes.

Kedjan, i ordning:

1. **BUT-1780 byggdes** och tre specialistgranskare släppte igenom bytena. Slutverifieraren
   underkände dem på två av tre linser — `correctness=fail`, `data-safety=pass`,
   `intent=fail`. Kärnan i båda: de tre nya testen läser `card.showAllergenBadges` av den
   konstruerade widgeten i stället för att leta upp ett renderat märke, och `RecipeFactory`
   kan inte sätta `tagResult`, så gaten på `recipe_card.dart:223` är alltid falsk. Testen
   förblir gröna om hela märkesblocket raderas. Kriterium 3 var alltså inte uppfyllt.
2. **Batchen lades i stash** (`stash@{0}` / `590a45347`, 2 filer, 62 rader) enligt regeln att
   underkänd kod aldrig når en commit.
3. **Trädet var inte rent efteråt** — fyra orelaterade filer var redan modifierade. Motorn
   stannade hellre än att låta nästa batch bygga ovanpå oredovisat material. Rätt beslut.
4. **Agent D hann bli klar ändå** och lämnade `.claude/state/sprint-patches/batch-1-20260816-153706.patch`
   (5 filer, 632 rader) för BUT-1857 / BUT-1853 / BUT-1860. Den applicerades aldrig och är
   OGRANSKAD. Körningens egen rapport kallar de tre "tysta bortfall" och säger att ingenting
   producerades — det stämmer inte, och patchen är den enda kopian.

### Avvikelselogg

- **Fyra falska rader i `docs/org/metrics/events.jsonl`.** Skrivna 13:13:57 med
  `outcome: "declined-unattended-shipped"` och texten "BUILT and committed … then parked In
  Review" för alla fyra biljetterna. Varje sats var osann. Rättade 2026-08-16 till
  `declined-unattended` med ett `corrected`-fält som namnger felet; BUT-1865 bär historiken.
  Raderna hann aldrig committas, så inget mätvärde hann påverkas.
- **Post-sprint-steg 1, 2 och 7 kördes aldrig** (full `dart analyze`, uppföljningsbiljetter före
  commit, rapport till Malin). Steg 2 och 7 togs i efterhand samma dag: tio uppföljningar
  filade (BUT-1865 t.o.m. BUT-1874) och rapporten levererad.
- **Två granskarfynd stod okvitterade** när körningen slutade — den döda luckan vid tomt
  allergenval och `content_card.dart` på 503 rader utan post i `ACCEPTED_LARGE_FILES.md`.
  Nu BUT-1869 och BUT-1870.

### Besluten som togs efteråt, 2026-08-16

Malin frågades ut om samtliga öppna val samma kväll. Sju beslut, vart och ett inskrivet i sin
egen biljett — det är biljetterna som är protokollet, inte den här filen:

- **BUT-1780** — bygg märkena, men `showOnCards` byter default till **av**. Ytor: listvyn i
  Mina Recept + ingredienssöket. UNKNOWN-märket ska filtreras bort i `CompactAllergenRow`
  också. Testet måste hitta märkeswidgeten i det renderade trädet.
- **BUT-1867** (rutnät/kompakt) och **BUT-1868** (arkivimport-halvan) — avböjda, stängda.
- **BUT-1832** — rösterna flyttas till `messages/{messageId}/poll_votes/{voterUid}`, inte
  enradaren. Byggs ihop med **BUT-1835**.
- **BUT-1801**, **BUT-1835**, **BUT-1833** — grönt ljus, bromsarna släppta.
- **BUT-1812** — egen auto-id-rad per delning; samordnas med BUT-1809:s backfill.
- **BUT-1792** — alla fyra TTL-policyer slås på, presence inkluderad.
- **BUT-1873** — priskontrollerna tas bort ur båda varudialogerna.

---

# SPRINT 2026-08-16 — poll/GDPR full-panel backlog unstuck, chat-client bugs, shopping test-gap

Selection phase only (Phase 1 of sprint-execute). Linear is up. 10 tickets across 4 batches.
2 tickets found already shipped under a different/no ticket tag — filed here as obsolete.

## Step-0 catch: obsolete tickets (fix already shipped, ticket never closed)

- **BUT-1845** (måltidstyp: tre vyer, två listor, ett fritextfält) — fixed in `8343d74e5`.
  `RecipeFormState.mealTypeOptions(storedValue)` now does the tolerant listing Malin decided
  on 2026-08-14; her own comment on the ticket documents the build and the mutation proof.
  The ticket is still open only because nobody closed it after the fix landed.
- **BUT-1838** (gruppchatt-epicet: barnsäkerhetsgrinden vid varje inbjudan) — implemented.
  `functions/src/groups/minor-membership-gate.ts` exists and is exactly the shared module the
  ticket asked for; the app-side chat-group module, the roster-orphan fix, and the unread-badge
  fix all shipped tagged `(BUT-1838)` (`faaba5978`, `c7fc9dd6b`, `d627daf25`, `8db7800e7`,
  `18cf5e97c`, `370a0f679`). Nine follow-up tickets (BUT-1840 through BUT-1863) already refer to
  it in the past tense as the thing that surfaced them. Recommend closing citing those commits.

## Note on 5 tickets already in Todo since 2026-08-13

BUT-1832, BUT-1835, BUT-1833, BUT-1801, BUT-1792 each carry an automated "picked up, then set
down" comment from 2026-08-13, written when this repo's stakeholder-router `panelPolicy` was
`block` — a full-panel ticket could not be built at all. `shared-plugin.json`'s own `_panelPolicy`
note records that this exact batch (six tickets, one already fixed as BUT-1822) is *why* the
policy was changed to `park`: build the ticket, land it in In Review, let the specialist gates
plus her review do the work the panel would have. That change supersedes the 2026-08-13 notes —
they describe a policy this repo no longer runs. Treated as ordinary `build` candidates below,
not as a parking brake (none of the five asks a question only Malin can answer; every one waits
on a review mechanism, and the mechanism now runs at commit time instead of blocking selection).
BUT-1832 additionally carries Malin's own explicit "fix it, not remove the button" — quoted in
full in that ticket's acceptance criteria below.

## Agent A — backend-security-gdpr (5 tickets, Tier C, full-panel router tier)

Area: firestore.rules + functions/src (poll votes, account-deletion cascade, TTL indexes,
top-level recipe reads). All five share `firestore.rules` and/or `account-deletion-cascade.ts`,
so they run as ONE batch/worktree. `requiresPlanMode: true` on every ticket (full-panel).

- [ ] **BUT-1832** [build — Malin's decision is in the ticket: "fix it... not to remove the
  button"] Poll voting denied for everyone but the poll's author (`firestore.rules`
  messages-update rule keys on `senderId`). Ship the read-receipt fields
  (`markMessageAsRead`, `batchMarkAsDelivered`) in the same change — same rule, same trap.
  Design fully spec'd in the ticket by `firebase-backend-security` + `firestore-rules-tester`:
  move votes to `messages/{id}/poll_votes/{voterUid}` (doc id == voter, provable one-liner
  rule) rather than a `hasOnly(['metadata'])` grant that cannot be scoped inside a list of
  maps; separate `allow update` statements per branch (never OR'd — a CEL error in one
  operand can sink the others); `.get(k,{}) is map ? ... : null` for `metadata` (the
  BUT-1788 null-trap recurs here). Files: `firestore.rules`,
  `lib/repositories/firebase/modules/message_mutation_module.dart`,
  `functions/src/__tests__/*-rules.test.ts`.
- [ ] **BUT-1835** [build — ship WITH BUT-1832, not after; the ticket's own timing argument]
  Poll voter uids survive account erasure inside the messages the cascade anonymises.
  Today the residual is bounded to the poll author only *because* BUT-1832 is broken — fixing
  voting without this widens a live Art. 17 gap the same day. Cascade leg 1 must rewrite
  `metadata.poll.creatorId` → `"deleted"` and strip the deleted uid from every option's
  `voterIds`, in the same batch that already holds the doc (`own.docs`), zero extra reads.
  Files: `functions/src/account/account-deletion-cascade.ts`.
- [ ] **BUT-1833** [build] Delete two dead `firestore.rules` helpers — `isAddingSelfToList`
  (harmless) and `isDocumentOwner` (a trap: reads `resource.data` on `allow create`, which
  doesn't exist yet, so any future caller gets a silent blanket deny). Two lines each, no
  behaviour change. Files: `firestore.rules`.
- [ ] **BUT-1801** [build] Six more sites read recipes from the empty top-level `recipes`
  collection instead of `users/{uid}/recipes` — including the GDPR export (Art. 15) and the
  deletion cascade (Art. 17). Sites: `bulk-retag.ts:252,418`,
  `compute-feature-retention.ts:338`, `canonical-rating-aggregation.ts:157`,
  `account-deletion-cascade.ts:375`, `recipe_gdpr_export_operations.dart:66`. Check each
  against `firestore.rules` for a real `match` block, and whether a collection-group index is
  needed (BUT-1781's `fieldOverrides` may not cover all six).
- [ ] **BUT-1792** [build] Three more collections stamp `expireAt` with no TTL policy
  (`notification_opened_events`, `report_processing_markers`, `system_ip_audit_caps`), plus
  presence (`activeUsers.expiresAt` — different field name, don't copy the others' command).
  Declare `fieldOverrides` with `"ttl": true` (never `false` — that disables a live policy
  with no warning; never bare) in `firestore.indexes.json`, update `EXPECTED_TTL_GROUPS` in
  `firestore-ttl-policies.test.ts`, replace the now-false "Manual setup required" heading in
  `record-notification-opened.ts`. Never `--force` deploy — 13+ live TTL policies are missing
  from the file. Count documents in all three collections before deploy; don't assume empty.

## Agent B — recipe-social-sharing (1 ticket)

Area: recipe sharing doc-id scheme. Router: single (Software Architect, Product).
`requiresPlanMode: true` (priority High).

- [ ] **BUT-1812** [build-review — genuine design choice] Re-sharing a recipe someone else
  already shared silently adds nobody: `shared_content` uses `recipeId` as the doc id, and
  the second sharer is denied both the read-probe and the write. Two candidate fixes in the
  ticket; **recommend Option 2** (stop reusing `recipeId` as the doc id — auto-id documents,
  matching `social_menu_operations` and `shopping_social_share_module`) over widening the
  rule — more consistent with the sibling writers, and it avoids a `firestore.rules` edit
  that would conflict with Agent A's batch. Needs a migration story for existing rows before
  BUT-1809's backfill runs. Files:
  `lib/services/unified/operations/modules/recipe_sharing_manager.dart`. Signoff: which fix
  approach, and the backfill/migration shape for existing `shared_content` rows.

## Agent C — recipe-safety-ui (1 ticket)

Area: recipe cards / allergen safety. Router: single (Creative Director / Brand Lead).
`requiresPlanMode: true` (priority High).

- [ ] **BUT-1780** [build-review — UI/safety tradeoff, signoff named in the ticket itself]
  Allergen/dietary badges never render on any recipe card in any list or grid —
  `showAllergenBadges`/`showDietaryBadges` default `false` and nothing in the repo ever
  passes `true`, despite the user-facing setting (`showOnCards`) defaulting ON. Add the
  passthrough on `ContentCard` (or derive from `userAllergenPrefs`/`userDietaryPrefs != null`,
  which `recipe_card_widget.dart` already populates) and forward into the `RecipeCard(...)`
  call at `content_card.dart:246`. Files: `lib/widgets/common/content_card.dart`,
  `lib/widgets/recipe/recipe_card.dart`. Signoff: does turning badges on override the
  deliberate "clean list cards by default" redesign intent (comment at `recipe_card.dart:80`)?

## Agent D — social-messaging-client (3 tickets, disjoint files from Agent A)

Area: chat client bugs + shopping test coverage, all found by the BUT-1838 whole-range review.

- [ ] **BUT-1857** [build] `requiresPlanMode: true` (High priority, chat-safety-adjacent
  screen). Gruppinfo from the conversations list crashes — pushes a route with a `Map`
  argument while the handler casts `as String?`, and targets the social-group detail view
  instead of the chat's group detail. Copy the working navigation pattern used from inside
  the chat itself. Files: `ConversationsListView._navigateToGroupInfo` + route registration
  (`lib/views/messaging/...`, `lib/core/navigation/app_router.dart` or equivalent).
- [ ] **BUT-1853** [build] `requiresPlanMode: true` (security label, High priority, Cloud
  Functions data write). A missing `sentAt` makes the chat-history cut-off (`memberSince`
  vs. `lastMessage.sentAt` in `canReadMessageAt`) fail OPEN instead of closed: the
  delete-recompute path in `sync-conversation-last-message.ts` can project a survivor with no
  `sentAt`, and `?? clock.now()` then makes every stamp comparison pass. Skip the projection
  (or clear `lastMessage`) when `sentAt` is missing. Files:
  `functions/src/messaging/sync-conversation-last-message.ts`.
- [ ] **BUT-1860** [build] `requiresPlanMode: false` (test-only, no production behaviour
  change). The shopping item add/edit dialog users actually reach
  (`shopping_item_dialogs.dart`, 579 lines) has zero tests, including its `copyWith` fix for a
  previously-shipped bug where a written note/price silently vanished. Add widget tests
  (name/note/price survive save) and unit tests for `_CategorySuggester.suggest`.
  Mutation-prove the `copyWith` regression test by removing the line it protects and
  confirming red. Files: `test/widget/views/unified_shopping/shopping_item_dialogs_test.dart`
  (new), `test/unit/...` for `_CategorySuggester` (new).

## Not selected this round (capacity, not doubt)

Real, buildable, all confirmed still open by grep:

- **BUT-1854** (GDPR export contradicts itself on a late joiner's `lastMessage`) —
  build-review, genuine two-option decision (ticket recommends A: apply the cut-off). Not
  picked up to keep N at 10; next in line.
- **BUT-1850** (`conversation_memberships` write-only PII, no reader) — build-review,
  two-option decision (ticket recommends Option 2: delete it). Held back because Option 2
  would touch `firestore.rules`, which would conflict with Agent A's batch this round.
- **BUT-1856** (a meal-vote poll now mints a permanent, undeletable group chat) —
  build-review, explicit product decision (ticket recommends Option B: one persistent chat
  per social group). Not a bug; deferred for capacity.
- **BUT-1795 / BUT-1830 / BUT-1831 / BUT-1796 / BUT-1828 / BUT-1825 / BUT-1829 / BUT-1823 /
  BUT-1824 / BUT-1827 / BUT-1834 / BUT-1716** — all still open, all worth building, all
  excluded because they would collide with Agent A's `firestore.rules` /
  `account-deletion-cascade.ts` edits or because they need their own dedicated session
  (BUT-1795 is the root two-storage-locations cause behind most of the others). Recommend a
  dedicated messaging/rules sprint next, seeded from BUT-1795.

## Needs Malin (not built, ops/deploy access this loop doesn't have)

- **BUT-1731** — deploy-day ops task (`backfillSharedListContributors` + delete the stale
  export). Needs production access.
- **BUT-1747** — GDPR export missing shopping lists the user LEFT. Real gap; her own prior
  comment recommends bundling the deploy with BUT-1731's.

## Post-sprint (mandatory)

1. Full `dart analyze --fatal-infos`.
2. File follow-up tickets for anything deferred mid-batch before commit.
3. Commit through the review gates named in `shared-plugin.json → reviewGates` — Agent A's
   batch triggers `firebase-backend-security`, `firestore-rules-tester`, and
   `cloud-functions-specialist` at minimum given the full-panel router tier.
4. Push (push does not trigger deploy in this repo — `ship.pushTriggersDeploy: false`).
5. Transition: Tier A build + all-pass → Done. Tier B/C, build-review, or any failed/unclear
   criterion → In Review + plain-language comment + PushNotification.
6. Close BUT-1845 and BUT-1838 as obsolete, citing the commits above.
7. Report written for Malin: plain-language paragraph per shipped ticket.

## Deviation log

(append here as execution diverges from plan)

---

# ARCHIVE — SPRINT 2026-08-13 — poll/GDPR rules gaps, wrong-collection recipe reads, allergen badges

Selection phase only (Phase 1 of sprint-execute). 8 tickets across 3 batches. Linear is up;
selected tickets transitioned to Todo. 8 tickets found already fixed on `main` under a
different commit than their own — filed here as obsolete, not re-built.

**Outcome, recorded 2026-08-16:** of the 8 batched tickets (BUT-1832, BUT-1835, BUT-1833,
BUT-1822, BUT-1801, BUT-1792, BUT-1812, BUT-1780), only **BUT-1822** actually shipped
(`370a0f679`) — under the `panelPolicy: block` router setting then in force, the other five
full-panel tickets were picked up and set back down unbuilt (see the note atop the current
sprint above), and BUT-1812/BUT-1780 were never picked up at all before this session's work
shifted to the BUT-1838 chat-groups effort. All 7 non-obsolete tickets are re-selected in the
2026-08-16 sprint above under the now-current `panelPolicy: park`.

## Step-0 catch: obsolete tickets (fix already shipped, ticket never closed)

Confirmed by reading the current code, not just `git log`:

- **BUT-1779** (handwritten-recipe save → error screen) — fixed in `3e1c193dc`.
  `RecipeSaveNavigation.afterSuccessfulSave` passes `savedRecipe`, not a bare id.
- **BUT-1782** (notification-prefs local cache was a stub) — fixed in `3e1c193dc`.
  `NotificationPreferences.toJson`/`tryFromJson` are real now, with a BUT-1799 follow-up note.
- **BUT-1784** ("Listan skapad" shown on a failed create) — fixed in `3e1c193dc`.
  `showCreateListDialog` checks `createPersonalList`'s bool before the success snackbar.
- **BUT-1791** (retention job measured only the first 4.5h of its day) — fixed in `3e1c193dc`.
  `compute-feature-retention.ts` now bases everything on the previous full UTC day.
- **BUT-1789** (feature-retention per-user rows never erased) — fixed in `3e1c193dc`.
  `deleteFeatureRetentionFlags` in `account-deletion-cascade.ts` sweeps them.
- **BUT-1777** (shared-list permission dialog used the live, not opened, base) — fixed in
  `3e1c193dc`. `viewedBase` doc comment names the ticket directly.
- **BUT-1788** (leave group / remove member always denied) — the dedicated
  `leave-group-conversation.ts` Cloud Function (wired to the client at
  `conversation_mutation_module.dart:339`) now owns this server-side, reading/writing the
  canonical top-level `conversations` doc. Shipped across `3e1c193dc` / `cf5cfdc0b`.
- **BUT-1819** (sanitized title/description discarded when a new recipe needed ingredient
  normalization) — fixed in `cc45d5c83`. `FirebaseRecipeRepository.create` now rebuilds from
  `recipeToSave`, with a comment citing the ticket.

None of these were re-selected. Recommend closing all eight citing the commits above.

## Agent A — backend-security-gdpr (6 tickets, Tier C, full-panel router tier)

Area: firestore.rules + functions/src (account deletion cascade, TTL indexes) + the messages
repository module. All six share files, so they run as one batch/worktree, not six.
Router (`tools/stakeholder_router.py`) returns **full-panel** on `firestore.rules` +
`account-deletion-cascade.ts` — Security Architect, Privacy/DPO, Trust & Safety, Database
Admin, Software Architect, Legal, Product, FinOps. `requiresPlanMode: true` on every ticket
in this batch.

- [x] **BUT-1832** — carried forward, unbuilt. See 2026-08-16 sprint above.
- [x] **BUT-1835** — carried forward, unbuilt. See 2026-08-16 sprint above.
- [x] **BUT-1833** — carried forward, unbuilt. See 2026-08-16 sprint above.
- [x] **BUT-1822** — DONE, `370a0f679`.
- [x] **BUT-1801** — carried forward, unbuilt. See 2026-08-16 sprint above.
- [x] **BUT-1792** — carried forward, unbuilt. See 2026-08-16 sprint above.

## Agent B — recipe-social-sharing (1 ticket)

- [x] **BUT-1812** — never picked up. Carried forward. See 2026-08-16 sprint above.

## Agent C — recipe-safety-ui (1 ticket)

- [x] **BUT-1780** — never picked up. Carried forward. See 2026-08-16 sprint above.

## Not selected this sprint — real work, deferred for batch-conflict / capacity reasons

All confirmed still open (not obsolete), all worth building, all excluded only because they'd
collide with Agent A's `firestore.rules` / `account-deletion-cascade.ts` edits or because N
is capped at 8 this round: **BUT-1795** (the root two-storage-locations fix — High, Tier C,
needs its own dedicated session), **BUT-1830** (Urgent — conversation-id squatting, same
root cause as 1795), **BUT-1831** (Urgent — DM send fails on every attempt for 3 independent
reasons, root fix is reading the top-level conversation), **BUT-1796**/**BUT-1828** (add-member
to a group has never worked), **BUT-1825**, **BUT-1829**, **BUT-1823**, **BUT-1824**,
**BUT-1827**, **BUT-1834**, **BUT-1716** (second shared-shopping write path with no
attribution). Recommend a dedicated messaging/rules sprint next, seeded from BUT-1795.

## Needs Malin (not built)

- **BUT-1747** — GDPR export missing shopping lists the user LEFT. Real gap, but needs a new
  server-side Cloud Function and a deploy slot; her own prior comment recommends bundling the
  deploy with BUT-1731's. Not squeezed into this round.
- **BUT-1731** — deploy-day ops task (`backfillSharedListContributors` + delete the stale
  export). Needs production access this loop doesn't have.
- **BUT-1693** — Part 2 of household allergen sharing. Malin approved the DPIA/consent/policy
  2026-08-12 (data layer shipped), but the ticket's own "Sequence" section requires
  `/stakeholder-review` + `/interview` before any code, AND its next step (the `firestore.rules`
  match block) would collide with Agent A's rules edits this round regardless.

## Post-sprint (mandatory)

1. Full `dart analyze --fatal-infos`.
2. File follow-up tickets for anything deferred mid-batch before commit.
3. Commit through the review gates named in `shared-plugin.json → reviewGates` — Agent A's
   batch triggers `firebase-backend-security`, `firestore-rules-tester`, and
   `cloud-functions-specialist` at minimum given the full-panel router tier.
4. Push (push does not trigger deploy in this repo — `ship.pushTriggersDeploy: false`).
5. Transition: Tier A/build + all-pass → Done. build-review or any failed/unclear criterion →
   In Review + plain-language comment + PushNotification.
6. Close the 8 obsolete tickets above, citing their resolving commits.
7. Report written for Malin: plain-language paragraph per shipped ticket.

---

# ARCHIVE — IN EXECUTION 2026-08-12 — the rules/model drift sprint

Malin: "planera och fixa alla fyra i en sprint" (2026-08-12). Fem stycken, inte
fyra — granskningen hittade en latent till efter att hon sa det.

## Context

`f3db9261e` fixade en produktionsincident: att spara ett recept hade nekats av
databasens säkerhetsregler i tre veckor, för att ett nytt fält lagts i modellen
utan att läggas i reglernas lista över tillåtna fältnamn. Ingen märkte det, för
ingen sparade ett recept under de veckorna.

Granskningen av den fixen ställde följdfrågan: **finns samma glapp någon
annanstans?** Den jämförde varje `hasOnly`-lista i `firestore.rules` mot vad
koden faktiskt skickar. Fyra levande träffar till, plus en latent. Tre av dem
har jag själv bevisat mot emulatorn.

`hasOnly` är den farligaste formen i filen: den **failar stängt, tyst**, på
SKRIVNINGEN. Ingen kompilator, ingen analys, inget felmeddelande användaren
skulle rapportera — funktionen slutar bara fungera.

## De fem

| # | vad som är trasigt | status | vad användaren märker |
|---|---|---|---|
| **D1** | `users/{uid}/counters` — reglerna tillåter `shared_recipes`, koden skickar `unreadSharedRecipes`. Två olika ordförråd för samma sak | **bevisad DENIED** | märket "nytt delat recept" räknas aldrig upp |
| **D2** | `conversation_memberships` — modellen skickar 9 fält, reglerna tillåter 7 (`isMuted`, `isPinned` saknas). OCH `conversations/{id}/participants` saknar `match`-block helt | **bevisad DENIED, båda** | att skapa en konversation kastar |
| **D3** | `notification_history` — skribenten stämplar `expireAt` (90-dagars TTL), listan saknar det | granskarens nyckeljämförelse | notishistorik sparas aldrig |
| **D4** | `deep_links/{id}/clicks` — reglerna vill ha `clickedAt` + `referrer`, koden skickar `timestamp` | granskarens nyckeljämförelse | klickstatistik för delningslänkar saknas |
| **D5** | `TagResult.decisions` skrevs av `toFirestore(includeDecisions: true)` och stod inte i listan | **latent, nu åtgärdad** — parametern borttagen | slog någon på flaggan var receptsparningen nere igen |

**D2 är värst och tas först.** De andra fyra sväljs av en `catch` och loggar en
varning; D2 gör det inte — `addParticipants` har ingen lokal catch, så
`batch.commit()` kastar uppåt genom `createDirectConversation` /
`createGroupConversation`, som kastar vidare. Och den är gatad på
`enable_subcollection_participants`, som **defaultar till true**.

## Bygget

Ordningen är vald så att varje steg går att verifiera för sig.

### ⓪ Skyddet först, inte sist

Ett test som jämför VARJE `hasOnly`-lista i `firestore.rules` mot de nycklar
skribenten faktiskt skickar. Det är det enda steget som gör att en sjätte inte
uppstår, och det ska skrivas FÖRE fixarna så att det rödnar på alla fem och
sedan grönar en i taget. Utan den ordningen bevisar det ingenting.

形: en emulatorsvit som för varje samling skickar den VERKLIGA nyttolasten
(hämtad från modellens `toFirestore()` eller repositoryts literal, aldrig
handskriven) och hävdar ALLOWED. Handskrivna nyttolaster är precis
mekanismen som lät alla fem glida — granskaren påpekade att även min egen nya
`R4b` är handskriven.

### ① D2 — meddelanden

Två fel i en: lägg `isMuted` + `isPinned` i listan, och **skriv ett
`match`-block för `conversations/{id}/participants/{uid}`** som i dag saknas
helt och därför faller på default-deny. Det senare är en ny regel för en väg
som redan används, så den behöver egen genomgång av vem som får läsa och
skriva — inte bara "tillåt deltagaren".

### ② D1 — delningsräknarna

Reglerna får de fältnamn koden använder. **Byt inte i koden i stället:** fälten
läses av `UserCounters`-modellen och av vyer, och konstanterna i
`UserCounterIncrements` är sanningen. Kontrollera samtidigt om
`unreadMessages` och `pendingFriendRequests` skrivs till samma dokument — de
står i samma konstantklass men jag hittade ingen skribent, och en oskriven
konstant är inte samma sak som ett fält som inte finns.

### ③ D3 + D4 — ett fält var

`expireAt` till notishistorikens lista (dess två systersamlingar har det redan,
med TTL-kommentar). `deep_links`-klicken: reglerna får `timestamp`, och
`referrer` tas bort ur listan om ingen skriver det — men först kontrolleras
vilken sida som är rätt, för här kan koden vara den som har fel.

### ④ D5 — det latenta

Antingen tillåts `decisions` med en storleksgräns, eller så tas parametern
`includeDecisions` bort. **Det är ett val, inte en fix:** parametern finns för
felsökning, och att tillåta fältet innebär att spara beslutsloggar per recept i
databasen. Jag lutar åt att ta bort parametern — den har noll anropare och dess
enda effekt i dag är att vara en fälla.

## Verifiering

- ⓪ måste rödna på alla fem innan någon fix skrivs, och sedan gröna en per fix.
  Det är stegets enda existensberättigande.
- Varje fix får ett ALLOW-test som skiljer sig från ett redan passerande test
  med **exakt den nya nyckeln**. Ett deny-test kan inte pinna en utvidgning:
  med utvidgningen återställd är det fortfarande grönt, nekat av `hasOnly` i
  stället, och två Firestore-nekanden går inte att skilja på i texten.
- D2 får dessutom ett riktigt test av deltagarvägen, inte bara medlemskapet.
- `firebase deploy --only firestore:rules` efter varje steg, och **aldrig**
  `--force` på index — projektminnet har 13 levande TTL-regler som saknas i
  filen.
- Slutkontroll på riktig enhet: skapa en konversation, dela ett recept, och se
  att räknaren tickar upp.

## Filer

`firestore.rules` (fem ställen), `functions/src/__tests__/` (⓪ plus ett test
per fix), och för D5 antingen `firestore.rules` eller
`lib/models/tagging/tag_result.dart`.

## Öppna frågor — båda besvarade i den här committen

1. **D5: flaggan togs bort.** `includeDecisions` hade noll anropare och dess
   enda effekt var att vara en fälla, så parametern är borta ur
   `TagResult.toFirestore`. `decisions` finns kvar i minnet och i `toJson`.
2. **D4: reglerna hade fel.** Skribenten skickar `timestamp` och `userId`;
   reglerna ville ha `clickedAt` och `referrer`, som ingen skickar. Reglerna
   fick skribentens namn, och `referrer` togs bort — ingenting läser den
   samlingen, så skribenten är sanningen här.

## Kvar efter sprinten, medvetet inte gjort

- **KLART i den här committen: bootstrap-residualen står nu i beslutsloggen.**
  Den låg länge här som "medvetet inte gjort", eftersom båda
  `accepted-deviations.md`-filerna var ändrade av en parallell session (BUT-1693)
  och att staga dem hade svept in deras arbete i min commit. Deras ändring
  landade som `638c5cf9c`, filerna blev fria, och entryn ligger nu i båda —
  tillsammans med de två andra residualerna och nollmedlems-skalet. Tröskeln för
  att stänga hålet helt är fortfarande BUT-1795. Punkten står kvar som synligt
  avklarad hellre än raderad, för det var den som höll den öppen i ett dygn.
- **Tre av de fem fixarna saknar ett ALLOW-test mot emulatorn, tvärtemot
  planens acceptanskriterium.** `counters`, `notification_history` och
  `deep_links/{id}/clicks` skyddas bara av textjämförelsen i det nya Dart-testet
  — och det testet säger själv i sin rubrik att det inte kan bevisa att regeln
  UTVÄRDERAS, bara att listan innehåller rätt fält. För räknarna är det extra
  tunt: samma regel bär också `isServerTimestamp('lastUpdated')` och
  `rateLimitWrite`, som ingen textjämförelse ser. Planen krävde ett ALLOW-test
  per fix som skiljer sig från ett redan passerande test med exakt den nya
  nyckeln. Det är inte gjort, och det står här i stället för att jag låtsas att
  textguarden räcker. Ligger i BUT-1823.
- **Omröstningar i chatten: bara den som skapade omröstningen kan rösta.**
  `votePoll` uppdaterar meddelandets `metadata`, och meddelanderegeln tillåter
  bara en uppdatering från den som skickade meddelandet. Alla andra nekas, och
  `votePoll` har ingen catch — felet går hela vägen upp i vyn. Samma sjukdom som
  D1-D5: skribent och regel är oense, och ingen märker det. **BUT-1832**, och
  **Malin har beslutat att den ska lagas** (2026-08-13). Läskvitton
  (`markMessageAsRead`, `batchMarkAsDelivered`) nekas av samma regel och tas i
  samma ändring om formen är densamma.
- **Två döda hjälpfunktioner i reglerna, varav en är en fälla.**
  `isDocumentOwner` har noll anropare och läser `resource.data`, som inte finns
  vid en nyskapning — den som i god tro anropar den på en `allow create` får ett
  blankt nej. Utrullningen varnar för båda; varningarna om "ogiltigt
  variabelnamn" är brus och det är nu bevisat. **BUT-1833.**
- **Två levande buggar av samma sjukdom hittades under granskningen, ingen av
  dem fixad här.** BUT-1826: den delade receptcachen har aldrig accepterat en
  klientskrivning — reglerna kräver fyra fält skribenten inte skickar, felet
  sväljs två gånger, och utåt ser det ut som låg träffkvot. Det är spegelbilden
  av hela sprinten (ett fält som SAKNAS i stället för ett för mycket) och den
  första konkreta instansen av luckan i BUT-1823. BUT-1827: om raderingen av
  konversationen misslyckas permanent i utkastningsfunktionens kollapsgren
  landar aldrig utkastningen av de minderåriga. Djupt hörn, ingen trolig orsak,
  men fixen är en extra skrivning på en barnsäkerhetsväg och förtjänar ett eget
  beslut.
- **Två kommentarnyanser medvetet inte lagade, för att inte köra om grindarna
  en gång till.** I skyddet står "var och en namnger sin skribents fil OCH
  RAD" — sant för två av tre, eftersom den tredje just bytte till metodnamn
  (raderna var fel med ett). Och regelfilens motsvarande pekare
  (`base_shared_content_repository.dart:59-63`) är fel på samma sätt och nämner
  bara en av tre skribentmetoder. Båda är en mening var, båda i filer som öppnas
  igen inom timmar för BUT-1831, och att laga dem hade ogiltigförklarat tre
  granskningar. Görs där.
- **Skyddet ser bara ena riktningen — spegelfamiljen är otäckt.** Reglerna
  kräver också att vissa fält FINNS (`keys().hasAll`, `hasRequiredFields`), och
  en modell som SLUTAR skicka ett obligatoriskt fält nekas precis lika tyst som
  en som lägger till ett okänt. Det nya skyddet jämför bara "allt som skickas är
  tillåtet" och kan strukturellt inte se det. Fixturen finns redan i huvudet:
  jämför andra hållet. Ska bli ett EGET test, inte ett andra påstående i det
  befintliga — en röd lampa ska betyda en sak. BUT-1823.
- **Meddelande-reservvägen stämplar om `createdAt`, så dess skrivning nekas mot
  varje konversation som redan finns.** `ConversationDto` skickar `createdAt`
  ovillkorligt, skrivningen är en merge-set, och uppdateringsregeln nekar varje
  diff som rör det fältet. Vägen är inte sällsynt: `readConversation` läser den
  användarskopade kopian, medan `createDirectConversation` bara skriver den
  översta — så för ett DM finns aldrig den användarskopade kopian och grenen
  körs vid varje sändning. Regeltestet kan inte se det: C11/C11B håller
  `createdAt` konstant, alltså skickar inget test det produktion skickar.
  **BUT-1831.** Omfattningen är FASTSTÄLLD 2026-08-13, mätt mot
  emulatorn med den verkliga nyttolasten: det är varje sändning, och det finns
  TRE oberoende orsaker (null-metadata, omstämplat `createdAt`, och omvänd
  deltagarordning när mottagaren svarar). Enda kombinationen som går igenom är
  den koden aldrig skickar. Kvar att bekräfta: vad användaren faktiskt ser på
  riktig telefon. Riktig fix är att läsa den ÖVRE konversationen i stället, vilket
  tar bort alla tre på en gång.
- **Anpassningen som gör den övre konversationen ockuperbar är egen och akut:
  BUT-1830.** Vem som helst som känner till ett grupp-id kan skriva den översta
  konversationen med sig själv som enda deltagare, och då körs utkastningen av
  minderåriga aldrig för den gruppen. Inte orsakad av den här sprinten; reglerna
  för att skapa konversationer är oförändrade. Står i båda beslutsloggarna.
- **Att lägga till en medlem i en gruppchatt man redan skrivit i fungerar inte,
  och kan inte fungera från appen.** Deltagarraden kräver att den översta
  konversationen redan namnger personen, och ingen klient får någonsin skriva i
  den listan — det är själva regeln som gör gruppmedlemskap oföränderligt från
  klienten. Så knappen i gruppvyn kastar. **Inte orsakad av den här sprinten**:
  vägen var stängd av default-deny förut också. Kräver en molnfunktion som äger
  "lägg till medlem", eller BUT-1795. **BUT-1828.**
- **Kontoradering städar INTE bort deltagarraden — ny GDPR-lucka, och den blev
  levande i dag.** `account-deletion-cascade.ts:1911-1926` raderar
  `users/{uid}/conversation_memberships` men ingenting någonstans raderar
  `conversations/{id}/participants/{uid}`, som bär den raderade användarens
  visningsnamn och avatar. Det var ofarligt så länge sökvägen var stängd i
  reglerna — då fanns inga rader — men den här sprinten öppnade den, så rader
  börjar skapas nu. Samma sjukdom som allt annat i sprinten: ett tvåvägsindex
  där bara ena halvan städas. Fixen är ett `collectionGroup("participants")`-ben
  i kaskaden plus ett i residualsonden, och ett `fieldOverride` för
  collection-group-index. Kunskapen fanns redan i koden —
  `admin/reset-user-data.ts:92` räknar upp `participants` som en
  konversationsunder­samling. **BUT-1822, hög prioritet**, och den ska
  granskas av `firebase-backend-security`.
- **Kollapsgrenens felväg är prövad, men inte mot emulatorn.** Grenen KASTAR
  inte — en tidig version gjorde det, och den här raden beskrev den versionen i
  flera timmar efter att den ersattes. Den RAPPORTERAR: `tryClearRoster`
  returnerar `false` och anroparen går över till uppdateringsgrenen i stället,
  så konversationen står kvar i stället för att raderas ovanpå rader som
  överlevde. Att bevisa det kräver att man får en radering att misslyckas mot
  emulatorn — Admin-SDK:n går förbi reglerna och en radering av något som inte
  finns lyckas. Löst i enhetslagret i stället, med en fejkad databas där en
  radering vägrar. **Uppräkningen** är mutationsbevisad. **Ordningen** (rader
  före förälder) är det INTE och kan inte bli det mot emulatorn: barnstädningen
  fungerar likadant efter att föräldern är borta, så att byta plats på de två
  raderna ger ett bit-identiskt slutläge och sviten förblir grön. Den första
  versionen av den här raden påstod att ordningen var bevisad. Det var fel.
- **En raderad konversation lämnar sin deltagarlista föräldralös.** Reglerna kan
  inte skilja "föräldern finns inte än" från "föräldern är raderad", så den
  bootstrap-gren som gruppskapandet behöver öppnar sig igen för en konversation
  som HAR funnits. Två vägar dit: molnfunktionen som vräker minderåriga raderar
  hela konversationen när den kollapsar under två medlemmar — **den vägen är
  lagad i dag**, funktionen städar nu bort raderna, och
  integrationstestet pinnar det (ingen siffra här — de två föregående
  påståendena om antal var båda inaktuella inom ett dygn) — och användarens egen "radera konversation" i
  listvyn, som **inte** är lagad: raderingsregeln kaskaderar inte, och en medlem
  får bara radera sin EGEN rad, så klienten kan inte städa åt de andra. Vad det
  kostar i praktiken: en före detta gruppmedlem som kan sitt konversations-id
  kan sätta sig i den övergivna listan och läsa namn och avatarer på personer
  hen redan chattat med. Id:t är en UUIDv4, alltså inte gissningsbart för en
  utomstående. Stängs helt av BUT-1795, som tar bort grenen. BUT-1825.
- **Den döda `UserCounters.toFirestore` är samma fälla som D5.** Klassen har
  ingen produktionsanropare, men dess serialisering skickar sju nycklar varav
  två — `unreadMessages` och `pendingFriendRequests` — reglerna nekar. Kopplar
  någon in den slutar räknarna fungera tyst. Ta bort serialiseringen eller lägg
  till fälten medvetet. Skyddet ser den inte: det härleder från
  `UserCounterIncrements`, inte från den metoden. BUT-1824.
- **Uppdateringsgrenen för `lastReadAt` är oprövad.** Den ligger bredvid den
  bredare medlemsgrenen, så varje test vars aktör ÄR medlem godkänns av den
  andra grenen — tar man bort den självskopade grenen förblir hela sviten grön (ingen siffra — den har varit inaktuell tre gånger).
  Dess enda unika effekt är att en BORTTAGEN medlem stämplar sin föräldralösa
  rad (BUT-1823 samlar den). Fixturen som pinnar den: en konversation vars `participantIds` INTE
  nämner aktören men som ändå har en rad för hen. Det är samma sjukdom som hela
  sprinten handlar om, så det ska göras — men det är en Medium på en regel som
  redan är korrekt och utrullad, och det står här hellre än att jag låtsas att
  det är klart.
- **`conversation_memberships` låter vilken inloggad användare som helst skriva
  vilken annans medlemsrad som helst** (ingen `isOwner`). Modulen skriver
  faktiskt medparternas rader, så det ser avsiktligt ut — men det är
  odokumenterat, och en främling kan plantera en falsk konversationspost i
  någons inkorgsindex. BUT-1829.

## Vad det betyder på vanlig svenska

- **Fyra saker i appen har varit tysta trasiga**, av exakt samma skäl som att
  spara recept var det: ett fält bytte namn eller tillkom på ena sidan men inte
  på den andra, och databasen svarar med att bara vägra.
- **Den värsta är meddelanden** — att starta en konversation kastar ett fel i
  stället för att svälja det.
- **Den viktigaste delen av sprinten är inte de fyra fixarna**, utan testet som
  gör att en femte inte kan uppstå tyst. Det skrivs först.
- Du får två frågor under bygget, inte fler. Båda står ovan.
