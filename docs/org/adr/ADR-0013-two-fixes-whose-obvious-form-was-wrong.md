# ADR-0013: two fixes whose obvious form was wrong

- **Date:** 2026-09-03
- **Status:** Accepted — both fixes proceed, neither in the form first planned
- **Trigger:** BUT-1862 and BUT-1807, inside the plan that cleans up the eighteen
  partially-built tickets
- **Blast-radius tier:** full-panel (same panel as [ADR-0012](ADR-0012-real-recipe-pages-as-test-fixtures-in-a-public-repo.md))
- **Stakeholders seated:** Privacy / DPO, Security Architect, Legal Counsel, QA / Test
  Engineer, Software Architect, Codebase Archaeologist

## Why this is written down

No role blocked and no role contradicted another. What the panel refuted was **the plan's
own prescriptions** — twice, on the two items with real user impact. Both refutations came
from reading code the plan had cited but not traced far enough. That is the value the panel
produced, and it is worth a record because the wrong form was the obvious one in both cases
and will look obvious again to the next reader.

## 1. `withRateLimit` would have taxed chat on the AI budget

**The defect is real.** `create-chat-group.ts`, `add-chat-group-members.ts` and
`remove-chat-group-member.ts` each throw `resource-exhausted` with a two-argument
`HttpsError` and no `details` payload. `ChatGroupErrorMapper` reads
`error.details['retryAfterSeconds']` and falls back to 60 when it is absent, so a user who
has hit `createChatGroup`'s 50-per-day cap is told to retry in a minute when the real wait
is until the cap resets.

**The plan's fix was to route the three callables through `withRateLimit`**, which already
sends `retryAfterSeconds`. The Security Architect and the Codebase Archaeologist refuted
this independently:

- `withRateLimit` also calls `checkGlobalLimit()`, the shared `system/llmLimits` counter
  that bounds Vertex AI spend across the whole app. Group membership operations would
  become gated on the LLM budget, so a heavy AI day could refuse someone who is merely
  *leaving a group chat*.
- `remove-chat-group-member.ts` carries an explicit, documented invariant that the opposite
  must hold: a user whose token has gone stale must always be able to leave.
- The wrapper runs auth and rate-limiting as the **outer** layer, so `assertAgeCompliant` /
  `assertAccountMatured` would move to *after* rate-limiting. `create-chat-group.ts`
  validates before consuming a token on purpose and says so in a comment.
- An implementer who added the wrapper without deleting the inline `checkRateLimit` call
  would burn two tokens per invocation and trip the daily cap at half the intended rate.

**Decision: use `enforceRateLimit`.** It already exists in `rate_limiter.ts`, already
throws `resource-exhausted` with `{retryAfterSeconds, remainingTokens}`, and never touches
`checkGlobalLimit`. The three callables currently hand-roll what it does. Only the call site
changes; the `RATE_LIMIT_CONFIGS` keys already match.

