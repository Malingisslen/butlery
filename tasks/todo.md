# Sprint 2026-07-30c — Selection

Third sprint today. Backlog scanned: 130 Backlog + 4 Todo + 0 In Progress + 0 Triage, team
Butlery (Linear MCP live, confirmed via `list_issues`). Two backlog items (BUT-677, BUT-722)
carry `onboarding-reserved` and were excluded from scoring entirely, per instruction.

**Ship-state check first.** `git log --since="7 days ago"` shows two commits since the last
sprint write-up: `eaca99e46` (the 2026-07-30b rescue pass — BUT-1746/1721/1706/1752/1758/
1724/1736/1692/1756/1749, four fixed on top of the held commit) and `af797f046` (BUT-1772,
the conversations-export avatar redaction Malin decided that same day). Working tree is
clean. This sprint's candidates are almost entirely follow-ups filed *during* that rescue
pass's review round (BUT-1755, BUT-1760–1775).

**Step-0 premise re-check against current `main`** (grep, not `git log`) for every ticket
selected below:
- `functions/src/analytics/compute-feature-retention.ts:263-272` — the `shopped` probe still
  reads only `Collections.unifiedShoppingLists` under `users/{uid}`, never
  `unified_shared_shopping_lists`. BUT-1761 live.
- `lib/repositories/firebase/firebase_data_export_repository.dart:346-350` — still
  `convoDoc.reference.collection(FirestoreCollections.messages).orderBy('timestamp', ...)`.
  BUT-1767 live (wrong collection, wrong sort field, confirmed byte-for-byte against the
  ticket's own quote).
- `functions/src/account/account-deletion-cascade.ts:975` — still
  `convoDoc.ref.collection("messages").get()`, the same phantom subcollection. BUT-1766 live.
- `grep realtime_menus functions/src/account/` — zero hits (only
  `admin/reset-user-data.ts`, `functions/src/shared/collections.ts` and a rules-test file
  reference it outside the account tier). BUT-1768 live.
- `content_export_manager.dart` and `preferences_export_manager.dart` — zero occurrences of
  `error_code` in either file (grep count 0/0). BUT-1760 live.
- `functions/src/social/on-profile-updated.ts` — zero occurrences of `addedByDisplayName` /
  `lastModifiedByDisplayName`. BUT-1770 live.
- `lib/models/unified/unified_shopping_list.dart:682,754` — both `safeRequiredDateTime(json,
  'createdAt')` calls still pass no `defaultValue`. BUT-1755 live.
- `lib/viewmodels/collaborative_shopping/` — only
  `shopping_item_operations_manager.dart` references `_error`/`hasError`; the ViewModel and
  view still don't read it. BUT-1722 live.
- `_guardSelfExport` in `firebase_data_export_repository.dart` still delegates to
  `validateOwnership` with no `logPermissionCheck` call anywhere in the export path.
  BUT-1773 live.

Nothing here is already fixed.

Every ticket below was Claude-authored — `code-reviewer`/`firebase-backend-security`/
`cloud-functions-specialist` follow-up findings from the 2026-07-30b rescue-pass review round
(named explicitly in each ticket body as "existing, not introduced by the sprint") — never
human-approved. The mandate column records why each is safe to build anyway.

**Priority note from Malin, read directly off BUT-1774/1775's own text:** she has already
set build order across two tickets not in this sprint's batches — BUT-1766 and BUT-1767 are
to be built *before* BUT-1774 (merged with BUT-1775, the `perUserSettings`/`shared_content`
avatar redaction — already **BESLUTAT**, decided 2026-07-30, not a re-litigation). Both
1766 and 1767 are selected below; 1774/1775 is held this sprint (see Deferred) precisely
*because* it edits the same `social_export_manager.dart` method BUT-1767 must also touch
(AC4 extends the avatar-strip to message rows) — building it in parallel this sprint would
be the exact cross-batch file collision the clustering rule exists to prevent. Next sprint,
after this one lands.

## Agent A — account: chat messages never leave the phantom subcollection (Art. 17 + Art. 15)
Area: account. Router: **full-panel** (Security Architect, Software Architect, Privacy/DPO,
Legal Counsel, Product Manager, FinOps, Performance Engineer, Trust & Safety, Data
Analyst/BI, Vendor/Procurement — `firestore.rules`, `account-deletion-cascade.ts` and
`social_export_manager.dart` are all high-stakes hits). Files (deliberately overlapping —
one batch, sequential-within-agent, so worktree patches don't conflict):
`lib/repositories/firebase/modules/message_mutation_module.dart`,
`lib/repositories/firebase/modules/message_query_module.dart`,
`lib/repositories/firebase/firebase_messaging_repository.dart`,
`functions/src/account/account-deletion-cascade.ts`,
`functions/src/account/request-account-deletion.ts`,
`lib/repositories/firebase/firebase_data_export_repository.dart`,
`lib/services/account/export/social_export_manager.dart`,
`lib/services/account/data_export_service.dart`, `firestore.indexes.json`, plus new/updated
tests under `test/unit/repositories/firebase/`, `test/unit/services/account/export/`,
`functions/src/__tests__/`.

- [ ] **BUT-1766** [Tier C][build] Both account-deletion cascades (client + Cloud Function)
  sweep `conversations/{id}/messages`, a subcollection nothing writes to — production writes
  land in the top-level `messages` collection instead. A deleted user's chat messages,
  including message text and `senderId`, stay in Firestore indefinitely, and
  `deleteAllMessagesForUser` returns 0 and logs success, so nothing alarms. Art. 17 gap,
  pre-existing. **requiresPlanMode: true** (Urgent + Bug + security + account/GDPR). Router:
  full-panel.
  - Fix: sweep top-level `messages` on `senderId == uid` in both cascades (needs an index);
    decide and implement what happens to messages the deleted user only *received*
    (delete, or anonymize the sender name to "[Raderad användare]" the same way comments
    already do — the ticket names this as the established precedent, not an open product
    question); make `deleteAllMessagesForUser`'s zero-return path alarm rather than report
    success.
  - Acceptance:
    1. After account deletion, zero documents remain in top-level `messages` with
       `senderId == uid` — proven by an emulator/integration test seeded on the production
       path (the real `messages` collection), not the phantom subcollection.
    2. The decision on received-message handling is implemented and stated in the commit
       body (anonymize sender per the comments precedent, or delete — pick one, don't leave
       it open).
    3. A mutation test reds if the sweep is removed.

- [ ] **BUT-1767** [Tier C][build] The Art. 15 export's message query has three independent
  defects on the same phantom path as BUT-1766: wrong collection
  (`conversations/{id}/messages` instead of top-level `messages`), wrong sort field
  (`timestamp` instead of `sentAt`), and a `recipientIds` filter that doesn't exist on a
  message document at all (it's a shared-menu field) — so even with path and sort fixed,
  every *received* message would still silently drop. The query is denied outright by
  `firestore.rules`'s catch-all, so every user with at least one conversation loses the
  entire messages section (their own conversation metadata included), visible only as one
  `export_metadata.warnings[]` line. **requiresPlanMode: true** (Urgent + Bug + security +
  account/GDPR). Router: full-panel.
  - Fix: query top-level `messages` on `conversationId == id`, `orderBy('sentAt')`, drop the
    `recipientIds` filter (membership is already proven upstream by the conversation
    selection); declare the composite index (`conversationId` ASC + `sentAt` ASC) in
    `firestore.indexes.json` — deploying it is a separate ops step, flag it, don't assume
    push deploys it (`pushTriggersDeploy: false`); extend BUT-1772's avatar-strip (keep
    names, strip avatars — Malin's decision) to each message row's own
    `senderDisplayName`/`senderAvatarUrl`, since it has zero production effect today.
  - Acceptance:
    1. The export returns both sent and received messages for a seeded conversation, seeded
       on the production path.
    2. The composite index is declared in `firestore.indexes.json` and verified against the
       emulator (deploying it to production is called out as a post-sprint ops step, not
       assumed done).
    3. BUT-1721's boundary test (`cap + 1` truncation probe) is re-seeded on the production
       path and still reds against the retired `>=` variant.
    4. BUT-1772's avatar-strip is extended to every message row's `senderAvatarUrl`,
       mutation-tested; other `conversation_info` fields (names, UIDs, timestamps) stay
       untouched.

- [ ] **BUT-1768** [Tier B][build] `realtime_menus` is in neither deletion tier at all
  (only `deleteRealtimeRecipes` runs), and `lastEditedByDisplayName` is scrubbed nowhere in
  `functions/src/account/` — so a deleted user's realtime menus survive, and their name can
  persist on someone else's realtime recipe indefinitely. Found while reviewing BUT-1736's
  fix, which assumed both maintenance paths already covered this. **requiresPlanMode: true**
  (High + Bug + security + account/GDPR). Router: full-panel.
  - Fix: add `realtime_menus` (owned docs, `ownerId == uid`) to the cascade — watch the
    BUT-1396 trap of filtering on the wrong field name; decide and implement what happens to
    `lastEditedByDisplayName` on documents the deleted user doesn't own (anonymize per the
    comments precedent, or null the field).
  - Acceptance:
    1. After account deletion, zero `realtime_menus` remain with `ownerId == uid`.
    2. No `lastEditedByDisplayName` anywhere still carries the deleted user's name.
    3. Tests seed on the production path and are mutation-tested.

- [ ] **BUT-1773** [Tier A][build] The Art. 15 export gateway (`_guardSelfExport` in
  `firebase_data_export_repository.dart`) writes an audit row on denial but **nothing** on a
  granted export — a mass read of a user's entire dataset leaves no trail either way. The
  only gap found in an otherwise-clean repository-wide audit-logging review.
  **requiresPlanMode: true** (Medium + tech-debt + security). Router: full-panel (shares
  `firebase_data_export_repository.dart` with BUT-1766/1767 above).
  - Fix: write exactly **one** audit row per export at the `DataExportService` level (not
    ~30 per bundle at the gateway level, which is called once per section) carrying
    user id, timestamp, `operation: 'gdpr_export'`, and outcome.
  - Acceptance:
    1. A granted export writes exactly one audit row.
    2. A denied export writes exactly one row with `granted: false`.
    3. A mutation test reds if the row is removed.

## Agent B — account: GDPR export raw-text leak in the two remaining managers
Area: account. Router: **full-panel** (Privacy/DPO, Legal Counsel, Security Architect,
Software Architect, Product Manager, FinOps). Files (file-disjoint from Agent A — no shared
files, safe to run in parallel): `lib/services/account/export/content_export_manager.dart`,
`lib/services/account/export/preferences_export_manager.dart`, plus new/updated tests under
`test/unit/services/account/export/`.

- [ ] **BUT-1760** [Tier A][build] Two of four GDPR export managers still leak raw Firestore
  exception text into the exported bundle on failure (12 and 9 bare `{'error':
  e.toString()}` catches) — `social_export_manager.dart` and `activity_export_manager.dart`
  were fixed to stable `error_code` tokens in the 2026-07-30b sprint; these two were not.
  The raw text can contain another user's id (embedded in composite document ids), internal
  Firebase project links, and `memberPermissions.<uid>` paths. **requiresPlanMode: true**
  (High + security label). Router: full-panel.
  - Fix: give both managers the same treatment `shared_shopping_list_export.dart` already
    has — one stable, authored sentence + one `error_code` token per catch, no
    `e.toString()` reaching the export payload.
  - Acceptance:
    1. `grep -c "e.toString()"` in both files returns 0 for anything landing in the export
       payload.
    2. Every catch block has a unique, stable `error_code` token following the
       `shared_shopping_list_export.dart` convention.
    3. One test per manager injects a failure and asserts the export body contains the
       authored sentence + code, not the exception's own text.

## Agent C — shopping: three independent bug fixes, disjoint files
Area: shopping. Router: **single** for BUT-1722/1770 (Trust & Safety, Performance,
Data Analyst/BI, Vendor/Procurement, DB Administrator), promoted to **requiresPlanMode**
by BUT-1755's High priority. Files (disjoint from Agents A/B; internal overlap is fine —
same batch): `lib/models/unified/unified_shopping_list.dart`,
`lib/repositories/firebase/modules/shopping_list_permission_guards.dart`,
`lib/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart`,
`lib/viewmodels/collaborative_shopping/collaborative_shopping_viewmodel.dart`,
`functions/src/social/on-profile-updated.ts`, `firestore.indexes.json` (collection-group
override — **note:** BUT-1767 in Agent A also touches this file for a different index;
same-file cross-batch touch, flagged in the deviation-watch below), plus updated tests
under `test/unit/models/unified/`, `test/unit/repositories/firebase/modules/`,
`test/views/social/collaborative_shopping_view_test.dart`,
`functions/src/__tests__/`.

- [ ] **BUT-1755** [Tier A][build] `UnifiedShoppingList.fromMap` calls
  `safeRequiredDateTime(json, 'createdAt')` with no `defaultValue`, so a document with a
  missing/unreadable `createdAt` gets a FRESH value on every read. This is what made
  BUT-1726's drift check (`base.createdAt != stored.createdAt`) permanently deny every edit
  on an older/imported shared list — already worked around at ship time by dropping
  `createdAt` from the drift set entirely, but the underlying synthesis bug is unfixed and a
  second site (`requireNoPrivilegeEscalation`'s strict `!=` check, pre-dating this sprint)
  still hits it on the non-owner edit path. **requiresPlanMode: true** (High + Bug,
  `lib/repositories/`). Router: single, promoted.
  - Fix: give the field a deterministic `defaultValue` at the parse seam (e.g.
    `DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)`) in `UnifiedShoppingList.fromMap`.
    Do NOT apply the same fix to `updatedAt` (it would diff on every write, per the ticket's
    explicit warning).
  - Acceptance:
    1. A document with missing/unreadable `createdAt` returns the same sentinel value on
       every read (test proves no `clock.now()` fallback fires).
    2. `requireNoPrivilegeEscalation`'s strict `createdAt != createdAt` check on the
       non-owner path is closed by the same sentinel — a test proves an edit/admin member on
       an older list is no longer permanently denied.
    3. `updatedAt` is explicitly NOT given the same treatment — stated in the commit body.

- [ ] **BUT-1722** [Tier A][build] The collaborative shopping screen's failed-edit message
  is silently destroyed: `ShoppingItemOperationsManager` (collaborative variant) writes the
  permission-denied reason into its own `_error` field, which nothing in `lib/` reads — the
  ViewModel never delegates to it and the view reads only `BaseViewModel._error`. A
  view-only member's tick silently un-ticks with zero explanation, on the one screen this
  matters most (found while verifying BUT-1696's fix, which fixed only the unified screen).
  **requiresPlanMode: false** (Medium, shopping, no security label). Router: single.
  - Fix: mirror the manager's error into `CollaborativeShoppingViewModel` (either delegate
    `error`/`hasError` to the manager, or set it explicitly after a failed toggle).
  - Acceptance:
    1. A view-only member tapping a checkbox on a shared list sees the permission sentence,
       not silence.
    2. `test/views/social/collaborative_shopping_view_test.dart:574` ("a failed toggle
       announces nothing") is updated to assert the message.
    3. Only the `collaborative_shopping/` `ShoppingItemOperationsManager` is touched — the
       ticket explicitly flags a second same-named class under `viewmodels/shopping/` that
       is NOT this one; don't touch it by mistake.

- [ ] **BUT-1770** [Tier B][build] A display-name change never reaches shopping-item row
  level: `on-profile-updated.ts` updates list-level `ownerDisplayName` /
  `lastActivityByDisplayName`, but `addedByDisplayName` / `lastModifiedByDisplayName` on
  individual items (both the `items` subcollection and the embedded `items` array) are never
  touched — so "Anna added milk" keeps saying Anna forever after she renames to Annika. The
  deletion cascade already scrubs these exact two fields, so propagation and deletion
  disagree about which fields count. **requiresPlanMode: false** (Medium + security label,
  but a scoped, well-specified fix). Router: single.
  - Fix: a `db.collectionGroup("items").where("addedByUserId", "==", userId)` pass (and the
    same for `lastModifiedByUserId`) — requires a `fieldOverrides` entry with
    `queryScope: "COLLECTION_GROUP"` in `firestore.indexes.json`. The embedded array copy on
    the list document isn't queryable and needs a per-matched-list read-modify-write.
    Rename changes are rare, so the collection-group sweep's cost should be negligible — say
    so with a number in the commit body, per the cost-principles rule.
  - Acceptance:
    1. After a rename, no `addedByDisplayName`/`lastModifiedByDisplayName` anywhere still
       carries the old name, in either storage shape.
    2. The index is declared and verified against the emulator.
    3. A test seeds both storage shapes and reds if the sweep is removed.

## Agent D — analytics: shared-list activity undercounted in feature retention
Area: analytics. Router: **single** (Data Analyst/BI, Growth/ASO, Vendor/Procurement — no
high-stakes hits). File-disjoint from every other batch:
`functions/src/analytics/compute-feature-retention.ts`, plus updated tests under
`functions/src/__tests__/compute-feature-retention.test.ts`.

- [ ] **BUT-1761** [Tier A][build] The `shopped` feature-retention probe only queries
  personal shopping lists — shared lists, the flagship feature the product is built around,
  are never probed at all, so the metric for shared shopping activity is structurally always
  zero. The code carries an unticketed `KNOWN GAP 1` comment; this is that ticket.
  **requiresPlanMode: false** (Medium, analytics, no security label). Router: single.
  - Fix: extend the `shopped` probe to also query `unified_shared_shopping_lists`; replace
    the unticketed `KNOWN GAP 1` comment with this ticket's number in the same change.
  - Acceptance:
    1. `shopped` is true for a user whose only activity is on a shared list (no personal
       activity).
    2. A test pins exactly that case.
    3. The `KNOWN GAP 1` comment is removed or replaced with BUT-1761's number.
    4. No added Firestore read per user per day beyond what's already budgeted in the
       comment — state the cost explicitly if the fix changes it.

## Deferred to capacity (clear mandate, held back — file overlap or observed agent-count cap)

- **BUT-1774** (merged with BUT-1775) — Malin's own decided redaction
  (strip `perUserSettings` for others, keep `lastReadTimestamps`; strip `sharedByAvatarUrl`
  in `shared_content`) touches `social_export_manager.dart`'s avatar-strip helper — the exact
  method BUT-1767 (Agent A, this sprint) also extends. Building both in the same sprint
  across two parallel batches is the cross-batch file collision the clustering rule exists
  to prevent, and Malin's own ticket text says build order is 1766/1767 first anyway. Next
  sprint's Agent A, once this sprint's Agent A has landed.
- **BUT-1762** — feature-retention `KNOWN GAP 2` (personal-list check-only sessions don't
  bump `updatedAt`, so a shop-and-tick-only session isn't counted). The ticket itself offers
  two cost-tradeoff fixes (bump `updatedAt` on every item write vs. a new per-day counter
  doc) or "leave the gap documented" as a legitimate third option — a genuine
  running-cost decision, not a mechanical fix. Flagged in Needs your call below rather than
  built.
- **BUT-1716** — the second shared-shopping repository's missing attribution stamp. Held a
  third sprint: its own AC3 (verify the deletion cascade scrubs the subcollection shape)
  plausibly touches `account-deletion-cascade.ts`, the same file Agent A is already deep in
  this sprint for BUT-1766/1768. Next sprint's Agent A, after this sprint's cascade work
  settles, to avoid guessing at a collision on a file already at capacity.
- **BUT-1730** — build a real Firestore-emulator CI lane. Failed twice already (BUT-1695,
  then this ticket's own reproduction of a `PlatformException` under `flutter test
  --dart-define=USE_EMULATOR=true`). The ticket itself asks to "pick one deliberately"
  between two different test-harness architectures — an engineering-direction call, not a
  ticket with one obvious fix. Recommend deciding the harness approach with Malin before a
  third autonomous attempt (see Needs your call).
- **BUT-1747** — GDPR: shared lists the user has LEFT are missing from the export (needs a
  new Cloud Function; unblocked now that BUT-1732 has landed). Real gap, clear mandate, but
  a new Cloud Function plus its own deploy step is a bigger, more ops-adjacent lift than any
  batch above — same read as the last two sprints: worth its own dedicated slot, ideally
  paired with BUT-1731's deploy-day step, not squeezed in alongside two Urgent tickets.

## Needs your call (not built this sprint)

- **BUT-1762** — see Deferred above: pick a cost tradeoff (extra per-tick write vs. a new
  per-day counter doc) or accept the documented gap. My read: option 2 (counter doc) if the
  metric matters enough to fix precisely; otherwise leave it — this is a BI-accuracy gap,
  not a safety one, so "leave it documented" is a legitimate answer.
- **BUT-1730** — decide the emulator-lane architecture direction (an `integration_test` host
  that loads FlutterFire plugins, vs. a pure-Dart Firestore client for these three suites)
  before a third autonomous attempt. My read: worth doing, but needs an explicit direction
  first, not another CI-YAML pass.
- **BUT-1718** — a household member cannot leave a shared shopping list (rules deny
  self-removal) — deliberate rule, product/permissions call. Carried from the last two
  sprints, unchanged.
- **BUT-1699** — enable the two Firestore TTL policies that were never turned on
  (`notification_send_events`, `scheduled_notifications`) — real data-retention behaviour
  change. Carried, unchanged.
- **BUT-1731** — deploy-day ops task (run `backfillSharedListContributors`, delete the export
  after the 30-day soak). `need-malin` label, Tier D. Carried, unchanged.
- **BUT-1693, BUT-1480, BUT-1323, BUT-1685, BUT-880, BUT-1502, BUT-1557, BUT-1179, BUT-1368,
  BUT-863, BUT-1445, BUT-1649, BUT-1636, BUT-1361** — the standing `need-malin` manual-QA /
  compliance-diagnosis / product-decision backlog, unchanged this sprint.

## Cross-batch file-collision watch (declared at selection, not discovered at ship)

`firestore.indexes.json` is touched by **both** Agent A (BUT-1767's `conversationId`+`sentAt`
composite) and Agent C (BUT-1770's `items` collection-group override) — two different index
entries in the same config file. Per the delivery digest's worktree lesson, serialize these
two batches' writes to this one file rather than trusting an automatic merge: apply Agent A's
patch, let it land, then re-diff Agent C's before applying. Flag explicitly at ship if either
batch's patch to this file needed a manual re-apply.

## Post-sprint steps (to run after implementation)

1. `dart analyze --fatal-infos` + `npx tsc --noEmit -p functions` on the full tree.
2. File follow-up Linear tickets for every deferred sub-scope before commit.
3. Commit through the gate: `code-reviewer` on all `.dart`, `firebase-backend-security` on
   Agents A/B/C's repository and export-manager touches, `cloud-functions-specialist` on
   Agents A/C/D's `functions/src` touches, `firestore-rules-tester` only if `firestore.rules`
   itself changes (expected: it does not — Agent A adds a query + index, not a rule).
4. Push (push does NOT trigger deploy in this repo — `pushTriggersDeploy: false`). The two
   new `firestore.indexes.json` entries (BUT-1767, BUT-1770) need an explicit
   `firebase deploy --only firestore:indexes` — call this out as a Needs You step, don't
   assume push covers it.
5. Transition tickets: Tier A/B/C build + all-pass → Done. Any failed/unclear criterion → In
   Review + plain-language comment + PushNotification.
6. Re-check `docs/onboarding/workflow-map.stale` before commit — none of this sprint's flows
   look map-relevant (export/deletion internals, analytics), but verify rather than assume.
7. Grade each selected ticket against its OWN diff before any Done/In Review transition.

---

# BUT-1772 — conversations export: strip other participants' avatar URLs

**Founder decision, 2026-07-30.** Malin was shown the three options (strip names + avatars /
keep names, strip avatars / keep both and record it) and chose **keep names, strip avatars**.
Recorded in `docs/architecture/ACCEPTED_DEVIATIONS.md` and the always-on digest, in her name,
with the reasoning: a name the requester has already seen on screen discloses nothing new and
its removal would fail Art. 12(1)'s "intelligible" limb, while an avatar URL is a durable
dereferenceable pointer to another person's photograph that outlives the app and buys the
requester nothing.

Sensitive domain (GDPR, `lib/services/account/export/`), so this is the written plan the
threshold guard asks for, even at one production file.

## Fileset

- `lib/services/account/export/social_export_manager.dart` — the redaction, at the
  `conversation_info` construction. NOT the repository: the repository returns the raw document
  and the manager is the export-shaping layer, which is where the sibling shared-list redaction
  already lives.
- `test/unit/services/account/export/social_export_manager_test.dart` — pins it.
- `docs/architecture/ACCEPTED_DEVIATIONS.md`, `.claude/rules/accepted-deviations.md` — the record.

## What ships

1. `participantAvatarUrls` keeps ONLY the requester's own entry; every other key is dropped. The
   requester's own avatar is their data and Art. 15 is a right to receive it — dropping it would
   be the opposite failure.
2. The embedded `lastMessage.senderAvatarUrl` is dropped unless the sender is the requester.
3. The section's `data_minimisation` line states what was dropped, so the bundle does not make a
   false statement about itself. That line has to stay exhaustive — the shared-list version
   shipped naming four of six fields once already.

## Acceptance criteria

1. Another participant's avatar URL appears nowhere in the exported bundle — asserted against the
   whole serialised JSON, not just the map, so a copy hiding in `lastMessage` cannot pass.
2. The requester's own avatar URL IS present.
3. Every other `conversation_info` field is untouched — names, UIDs, read timestamps, last-message
   content. A test pins this, because "strip the avatars" must not quietly become "strip more".
4. Mutation-tested: removing the redaction reds the test.

## Not in scope

The `messages` array never returns anything today. The review corrected my own premise here:
the section does not ship EMPTY, it **fails**. `conversations/{id}/messages` has no `match` block
in `firestore.rules`, so the catch-all denies the query, `permission-denied` propagates to the
section's outer catch, and any user with at least one conversation loses the whole messages
section — their own conversation metadata included. So this redaction has no production effect
until BUT-1767 lands; it is proven at unit level and nowhere else. Both BUT-1767 and the deviation
entry now say so.

## Outcome — graded 2026-07-30

Shipped as specified, with three review findings folded in before commit:

| Finding | Source | Disposition |
| --- | --- | --- |
| The redaction FAILED OPEN on an unrecognised shape — a list-shaped `participantAvatarUrls` would ship verbatim while `data_minimisation` claimed it was removed | `code-reviewer` | Fixed. Both branches now drop the field wholesale and set `redaction_fell_back: true`. Mutation-proven: deleting the fallback reds 1. |
| The `data_minimisation` line enumerated the KEEPS, and the enumeration was already incomplete (`lastReadTimestamps`, `perUserSettings`, `reactions`, poll `voterIds`) — the bundle stated something false about itself | both reviewers | Fixed. It states the drop and stops. A test asserts the enumeration is gone, because a list that must stay exhaustive to stay true will stop being true. |
| The scope note's failure mode was wrong — "ships empty" vs "fails with `messages-export-failed`" | `firebase-backend-security` | Corrected in the deviation entry, the digest and BUT-1767. |

Also moved the notice from per-conversation (up to 100 copies) to section level, matching the
sibling shared-list export.

**Escalated to Malin rather than decided here:** `perUserSettings` carries every other
participant's mute/pin/archive state and timestamps. Her keep-argument for names — "you have
already seen them in the app" — is false for it, since the client never renders another user's
sub-map. **BUT-1774**, undecided. Named explicitly in the deviation entry so the record cannot be
read as exhaustive.

**Follow-ups filed:** BUT-1774 (`perUserSettings`), BUT-1775 (`shared_content` still carries
`sharedByAvatarUrl` — the same principle, three sections down, plus two more Auth-displayName
persisters of the BUT-1736 class).

---

# Sprint 2026-07-30b — Selection

Second sprint today. Backlog scanned: 122 Backlog + 4 Todo + 0 In Progress + 0 Triage, team
Butlery (Linear MCP live). Two backlog items (BUT-677, BUT-722) carry `onboarding-reserved`
and were excluded from scoring entirely, per instruction.

**Ship-state check first.** `git log --since="7 days ago"` shows the morning's sprint
(BUT-1741/1715/1729/1740/1739/1733/1726/1732/1727 + BUT-1677/1697 obsolete) shipped in
`c17c4068e`, and a lessons-digest commit (`a14bb3a16`) landed on top. Working tree is clean.
This sprint picks up its own follow-ups — 9 of the 10 selected tickets below were filed
*during* that ship pass (BUT-1746 through BUT-1758).

**Step-0 premise re-check against current `main`** (grep, not `git log`) for every ticket
selected below:
- `functions/src/notifications/send-notification.ts:467` — `const MAX_BATCH_NOTIFICATIONS =
  100;` still has no `export`. BUT-1692 live.
- `functions/src/analytics/compute-feature-retention.ts` still probes
  `users/{uid}/shopping_lists`. BUT-1724 live.
- `lib/services/realtime/realtime_menu_service.dart:52-53` and
  `lib/services/realtime/realtime_recipe_service.dart:48-49` both still read
  `.currentUser?.displayName` (the raw Firebase Auth handle) with no `profileDisplayName`
  reference anywhere in either file. BUT-1736 live. **Correction to the ticket text:** the
  ticket says "recipe_service" — the actual twin of `realtime_menu_service.dart` is
  `lib/services/realtime/realtime_recipe_service.dart` (identical
  `_currentUserDisplayName` getter, line-for-line), not `social_recipe_service.dart` (which
  has no `displayName` reference at all). Implementer: fix the two `realtime/*` files.
- `functions/src/notifications/send-notification.ts` has no `RATE_LIMIT_CONFIGS`-pinning
  assertion anywhere in its test file. BUT-1692 live.
- No `docs/architecture/ADR-0*` file mentions `updateCollaborativeListMembership` or
  `StaleAccessControlBaseException`. BUT-1752 live.
- `test/integration/firebase/repositories/comments_repository_integration_test.dart:139`
  still uses strict `isAfter`. BUT-1756 live.
- No file under `test/widget/shopping/` references `ShoppingMemberManagementDialog`.
  BUT-1749 live.
- `functions/src/__tests__/shared-shopping-lists-rules.test.ts` exists but (per BUT-1706's
  own text, re-confirmed by reading it) has no create-conjunct or replay-denial coverage.
  BUT-1706 live.
- `firebase_data_export_repository.dart`'s query predicates still have no test that builds
  the real repository (all current tests stub it behind a `Fake`, per the outcome note in
  the prior sprint section below). BUT-1721/1746 live.

Nothing here is already fixed.

Every ticket below was Claude-authored (mostly the `firebase-backend-security`/
`code-reviewer`/`testing-specialist` follow-up findings from the two 2026-07-30 ship review
passes), never human-approved. The mandate column records why each is safe to build anyway.

## Agent A — shopping + account (GDPR export completeness, rules coverage)
Area: shopping / account. Router: **full-panel** (Security Architect, Software Architect,
Privacy/DPO, Legal Counsel, Product Manager, FinOps, Performance Engineer, Data Analyst/BI,
Trust & Safety, QA/Test Engineer, Vendor/Procurement — `firebase_data_export_repository.dart`
and the shared-shopping-lists rules test are both high-stakes hits). Files (deliberately
overlapping — one batch so sequential worktree patches don't conflict):
`lib/repositories/firebase/firebase_group_weekly_menu_plan_repository.dart`,
`lib/repositories/firebase/modules/shopping_repository_query_module.dart`,
`lib/repositories/firebase/firebase_data_export_repository.dart`,
`lib/repositories/firebase/modules/shopping_repository_routing_module.dart`,
`lib/services/account/export/social_export_manager.dart`,
`lib/services/account/export/activity_export_manager.dart`,
`lib/services/account/data_export_service.dart`,
`functions/src/__tests__/shared-shopping-lists-rules.test.ts`, a new
`tools/check_null_filter.sh` (or equivalent) + `lefthook.yml` wiring,
`test/unit/repositories/firebase/firebase_group_weekly_menu_plan_repository_test.dart`,
`test/unit/repositories/firebase/modules/shopping_repository_query_module_test.dart`,
`test/unit/repositories/firebase/modules/shopping_repository_routing_module_test.dart`,
`test/unit/services/account/data_export_service_test.dart`.

- [ ] **BUT-1746** [Tier C][build] Firestore `isNotEqualTo: null` silently drops the filter —
  the query degrades to an unfiltered collection read, which the security rules then refuse
  outright, so the feature just stops working. The 2026-07-30 sprint fixed four sites to
  `isNull: false` but shipped no test and no guard. **requiresPlanMode: true** (High + Bug +
  `lib/repositories/`). Router: full-panel.
  - Fix: pin the filter contract with a test at all four sites (assert the *emitted filter*,
    not just the result — an in-memory fake can't catch this) —
    `firebase_group_weekly_menu_plan_repository.dart:174`,
    `shopping_repository_query_module.dart:66` and `:229`, plus the BUT-1732 export probes in
    `firebase_data_export_repository.dart`. Add a mechanical grep-based guard or analyzer rule
    that fails on `isNotEqualTo: null` / `isEqualTo: null` anywhere in the tree. Name
    `firebase_group_weekly_menu_plan_repository.dart` in the security reviewer's marker (it
    was outside the sprint that introduced the bug and got no review pass).
  - Acceptance:
    1. A test at each of the four sites asserts the emitted Firestore filter shape, not just
       the query result.
    2. A repo-wide mechanical guard (script or lint) fails the build on any
       `isNotEqualTo: null` / `isEqualTo: null` construction — proven with a fixture, not a
       clean run alone.
    3. `firebase_group_weekly_menu_plan_repository.dart` is named in the
       `firebase-backend-security` review marker.

- [ ] **BUT-1721** [Tier C][build] GDPR export: two aggregator holes let a section that
  failed or was clipped read as complete. (A) a per-conversation truncation flag lives inside
  a List, not a Map, so `data_export_service.dart`'s walk never finds it — clipped messages
  never reach `truncated_collections`. (B) `social_export_manager.dart` /
  `activity_export_manager.dart` return a bare `{'error': ...}` with no `error_code`, so a
  thrown section never reaches `warnings` either — the bundle looks clean while a whole
  section is missing. **requiresPlanMode: true** (High + Bug + account/GDPR). Router:
  full-panel.
  - Fix: walk list elements too
    (`value.values.whereType<List>().expand((l) => l).whereType<Map>()`); move
    `firebase_data_export_repository.dart:353-354` off the retired `>=` rule onto the
    `fetchCapped` N+1 shape; add an `error_code` to every catch in both export managers (one
    token per catch, mirroring `exportPooledRatingEvents`, which already does it right).
  - Acceptance:
    1. A clipped message thread (list-nested truncation flag) appears in
       `truncated_collections`.
    2. A section that throws produces a `warnings` entry with a non-null `error_code`.
    3. `data_export_service_test.dart` gets the aggregator-level lift test: seed one section
       past its cap, assert both `truncated_collections` and `data_completeness`.
    4. `firebase-backend-security` reviews the diff.

- [ ] **BUT-1706** [Tier C][build] Shared shopping lists have zero emulator rules coverage,
  and the client's `_requireSelfOwnedCreate` guard mirrors only 1 of the rule's 3 create
  conjuncts — a create with `ownerId == uid` but `uid` absent from `memberPermissions` logs
  `granted: true` client-side and is then server-denied. Third consecutive deferral of this
  gap (BUT-1665 → BUT-1679 → now). **requiresPlanMode: true** (High + security +
  `lib/repositories/`). Router: full-panel.
  - Fix: emulator rules tests for `unified_shared_shopping_lists` (owner write, member-with-edit
    write, revoked/non-member write denied — the `_onReplayRejected` path — and a create that
    forges `ownerId` or omits itself from `memberPermissions`); widen
    `_requireSelfOwnedCreate` to all three conjuncts with a test proving the omitted-member
    case now logs `granted: false`; enforce (assert/throw, not comment) the `_appendPayload`
    whitelist with a test for a mutator touching a non-whitelisted field; fix the stale doc
    comment at `shopping_repository_routing_module.dart:232-235`.
  - Acceptance:
    1. Emulator rules tests cover all four named cases (owner allow, member-edit allow,
       revoked/non-member deny, forged-create deny).
    2. `_requireSelfOwnedCreate` checks all three create conjuncts; a test proves the
       omitted-from-`memberPermissions` case is denied client-side before it ever reaches the
       server.
    3. The append whitelist is enforced in code (assert/throw), not just documented.
    4. `firebase-backend-security` AND `firestore-rules-tester` both review the diff.

- [ ] **BUT-1758** [Tier A][build] BUT-1733's AC2 shipped six hand-rolled inline assertions
  instead of the one shared test helper the criterion asked for — a fourth write path added
  later would have no guard and the suite would stay green. **requiresPlanMode: false**
  (Medium, no security label, test-file-only). Router: single (QA/Test Engineer).
  - Fix: extract `expectContributorTrailExtended(doc, writerUid)` (or similar) and use it at
    all three write sites (create, chokepoint, update) in
    `shopping_repository_routing_module_test.dart`; consider driving it from a registered list
    of write paths so a new one must be added for the suite to compile.
  - Acceptance:
    1. One shared helper function asserts the contributor-union invariant, used at all three
       write-site tests — no remaining hand-rolled inline `expect(contributorUserIds...)`.
    2. The six existing assertions are replaced, not duplicated alongside the helper.

## Agent B — backend cleanup: dead/wrong-path reads of a retired collection
Area: backend. Router: single (Vendor/Procurement, Data Analyst/BI, Growth/ASO,
Information Architect). Files: `functions/src/analytics/compute-feature-retention.ts`,
`functions/src/social/on-profile-updated.ts`,
`lib/services/unified/friends/friends_utility_operations.dart`,
`admin/reset-user-data.ts`, `lib/core/constants/firestore_collections.dart`, plus updated
tests under `functions/src/__tests__/compute-feature-retention.test.ts` and Dart/Jest
equivalents for the other two sites (disjoint from every other batch).

- [ ] **BUT-1724** [Tier A][build] Three dead or wrong-path reads of the retired
  `shopping_lists` collection, found while verifying the BUT-1697 rename was complete.
  **requiresPlanMode: false** (Medium, no security label). Router: single.
  - Fix: (1) `compute-feature-retention.ts:206-216`'s `shopped` retention probe reads
    `users/{uid}/shopping_lists`, which nothing writes → always false → route to
    `Collections.unifiedShoppingLists`. (2) `on-profile-updated.ts:160-165` loops
    `unifiedShoppingLists` as a top-level collection when personal lists are a user
    subcollection → matches nothing, bills a query per rename → fix the path shape. (3)
    `friends_utility_operations.dart:145-150` reads a top-level `shopping_lists` with
    fields the live model doesn't have; the rules catch-all denies it and the caller
    swallows the error, so `getRecentShoppingCollaborators()` is permanently empty — fix the
    read or delete the feature (ticket calls for a decision, not silent deletion). Also:
    `admin/reset-user-data.ts:46` deletes list docs but not their `items` subcollection —
    orphans them on manual remediation the same way the cascade used to.
  - Acceptance:
    1. All three reads either hit the live path or are deleted; the retention/collaborator
       features they power work or are explicitly removed (state which, in the commit body).
    2. `admin/reset-user-data.ts` also removes the `items` subcollection per list.
    3. `firestore_collections.dart`'s `userShoppingLists` doc comment names every remaining
       reader accurately (today it names only one of three).
    4. If `getRecentShoppingCollaborators()` is kept working, a test proves it returns real
       collaborators; if deleted, no dead reference remains.

## Agent C — account security: Auth-displayName persistence + notification rate-limit pin
Area: account / backend. Router: single (Software Architect, Product Manager /
FinOps, Vendor-Procurement). Files: `lib/services/realtime/realtime_menu_service.dart`,
`lib/services/realtime/realtime_recipe_service.dart` (corrected target — see Step-0 note
above), `functions/src/notifications/send-notification.ts`,
`functions/src/middleware/rate_limiter.ts` (read-only reference), plus new/updated tests
under `test/unit/services/realtime/` and `functions/src/__tests__/` (disjoint from every
other batch).

- [ ] **BUT-1736** [Tier A][build] `realtime_menu_service.dart` and
  `realtime_recipe_service.dart` both persist the raw Firebase-Auth display name (via
  `PermissionService.currentUser?.displayName`) instead of `UserService.profileDisplayName` —
  the exact class of bug BUT-1705 fixed for the two shopping writers and recipe-share, scoped
  out here at the time. **requiresPlanMode: true** (Medium + security label). Router: single.
  - Fix: switch both `_currentUserDisplayName` getters to `UserService.profileDisplayName`
    (no Auth fallback), matching BUT-1705's pattern exactly. Leave `currentDisplayName`
    (display-only reads) alone.
  - Acceptance:
    1. Both sites persist `profileDisplayName`; a test with a real `UserService` and an empty
       profile proves no Auth handle is written.
    2. A grep proves no remaining *persisting* call site reads the raw Auth
       `.displayName` — display-only reads are unaffected and stay.
    3. If either site turns out to need a pre-profile-load fallback, that is stated in the
       commit body, not silently kept.

- [ ] **BUT-1692** [Tier A][build] The notification batch cap (`MAX_BATCH_NOTIFICATIONS =
  100`) and its rate-limit bucket ceiling (`maxTokens: 100`) must stay in lockstep and
  nothing enforces it — lowering `maxTokens` below the batch cap would make every full-size
  batch permanently undeliverable, invisible to the current suite (it stubs the rate
  limiter). **requiresPlanMode: true** (Medium + security label). Router: single.
  - Fix: `export` the constant; add a `RATE_LIMIT_CONFIGS`-pinning assertion (precedent block
    already exists in `rate-limiter-daily-cap.test.ts`). Also fold in two Medium findings
    from the same review: route the batch rate-limit denial through `enforceRateLimit(...)`
    so a hit actually writes the `system_events`/`rate_limit_violation` audit row (today it's
    silent); narrow the preflight docstring's "malformed or oversized payload is rejected
    without consuming budget" claim to "non-array" (element-level validation runs after the
    charge, so a poison-pill element inside a valid-shaped batch IS charged first).
  - Acceptance:
    1. A test fails if `RATE_LIMIT_CONFIGS.sendNotificationBatch.maxTokens` is ever set below
       `MAX_BATCH_NOTIFICATIONS`.
    2. A batch rejected for rate-limit reasons writes an audit row (test asserts the
       `system_events` write, not just the thrown error).
    3. The preflight docstring's guarantee claim matches actual behaviour (narrowed to
       non-array rejection, not all malformed payloads).

## Agent D — housekeeping: ADR record, flaky test, member-dialog widget test
Area: backend / shopping (docs + tests only, no production behaviour change). Router:
skip/single (no security-sensitive production file touched). Files:
`docs/architecture/ADR-002-collaborative-list-membership-guard.md` (new, number TBC at
implementation — check the next free ADR number),
`test/integration/firebase/repositories/comments_repository_integration_test.dart`,
`lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart`
(read-only, testability seam only if needed), new
`test/widget/shopping/shopping_member_management_dialog_test.dart` (disjoint from every
other batch).

- [ ] **BUT-1752** [Tier A][build] BUT-1726 shipped a materially different (and larger)
  design than its plan — a new public repository method
  (`updateCollaborativeListMembership`), a new exception type
  (`StaleAccessControlBaseException`), a new service/module method pair, and a retyped
  `ListMemberOperations` seam — with no ADR and no specialist review naming the new method.
  **requiresPlanMode: false** (High priority, but pure doc + review-marker record, no code
  behaviour change). Router: skip.
  - Fix: write a short ADR recording the design actually shipped and why it diverged from
    the plan; ensure the `firebase-backend-security` marker for this commit explicitly names
    `updateCollaborativeListMembership`.
  - Acceptance:
    1. An ADR file exists describing the shipped design (new repository method, exception
       type, service/module seam) and the reason it diverged from BUT-1726's original plan.
    2. The review marker for this commit names `updateCollaborativeListMembership`
       explicitly, not just the file it lives in.

- [ ] **BUT-1756** [Tier A][build] `comments_repository_integration_test.dart:139` compares
  two wall-clock timestamps with strict `isAfter` — same-tick timestamps make it flaky
  (measured: 2 of 3 red in a ~380-test batch, clean in isolation, clean on a HEAD control).
  **requiresPlanMode: false** (Medium, test-file-only). Router: single.
  - Fix: `!editedAt.isBefore(createdAt)` (tolerant of same-moment) or control the clock with
    `withClock` and force a determined gap between the two writes. Also scan the same
    integration suite for other strict-`isAfter` timestamp assertions of this shape.
  - Acceptance:
    1. The `editedAt`/`createdAt` assertion is same-tick-tolerant.
    2. Any other strict-`isAfter` timestamp assertion found in the same suite during the scan
       is either fixed the same way or explicitly left with a one-line reason.
    3. Don't widen the fix into a general clock-injection framework — same-file, same-shape
       fix only.

- [ ] **BUT-1749** [Tier A][build] The user-visible payoff of BUT-1726 — "listan har ändrats
  på en annan enhet, läs in den igen" vs. the generic permission-denied line — reaches the
  user only through `ShoppingMemberManagementDialog`, and nothing under `test/` references
  that dialog at all. **requiresPlanMode: false** (Medium, widget-test-only). Router: single.
  - Fix: a widget test driving failed add-member, remove-member and change-permission through
    the dialog, asserting the new Swedish message is shown (not the generic line) in each
    case.
  - Acceptance:
    1. All three flows (add/remove/change-permission) are exercised in the test.
    2. Each asserts the specific "changed on another device" message, not just "some error
       shown".
    3. No production file changes beyond a testability seam if one turns out to be needed —
       state in the commit body if one was.

## Deferred to capacity (clear mandate, held back — same reasoning as the last two sprints:
adding a 5th ticket to Agent A or a 3rd non-doc ticket to Agent C risks the agent timeout
the automation-proposals rule warns about, and several of these share a file family with
tickets already selected this sprint)

- **BUT-1743** — shopping repository hygiene (guaranteed-denied read on personal create,
  orphaned items subcollection, unguarded delete twin). Same file
  (`firebase_shopping_repository.dart`) as no ticket selected this sprint, but Agent A is
  already at its 4-ticket cap and this is a distinct file from all four of Agent A's tickets
  — held purely for agent-count capacity, next sprint's Agent A.
- **BUT-1717** — Swedish-boundary lint can't catch the dynamic `RegExp(r'\b' + var + r'\b')`
  form. Tooling-only, no file conflicts, held for capacity (would have been Agent B/C's 3rd).
- **BUT-1754** — may a lone colon-terminated line become the recipe title? Explicitly a
  product/title-quality call per the ticket itself ("no allergen-safety question; pure title
  quality") — **build-review disposition if picked up**, not build; held this sprint for
  capacity, not ambiguity, but flag for her either way when it is picked up.
- **BUT-1738** — `ShoppingListPermissionGuards` has no test file of its own. Same file family
  as this sprint's BUT-1706/1746 guard changes — a test written now would need rework the
  moment those land. Next sprint's Agent A once this sprint's guard changes settle.
- **BUT-1716** — the other shared-shopping repository stamps no "last changed by" at all.
  Same file family as BUT-1746/1706. Held for the same reason as the last two sprints.
- **BUT-1748** — ~50 remaining `logPermissionCheck` fire-and-forget call sites across the
  whole repository (not just shopping, which BUT-1741 already fixed). Genuinely large
  (spans `base_shared_content_repository.dart`, `firebase_comments_repository.dart`,
  `firebase_friends_repository.dart`, `firebase_notifications_repository.dart`,
  `firebase_ratings_repository.dart`, `firebase_shared_menu_repository.dart`,
  `firebase_shared_recipe_repository.dart`, `firebase_shared_shopping_repository.dart`,
  `firebase_social_request_repository.dart`, `firebase_user_repository.dart` (15 sites),
  `friend_category_repository.dart` (8 sites), `user_root_deletion_mixin.dart`) — this is a
  cross-module sweep (tierCTriggers match), not a single-batch fit. Recommend splitting into
  2-3 tickets by repository cluster next sprint rather than one 13-file batch.
- **BUT-1730** — build a real Firestore-emulator CI lane. Tier C, high-risk; BUT-1695 already
  attempted this once and only landed the tag change (the real leg reproduced a
  `PlatformException`). Needs a harness fix first, not another CI-YAML pass.
- **BUT-1731** — deploy-day ops task (run the backfill, delete the export after the 30-day
  soak). `need-malin` label, Tier D — not autonomous work.

## Needs your call (not built this sprint)

- **BUT-1747** — GDPR: shared shopping lists the user has LEFT are missing from the export
  because the client can no longer read them and a new Cloud Function read path is needed.
  High priority, real gap, but a new Cloud Function is a bigger and more ops-adjacent lift
  than this sprint's batches — **my read: worth building, but wanted as its own dedicated
  sprint slot (not squeezed into an already-full-panel batch) given it needs its own deploy
  step.** Recommend: next sprint, alone or paired with BUT-1731's deploy-day step.
- **BUT-1718** — a household member cannot leave a shared shopping list (rules deny
  self-removal). This is a deliberate rule, not an obvious bug — whether self-removal should
  be allowed is a product/permissions decision, not a correctness fix. **My read: needs your
  call**, ideally alongside BUT-1706's rules-review pass once it's landed this sprint.
- **BUT-1699** — enable the two Firestore TTL policies that were never turned on
  (`notification_send_events`, `scheduled_notifications`). This changes real data-retention
  behaviour on production data. **My read: needs your call** — not something to silently
  auto-enable even though the code change itself is small.
- **BUT-1693, BUT-1480, BUT-1323, BUT-1685, BUT-880, BUT-1502, BUT-1557, BUT-1179, BUT-1368,
  BUT-863, BUT-1445, BUT-1649, BUT-1636, BUT-1361** — the standing `need-malin` manual-QA /
  compliance-diagnosis / product-decision backlog, unchanged this sprint.

## Post-sprint steps (to run after implementation)

1. `dart analyze --fatal-infos` + `npx tsc --noEmit -p functions` on the full tree.
2. File follow-up Linear tickets for every deferred sub-scope before commit.
3. Commit through the gate: `code-reviewer` on all `.dart`, `firebase-backend-security` +
   `firestore-rules-tester` on Agent A's diff (rules test file touched), `cloud-functions-specialist`
   on Agent B/C's `functions/src` touches. Confirm `firestore.rules` itself is unchanged
   (Agent A only adds *tests* against the existing rule) before deciding
   `firestore-rules-tester` scope.
4. Push (push does NOT trigger deploy in this repo — `pushTriggersDeploy: false`).
5. Transition tickets: Tier A/C build + all-pass → Done. Any failed/unclear criterion → In
   Review + plain-language comment + PushNotification.
6. Re-check `docs/onboarding/workflow-map.stale` before commit — none of this sprint's flows
   look map-relevant (repository/service internals, CI/tooling, docs), but verify rather than
   assume.
7. Grade each selected ticket against its OWN diff before any Done/In Review transition.

## Deviation log — files changed that the plan did not declare

The delivery digest requires a widened file to be recorded here **and** named in the
reviewer marker. Two rounds widened this sprint: the parallel implementation itself, and
the rescue pass Malin authorised after the engine held its own commit.

**Round 1 — the parallel batches**

| File | Batch | Why it was touched |
| --- | --- | --- |
| `lib/repositories/firebase/modules/shopping_list_permission_guards.dart` | A | The guard the routing module's declared-base check delegates to; the fix could not land in the caller alone. |
| `lib/repositories/firebase/modules/shopping_offline_write_module.dart` | A | Owns `privilegedKeys`, the single enumeration ADR-002 is written about. |
| `lib/services/unified/unified_friends_service.dart` | B | The dead-read at `friends_utility_operations.dart` is reached through this facade; deleting one without the other leaves a caller pointing at nothing. |
| `lib/viewmodels/recipe_form/recipe_collaborative_manager.dart` | C | **Third** Auth-displayName persister, outside BUT-1736's declared `lib/services/realtime/*`. Found by grep during implementation; per the BUT-1691/1697 twin-class lesson, fixing one and leaving the sibling is the failure mode, not the fix. |
| `functions/src/middleware/rate_limiter.ts` | C | The plan declared it "(read-only reference)". It was modified: how the audit row's Firestore handle is resolved. |

**Round 2 — the rescue pass, 2026-07-30 (after four tickets failed outcome verification)**

| File | Ticket | Why it was touched |
| --- | --- | --- |
| `lib/repositories/firebase/firebase_data_export_repository.dart` | BUT-1721 | The fix the ticket **named** and the sprint never made: `messages_truncated` used `>= cap` against a query limited to `cap`, so an exactly-full conversation reported itself clipped. Now probes `cap + 1`. |
| `lib/repositories/interfaces/shopping_repository.dart` | BUT-1752 | ADR-002 had no inbound pointer anywhere in the repo — the doc rule's "something must point at it". |
| `functions/src/__tests__/shared-shopping-lists-rules.test.ts` | BUT-1706 | SSL40: a revoked member's **write** deny. The first pass pinned only their read. |
| `tools/check_null_filter.sh`, `.github/workflows/architecture-validation.yml` | BUT-1746 | AC2 asked for a guard that "fails the build"; it ran from lefthook only. Now CI-wired, with a `--self-test` that proves its own detection. |
| `test/integration/firebase/repositories/recipe_repository_integration_test.dart` | BUT-1756 | AC2's scan was file-scoped, not suite-scoped; this is the identical strict-`isAfter` twin, and it also dropped a 100 ms real sleep. |
| `test/unit/repositories/firebase/firebase_data_export_repository_conversations_test.dart` (new) | BUT-1721 | Boundary coverage at exactly-cap. Mutation-tested: 1 red with the old `>=`, 3 green with the fix. |
| `test/unit/viewmodels/recipe_form/recipe_collaborative_manager_display_name_test.dart` (new) | BUT-1736 | Closes AC1 for the third persister, including the 30-second presence heartbeat. Mutation-tested: 3 red when the Auth handle is restored. |

## Outcome — graded 2026-07-30 against each ticket's own diff

| Ticket | Disposition | What actually shipped |
| --- | --- | --- |
| BUT-1746 | **In Review** `[!]` AC1 | Four literal-null filters fixed; the mechanical guard is now CI-wired **and self-testing**. AC1's "assert the emitted filter, not the result" is **not** met — the existing tests are result-based and redden only because the fake throws. Graded openly; the remaining half is BUT-1765. |
| BUT-1721 | **Done** | Both aggregator holes closed, **and** the named `>=` fix in the export repository that the first pass missed. Exactly-at-cap boundary test added and mutation-proven. The two untouched export managers (21 bare catches) are BUT-1760. |
| BUT-1706 | **Done** | Rules coverage for read gate, create conjuncts and owner-only delete, plus SSL40 — the revoked member's **write** deny, the actual `_onReplayRejected` scenario. 40/40 green on the emulator. |
| BUT-1752 | **Done** | ADR-002 written **and** pointed at, from the interface declaration of the method it documents. |
| BUT-1758 | **Done** | Shared contributor-union test helper across all three write sites. |
| BUT-1724 | **Done** | Three dead/wrong-path reads of the retired collection fixed; the `shopped` retention probe now reads a collection something actually writes. Two structural gaps it exposed are BUT-1761/BUT-1762. |
| BUT-1736 | **Done** | Both declared realtime persisters **and** the third one found by grep, each now covered — create stamp, and the presence heartbeat. |
| BUT-1692 | **Done** | Notification batch cap and its rate-limit bucket pinned to each other in code. The single-send callable's separate hole is BUT-1763. |
| BUT-1756 | **Done** | The flaky `editedAt` assertion is clock-controlled, and AC2's suite-wide scan reached its twin in the recipe suite. |
| BUT-1749 | **Done** | Widget test for the "listan ändrades på en annan enhet" state. |

**Why this sprint held its own commit:** the engine's outcome verification failed four
tickets on data-safety, then could not withdraw the two batches holding them — a later
automated fix had rewritten the same lines, so no clean patch reversal existed. It stopped
rather than half-withdraw, which was the right call. Malin chose rescue-in-two-steps over
ship-as-is or discard, 2026-07-30.

## What the rescue-pass review round found

Five commit-gate specialists ran against the staged diff — none of them had ever seen a
byte of it, since every marker in `.claude/state/` was the previous sprint's. Verdicts:
`code-reviewer` fail on the export services and on the repository layer, pass on the
display-name persisters; `cloud-functions-specialist` pass; `firestore-rules-tester` pass
with three required additions; `firebase-backend-security` pass on its five files;
`testing-specialist` pass with three coverage gaps.

Every blocking finding was verified against the code by hand before being acted on — the
digest's rule that a verifier's `fail` is a hypothesis, not a fact. Three were real and are
fixed in this commit:

1. **The aggregator asserted total failure for a partially-successful section.** The new
   derived warning said "could not be exported" for `shared_shopping_lists` when one of its
   three probes failed and the other two returned — a false incompleteness claim at the root
   of an Art. 15 bundle. This is the ticket's own defect with the sign flipped.
2. **`data_completeness` was silent about failures**, only about truncation: three failed
   sections with nothing clipped left the field absent, byte-identical to a clean bundle.
3. **A raw uid and an empty error object in a Cloud Functions warn log** — `err` nested in
   the payload serialises to `{}`, so the field meant to say WHY a probe failed said nothing.

Plus three coverage gaps closed (`data_completeness`'s warnings arm, and the failure-envelope
tokens in both export managers), all mutation-proven, and three rules assertions (SSL41-43).

**The reviewers also found eight defects OLDER than this sprint.** Two are serious enough to
name here: account deletion has never deleted a chat message, and the Art. 15 export has
never returned one — both because the code reads a Firestore subcollection that nothing
writes to. Each needs a new index and its own deploy, so neither was squeezed into this
commit. Verified by hand against the code before filing.

One reviewer's own claim was wrong and is recorded so it is not repeated: two Firestore deny
verdicts CANNOT be told apart by their `PERMISSION_DENIED` string — the evaluation error
fingerprints the rule LINE, not the actor. SSL40's non-vacuity was proven with a fail-closed
probe and a discriminating mutation instead.

**Follow-ups filed 2026-07-30:** BUT-1759 (the decision itself), BUT-1760, BUT-1761,
BUT-1762, BUT-1763, BUT-1764, BUT-1765, BUT-1766, BUT-1767, BUT-1768, BUT-1769, BUT-1770,
BUT-1771, BUT-1772 (`need-malin`), BUT-1773.

---

# Archived — 2026-07-30 sprint (10 tickets, shipped 2026-07-30 in `c17c4068e`, ship
remediation in the same commit; lessons in `a14bb3a16`)

Backlog scanned: 106 Backlog + 6 Todo + 0 In Progress + 0 Triage, team Butlery (Linear MCP
live). Two backlog items (BUT-677, BUT-722) carry `onboarding-reserved` and were excluded
from scoring entirely, per instruction.

**Ship-state check first.** The 2026-07-27 sprint's own todo.md ended "STAGED AND
UNCOMMITTED" — its review markers pinned the *previous* sprint's blob shas, so no
specialist had actually seen that diff. That gap is closed: commit `e14455ceb`
("shared-list erasure completeness, conversion safety, Swedish gluten rescue, CI guard
hardening", 2026-07-29) re-ran all five commit-gate specialists against the real staged
diff from scratch, fixed two more blocking defects found during that pass (an erased-owner
uid re-created by the backfill migration, and a migration that stalled at ~10,350 docs
while reporting success), and closed BUT-1723/1719/1705/1725/1713/1714/1707/1708/1709/1695.
Verified by reading the commit body and `git log`, not by trusting a summary.

**Obsolete (superseded by shipped work, closing below):**
- **BUT-1677** ("Measure Firestore rules coverage and gate newly added match blocks") —
  every acceptance criterion is now met: the coverage script + workflow shipped in
  `22e960af3`, and the one criterion still pending then ("the follow-up ticket with the
  untested-block count exists") is exactly what BUT-1708 became, shipped in `e14455ceb`.
  Closing citing `e14455ceb`.
- **BUT-1697** ("last changed by" can name the wrong person / wrong source / survives
  deletion) — all three numbered defects are fixed: the attribution write path is
  `profileDisplayName` with no Auth fallback, and the cascade + residual probe now reach
  list- and item-level fields by uid match (both BUT-1705, shipped in `e14455ceb`); the
  removed-member residual is closed by the `contributorUserIds` trail (BUT-1725, same
  commit). Of the two "also worth folding in" items: the N-transaction `uncheckAllItems`
  concern no longer applies — `firebase_shared_shopping_repository.dart:642` uncheckAllItems
  is now a single repository-level batch operation, not `Future.wait` over N per-item
  transactions. The non-owner-cannot-leave-a-list gap is real and is tracked separately as
  BUT-1718 (open, product call, see Deferred below). Closing BUT-1697 citing `e14455ceb`
  + BUT-1718 for the one remaining thread.

**Premise re-verified against current `main`** for every ticket selected below via targeted
grep (not just `git log`): `firebase_shared_shopping_repository.dart` has zero
`contributorUserIds` references (BUT-1733, BUT-1732 both confirmed live — the trail exists
only in `shopping_repository_routing_module.dart`); `functions/scripts/rules-coverage-report.js`'s
`evaluateGate` still requires `exprHit === 0` and `stripComments` still has no string-literal
awareness (BUT-1729, both holes read directly in the source); `lib/services/import/text_import_strategy.dart`
still has no reference to `HeadingWordLists`/`bareGlutenWords` (BUT-1727, confirmed —
`heading_word_lists.dart` is only imported by `recipe_section_detector.dart`);
`check-test-registration.js` still scans only `functions/src/__tests__/`, never
`functions/package.json`'s own `test:*` scripts (BUT-1740). All still live — nothing here
is already fixed.

Every ticket below was Claude-authored — mostly `firebase-backend-security`'s own follow-up
findings (F2, F5) from the `e14455ceb` review pass, plus verification-reproduced holes in
tooling that same sprint built — never human-approved. The mandate column records why each
is safe to build anyway.

*(Full per-ticket bodies, outcome table and deviation log from this sprint trimmed here for
length — see git history of this file for the complete 2026-07-30 record, or `c17c4068e`'s
commit body.)*

## Outcome — graded 2026-07-30, shipped in `c17c4068e`

| Ticket | Disposition | What actually shipped |
| --- | --- | --- |
| BUT-1741 | **Done** | All four shopping-module audit callbacks retyped `Future<void>`; all 17 call sites await, one explicit `unawaited()` with a stated why. |
| BUT-1715 | **Done** | Swedish word boundaries for dotted abbreviations fixed at both call sites. |
| BUT-1729 | **Done** | Four rules-coverage gate holes, each mutation-confirmed. |
| BUT-1740 | **Done** | CI guard suites can no longer be silently deregistered. |
| BUT-1739 | **Done** | `"ca 2 dl grädde"` → `"grädde"`, 24/24 golden tests green. |
| BUT-1733 | **Done** `[!]` AC2 | Contributor trail extended; AC2's shared-test-helper ask unmet (six inline assertions instead) — now BUT-1758. |
| BUT-1726 | **In Review** | Round-1 Critical closed; a device-staleness gap is pre-existing, not introduced here. Design diverged from plan with no ADR — now BUT-1752. |
| BUT-1732 | **In Review** | 3 of 4 selectors ship; `lastActivityByUserId` needs a Cloud Function — now BUT-1747. |
| BUT-1727 | **In Review** | Gluten rescue reaches the real import path; cross-class agreement test (AC2) undocumented. |
| BUT-1677 | **Closed — obsolete** | Every criterion met by `22e960af3` + `e14455ceb`. |
| BUT-1697 | **Closed — obsolete** | All three defects fixed in `e14455ceb`; remaining thread is BUT-1718. |

**Founder decision recorded 2026-07-30:** the shared-shopping-list GDPR export ships with
other members' raw user ids, permission levels and the full `contributorUserIds` array
unredacted — Malin's explicit call. Display names ARE stripped. Recorded in
`ACCEPTED_DEVIATIONS.md` and the always-on digest.

**Follow-ups filed 2026-07-30:** BUT-1745 (closed by the ship commit), BUT-1746, BUT-1747,
BUT-1748, BUT-1749, BUT-1750 (done in commit), BUT-1751 (done in commit), BUT-1752, BUT-1753,
BUT-1754, BUT-1755, BUT-1756, BUT-1758 (filed after ship, from BUT-1733's own AC2 gap).

---

# Archived — 2026-07-27 sprint (10 tickets, shipped 2026-07-29 in `e14455ceb`)

Selected: BUT-1723, BUT-1719, BUT-1705, BUT-1725 (Agent A — shopping/account, full-panel),
BUT-1713, BUT-1714 (Agent B — parsing, single), BUT-1707, BUT-1709, BUT-1708, BUT-1695
(Agent C — backend/CI, single). All shipped Done except BUT-1695 (superseded by BUT-1730)
and BUT-1703 (re-closed). Full detail trimmed — see prior git history of this file.

---

# Archived — 2026-07-26 sprint and earlier

Trimmed for length — all fully shipped. See prior git history of this file for the complete
record if needed.
