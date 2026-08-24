# ADR-0007: Switching on the chat duplicate guard means deleting people's messages without telling them

- **Date:** 2026-08-19
- **Status:** Decided — escalated to Malin, answered 2026-08-19
- **Trigger:** BUT-1898 (repoint `guardDuplicateMessage` to the top-level `messages` collection) reviewed together with BUT-1896 (`sentAt is timestamp` on the messages create rule)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Trust & Safety / Content Moderation, Product Manager, Security Architect, Privacy / Data Protection Officer (GDPR), Financial Controller / FinOps, Codebase Archaeologist

**Dropped from the router's 11, and why:** Customer Support / Operations — its concern ("my
message vanished" support load) is wholly contained in the Product Manager's stake and would
have produced the same finding twice. Database Administrator — no new collection, index or
document shape; the hash store already exists and is capped at 20 entries. Legal Counsel —
the only legal surface is the DSA/notice question, which Trust & Safety raised from its own
world-watch and which escalates to Malin regardless. Software Architect — the change is one
trigger path string and one rules conjunct; no layering moves. QA / Test Engineer — the test
conditions are already mandated by the commit gates that will review the diff. Vendor /
Procurement — no dependency change.

## The disagreement

There is no disagreement about the **defect**. `guardDuplicateMessage` is registered on
`conversations/{conversationId}/messages/{messageId}`. Every message writer in the repo uses
the **top-level** `messages` collection, and `firestore.rules` has no match block for that
subcollection at all, so nothing could ever write there. The chat anti-spam guard has never
run a single time since it was written on 2026-05-04. All six seats agree the path is wrong.

The disagreement is about what repointing it **does**, because the guard's action on a
duplicate is `tx.delete(docRef)` — it deletes the message, server-side, with no signal to the
sender anywhere in the app. Five of the six seats attached conditions before that may ship,
and three of those conditions are the same condition arrived at independently:

- **Per-conversation key.** The duplicate key is `sha1(authorId + ":" + body)` with no
  `conversationId` component. The same text sent to two different people within five minutes
  collides, and the second is deleted. Raised independently by Trust & Safety, the Product
  Manager and the Codebase Archaeologist.
- **A floor on length.** There is none. `ok`, `ja`, `nej`, `?`, `haha` are all eligible.
  Raised independently by Trust & Safety, the Product Manager and FinOps — the last on cost
  grounds (a one-word reply should never open a Firestore transaction), the first two on
  false-positive grounds.
- **A signal to the sender.** Trust & Safety and the Product Manager both call a silent
  server-side delete on a live chat surface a trust regression rather than a moderation win.

Two further findings neither the ticket nor I had:

- **A race that can freeze a conversation's preview.** `syncConversationLastMessage` fires on
  the same document create. The two triggers are independent CloudEvents with no ordering
  guarantee, and each works from its captured payload rather than re-reading. If the guard's
  delete lands first, the create-side run can still write `lastMessage` pointing at a document
  that no longer exists, and nothing re-fires to correct it. The preview stays stuck until the
  next real message. Found by the Codebase Archaeologist, independently flagged by the
  Security Architect.
- **The same class of hole in ~30 other rules.** `hasRequiredFields` pins a field's PRESENCE,
  never its TYPE, and only three timestamp fields in the whole rules file pair it with an
  `is timestamp` conjunct. Any collection with an unfiltered `orderBy` on one of the others is
  open to the same sort-poisoning BUT-1896 closes for `sentAt`. Found by the Security
  Architect; filed separately rather than absorbed here.

## Decision

**BUT-1896 (the rules type check) — proceed.** Unanimous approve, no conflict, no ADR needed
for it on its own; recorded here only because it was reviewed in the same panel. The Security
Architect settled the two open questions by reading the code: the conjunct belongs on
**create only**, because `cannotModify(['senderId','conversationId','sentAt'])` already forbids
any update that touches the field, and **no legitimate writer breaks** — `MessageDto.toFirestore`
always writes `Timestamp.fromDate`, and `writeGroupSystemMessage` goes through the Admin SDK,
which bypasses rules entirely.

**BUT-1898 (repointing the trigger) — escalated to Malin. She answered on 2026-08-19:
switch it on, but only on real spam.** In her words the condition was that the false
positives are closed first and that it gets a switch she can flip without a release. She was
shown the alternatives and their costs: shipping it as-is, holding it until a sender-visible
signal exists, and marking duplicates instead of deleting them.

