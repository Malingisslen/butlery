# ADR-0009: The chat duplicate guard marks a message instead of deleting it

- **Date:** 2026-08-26
- **Status:** Decided — Malin, 2026-08-26, in the BUT-1904 planning session
- **Trigger:** BUT-1904, the condition ADR-0007 left holding
  `enable_chat_duplicate_guard` off
- **Blast-radius tier:** full-panel by the router (`firestore.rules` is a high-stakes hit).
  ADR-0007's panel was reused rather than re-seated — see "On the seating" below.
- **Supersedes in part:** [ADR-0007](ADR-0007-silent-deletion-of-duplicate-chat-messages.md).
  That decision stands on everything except the ACTION taken on a duplicate.

## The question

ADR-0007 recorded Malin's answer of 2026-08-19: switch the guard on, but only on real spam.
Three of the panel's conditions shipped with BUT-1898 — the per-conversation key, the length
floor, the kill switch. The fourth did not, and was explicitly not waived: **a signal to the
sender.** Trust & Safety and the Product Manager both called a silent server-side delete on a
live chat surface a trust regression rather than a moderation win, and the escalation that
made the decision Malin's was one sentence:

> the second identical message a person sends is usually the one they send because they think
> the first did not go through — and deleting it makes the app look exactly as broken as they
> feared.

BUT-1904 is that signal. Its ticket offered three shapes: a row in the thread, a snackbar at
send time, or marking the message instead of deleting it — the last described as the biggest
change, "but then nothing ever disappears". Malin picked the row.

The question this record exists for is the one that came next: **where does that row come
from?** The row has to sit in the thread at the place the message would have been, and only
its own sender may see it.

## Decision

**The guard stops deleting. It empties the message and stamps it `duplicateBlocked`, in
place.** The sender's own client draws the localized row where the message sat; every other
participant's client drops the row before the list reaches the UI.

Malin's call, taken against the alternative below, 2026-08-26.

The alternative was: keep `tx.delete`, and write a private per-sender notice into the
sender's own subtree that the client weaves into the thread by `sentAt`. Identical on screen.
It costs a new collection in the Art. 15 export and the Art. 17 cascade, a second listener in
the chat view, and it leaves the `syncConversationLastMessage` race — the other thing
BUT-1904 must fix — to be solved separately.

Marking wins on three counts:

- **The race dies by construction.** ADR-0007 recorded that if the guard's delete lands
  first, the sync trigger's create-side invocation can still write `lastMessage` pointing at
  a document that no longer exists, with nothing left to fire and correct it. Nothing on this
  path is destroyed any more, so no preview can point at a destroyed document. (The narrower
  ordering hazard that survives — a stale payload racing the mark — is closed by a
  transactional re-read in that trigger, and a blocked row is never previewable. Both are
  pinned by tests that redden when either half is removed.

  That re-read is deliberately NOT confined to creates, and confining it was a real defect this
  change shipped and then repaired: `messages` has a second update path, the read-receipt branch
  every recipient's client writes, and its invocation carries a pre-mark payload. Skipping it put
  the blocked duplicate's TEXT back in every participant's preview — strictly worse than the
  BUT-1898 race, which only left a preview pointing at a missing document.

  A SECOND hole in the same design was then measured by the same gate: the guard decides
  candidacy from the CREATE payload and marks regardless, while the sender update branch leaves
  `content` and `type` writable — so an update edited OUT of candidacy (a sender trimming their
  message to "ok") skipped a candidacy-gated re-read and landed last on a blocked, emptied row.
  Updates now re-read whenever they survive the cheap pre-read gate; only creates are gated on
  candidacy. Both holes are pinned by their own cases, each of which reddens alone.

  Recorded rather than smoothed over: this fix took three rounds, and both extra rounds were the
  same mistake — reasoning about which invocations can carry a stale payload instead of measuring
  it. The resolution is not a better list. EVERY writer of the collection wakes an
  `onDocumentWritten` trigger, so the gate is keyed on the KIND of write rather than on who wrote
  it, and a writer nobody enumerated is closed for free. A third draft of this paragraph did hand
  over a list of four; it was measured at eight and struck.)
