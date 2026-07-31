# ADR-0004: The shared-list self-removal rule allowlists exactly `memberPermissions` + `updatedAt`

- **Date:** 2026-07-31
- **Status:** Decided (synthesizer, after a self-correction the cold audit forced)
- **Trigger:** the plan for BUT-1718 / BUT-1699 / BUT-1762 (`tasks/but-1718-1699-1762-plan.md`),
  routed on `firestore.rules` + `lib/repositories/firebase/modules/*` + `functions/src/shared/*`
- **Blast-radius tier:** full-panel (`tools/stakeholder_router.py --json` →
  `{"tier": "full-panel", "high_stakes_hits": ["firestore.rules"]}`)
- **Stakeholders seated:** Security Architect, Privacy / Data Protection Officer (GDPR),
  Database Administrator / Data-layer Engineer, Data Analyst / BI, Financial Controller /
  FinOps, Codebase Archaeologist (blindspot pass)

## The disagreement

BUT-1718 adds a new **write permission to a shared, multi-tenant document**: a household
member may remove their own key from `memberPermissions` on a shared shopping list, so
"leave list" stops failing.

The first draft guarded that arm with a **blocklist** —
`!diff().affectedKeys().hasAny(['ownerId','createdAt'])`.

**Security Architect blocked it.** The cited precedent (`firestore.rules:834-848`,
`menus/{menuId}`, BUT-747/749) uses an **allowlist** (`hasOnly([...])`), and for good
reason: with a blocklist, every field *not* named stays writable. A **view-only** member —
who cannot write `items` at all today — could vandalise or wipe the entire item array in
the same accepted write as leaving. A one-shot grief on the way out. Its must-have was
`hasOnly(['memberPermissions'])`.

**The synthesizer (me) overrode that must-have** and widened the allowlist to three keys,
claiming as *verified* that the real client write also carries `contributorUserIds`.

**That claim was false, and the cold-eyes plan audit caught it.**
`_withContributorTrail` (`shopping_repository_routing_module.dart:395-400`) opens with
`if (!payload.containsKey(itemsField)) return payload;` — a leave write carries no `items`
key, so the trail is never stamped. The call site had been read; the helper had not.

The consequence was not cosmetic. With `contributorUserIds` allowlisted, a view-only member
could union up to 200 arbitrary UIDs into an append-only array that
`account-deletion-cascade.ts:314,593` selects lists by and `:721-723` rewrites — dragging a
stranger's Art. 17 cascade into a household they were never in. The *same* griefing class
the allowlist exists to close, reopened one key over, by overriding a correct security
finding with a bad verification.

## Decision

**Allowlist exactly two keys: `['memberPermissions', 'updatedAt']`.**

Security Architect's principle was right and its literal remedy was one key short, not
wrong: `removeMember` does `copyWith(memberPermissions:…, updatedAt: clock.now())`
(`list_member_operations.dart:135-139`), so the narrowed payload is
`memberPermissions.<uid>` plus `updatedAt` — and nothing else.

Decided by the synthesizer. The priority order was **not** needed: security and correctness
converge once the allowlist is right. What was needed was evidence, and the first attempt
substituted an unverified claim for it.

`keepsContributorTrail()` stays **outside** the OR and continues to bind every arm, so a
departing member's uid remains in the trail — the only handle account erasure has on a list
someone has left (BUT-1725).

## Stakes (per role)

- **Security Architect:** blocked the blocklist. Protecting against privilege escalation and
  griefing on a shared document — specifically a view-only member gaining a one-shot write
  to fields their permission level forbids.
- **Privacy / DPO:** approved unconditionally. Protecting the Art. 17 erasure handle; noted
  that keeping a departed member's uid in `contributorUserIds` matches Malin's already-decided
  export precedent (2026-07-30) rather than creating a new deviation.
- **Codebase Archaeologist:** protecting against the guard/routing chain's history — this is
  one of the most rescue-heavy files in the repo (BUT-1683, 1696/1697, 1706, 1719, 1725/1733,
  1726, 1741, 1755, plus two post-hoc rescue commits). Found that the carve-out resolves
  cleanly *only* because `leaveList` routes through the one call site where the proposed
  entity is in scope.
- **DBA, Data Analyst/BI, FinOps:** no stake in this conflict; their conditions applied to
  the sibling tickets (TTL activation wording, the measurement ramp, and the cost arithmetic).

## Consequence

The self-removal arm is strictly `memberPermissions`-only (plus the inert `updatedAt`), and
the client-side predicate behind `requireEditRights` / `requireNoPrivilegeEscalation` must be
scoped identically so client and server cannot drift.

Two emulator cases carry the decision so it cannot silently regress:

- a leave write that **also modifies `items`/`name`** → denied (fails against the blocklist
  draft — mutation-test it in that direction);
- a leave write that **also unions a foreign UID into `contributorUserIds`** → denied (this
  case is only expressible *because* the allowlist narrowed to two keys, and must be run
  against the three-key version, where it will wrongly allow).

Both must run on the **emulator**. `FakeFirebaseFirestore` enforces no rules, which is
exactly how BUT-1766 and BUT-1788 stayed hidden.

**Process consequence worth keeping:** overriding a security finding demands the same
standard of proof as the finding itself. Also — Trust & Safety was dropped from this panel
on the grounds that "anti-griefing is explicit; Security covers that arm", and a griefing
hole is precisely what got through. Seat T&S whenever a write-permission arm is being
widened, regardless of who else is at the table.

Advisory only: BUT-1718 was **not built** in this session. This ADR records the decision so
the implementer does not re-derive it — or repeat the override.
