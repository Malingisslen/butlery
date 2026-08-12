# ADR-0005: Household allergen sharing — scope, recipients, and the minimisation premise

- **Date:** 2026-08-12
- **Status:** Escalated to Malin → decided (decisions 1–4); one sub-question open
- **Trigger:** BUT-1693 — let a household member share their allergen list so
  menu generation stops guessing (Part 2 of BUT-1663). Plan:
  `tasks/butlery-1693-household-share-plan.md`
- **Blast-radius tier:** full-panel (`tools/stakeholder_router.py` returned
  `full-panel`, high-stakes hit on `firestore.rules`)
- **Stakeholders seated:** Legal Counsel, Privacy / Data Protection Officer,
  Security Architect, Product Manager, Database Administrator / Data-layer
  Engineer, plus the Codebase Archaeologist blindspot pass.
  **Dropped as incidental:** Customer Support/Ops, Data Analyst/BI, FinOps,
  Performance Engineer, Trust & Safety, Vendor/Procurement, Software Architect —
  each matched only through a path glob (`firebase_user_repository.dart`,
  `functions/src`) with no distinct concern in this change; the data-integrity
  concern that would have seated Software Architect is held by the DBA seat.

All five roles returned **approve-with-conditions**. Nobody blocked. The
conditions became acceptance criteria in the plan; only the genuine
disagreements and escalations are recorded here.

## The disagreements

### D1 — Which "household" scopes the share (DBA vs Security Architect)
Butlery has two live, unrelated household concepts: `FriendCategory.isHousehold`
(owner-scoped, asymmetric, what `HouseholdService` aggregates over today) and
`households/{householdId}` (symmetric `memberUserIds`, an existing
`isHouseholdMember(hid)` rules helper, and the collection under which this app
*already* stores household-readable Art. 9 allergen data for diner profiles).

- **Security Architect:** build against the friend category, matching the code
  that consumes the union today; a bounded `get()` on the owner's category
  document is the file's dominant idiom and is spoof-proof.
- **DBA:** build against `households/{hid}`; the friend-category route forks a
  third parallel household identity, and the symmetric collection already solved
  member-scoped reads for exactly this kind of data.

### D2 — What a member may share in one act (Product Manager vs the BUT-1663 floor reasoning)
- **Product Manager:** one combined toggle for allergens *and* dietary choices —
  splitting it doubles the decision at the moment we want least friction.
- **The standing engineering position** (recorded in `ACCEPTED_DEVIATIONS.md`,
  BUT-1663): the safety floor deliberately carries allergens **only**, because
  the menu treats a tracked diet as a hard requirement, and inheriting diets
  would empty an omnivore household's menu. Extending that reasoning to sharing
  argued for allergens-only, or two separate toggles.

### D3 — Whether the recipient set is live or a snapshot (Privacy/DPO)
The DPO flagged that a household-scoped read rule grants access to **anyone who
joins the household later**, which the sharer never met at consent time — and
noted this is the opposite of the app's own group-share precedent (BUT-1797),
where members are resolved at share time and joining later grants nothing.

### D4 — Whether the earlier data-minimisation override still holds (Legal Counsel)
On 2026-06-28 legal/DPO recommended dropping per-child allergen storage;
Malin overrode it eyes-open, partly on the stated premise that the household
filter keeps individual allergen attribution opaque. Storing one list per
consenting member changes that premise, so Legal held that the override must be
re-confirmed on the new facts rather than inherited.

## Decision

**D1 — decided by the synthesizer under the priority order** (user-safety &
trust > legal/privacy > data-integrity & security > correctness > cost): scope
the share to **`households/{householdId}`**. Both routes are security-acceptable,
so the tiebreak fell to correctness: a share is a statement *by* a member, so the
member must be able to name a household they belong to and write to it. A friend
category is owned by one person and the other members can neither see nor write
it — the asymmetry makes the friend-category route wrong for a self-declaration,
independent of cost. `HouseholdService` keeps aggregating over the friend-category
roster; a member present there but absent from `households/{hid}` simply has no
readable share and keeps the floor, which is safe by construction. Unifying the
two rosters changes which people the allergen union covers and is therefore its
own safety decision, deferred to its own ticket rather than ridden along.

**D2 — escalated to Malin → one combined toggle** (allergens *and* dietary
choices), against the engineering recommendation. She was shown the consequence:
if one member shares "vegansk", the whole household's weekly menu is planned
vegan. Accepted knowingly; the consent copy must state it before the toggle is
flipped. Do not re-propose splitting the toggle as a defect — revisit only on
evidence that households are losing their menus.

**D3 — escalated to Malin → live household scope.** Everyone in the household
sees the shared list, including anyone who joins later, and the consent text says
so in plain Swedish before the member opts in. Her reasoning: a newly arrived
family member who is silently unprotected is the failure this feature exists to
remove, and joining a household is an act the household controls. The BUT-1797
snapshot precedent governs *group content sharing*, not a standing safety
declaration, and is deliberately not followed here.

**D4 — escalated to Malin → override re-confirmed** on the new facts (per-member
storage; the interface still shows only a combined list, never "Anna: mjölk").
The June decision stands. This entry is the record so it is not re-litigated.

**Sequencing — Malin's call:** the DPIA addendum, the consent copy and the
privacy-policy clause are written and approved **before** any code. Not a
build-behind-a-flag-and-paper-it-later.

**Still open:** whether a member's Art. 15 export includes the *other* members'
shared lists (which their own client can already read). Engineering recommends
**no** — other people's allergies are not the requester's personal data. Recorded
as R8 in the DPIA addendum, to be settled there rather than by analogy with the
export precedents for display names and shopping lists.

## Stakes (per role)

- **Legal Counsel:** a new Art. 9 processing purpose landing on top of an
  already-open DPIA gap; protecting against a launch with an unreviewed lawful
  basis and a privacy policy that never mentioned the disclosure.
- **Privacy / DPO:** consent specificity, and erasure that actually reaches the
  data — the roster-change question, plus wiring the collection into the
  deletion cascade, the residual probe and the leave-household path rather than
  only the toggle.
- **Security Architect:** that a household-readable projection cannot be pointed
  at a stranger's household, cannot be spoofed by a client writing its own
  membership array, and does not leave a stale grant behind after a removal.
- **Product Manager:** that an opt-in nobody discovers gets no adoption, and that
  per-person attribution would recreate the disclosure problem the feature exists
  to avoid.
- **DBA / Data-layer:** read cost on two hot paths, and a projection that silently
  goes stale — which on this field is a safety bug, not an inconsistency.
- **Codebase Archaeologist:** that this exact bug class ("treat unreadable as
  safe") was caught and reintroduced three times inside BUT-1663's own review
  cycle, and that a new collection here has four registration points, not one.

## Consequence

If Butlery proceeds: the DPIA addendum, consent copy and policy clause are
approved first; then the share is built against `households/{householdId}` with
owner-only writes, live household-scoped reads, an atomic write alongside the
member's own settings edit, and erasure on all four triggers. Members who do not
share keep BUT-1663's floor unchanged, so nothing becomes less safe. The BUT-1663
deviation entry is superseded by a dated addition in both
`docs/architecture/ACCEPTED_DEVIATIONS.md` and `.claude/rules/accepted-deviations.md`
once the floor becomes conditional on opt-in.

Advisory only — the panel recommends; the controller decided, above.
