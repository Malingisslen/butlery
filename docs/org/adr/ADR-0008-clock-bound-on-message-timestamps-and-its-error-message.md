# ADR-0008: The one-hour bound on `sentAt` and the error message that had to ship with it

- **Date:** 2026-08-19
- **Status:** Decided — the bound was escalated to Malin, answered 2026-08-19
- **Trigger:** BUT-1903 (a future-dated `Timestamp` pins a chat message to the top of a
  conversation), the follow-up BUT-1896 deliberately deferred
- **Blast-radius tier:** full-panel (`tools/stakeholder_router.py`)
- **Stakeholders seated:** Security Architect, Trust & Safety / Content Moderation, Customer
  Support / Operations, Financial Controller / FinOps, Codebase Archaeologist

**Dropped from the router's 11, and why:** Product Manager — its stake (the send surface, the
residual harm window) was wholly contained in Trust & Safety's and Customer Support's and would
have produced the same finding a third time. Privacy / DPO — the only new data is a bucketed
integer with no identifier; no export or erasure surface opens. Database Administrator — no new
collection, index or document shape. Legal Counsel — the only legal surface is the DSA /
minor-protection angle, which Trust & Safety raised from its own world-watch and which is
recorded rather than decided here. Software Architect — one rules conjunct, one log line, one
error mapper following an existing sibling; no layering moves. QA / Test Engineer — the test
conditions are already mandated by the commit gates that reviewed the diff. Vendor / Procurement
— no dependency change.

## The defect, which nobody disputed

BUT-1896 added `request.resource.data.sentAt is timestamp` to the `messages` create rule. That
closes the TYPE route. A well-typed `Timestamp` of 9999-12-31 still passed, and it is worse than
the string it replaced: it wins `orderBy('sentAt','desc')` in a DM, and being a real timestamp it
also clears a group's `memberSince` cut-off and the client's range filter, which the string
tripped over.

Trust & Safety added the framing the ticket did not have. Because `shouldReplaceLastMessage`
compares with `>=`, a future-dated message does not merely sit on top — it blocks *every*
subsequent real message from updating the conversation's preview. That preview is visible on the
chat list **without opening the thread**, reachable by any participant including a stranger who
opened a DM or any co-member of a group, and the minor DM gate does not touch it (that gate
governs who may *open* a DM, not what a permitted contact may then plant).

## The conflict

Not about whether to bound it. About **how tight**, and **what else has to ship alongside**.

The tension is that `Message` stamps the DEVICE clock
(`lib/models/messaging/message.dart`, five factories), not the server, and there is no field data
on device-clock skew because the app has no users.

- **Trust & Safety** wanted the window small — a day of frozen, attacker-chosen preview on a
  minor's chat list is a no-click harassment surface — and explicitly warned against gold-plating
  the ticket in other directions.
- **Customer Support / Operations** wanted client-side diagnosability *in this ticket*: a phone
  whose clock is wrong would be refused on every send, permanently, behind a generic "kunde inte
  skicka" that never resolves and gives the user nothing to act on. Both wanted more safety; they
  disagreed on where the scope line falls.

**Customer Support also found the finding that reshaped the plan:** the skew-measuring log lives
in a POST-WRITE trigger, so it structurally cannot observe a denial — the message it would measure
is never written. The instrument measures the ALLOWED distribution only.

## Decision

**Escalated to Malin, because it is a trade between two user harms and the priority order cannot
rank one above the other.** Shown both options with their costs, she chose **one hour plus a real
error message** over **twenty-four hours plus no app change**, on 2026-08-19.

What follows from that answer: the two halves ship together and **neither is defensible alone**.
The bound is only safe because a refused user is told what is wrong; the message is only needed
because the bound is tight. A later change that loosens one must revisit the other.

**One hour is a chosen ceiling, not a measured skew tolerance.** That sentence is in the rule's
own comment, at the Security Architect's insistence, so a future reader does not mistake it for
data.

## Conditions carried, and where each landed

1. **Name the residual as a conscious trade** (Security Architect) — an attacker can still hold
   the top of the MESSAGE LIST for an hour. In the rule comment. (The chat-list preview is a
   separate route and is not hour-bounded — see Consequence.)
2. **Give the skew log an owner and an expiry** (Security Architect, FinOps) — its removal is
   stated as a rule, not a judgement call: it is deleted in the same change that tightens the
   bound.
3. **A bare log line, no metric or dashboard** (FinOps) — a second billable surface is a second
   thing to forget to remove. **Scoped to the SERVER-SIDE skew log only.** It does not govern the
   client analytics event in condition 5, which counts a different population through a channel
   the repo already runs. Said explicitly because the two conditions sit eight lines apart and
   read as contradictory otherwise.
