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
  menu is dead for EVERY message type today anyway, since `ChatActionHandler` has no `'menu'`
  case and long-press has logged "Unknown message action" since before this ticket. The rules
  permission is real; the affordance is not. Raised by the `code-reviewer` gate, which measured
  the pre-existing half too. **So the sender cannot remove the row from inside the app, and it
  stays in their thread.** Whether that is acceptable, or whether the notice needs its own
  dismiss control, is Malin's call and is not decided here.)*
- **The flag stays OFF.** The condition ADR-0007 left holding it off is met, but turning it on
  is a separate, explicit decision. Nothing in this record implies it.
- **One thing to decide BEFORE that flag is switched on, and it is Malin's:** the Art. 15 export
  copies every message row verbatim, so a requester's bundle would carry another participant's
  blocked row — `{type: duplicateBlocked, content: "", senderId: <other uid>}` — which is exactly
  the fact `_withoutOthersBlockedRows` exists to withhold on screen. That is the class BUT-1774
  decided (third-party behaviour the client never renders for anyone but yourself), and no
  accepted deviation covers it. Harmless today, because with the flag off no such row can exist.
  Either drop those rows from the export or append a dated deviation — but decide it, rather than
  letting the code settle it silently. Raised by the `integration-reviewer` gate.
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
