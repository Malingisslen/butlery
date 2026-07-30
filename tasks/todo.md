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