4. **Confirm a delete really clears a frozen preview** (Trust & Safety) — verified by reading:
   the delete branch re-queries `orderBy("sentAt","desc").limit(1)` inside the transaction and
   rewrites `lastMessage`. The existing report → moderator-delete route is a real remedy during
   the window.
5. **Client-side denial signal** (Customer Support) — delivered as `MessageSendErrorMapper` plus a
   `message_send_denied_clock_ahead` analytics event. **Corrected during the code-review gate:** the
   first implementation used `AppMonitoringService.recordBusinessMetric`, which is `if (kIsWeb)
   return;` followed by a Crashlytics CUSTOM KEY — metadata attached to a later crash report, not
   an event stream. It would have counted nothing on web and next to nothing on native, while this
   document claimed it was the only view of the denied population. It now goes through
   `AnalyticsService.tryLog`, and the honest limit is stated rather than papered over — wider than
   the first correction claimed. `logEvent` gates on `ConsentService.checkSafely`, which fails
   CLOSED: a missing consent record, a null consent service and a lookup that THROWS all read the
   same as a refusal. So the invisible population is everyone without an explicit stored grant, not
   merely those who declined — a follow-up that subtracts the decline rate and believes it has
   corrected for the gap is still looking at an unknown fraction. **Read it as a lower bound, never
   a census.**
6. **Gate the skew log to true CREATE** (Codebase Archaeologist) — an edit keeps the original
   `sentAt`, so an ungated line would re-log the same delta and bias the distribution.
7. **Correct three forward-reference comments in the same commit** (Codebase Archaeologist) —
   `firestore.rules` and two blocks in `sync-conversation-last-message.ts` all said the
   future-dated case was still open; all three were false the moment this shipped.

## The mechanism, and why it needed inventing

Firestore returns **one opaque `permission-denied` for every conjunct** on that rule — the clock
bound, `rateLimitWrite`, `isAccountMatured`, `isAgeCompliant`, membership. A blanket "check your
clock" would be actively wrong for every brand-new user, who cannot chat for sixty minutes by
design.

So the clock message is earned: on a denial, force-refresh the Firebase ID token
(`user.getIdTokenResult(true)`) and compare `clock.now()` against its server-stamped
`issuedAtTime`. The threshold is the rule's own bound, deliberately not smaller — classifying
below it would blame the clock for the rate limiter's work. A null `issuedAtTime`, a probe that
throws, and a device running *behind* all fall to the generic message: an absence of evidence
must never become evidence about somebody's clock.

## Consequence — what is NOT closed

- **The preview freeze is NOT hour-bounded, and an earlier draft of this document said it was.**
  Found by the firestore-rules-tester gate on this very diff: `conversations.lastMessage` is a
  denormalised COPY of `sentAt` on another collection, and that collection's `allow update`
  deny-list — `hasAny(['participantIds', 'createdAt', 'memberSince', 'groupId'])` — does not
  name it. (Quoted by value rather than by line number, per the lesson this same commit adds:
  a rules line number goes stale on the next edit above it, and this change moved everything
  below it by 55 lines.) Any participant can therefore write
  `lastMessage.sentAt` directly, at any value, never touching the rule this ADR is about.
  **How long it lasts, corrected twice before it was right:** the SERVER never heals it —
  `shouldReplaceLastMessage`'s self-healing branch fires only when the stored stamp is NOT a
  Timestamp, and a well-typed far-future one is precisely the un-healable case. What clears it is
  the next message sent through the real client, which merge-sets the whole `lastMessage` map with
  no comparison at all. So the freeze lasts until the next message in that conversation —
  indefinite in a quiet one, which is where a frozen preview is both most visible and least likely
  to clear itself — and it can be re-poisoned after every send. Not "permanent", which an earlier
  draft of this bullet claimed from the Cloud Function alone without checking the client writer.
  Pre-existing, not introduced here, and it makes the follow-up more urgent rather than less.
  The generalisable lesson: **bounding a field's VALUE on one collection does not bound a
  projection of it stored on another.** The complete close for both routes is ordering
  `lastMessage` on a server-written stamp instead of the device-written `sentAt` — a new
  projection field, a rules `hasOnly` update and a new index. **Own ticket, and a tighter number
  here is not a substitute for it.**
- **The bound is still a guess.** The instrument now exists to replace it with a number, but only
  once there is traffic. The follow-up must read the log *and* the client metric — the log alone
  cannot see the denied population.
- **No lower bound.** A past-dated message buries itself rather than pinning, and inside a group
  falls below `memberSince` and vanishes. Opposite direction, own ticket.

Advisory only for everything except the bound itself, which Malin decided.
