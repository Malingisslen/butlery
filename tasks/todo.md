# BUT-2413: poll votes are erased but not exported (2026-10-19)

GDPR Art. 15/17. Split out of BUT-1919 point 4 (Malin: "Ja, eget ärende", 2026-10-19).
Router: `python tools/stakeholder_router.py --json firestore.rules
lib/repositories/firebase/firebase_data_export_repository.dart
lib/services/account/export/social_export_manager.dart` → `full-panel` (high-stakes hits:
`firestore.rules`, `social_export_manager.dart`). Not convened as eleven parallel seats (the
model-choice rule forbids parallel agents); the Privacy/DPO and Security Architect stakes are
carried by the `firebase-backend-security` and `firestore-rules-tester` gates (Opus), which read
this plan beside the staged diff.

## Goal beyond the ticket

Cause: the erasure (`deletePollVotes`) and the export pick the requester's vote rows by two
different predicates. Erasure: `collectionGroup('poll_votes').where('voterId', ==, uid)`, every
row. Export: one probe per exported message that has `metadata.poll`, after the `memberSince`
filter. Every row the second predicate misses is erased without ever being shown. Repair: the
export reads with the erasure's predicate, so the two sets are the same by construction.
Siblings: an audit of every cascade step against its export leg (separate Explore pass; findings
reported to Malin, fixed here only if they are the same one-query shape). Guard: tests that pin
both of the ticket's holes and a rules test for the new read.

## Design

1. `firestore.rules`: a read-only collection-group block, same shape as BUT-2114 `likes` and
   BUT-2118 `votes`:
   `match /{path=**}/poll_votes/{voterId} { allow read: if isAuthenticated() &&
   resource.data.voterId == request.auth.uid; }`
   `voterId` is pinned to the doc id and to `request.auth.uid` on every write limb
   (`isValidVote()`), so the row is the caller's own. No write verb is added. The nested block's
   sentence saying no collection-group match is added is struck.
2. Repository: `exportPollVotesByUser(userId, {maxDocuments})` →
   `[{message_id, data}]` via that query (index exists: `poll_votes.voterId` COLLECTION_GROUP).
   The per-message probe, `_hasPoll` and `maxPollVoteLookupsPerConversation` are removed:
   one read per vote row replaces about three reads per poll message.
3. `SocialExportManager.exportMessages`: reads the votes once (capped through
   `ExportPaginationHelper.fetchCapped`, type `poll_votes`, cap 2000 = `MAX_POLL_VOTE_SWEEP_ROWS`
   so the export reaches as far as the erasure does), then:
   - a vote whose message is exported rides beside it as `your_poll_vote` (as today);
   - a vote on a withheld duplicate-guard row stays in `your_poll_votes_on_withheld_messages`
     (BUT-1955, unchanged);
   - every other vote (message without `poll`, message before `memberSince`, past the message
     cap, a chat the user left, a message deleted) goes to a section-level
     `your_poll_votes_on_other_messages: [{message_id, your_poll_vote}]`.
   Past the cap: `poll_votes_truncated: true` at section level (the nested walk lifts it).
   Read failure: `poll_votes_error_code: 'poll-votes-read-failed'`, `error_code ??=` the same;
   the conversations still export without votes.
   `data_minimisation` gains one sentence about where votes are, conditional on the read
   having succeeded (the BUT-2014 rule).
4. Records: dated SUPERSEDES line for the export half of the BUT-1832 entry in
   `.claude/rules/accepted-deviations.md` and `docs/architecture/ACCEPTED_DEVIATIONS.md`;
   refresh the two `ACCEPTED_LARGE_FILES.md` rows. The write-side gaps of BUT-1832 (a vote on a
   non-poll, a late joiner voting) are NOT in this ticket and stay as recorded.

No new personal data, no new writer, no policy text: the export only shows rows that already
exist and are already named as the user's poll votes.

## Acceptance criteria / verification

- [ ] Rules test (`collection-group-wildcards-rules.test.ts`): own filtered query succeeds and
      returns only own rows across two messages; filter on another uid refused; unfiltered
      refused; a row lacking `voterId` denied; the catch-all is read-only (write refused).
      Emulator run green.
- [ ] Repo test: `exportPollVotesByUser` returns own rows only, with `message_id`, including a
      row under a message with no `poll` and one under a message before `memberSince`.
- [ ] Manager tests: hole 1 (vote on a non-poll message is exported), hole 2 (vote on a message
      filtered by `memberSince` is exported under `your_poll_votes_on_other_messages`), overlay
      beside an exported message, withheld-row list unchanged, cap → `poll_votes_truncated`,
      failure → error code and conversations still present, note conditional.
- [ ] Each new test reddens when its fix is reverted (revert probe, then restore).
- [ ] `flutter analyze` clean; every suite that grep finds for `FirebaseDataExportRepository`
      fakes and the changed methods is green.
- [ ] Separate reviewers per `reviewGates` on the final staged diff, then PR, CI green, merge,
      rules deploy after taking main in.

## Summary for Malin

Röster i omröstningar raderas när någon tar bort sitt konto, men exporten "Ladda ner min data"
visade bara en del av dem. Nu hämtar exporten rösterna på exakt samma sätt som raderingen gör,
så allt som raderas också syns i exporten. Det blir dessutom billigare: en läsning per röst i
stället för ungefär tre per omröstning. Ingen ny text i integritetspolicyn behövs.