What follows from that answer, and what does not: the guard ships with the per-conversation
key, the length floor and the kill switch, and the switch ships OFF. She did not waive the
sender signal — it was not on the table as a thing to skip, only as a thing that comes
later — so the implementing plan makes "the flag is not turned on before the sender-signal
ticket lands" a rule rather than an aspiration. If she wants it on sooner, that is her call
to make explicitly; it is not implied by this answer.

The reasoning that made it hers rather than the priority order's:

The priority order would resolve the cost and correctness conditions on its own. It cannot
resolve the central one, because that one is a question about what the product should do to a
person: *may Butlery delete a message someone sent, silently?* That is user-safety and trust,
the top tier, and it is interpretive rather than technical — Trust & Safety attached a live
DSA Article 17 angle (a hosting service that removes user content increasingly owes the
affected user a reason). Per this system's own rule, interpretive user-safety and legal
questions escalate rather than being settled by an agent.

The escalation, in one line: **the second identical message a person sends is usually the one
they send because they think the first did not go through — and deleting it makes the app look
exactly as broken as they feared.**

## Stakes (per role)

- **Trust & Safety / Content Moderation** — approve-with-conditions. Protecting against a
  removal mechanism that runs entirely outside the auditable moderation pipeline: no report,
  no strike, no admin visibility, no appeal route, and no statement of reasons. Its stance:
  repointing is correct, activating a silent per-user delete on live chat is not.
- **Product Manager** — approve-with-conditions. Protecting the core engagement surface.
  Confirmed `enable_messaging` is already ON in production, so this is not a dark launch.
  Wants a kill switch, because if the false-positive rate is bad there is currently no way to
  stop it without another deploy.
- **Security Architect** — approve both. Protecting against the ranking-manipulation hole in
  BUT-1896, and clear that only the **rules** conjunct closes it: the code guards that landed
  2026-08-19 stop the Cloud Function from crashing, not the client-side pin.
- **Privacy / DPO** — approve-with-conditions, and the mildest of the five. Verified rather
  than assumed that `recentContentHashes` is already inside the account-deletion cascade, so
  no erasure gap opens. Its asks are documentation: the store is outside the Art. 15 export
  (pre-existing, now widened to private content), and the anti-spam legitimate-interest basis
  was written for public comments, not private chat.
- **Financial Controller / FinOps** — approve-with-conditions. Protecting against an unmetered
  new write path: a trigger that costs zero today would fire on every message, with no
  dashboard, no alert and no kill switch, unlike every other paid surface this role owns.
- **Codebase Archaeologist** — no stake. Its finding is that **this exact bug has been fixed
  once already in this same subsystem**: BUT-1766 found the account-deletion cascade sweeping
  the same dead `conversations/{id}/messages` subcollection, so every account erased since
  BUT-788 kept its whole chat history while the cascade reported success. Same root cause,
  same silent-success symptom, different function.

## Consequence

If Malin proceeds with BUT-1898, the panel's conditions ride along:

1. Scope the duplicate key by `conversationId`, and pin the two-conversations-same-text case
   with a test — it is untested today.
2. Exempt short bodies before opening the transaction, which satisfies the false-positive and
   the cost condition with one change.
3. Put the chat path behind a flag that can be turned off without a deploy.
4. Comment and, if practical, test the create/delete race against
   `syncConversationLastMessage`.
5. Add a test pinning that a `type: "system"` message is skipped — reachable for the first
   time once the trigger fires, and today unpinned.
6. File the Art. 15 export question for `recentContentHashes`, and the purpose-scope question
   for hashing private message content.

If Malin declines, the guard stays dormant and the ticket becomes a documentation change
saying so — which is still worth landing, because the code currently reads as an active
control and it is not.

## One false positive survives the conditions, on purpose

Send a message, delete it, re-send the same text inside five minutes: the resend is deleted
silently. The window guard cannot tell that apart from a repeat, because the deleted message
left an entry behind and the entry is what it compares against.

This has been true of the comment surface since 2026-05-04 and nobody noticed — but
delete-and-resend is a far more common thing to do in a chat than in a comment thread, and
the conditions above do not touch it: the text is over the floor, it is the same
conversation, and it is the same person. Recorded here rather than fixed, because the honest
fix is the sender signal that the flag is waiting on: with a signal, the user sees why. Added
after the fact, from the implementing review — the panel did not raise it.

Advisory only. Malin decides.