- **The erasure and export story is already written.** A blocked row is an ordinary `messages`
  document: `deleteMessages` anonymises it with every other message the user sent, and the
  Art. 15 export carries it like any other row — as an empty one, since the guard removed the
  text.

  *(Corrected 2026-08-26, before this landed: an earlier draft ended that sentence "before the
  document was ever readable". False. `guardDuplicateMessage` is `onDocumentCreated` — the client
  commits the full text and the trigger runs after it, so a participant with the thread open sees
  the duplicate until the mark propagates — no measured duration, and a cold start makes it
  longer. The harm is nil, since it is by construction the same text they received moments
  earlier, and it was equally true of the delete behaviour — but the guarantee as stated did not
  exist. Raised by the `code-reviewer` gate.)*
- **Position in the thread is free.** `sentAt` is untouched, so the row is where the message
  was, without a second stream to merge.

What it costs, stated plainly: **the duplicate's text is destroyed.** The sender cannot
recover it from the row. The same text is a few rows above — that it is the same text is why
the row exists — but it is gone as a copy.

## What follows, and what does not

- The row is **sender-only**, and that is a UI rule, not a control. What protects the other
  participants is that the server removed the text; hiding the row from them withholds only
  the bare fact that somebody's message was stopped. Do not describe the client-side filter
  as a privacy boundary.
- **Comments still delete.** `guardDuplicateComment` is unchanged: a global per-author key, no
  length floor, no flag, and `tx.delete` on a duplicate — live since 2026-05-04. A duplicate
  one-word comment is spam; a duplicate one-word chat message is conversation. The asymmetry
  between the two surfaces is the decision, not drift.
