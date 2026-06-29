# Family Rating — Legal / DPO Backlog

The family-rating feature (household meal ratings, including non-account child
"diner profiles") is **fully built in code but must NOT ship to the app stores**
until the items below clear. This is the hand-off list for a privacy advisor /
DPO. Each item says what it is, why it blocks, and what it unblocks.

Engineering inputs already prepared (point your advisor at these):
- Consent mechanism (two-tier: guardian Art. 6 + separate explicit allergen
  Art. 9) — live in the "Min familj" screen.
- Data-retention / Art. 30 record — `docs/security/family-data-retention.md`.
- Data export (Art. 15/20) — includes child profiles + the user's family
  verdicts; see the in-code DPIA note in `family_export_manager.dart`.
- Erasure (Art. 17) — account-deletion cascade handles family data, including
  the shared-household re-home/teardown edge cases (§5b).

---

## P0 — Blocks launch

### 1. DPIA (Data Protection Impact Assessment) — *mandatory, none exists*
A formal DPIA is legally required because the feature processes **children's
data**, including **special-category health data** (allergens, Art. 9). It must
explicitly cover:
- Storing a child's name, age band, avatar, and allergens under guardian consent.
- The **export disclosure**: a co-controlling adult's data export includes the
  child's allergen data and the guardian-consent record (incl. the guardian's
  user id). Already coded; the DPIA must bless it.
- Retention / auto-deletion of dormant family data (see item 4).
- The consent mechanism's adequacy (versioned, timestamped, withdrawable).
**Unblocks:** the whole feature's launch.

### 2. Privacy policy rewrite (EN + SV)
Add the family-rating feature, the existence of managed child profiles, what is
stored, the lawful bases, and retention. **Also fix the existing "16"→"15" age
reference** (ADR-0001 floors self-accounts at 15). Files:
`docs/legal/privacy_policy.md`, `docs/legal/privacy_policy_sv.md`.
**Unblocks:** launch + transparency obligation (Art. 13/14).

---

## P1 — Decisions that unblock further build

### 3. Public ("alla") community-rating contribution — *Malin's request, needs a DPO ruling*
Malin wants household verdicts to feed a recipe's **public community average**
("4 families × 4 diners = 16 ratings"). Where this stands technically:
- **Adults already contribute, safely:** when an adult rates themselves on their
  own device, that verdict already mirrors into the public rating (and now
  un-mirrors on removal). No change needed.
- **The rest is blocked, and partly impossible-as-designed:** a verdict entered
  *for* another adult, and **any child's verdict**, cannot become that person's
  per-user public rating (children have no account; cross-user public writes are
  forbidden by design to prevent rating fraud). Making "all 16" count would
  require a **new public metric that aggregates children's verdicts**, which is
  precisely the children-data-goes-public step a DPO must rule on.
- **Engineering recommendation:** keep children's verdicts **private**; let only
  adults' verdicts influence the public number (the current behaviour). If the
  DPO wants more, it needs its own assessment + a privacy-policy line, and the
  aggregate must never expose an identifiable child's stars.
**Unblocks:** if approved, building the public family-aggregate; if not, this is
already correctly handled and can be closed.

### 4. Confirm the retention / dormancy window
`docs/security/family-data-retention.md` **proposes 24 months** of household
inactivity before auto-purging family data, with a defensible justification.
The DPO confirms or adjusts the number.
**Unblocks:** building + deploying the scheduled dormancy-sweep Cloud Function
(the mechanism is designed and the erasure logic already exists & is tested).

---

## P2 — Records & terms (no code dependency)

### 5. ADR-0003 — household diner profiles
Record the architectural/legal decision: managed non-account profiles for
under-15s, the deliberate, consented departure from ADR-0001's "no under-15
data" stance, and why (present-aware allergen safety + per-person verdicts).

### 6. Terms of Service — custody clause
§5b leaves **parent-vs-parent custody disputes** explicitly out of scope —
Butlery is not the arbiter. Add a short Terms clause stating that within a
shared household, members co-control diner profiles, and Butlery does not
mediate disputes over them.

---

## Suggested order
1 (DPIA) and 2 (policy) in parallel — both are P0 launch blockers and feed each
other. Then 4 (retention number, quick) and 3 (public-rating ruling). 5 and 6
can be drafted anytime. Nothing here needs more app development to *launch* —
items 3 and 4 only gate *optional* follow-on build.
