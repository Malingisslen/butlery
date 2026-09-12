# ADR-0018: Self-removal goes through the one named membership write, with an intent

- **Date:** 2026-09-12
- **Status:** Decided (synthesizer, priority order)
- **Trigger:** the plan for BUT-1718 (`tasks/but-1718-leave-shared-list-plan.md`)
- **Blast-radius tier:** full-panel (`tools/stakeholder_router.py --json` →
  `{"tier": "full-panel", "high_stakes_hits": ["firestore.rules",
  "functions/src/__tests__/shared-shopping-lists-rules.test.ts"]}`)
- **Stakeholders seated:** Security Architect, Privacy / Data Protection Officer (GDPR),
  Software Architect, Database Administrator / Data-layer Engineer, QA / Test Engineer,
  Codebase Archaeologist (blindspot pass), and Trust & Safety — seated late, on ADR-0004's
  own process rule that T&S sits on every widening of a write permission.

## The disagreement

Two client guards refuse a self-removal before the server sees it:
`ShoppingListPermissionGuards.requireEditRights` turns a view-only member away outright, and
`requireNoPrivilegeEscalation` throws for any non-owner whose write touches
`memberPermissions`, including one removing only their own key. Something had to give.

**The plan proposed a dedicated repository method** — `leaveCollaborativeList(listId)` — that
reads the document, checks the caller itself, and writes the narrow payload directly, leaving
both shared guards untouched. The Security Architect and Software Architect seats each
objected independently, on the same ground: `ShoppingListPermissionGuards`' own header states
that every write path in the routing module runs the guards, and a path that deliberately
skips them makes that sentence false in checked-in code. Both asked for the predicate to live
in the guard class as a named method.

**The Codebase Archaeologist raised the harder objection.** `ADR-002` is binding here and says
more than "put the logic in one place": every membership change routes through
`updateCollaborativeListMembership`, never a parallel write, because the FIRST attempt at
membership writes shipped with green unit tests and zero real callers — every add, removal,
permission change and leave wrote nothing while the dialog reported success, and an owner
believed access was revoked while the removed member kept writing. A second write path is the
shape that incident produced.

## Decision

**One write path, told what it is doing.** `updateCollaborativeListMembership` takes a
`MembershipWriteIntent`; `selfRemoval` runs `requireSelfRemovalOnly` — a new named method in
the guard class — in place of the two guards that refuse the write. Neither existing guard is
modified. Everything else the seam already does (the audit row, the payload narrowing, the
cached-base refusal that makes a membership change impossible offline) is inherited rather
than reimplemented.

Resolved by the priority order, not escalated: data-integrity and security agree, and the
disagreement was about layering rather than about what the user gets.

**The intent is REQUIRED, not defaulted.** A defaulted `ordinary` would silently hold a
departure to the guards that refuse it, and a forgotten optional argument is precisely the
failure ADR-002 records. Two call sites pass it explicitly.

The guard class header is corrected in the same change: it now says every write path runs ONE
of the guards, and names the exception. The alternative — leaving a sentence that the change
falsifies — is the comment-rot this repo pays for repeatedly.

## Stakes (per role)

- **Security Architect:** the rules arm and its test matrix; asked that the client predicate be
  a named guard rather than inline, and that the grant be audited as well as the refusal. The
  grant is audited — by `updateCollaborativeList` once the write has landed. The guard itself
  is refusal-only, like its three siblings, because a grant row inside it is written BEFORE
  the write: a departure the server then refuses would leave a standing grant for something
  that never happened, and a successful one would log two. That reconciles this seat's
  must-have with the `firebase-backend-security` gate's finding against the first version.
- **Software Architect:** layering, and the 500-line budget — `firebase_shopping_repository.dart`
  sat at exactly 500 and the routing module at 498, neither allowlisted, so a dedicated method
  had nowhere to live.

  **Superseded 2026-09-12, in the same build, by the `code-reviewer` and
  `integration-reviewer` gates.** Retired verbatim: "Putting the predicate in the 350-line guard class resolved both."
  It did not. All THREE files ended up over the limit — the routing module, the facade, and
  the guard class the predicate moved into — and each now carries an
  `ACCEPTED_LARGE_FILES.md` row whose count is recomputed at stage time. That is what the
  allowlist is for: the routing module has already been split twice, the guard class is the
  single-place mirror ADR-0004 requires, and the facade's rationale is in its own row. The
  sibling header in `shopping_offline_write_module.dart` that claimed the routing module stays
  under the limit was struck in the same edit.
- **Codebase Archaeologist:** ADR-002's incident history, and the post-leave read denial — the
  read rule refuses the document the instant the write lands, and nothing in the shopping views
  handles `permission-denied` on a stream.
- **DBA:** the write shape (a field-path delete, not a whole-map replace) and the first nested
  `diff()` in the rules file, which it asked be proven on the emulator rather than reviewed.
- **QA:** that one mutant cannot grade a five-conjunct arm, and that the owner case needs a
  control so a too-broad conjunct cannot hide behind a green deny.
- **Privacy/DPO:** the erasure handles, and that the Art. 15 gap for a departed member is
  re-argued rather than inherited from BUT-1732.
- **Trust & Safety:** that leaving stays silent, and that the consent gap on being ADDED becomes
  reachable once leaving is routine (filed as BUT-2089).

## Consequence

A future reader looking for `leaveCollaborativeList` will not find one, and that is the
decision. A departure is `updateCollaborativeListMembership(..., intent: selfRemoval)`.

Do not "simplify" the intent into a default, and do not move the self-removal predicate out of
`ShoppingListPermissionGuards` — both are the shapes this ADR and ADR-002 exist to refuse.
