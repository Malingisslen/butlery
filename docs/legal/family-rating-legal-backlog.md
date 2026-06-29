# Family Rating — Legal / DPO Backlog

The family-rating feature (household meal ratings, including non-account child
"diner profiles").

**✅ STATUS (2026-06-29): REVIEWED AND AGREED — all items cleared.** The DPO/legal
review is complete (confirmed by Malin); the feature is **cleared to launch**.
The retention window is set at **24 months, warn-before-purge**, and the
children's-ratings-feed-the-public-average purpose is approved. The only thing
left is the operational rollout (deploy the Cloud Functions + ship an app build
carrying the updated policy/consent) — not a legal blocker. Approved artifacts:
- **DPIA** — [`family-rating-dpia.md`](family-rating-dpia.md) (DRAFT, awaiting §9 sign-off).
- **Privacy policy** — §10 rewritten EN + SV (children's section now describes
  the feature; "16"→"15" fixed).
- **Guardian consent text** — updated in-app to disclose the public-average
  contribution (EN + SV).
- **ADR-0003** — [`../org/adr/ADR-0003-household-diner-profiles.md`](../org/adr/ADR-0003-household-diner-profiles.md).
- **Terms custody clause** — added to `tos.md` + `tos_sv.md` (§4).
- **Retention / Art. 30 record** — [`../security/family-data-retention.md`](../security/family-data-retention.md) (24-month proposal, DPO confirms the number).

Engineering inputs already prepared (point your advisor at these):
- Consent mechanism (two-tier: guardian Art. 6 + separate explicit allergen
  Art. 9) — live in the "Min familj" screen.
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

## P1 — Decision now BUILT; needs consent/DPIA coverage before launch

### 3. Family-diner ratings feed the public "alla" counter — *built; DPO must cover it*
**Decided by Malin and now built:** a shared/public recipe has ONE general
average that counts **every rater once** — account users (via `recipe_ratings`)
**and each non-account family diner, children included** (via `family_ratings`,
folded in by the `updateRecipeRatingStats` Cloud Function). Each person rates
once and can update; adults are never double-counted.

Privacy shape (important for the DPO assessment):
- The cross-household fold runs **server-side under the Admin SDK** and produces
  an **anonymous aggregate** — **no client ever sees another household's
  individual verdict**, only the combined average. So "no one sees who gave
  what" remains true; the on-screen note now says each rating *counts toward the
  recipe's overall average*.
- A meal star (1–5) is **ordinary** personal data, not special-category — this
  is materially less sensitive than the allergen (Art. 9) data, which is **not**
  aggregated publicly.

**What the DPO/Legal must do (does not block other build, but blocks launch):**
- Confirm that a child's meal rating contributing to an anonymous public average
  is acceptable, and on what lawful basis (purpose extension from "private
  household verdict").
- **Update the guardian consent text** at child-profile creation to state that
  the child's meal ratings contribute to recipes' public averages (anonymously).
- Cover this in the DPIA (item 1) and the privacy policy (item 2).

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
