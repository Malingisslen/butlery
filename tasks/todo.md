# BUT-2398: chat participants may react to each other's messages (2026-10-19)

Router tier: full-panel (`firestore.rules` high-stakes). Decision: Malin chose "Tillåt reaktioner"
on the card 2026-10-19 (each participant adds/removes only their own reaction, blocked people
cannot add, account deletion removes them, the export lists them).

## Goal beyond the ticket

Cause: `match /messages/{messageId}` has no reactions limb, so only the sender limb accepts a
`reactions.<key>` write. Sibling faults found: the sender limb and the create limb do not pin
`reactions`, so a sender can forge other people's uids into reactions on their own message.
No erasure path removes a uid from `messages.reactions`. Regression guard: emulator tests on
every limb, cascade and export unit tests.

## Steps

1. **Rules** (`firestore.rules`)
   - Hoist `reactionKeys`, `onlyCallerAdded`, `reactionListOk`, `reactionShapeOk` from
     `match /recipe_comments` to service level (bodies unchanged); keep the key-parity test
     in `account-deletion-cascade.test.ts` finding `reactionKeys()`.
   - In `match /messages`: `canReadMessage()` = the read rule's predicate (participant; group
     `sentAt >= memberSince[uid]`).
   - ADD limb: `isAuthenticated() && !isGuest() && canReadMessage() && reactionShapeOk(true)
     && isAgeCompliant() && type != 'duplicateBlocked'` + the BUT-2017 block gate (exact
     `blocks` read in a DM, `notBlockedByAnyOf` mirror). No `isAccountMatured`, no rate limit
     (as BUT-2115).
   - REMOVE limb: `isAuthenticated() && canReadMessage() && reactionShapeOk(false)`.
   - Sender limb: add `'reactions'` to `cannotModify`. Create limb:
     `request.resource.data.get('reactions', {}) == {}`. Verify no client sender update or
     create carries a non-empty reactions map.
2. **Erasure** (`functions/src/account/account-deletion-cascade.ts`): give `scrubCommentField`
   a collection argument; add `scrubMessageReactions` (six keys, `arrayRemove(uid)`, cap 2000
   per key, decline above cap, one failing key fails the step); probe leg in
   `probeResidualData` for `messages`. Register `runStep("message_reactions")` right after
   `comment_reactions` in `request-account-deletion.ts`.
3. **Export**: extend `exportCommentReactions` (`functions/src/exports/comment-reactions.ts`)
   with `messageReactions: {messageId, key}[]` (ids only, sorted, decline code
   `message-reactions-too-large`). Client `comment_reactions_export_manager.dart` adds a
   `message_reactions` section and maps the new code.
4. **Client toggle**: unchanged (already writes `reactions.<key>` arrayUnion/arrayRemove of the
   caller's uid; UI offers only the six keys).
5. **Accepted deviations**: a dated BUT-2398 entry in `.claude/rules/accepted-deviations.md` and
   `docs/architecture/ACCEPTED_DEVIATIONS.md`.
6. Not in scope: skipping `syncConversationLastMessage` for reaction-only updates (cost
   optimisation, needs its own race review) — ticket.

## Verification

- Emulator: `conversations-rules.test.ts` new section (allow: DM add/remove, own message, group
  after memberSince, blocked user removes, remove on duplicateBlocked, guest removes, remove with
  six full keys, create without reactions, sender edit, receipts; deny: non-participant, before
  memberSince, left member, other uid add/remove, unknown key, duplicate uid, >500, mixed with
  content/status, DM block, group mirror block, guest add, under-age add, duplicateBlocked add,
  sender forgery, create with reactions). Re-run `recipe-comments-rules.test.ts`.
- CF unit tests: cascade scrub, decline, failing key, probe leg, step order; export section,
  ids-only, decline.
- Dart: export manager section test. `flutter analyze`, functions `npm run build` + tests.
- Mutation-check: removing each new rule conjunct fails its test.
- Deploy: functions first (export + deletion), then rules.

## Summary for Malin

Nu kan alla i en chatt reagera med emoji på vilket meddelande som helst, men bara lägga till
eller ta bort sin egen reaktion. Den som är blockerad kan inte lägga till nya reaktioner men kan
alltid ta bort sina gamla. Ingen kan längre fejka någon annans reaktion, inte ens på sitt eget
meddelande. När ett konto raderas försvinner personens reaktioner i alla chattar, och
dataexporten listar dem, precis som för kommentarer.
