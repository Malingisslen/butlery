# ADR-0020: Rate limits stamp in the same request; messages carry no burst guard

- **Date:** 2026-09-14
- **Status:** Escalated to Malin → decided
- **Trigger:** `tasks/rate-limit-plan.md` — `rateLimitWrite` in `firestore.rules`
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Security Architect, Trust & Safety / Content Moderation, Database
  Administrator / Data-layer Engineer, Financial Controller / FinOps, Codebase Archaeologist,
  plus a cold plan audit

## The disagreement
Measured on the Firestore emulator (web SDK) on 2026-09-14: two writes of one stamped type queued
offline and replayed on reconnect — the first is accepted, the second refused, under today's rules
and under the proposed ones. A real burst guard therefore trades spam protection against losing
queued writes.

- **Trust & Safety:** keep guards on cross-user surfaces; messages and comments are spam vectors.
- **Database Administrator:** a newly enforced guard silently refuses a legitimate reconnect-time
  write; the user already saw it as sent.
- **Security Architect and the cold plan audit (independently):** a stamp shared by several writes
  in one batch let all of them through; binding the stamp to the guarded document id closes it.

## Decision
Escalated to Malin, who decided, 2026-09-14:
1. Mechanism: the writer stamps `users/{uid}/rate_limits/{type}` in the same request, pinned to
   server time and to the guarded document's id (`lastDocId`); no Cloud Function.
2. Messages carry no burst guard. Comments keep theirs. The first framing of this question
   wrongly said strangers could not spam comments; it was corrected and asked again.
3. Windows for sharing (`shared_content`, `received_list`, `received_menu`) and for starting a
   direct conversation (`conversations`) drop from 10 s to 3 s, after the plan audit showed
   ordinary online actions within 10 s would be refused.

## Decision, continued (2026-09-14, after the commit-gate reviews)
4. **`lastDocId` can hold another person's uid; stamps are short-lived.** A new direct
   conversation's id is `direct_<uidA>_<uidB>`, so the creator's own stamp names the other
   participant; that copy is not reached by the other participant's account erasure. Malin chose
   a short lifetime over erasing stamps in the deletion cascade and over removing the guard on new
   conversations: the writer sets `expireAt` 2 days from the device clock, the rules accept an
   `expireAt` after server time and at most 4 days ahead of it, and the `rate_limits` TTL policy
   was measured ACTIVE the same day. Group invitations get random ids instead of ids built from
   both uids. She also kept the Art. 15 exemption for `rate_limits` now that stamps carry a key.
5. **The pings stamp is keyed on `<groupId>/<pingId>`.** Keyed on the ping id alone, one stamp
   covered pings in any number of groups in one request (50 allowed on the emulator); keyed with
   `_`, a group/ping split of the same characters still let one stamp cover several pings (29
   allowed). `/` cannot occur in a document id.

## Stakes (per role)
- **Trust & Safety:** harassment through repeated cross-user writes; recipe-rating sweeps.
- **Database Administrator:** silent loss of queued offline writes; rules document-access budget.
- **Security Architect:** bypass of the stamp by batching or by deleting/backdating the bucket.
- **FinOps:** billed rules reads on inert guards; the client-writable LLM usage counter in
  `rate_limits/imports`, filed separately.
