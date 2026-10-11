# Delade listor och grupper: två regeländringar (2026-10-11)

Malin chose "Starta nu" on the coordinator's card (2026-10-10) for the work #671 had been
holding back. This thread owns `firestore.rules` while it runs. The previous plan in this file
(Mer, omtänkt) belongs to another thread's branch; this branch carries only this plan.

- BUT-2102 needed no work: BUT-2243 already moved the AI cost to the server ledger
  (`functions/src/middleware/llm_cost_ledger.ts`, "closes BUT-2102") and `rate_limits/imports`
  admits no cost key (`functions/src/__tests__/rate-limit-rules.test.ts`). Closed in Linear.
- Slice A: an older app build can recreate a group that has been handed over (BUT-2324 follow-up).
- Slice B: BUT-2089, consent before someone is put on a shared shopping list (Malin 2026-10-10,
  option a: "Samtycke vid tillägg").

Each slice is its own PR, merged and deployed before the next starts.

## Decisions in this plan (defaults taken, Malin can change any)

| Call | Default | Alternative |
|---|---|---|
| Who must accept | Everyone added to a shared list (Malin 2026-10-10, option a) | Only after a leave (option b) |
| Level an invitation gives | What the inviter picks, `edit` preselected as today | Always `view` until the owner raises it |
| Where the invitee answers | Top of the shopping-list overview | Groups tab, beside group invitations |
| Push notification | None, as group invitations | A push on every invitation |
| After a "Neka" | Same inviter cannot invite to that list for 30 days | No pause; or a block only |
| Older app builds | Adding someone fails with today's error until updated | Keep the old direct add for older builds (leaves the hole open) |
| Groups moved before this ships | Not backfilled (only Malin's account was live) | One-off script to tombstone them |

Weakest point: the invitee only sees an invitation when they open their shopping lists.
Reply starter: "Kör" builds it as above; "Ändra: …" names a row to change.

## Slice A: a handed-over group cannot be recreated under the old owner

### The defect

`handOverGroup` (BUT-2321) creates the group under the new owner and deletes
`users/{oldOwner}/friend_categories/{groupId}`. The create limb in `firestore.rules` admits any
create by the path owner whose `ownerId` names them. An app build from before BUT-2326 (#644)
saves an owner edit with `set()`, and so does any such write it queued offline. After the
handover that `set()` lands on a missing document, is evaluated as a create, and passes: the old
owner gets the group back as its owner, alongside the moved copy. #667 named this and left it for
a rules change.

### The change

1. `handOverGroup` writes a tombstone `group_moves/{groupId}` = `{ movedAt }` with `tx.set`
   (never `create`: the same id can be handed over again) in the same transaction as the move. It carries no uid, so it is not personal data and needs no erasure
   or export leg.
2. `firestore.rules`: the owner create limb on `users/{userId}/friend_categories/{categoryId}`
   gains `&& !exists(/databases/$(database)/documents/group_moves/$(categoryId))`.
   `group_moves` gets an explicit `allow read, write: if false` block, a `Collections` constant
   and a place in the reset and erasure coverage lists (it holds no uid).
3. Group ids are random Firestore ids, and the current app creates a new group with a new id,
   so no legitimate create meets a tombstone. A group handed back to its first owner moves via
   the Admin SDK, which the rule does not see.

Cost: one `exists()` read per group create. Groups handed over before this deploy have no
tombstone; production has had BUT-2321 since 2026-10-09 with only Malin's account active, so this
is accepted rather than backfilled.

### Acceptance

- Rules test: owner create of an id with a tombstone is DENIED; the same body and actor on an id
  without one is ALLOWED (single-variable control); a client cannot read or write `group_moves`.
- Integration test (`hand-over-group.integration.test.ts`): a handover writes the tombstone; a
  refused handover writes none; a second handover of the same id still succeeds.
- Mutation probes: removing the conjunct reddens the deny case; removing the tombstone write
  reddens the integration assertion.
- Deploy order: functions first, then rules (a rule without its writer is harmless; the reverse
  leaves the hole open until rules ship).

## Slice B: BUT-2089, an invitation to a shared shopping list

### What is true today (code map 2026-10-11)

- A seat on a shared list is a key in `unified_shared_shopping_lists/{id}.memberPermissions`.
  The rules let the owner write any map that keeps their own key (`ownerStaysSeated`), and a
  non-owner admin seat anyone (`adminManagesMembers`, BUT-2013). Create admits any map that
  seats the owner. No arm involves the person being seated, and no block check applies.
- Client seat writers: `ListMemberOperations.addMember` (member dialog,
  `shopping_member_management_dialog.dart`), and `convertPersonalToCollaborative` →
  `createCollaborativeList(memberIds)` (`shopping_list_operations.dart`), which seats the chosen
  friends at create.
- The "realtime" share (`universal_share_dialog_viewmodel.dart`) writes a `shared_content` row,
  and the recipient's "Gå med" (`joinSharedShoppingList`) calls `addMember` for themselves. A
  non-member cannot manage members, so that call returns false and no seat is written, while
  the join reports success. That path never seats anyone today; it is filed separately, not
  fixed here.
- Group invitations already have the consent shape this ticket asks for: `social_requests`
  rows of type `groupInvitation`, created by the callable `sendGroupInvitations` (friends both
  ways, block, 50 cap, 7-day expiry), accepted by the callable `acceptGroupInvitation`
  (server seats the caller), declined by the recipient's own status write
  (`social_requests` update rule), shown with `GroupInvitationCard`.

### The change (Malin 2026-10-10, option a: consent on every add)

1. **Rules: nobody but the server seats another person.**
   - Create: `memberPermissions.keys().hasOnly([request.auth.uid])`.
   - Owner arm and `adminManagesMembers`: the new key set is a subset of the old one. Removing
     a member and changing a member's level stay as they are; adding a key is refused.
   - `removesOnlySelfFromMembers` (BUT-1718) is unchanged.
2. **Callable `sendListInvitations(listId, userIds, permission)`** in `functions/src/social/`,
   built on `sendGroupInvitations`: caller is the list owner or an `admin`; each invitee is a
   friend both ways, not already seated, not already invited with a live invitation, and not
   blocking the caller (`blocks/{invitee}_{caller}`, refused as `unavailable` like groups);
   cap 50 per call; writes `social_requests` rows `type: "listInvitation"` with `listId`,
   `listName`, `permission` (`view`/`edit`, default `edit` as `addMember` used), 7-day
   `expiresAt`. App Check, age claim and rate limit as `sendGroupInvitations`.
3. **Callable `acceptListInvitation(invitationId)`**, built on `acceptGroupInvitation`, in one
   transaction: the row is a pending, unexpired `listInvitation` to the caller; the list exists;
   the inviter is still its owner or an admin; no block either way between inviter and caller;
   the map stays at most 200 keys. Then it seats the caller with the invitation's level and marks
   the row `accepted`. Anything else refuses with one generic word, so the inviter's state does
   not leak.
4. **Decline** is the existing recipient status write (`rejected`), which the `social_requests`
   rules already allow. No new rule.
5. **App:**
   - `ListMemberOperations.addMember` becomes `inviteMembers` calling the callable; the member
     dialog says "Bjud in" and reports "Inbjudan skickad" (sent) or names who could not be
     invited. The level picker stays.
   - `convertPersonalToCollaborative` creates the list with only the owner seated, then invites
     the chosen friends. A failed invite keeps the converted list and says who was not invited.
   - The realtime share of a shopping list sends list invitations instead of a `shared_content`
     row. The copy share is unchanged.
   - The invitee sees pending list invitations at the top of the shopping-list overview, using
     `GroupInvitationCard`'s layout (existing components, theme tokens, no new icons):

     ```
     ┌───────────────────────────────────────┐
     │ Inbjudan från Anna                    │
     │ Delad lista: Veckohandling            │
     │                     [Neka] [Gå med]   │
     └───────────────────────────────────────┘
     ```
6. **Re-adding after a leave** (the ticket's harassment loop) now needs the person's yes every
   time, and a block stops the invitation outright. Leaving stays silent (BUT-1718).

### Data protection

- The invitation is a `social_requests` row naming both people, the same shape as a group
  invitation. Erasure already deletes rows naming either party, and the Art. 15 export already
  carries `social_requests`; the new type rides both. Expired rows follow the existing expiry.
- No new personal data on the list document.

### Older app builds

An older build's direct add and its conversion-with-members are refused by the new rules and
show their existing failure message. That is the intended effect (fail closed); nothing they
queued offline can seat anyone either.

### Acceptance

- Rules tests in the existing `functions/src/__tests__/shared-shopping-lists-rules.test.ts`:
  owner and admin adding a key DENIED, each against an ALLOW control that differs only in the
  added key (removing a member, changing a level); create with a second key DENIED against an
  owner-only create ALLOWED; self-leave still ALLOWED.
- Integration tests for both callables (emulator): not a friend, blocked, already a member,
  inviter demoted before accept, expired, wrong recipient, 200 cap, accepted twice.
- Dart tests: invite operation, member dialog, conversion, overview card (accept, decline,
  failure text).
- Mutation probes on the rule conjuncts and on each callable guard.
- Deploy order: functions first, then rules. Between the two, both paths work.

## Open questions

No architecture-changing unknowns. Assumptions: the invitee sees list invitations in the
shopping-list overview (where they act on lists), not in the groups tab; an invitation carries
the level the inviter picked; no push notification (group invitations have none either).

## Stakeholder panel (2026-10-11): conditions folded in

Router: `python tools/stakeholder_router.py --json <plan files>` → `full-panel`, high-stakes hit
`firestore.rules`. Seated: Security Architect, Trust & Safety, Privacy/DPO, DBA, Product Manager,
plus the Codebase Archaeologist. Dropped: Customer Support, Vendor, FinOps, Legal, Monetization,
Agent-Ops and Software Architect (their match was a folder or this plan file, not a concern the
change touches; FinOps' only cost is one `exists()` per group create and two rare callables).
All six: approve with conditions. No conflict between seats, so no ADR.

Slice B conditions (acceptance criteria):

1. **Server-only invitation rows.** The `social_requests` create rule refuses
   `type == 'listInvitation'` from clients; only the callable writes them. Rules test: DENIED
   against an ALLOW control that differs only in `type`.
2. **Accept trusts nothing on the row** beyond its id: one transaction reads the row, the list
   and the friend and block docs; requires `pending`, `expiresAt > now`, `toUserId == caller`,
   inviter currently owner or `admin` of the live list, friends both ways, no block in either
   direction, map ≤ 200; clamps the level to `view`/`edit`; age claim and account maturity as
   `acceptGroupInvitation`; seats with a field-path update and marks the row `accepted` in the
   same transaction. An already-seated caller tapping again gets success; everything else gets
   one generic refusal. Integration cases include a row a client pre-flipped to `accepted`.
3. **Decline memory.** `sendListInvitations` skips an invitee who declined an invitation from
   the same inviter to the same list in the last 30 days, with the same `unavailable` word a
   block gets; an expired invitation may be sent again. A daily cap per caller in
   `rate_limiter.ts` (pinned in `rate-limiter-daily-cap.test.ts`).
4. **Minors** follow the group rule: an invitee must be a friend both ways, which satisfies the
   rules' `passesMinorRequestGate` (`creatorIsFriendOf`). Recorded as the same decided call as
   BUT-1838, not a widening.
5. **Rules subset** written with the existing diff family:
   `memberPermissions.diff(resource.data.memberPermissions).addedKeys().hasOnly([resource.data.ownerId])`
   on the owner arm and `adminManagesMembers` (the stored owner's own key stays addable so an
   unseated owner can re-seat themselves, BUT-1718; the owner arm also refuses an `ownerId`
   change, and the sender cannot delete a declined list invitation); create `keys().hasOnly([request.auth.uid])`. The existing
   `shared-shopping-lists-rules.test.ts` is updated (no second rules file). Two-step remove then
   re-add is denied on the re-add.
6. **Writer inventory** of `memberPermissions` on this collection (lib/ and functions/src) before
   the rules change; every key-adding writer converted or listed.
7. **Model:** `SocialRequestType.listInvitation` with `listId`, `listName`, `permission`;
   `listName` read from the list by the server and bounded to 100 characters.
8. **Inviter UI:** the member dialog lists pending invitees as "Inbjuden" with "Ta tillbaka"
   (the sender may delete their row); the toast says the person has to accept; block and
   not-friend failures share one line so a block never shows.
9. **Invitee UI:** the card sits at the top of the shopping-list overview, with "Neka", "Gå med"
   and a "Blockera" action through the existing block flow. States: loading (buttons disabled
   with progress), offline (accept/decline refused with `errorNetwork`, card stays), refused by
   the server (one generic message, card removed because the invitation is spent or void),
   transient error (message, card stays), empty (no section).
10b. **Client layers:** the callables and the pending-invitation stream go through
   `friends_invitations_operations.dart` → `firebase_social_request_repository.dart` (the group
   invitation analogue), exposed on `UnifiedFriendsService.invitations`; the overview card gets
   a small `ListInvitationsViewModel` registered in `ui_module.dart`. The card is a new widget
   `lib/views/unified_shopping/widgets/list_invitation_card.dart` built from the same shared
   components as `lib/views/social/friends_list/group_invitation_card.dart` (that file is
   group-bound through `GroupInvitation`). The member dialog's pending rows go in a new
   `pending_invitees_section.dart` beside it, so the 704-line dialog does not grow; the
   conversion and share view-model edits replace lines rather than add (both files are on or
   over 500 and are touched only at the call site).
10. **Registration:** `index.ts`, `rate_limiter.ts`, `app-check-enforcement.test.ts`, the daily
    cap test, `functions/package.json` scripts and `test:rules:all`,
    `.github/workflows/firestore-rules.yml` both lists, `tools/check_test_suite_coverage.sh`.
11. **Records:** dated SUPERSEDES entries in both deviation files for the BUT-2013 "admin may seat
    any uid" line and the BUT-2169 "memberPermissions across a block" gap (lists only); the
    BUT-2169 "groups, live lists and realtime menus are untouched" line STANDS, because it is
    about hiding existing content on a block, and nothing here hides or removes an existing
    seat; an
    accepted-deviation line that an invitation left over when a list is deleted stays until it
    expires. Workflow map, `docs/FEATURE_INVENTORY.md`, sv and en ARB keys, and three analytics
    events (sent, accepted, declined).
12. **Tests for the data legs:** the expiry job and the erasure sweep match `listInvitation` rows
    (they filter by party, not type); one test each.

## For Malin, in plain words

Two holes get closed. First: when you hand a group to someone else, an older version of the app
could quietly bring the group back to you. After this, it cannot. Second, the bigger one: today
anyone who owns or runs a shared shopping list can put a friend on it without asking, even right
after the friend left. After this, adding someone sends an invitation. The friend sees it at the
top of their shopping lists and chooses "Gå med" or "Neka", and can block the sender from there.
If they say no, the same person cannot invite them to that list again for 30 days. You, as the
one inviting, see "Inbjuden" next to people who have not answered yet and can take it back.
Nothing changes for lists you only keep for yourself.

- Risk: low for the group fix (one rule line and one server write). Moderate for lists: it
  changes who may seat people, so it gets rules tests, server tests and a run in the app.
- Undo: the rules can be redeployed from the previous version in a minute; the two new server
  functions then simply stop being used.
- An older app version on a phone will get an error when adding someone to a list, until it is
  updated. Today that is only your own phone.
- Verification before done: `flutter analyze --fatal-infos`, the changed Dart and function test
  suites, the rules suite, and the invite, accept, decline and convert flow clicked through in
  the app in a browser.
