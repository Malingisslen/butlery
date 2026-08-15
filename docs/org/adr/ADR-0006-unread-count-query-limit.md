# ADR-0006: The unread-conversations query keeps `limit(500)`

- **Date:** 2026-08-15
- **Status:** Decided (priority order: correctness > cost)
- **Trigger:** BUT-1838 follow-up — the two blocking findings from the whole-range
  integration review before pushing seven commits. Ticket plan:
  `tasks/butlery-1838-gruppchatt-plan.md`; the panel's working plan file is in the global
  `~/.claude/plans/` and not in this repo.
- **Blast-radius tier:** full-panel (router: `firestore.rules` +
  `functions/src/account/account-deletion-cascade.ts` are high-stakes hits), seated at three
  per the skill's 3–5 cap.
- **Stakeholders seated:** Security Architect, Privacy/DPO, Performance Engineer.
  Dropped as incidental, with reasons, in the plan's panel section.

## The disagreement

`ConversationQueryModule.getUnreadConversationsCount` preferred an inverse index
(`users/{uid}/conversation_memberships`) and returned early whenever it was non-empty. That
index's `hasUnread` flag is written `false` at row creation and never set true — its only
writer, `ConversationParticipantModule.updateConversationActivity`, has no production caller
— so the method answered **0 for every user with at least one such row**. The fix deletes the
branch, leaving the authoritative query that already sat below it as a fallback:

```dart
.where('participantIds', arrayContains: userId)
.orderBy('updatedAt', descending: true)
.limit(500)
```

**Performance Engineer** approved the correctness fix and attached a must-have: lower that
`limit(500)` to `limit(100)`, matching `getUnreadMessageCount` in the same class. Its
reasoning: the change swaps up to 50 small membership-document reads for up to 500 full
conversation documents (each carrying `participantDisplayNames`, `participantAvatarUrls`,
`lastMessage`, `lastReadTimestamps`), and no reason was stated for the count path allowing
5× the reads of the sum path.

**The implementer (me) declined it**, on a factual objection rather than a preference.

## Decision

**`limit(500)` stays.** Decided by the priority order — correctness above cost — with the
cost premise itself disputed:

1. **Firestore bills per document RETURNED, not per limit.** `limit` is a ceiling, not a
   prefetch. A household with twelve conversations pays for twelve either way. The two
   numbers only diverge for a user who actually has more than 100 conversations.
2. **In exactly that case, 100 undercounts.** The badge would silently drop unread
   conversations past the hundredth. The condition therefore buys nothing in the typical
   case and costs correctness in the only case where it does anything.
3. The consistency argument is real but weaker than the correctness one, and it points the
   other way as easily: `getUnreadMessageCount`'s `limit(100)` is the sibling worth
   revisiting, not this one.

Not overruled: the Performance Engineer's other two contributions, both accepted — the
composite index was verified to exist (`firestore.indexes.json`,
`participantIds CONTAINS` + `updatedAt DESCENDING`), and the call site was verified to fire
once per `ProfileMenu` mount via a post-frame callback, not per rebuild and not on a stream.
That bound is what makes the cost acceptable at all, and it is recorded here because it is
the fact a future cost review should re-check first.

## Stakes (per role)

- **Performance Engineer:** read-cost per profile-menu open; protecting against a quiet
  regression where a correctness fix multiplies document reads on a UI path.
- **Security Architect:** no stake in this conflict. Its own condition — that the rewritten
  rationale for `MAX_ROSTER_SWEEP_ROWS` must not claim there is no live client write path —
  was accepted in full and needs no ADR.
- **Privacy/DPO:** no stake in this conflict. Its three conditions were accepted in full.

## Consequence

- The query keeps its 500-document ceiling. A user with more than 500 conversations
  undercounts; that bound is unchanged by this decision and pre-dates it.
- A comment at the call site records why the limit was not lowered, so the next reader meets
  the reasoning rather than the inconsistency.
- **Revisit if** the app stops being household-scale, or if `unreadByUser` (the map field the
  code's own TODO proposes) makes a `count()` aggregation possible — at which point both
  limits become moot rather than merely inconsistent.
- Advisory only, as with every panel outcome: Malin decides whether to proceed.