**The convention this rests on is nearly invisible**, which is why it was missed and why it
is recorded here: non-LLM callables use `enforceRateLimit`, only genuinely LLM-backed ones
use `withRateLimit`. That line is drawn in exactly two inline comments —
`verify-signup-age.ts` ("Deliberately NOT withRateLimit — that helper also gates on the LLM
global limiter") and `set-profile-searchability.ts` ("the latter also consumes the GLOBAL
LLM budget, and this callable costs no model spend"). `rate_limiter.ts`'s own docstring
shows `withRateLimit` as *the* usage pattern, so a reader who greps the helper and not those
two call sites will reach the wrong answer, as this plan did.

**Accepted cost:** `enforceRateLimit` also calls `logRateLimitViolation`, so these three
operations begin writing an audit row on denial for the first time. One extra Firestore
write per *denied* request. Taken deliberately as a monitoring gain.

**Owed test:** that "a user must always be able to leave a group" survives the change.

### Superseded 2026-09-04 — three counts in §1 went stale when it shipped

Recorded rather than struck, because a decision record is superseded and dated, never
edited in place.

- **"the three callables" and "these three operations begin writing an audit row"** — it is
  **four**. `ensure-category-chat.ts` carries the byte-identical defect and was missed by
  both the ticket and the plan. It is the worst case of the four: it is one of only two
  buckets in `groups/` that declares a `dailyLimit` (50), so the gap between the client's
  60-second fallback and the real wait is widest exactly there, and its errors reach the same
  `ChatGroupErrorMapper` through `social_group_detail_viewmodel.dart`. Found by the
  `cloud-functions-specialist` gate, which stopped at the plan threshold rather than editing.
- **"exactly two inline comments"** — six files carry the convention now, because the four
  fixed call sites each gained one citing the original two.
- **A correction to §1's own framing:** the "real wait was until the daily cap reset"
  reasoning holds only for `createChatGroup` and `ensureCategoryChat`.
  `addChatGroupMembers` and `removeChatGroupMember` declare no `dailyLimit`, so their
  reachable wait is the minute bucket's. The comments in those two files say so.
- **What the fix was NOT pinned by:** widening the wiring test's regex to
  `(?:check|enforce)RateLimit\(` keeps the operation KEY pinned across the move, but makes
  the two spellings interchangeable to that suite — measured by reverting a call site to the
  bare form and watching it stay green. The payload is pinned instead by a dedicated case in
  `rate-limiter-daily-cap.test.ts`, mutation-probed by deleting `details` from
  `enforceRateLimit`.

## 2. The GDPR export fix would have moved the hole, not closed it

**The defect is real.** In `social_export_manager.dart`, a per-conversation read failure
sets `messagesData['error_code'] = 'conversation-messages-read-failed'`. A few lines later
`messagesData.addAll(await ChatGroupExport(...).export(userId))`, and `ChatGroupExport`
returns its own generic `error_code` on failure. `Map.addAll` overwrites, so on a double
failure the conversation error vanishes from the Article 15 bundle.

**The plan's fix was `??=`.** The DPO refuted it: `??=` only changes *which* of the two
failures disappears. `DataExportService` emits one warning per section from a single
`error_code`, so the losing code is not de-prioritised, it is gone from the artefact the
data subject may forward to a supervisory authority. That is the pre-BUT-1838 shape for
this pair, in a file where BUT-1838 already solved the same problem once by keeping
`poll_votes_error_code` separate.

**Decision: a dedicated field plus the fallback.** The chat-groups failure gets its own key
(mirroring `poll_votes_error_code`); `??=` governs only the generic `error_code` that the
single-warning chokepoint reads. Both failures stay recoverable from the bundle.

Legal Counsel confirmed no Article 12(1) angle of its own here and ceded export mechanics
to the DPO, consistent with its 2026-07-13 dossier note.

**Note for the implementer:** `cb3698f5c` (2026-09-03, BUT-2003/2004) rebuilt this file's
error handling — each read is now isolated per leg via `attemptedLegs`/`failedLegs`, and a
failed leg emits error keys with no list rather than a false-empty one. The bug above is
untouched by that commit, but the fix should follow the new shape.

### Superseded 2026-09-04 — §2's rationale overclaimed; the decision stands

The DPO's reasoning as recorded here says the losing code "is gone from the artefact the
data subject may forward to a supervisory authority". Measured against the code when the fix
shipped: it was **not** erased from the bundle. The conversations code also lands per
conversation, written by the BUT-1838 branch a few lines above whose comment exists to say
so. What the loser actually lost was the **bundle-level warning** — `DataExportService`
builds one warning per section from the root `error_code` alone.

The decision is unaffected and remains correct: a dedicated key plus `??=` on the generic
one, so both failures stay recoverable and neither depends on which happened first. The
priority between them decides only which token the root warning names — the sentence
`DataExportService` emits is the same either way.

Also corrected: the implementation comment briefly justified the priority as "an unreadable
conversation is a bigger claim than an unreadable group roster". That was unmeasured and is
contestable the other way (the chat-groups code means the whole leg returned nothing; the
conversations code can come from one conversation out of a hundred). Struck rather than
reworded; the code now states the readable fact — the conversations branch claims the root
key unconditionally, so this leg takes it only when neither other branch did.

## 3. `viewedBase` may guard nothing, and may be hiding a real bug

Recorded here because the plan changed from a build step to a **measurement**, and that
change is the decision.

`viewedBase` — a snapshot of the shopping list the user was looking at when they opened the
member-permission dialog — is checked only in Dart, by `restrictAccessControlToDeclaredBase`.
`firestore.rules` authorises membership writes on `resource.data.memberPermissions` at write
time and has no concept of a client-declared base. Malin asked for the strongest available
protection.

The Security Architect's finding: mirroring the Dart check into rules is **not** that.
Non-owners are already blocked from touching `memberPermissions` outright, so the drift
check only ever guards the owner's own writes — and a hand-crafted client can simply declare
a base equal to what it is about to write. The real gap it could close is narrower and is a
data-integrity one: a stale owner replay from a second device silently reinstating a removed
member. Closing *that* needs a **server-held monotonic version** (`aclVersion`,
compare-and-swap), never a client-supplied prior ACL.

The Codebase Archaeologist's finding, orthogonal and larger: `requireNoPrivilegeEscalation`
runs earlier in the same chain and refuses any non-owner whose `memberPermissions` differ
from stored, with no exemption for a member holding admin — and a test pins that as intended.
But `canManageShoppingList` explicitly grants non-owner admins the right to manage members.
If that trace holds, **admins cannot manage members at all today**, and hardening
`viewedBase` would be armour on a path nobody can reach.

**Decision: reproduce before building.** Prove against the emulator whether a non-owner
admin reaches `restrictAccessControlToDeclaredBase`. If the path is dead, that is the real
ticket. If it is live, the guard is `aclVersion` compare-and-swap, its new field is added to
the `hasOnly` allowlist in the same edit (BUT-1482), and the deny test is "a write computed
against a version the server has moved past" — not "a non-owner tries", which is already
covered.

## What would reopen this

- Anyone proposing `withRateLimit` for a non-LLM callable. The convention now has a home
  outside two inline comments; cite this ADR.
- The `viewedBase` reproduction returning "live", which turns §3 from a measurement into
  the `aclVersion` build.
- A change to how `DataExportService` surfaces section errors, which is what makes the
  dedicated-field decision in §2 load-bearing.