- **A blocked row cannot be edited.** `firestore.rules` refuses an update to a message whose
  stored `type` is `duplicateBlocked`; without it the sender could write the duplicate text
  straight back in and hand it to the other participants after all. Deleting one is still
  allowed by the rules.

  *(Corrected 2026-08-26, before this landed: that clause continued "— that is how the sender
  dismisses the notice", and no screen in the app reaches it. `MessageBubble` returns before it
  installs the long-press gesture, so the action menu never opens for a blocked row — and that
  menu is dead for EVERY message type today anyway, since `handleMessageAction` has no `'menu'`
  case and long-press has logged "Unknown message action" since before this ticket.
  (`ChatActionHandler` DOES have one, in `handleAttachment` — the weekly-menu share. Naming the
  class rather than the switch would send a reader to a live affordance.) The rules
  permission is real; the affordance is not. Raised by the `code-reviewer` gate, which measured
  the pre-existing half too. **So the sender cannot remove the row from inside the app, and it
  stays in their thread.** Whether that is acceptable, or whether the notice needs its own
  dismiss control, is Malin's call and is not decided here.)*

  **Superseded 2026-08-26, same day, before landing.** The sentence above is too broad and the
  `firestore-rules-tester` gate measured it. What is TRUE: no per-row dismissal reaches the
  delete — `MessageBubble` returns before it installs the long-press gesture, and that menu is
  dead for every message type anyway. What is FALSE: "cannot remove the row from inside the app".
  Deleting the whole CONVERSATION reaches it — but only in a DIRECT message.
  `ConversationsListView` → `deleteConversation` → `MessageManagementOperations.deleteAllMessages`
  searches
  with an EMPTY query string, and `content.contains('')` is true of every row, an emptied one
  included, so a blocked row is deleted with the rest the caller sent.
  **In a GROUP there is no path at all.** The delete-conversation tile is gated on
  `conversation.groupId == null`, `deleteAllMessages` has no other caller in `lib/`, and
  `leaveGroup` deletes no messages. So a blocked row in a group chat cannot be removed from
  inside the app by anyone.
  Whether that is enough, or whether the notice needs its own dismiss control, is still Malin's
  call and is still not decided here.

  **DECIDED 2026-08-26 — Malin: build the dismiss control.** The notice now carries its own
  `×`, wired to the per-MESSAGE delete rather than to the conversation-level one, which is why
  it works identically in a group and in a direct message and closes the group gap above. No
  confirm dialog and no undo: the recoverability test returns "nothing to protect", because the
  sentence on screen is the app's own — it comes from the ARB, not from the document — and the
  row returns if the guard trips again. That is a fourth friction class and it is written into
  `.claude/rules/ui-conventions.md` § "Destructive-action confirmation" — the canonical list,
  which auto-loads on `lib/widgets/**` — rather than here, so the next person classifying an
  action reads it where they are already looking.

  **Framing, and this is a constraint rather than a preference (Legal Counsel, 2026-08-26):**
  describe this as letting the sender clear their own notice. Do NOT write anywhere — code,
  record, or copy — that it satisfies or closes a DSA Article 17 obligation. Butlery has never
  determined it is in scope for DSA Art. 17 on this action, and ADR-0007 left that a Trust & Safety
  trend-flag escalated to Malin, not a legal position. The server-side rejection log is the
  record that survives the sender dismissing the notice; do not let a later refactor drop it on
  the theory that the in-app row covers the same ground.

  **What this does NOT close (Trust & Safety, 2026-08-26):** the guard still has no admin
  visibility and no appeal route. That gap is ADR-0007's and stays open — this change gets no
  credit for it.
- **The flag stays OFF.** The condition ADR-0007 left holding it off is met, but turning it on
  is a separate, explicit decision. Nothing in this record implies it.
- **One thing to decide BEFORE that flag is switched on, and it is Malin's:** the Art. 15 export
  copies every message row verbatim, so a requester's bundle would carry another participant's
  blocked row — `{type: duplicateBlocked, content: "", senderId: <other uid>}` — which is exactly
  the fact `_withoutOthersBlockedRows` exists to withhold on screen. That is the class BUT-1774
  decided (third-party behaviour the client never renders for anyone but yourself), and no
  accepted deviation covers it. Either drop those rows from the export or append a dated
  deviation — but decide it, rather than letting the code settle it silently. Raised by the
  `integration-reviewer` gate.

  *(Corrected 2026-08-26, before this landed: this bullet justified the deferral with "Harmless
  today, because with the flag off no such row can exist." Falsified by two tests in this very
  commit — B16 and B17 in `cook-snaps-and-message-mod-rules.test.ts` both ALLOW, because `type`
  sits in neither `cannotModify` nor the create rule, so a client can stamp its own message
  `duplicateBlocked` or create one already stamped. The exposure is small — such a row is
  self-stamped by its own sender — but it is not zero, and the false premise was the load-bearing
  half of the argument for deferring. The instruction stands; the excuse does not.)*

  **DECIDED 2026-08-26 — Malin: filter, do not write a deviation.** Another participant's
  blocked row is dropped from the bundle; the requester's own is kept. The predicate is
  `isOthersBlockedRow` in `SocialExportRedaction`, beside `dropAvatarUnlessOwn`, and it FAILS
  OPEN where its neighbour fails closed: a row whose `senderId` cannot be read is KEPT, because
  dropping a row on doubt withholds a record from its own subject, and under-disclosure is the
  worse Art. 15 failure. That asymmetry is the decision, not an oversight.

  **SUPERSEDED 2026-08-26, same day, before the follow-up landed.** The paragraph above ended
  "and it is safe only because a blocked row carries no text". That is false, and it is the
  SAME false premise this record already corrected once, in the bullet about deferring the
  export decision — written back in by the correction round that was removing it.
  Neither the create limb of `firestore.rules` nor the SENDER-update limb constrains what
  `type` is written TO (the third, the read-receipts update, forbids it outright via
  `affectedKeys().hasOnly`):

  - **create** — the rule inlines `hasRequiredFields(['senderId', 'conversationId', 'content',
    'sentAt'])` plus a 5000-character cap on `content`; it never names `type`, so a client may
    create a row already stamped `duplicateBlocked` **with up to 5000 characters of text in it**.
  - **sender update** — `cannotModify` lists `senderId`, `conversationId` and `sentAt`; `type` is not
    on it, so a sender may stamp an existing full message. The limb DOES read `type`
    (`resource.data.get('type', 'text') != 'duplicateBlocked'`), but that freezes a row already
    blocked rather than bounding the stamp — which is why B16 succeeds exactly once.

  Both are pinned as B16/B17 in `cook-snaps-and-message-mod-rules.test.ts`, and both ALLOW.

  The real reason failing open is safe is stronger and does not depend on emptiness: the create
  rule pins `request.auth.uid == request.resource.data.senderId` and requires the field, so no
  client write can produce a row whose sender is absent or unreadable. The fail-open branch is
  unreachable from a client, and the avatar helper that runs afterwards still fails closed.

  A future change letting another field ride along on a blocked row still means revisiting this.

  The section's `data_minimisation` sentence gained the drop AND had its completeness clause
  narrowed. "Everything else this conversation held is kept as it was stored" was a categorical
  claim about FIELDS, and it stopped being true the moment a whole ROW could be withheld; it now
  reads "Of the rows that ARE here, nothing else has been changed". A bundle that overclaims its
  own completeness is as false as one that redacts silently, and both halves are pinned in
  `social_export_manager_test.dart`.

  **A second residual, stated rather than closed (`code-reviewer` gate, 2026-08-26).** The row
  is dropped BEFORE the block that attaches `your_poll_vote`, so a vote the requester cast on
  another participant's blocked-typed row leaves the bundle with it — and that overlay is the
  requester's OWN data, which is the under-disclosure this helper exists to avoid. Reachability
  is narrow: the chat screen hides such a row, so casting the vote takes a hand-rolled client,
  and per the BUT-1832 deviation any map-metadata message accepts one. Not closed here because
  the fix is a re-order whose interaction with the `content == ''` conjunct deserves its own
  measurement, not a same-round patch.

  **The first residual, stated rather than closed (Software Architect, 2026-08-26).** The filter
  runs in the manager, downstream of the repository's raw row cap. A single conversation of more than
  `messages_per_conversation` rows, heavy with another participant's blocked ones, can therefore
  spend the cap before the filter removes them and under-deliver the requester's own real
  messages. It is not silent: `messages_truncated` is computed at the repository from the RAW
  pre-filter fetch, so the bundle flags itself as incomplete in exactly that case, and a test
  pins that the flag survives the filter. Moving the filter into the repository would close the
  residual and split one redaction decision across two layers — which the mixin exists to
  prevent. The residual was chosen knowingly over that.
- **A residual this record claimed, REFUTED rather than merely stale.** Earlier drafts said the
  recipient's push notification is sent client-side before the guard runs, so a blocked duplicate
  could still produce a push. Measured 2026-08-26 by the `integration-reviewer` gate and confirmed
  by hand: `sendMessageNotification` returns early on
  `message.isFromCurrentUser(currentUserId)`, and both of its callers pass the message the current
  user just sent — so **no chat push is sent for any message at all today**. There is no residual
  here, and the sentence would have manufactured a ticket for a hazard that does not exist while
  hiding the real defect: the chat notification path is dead. That belongs in its own ticket, with
  this measurement, and is not this change's to fix.

## The false positive ADR-0007 recorded on purpose

ADR-0007's closing section recorded one false positive that survived every condition: send a
message, delete it, re-send the same text inside five minutes, and the resend is deleted
silently — the deleted message left an entry behind, and the entry is what the window guard
compares against.

That section named the honest fix as "the sender signal that the flag is waiting on: with a
signal, the user sees why." **That fix has landed.** The false positive itself is unchanged —
the resend is still stopped — but it is no longer silent, and nothing is destroyed except the
duplicate text.

## On the seating

`tools/stakeholder_router.py` returns full-panel for this change's fileset, the same tier
ADR-0007 convened. A fresh panel was not re-seated: this decision changes the ACTION on a
duplicate in the direction every seat that attached a condition asked for, and adds no new
surface those seats did not already weigh — the same trigger, the same collection, one rules
conjunct that narrows rather than widens. The two seats with the strongest stake in it,
Trust & Safety and Product, are the ones whose condition it satisfies.

Recorded so the shortcut is visible rather than implied. If a later change to this path widens
what the guard may do, it re-seats.

Advisory only. Malin decides.
