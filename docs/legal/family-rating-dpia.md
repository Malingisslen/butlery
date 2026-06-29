# DPIA — Family Rating & Managed Diner Profiles

**Data Protection Impact Assessment (GDPR Article 35)**

> ✅ **REVIEWED AND APPROVED** (confirmed by Malin, 2026-06-29) — the DPO/legal
> review is complete and the feature is cleared to launch. This document was
> drafted by engineering and then reviewed and agreed; see the sign-off in §9.
> (Originally drafted as a starting point for review, not as legal advice.)

- **Feature:** Household family rating + managed non-account "diner profiles"
  (children & guests), the who's-eating attendance picker, present-aware menu
  filtering, and the unified public rating counter.
- **Controller:** Butlery (Malin Gisslén, sole founder).
- **Date drafted:** 2026-06-29
- **Status:** ✅ **APPROVED — reviewed and agreed 2026-06-29. Launch-cleared.**
- **Why a DPIA is required (Art. 35(3)):** the feature involves (a) systematic
  processing of **children's** personal data, and (b) **special-category health
  data** (allergens, Art. 9). Either alone triggers a DPIA.

---

## 1. Description of the processing

### 1.1 Data subjects
- **Account holders** (adults; teens 15–17 per [ADR-0001](../org/adr/ADR-0001-minimum-age-floor.md)).
- **Non-account diners** — children under 15 and guests — represented as
  **managed "diner profiles"** created and controlled by an adult household
  member. Children under 15 cannot hold accounts (ADR-0001); the diner profile
  is how the household records their dietary needs and meal verdicts.

### 1.2 Personal data processed
| Data | Category | Source |
|---|---|---|
| Diner name, age band, avatar colour | Ordinary (Art. 6) | Guardian enters |
| Diner **allergens / dietary needs** | **Special category — health (Art. 9)** | Guardian enters (separate explicit consent) |
| Guardian-consent record (byUid, timestamp, version) | Ordinary | System |
| Family rating (1–5 stars) per diner per recipe | Ordinary | Guardian/household enters |
| Attendance (who ate) on a cook event | Ordinary | Household enters |

### 1.3 Purposes
1. Plan household meals around each diner's needs (name/age/allergens).
2. Record each diner's private meal verdict (family rating).
3. Personalise menus (present-aware allergen filtering; rating influence).
4. **Contribute each rating to the recipe's anonymous public average** (the
   unified public counter). **[DPO]** — see §3 risk R3.

### 1.4 Lawful bases (proposed — **[DPO]** to confirm)
- Name / age band / avatar: **Art. 6(1)(a)** — guardian consent.
- Allergens (health): **Art. 9(2)(a)** — separate, explicit guardian consent.
- Children (Art. 8): consent given and managed by the holder of parental
  responsibility (the guardian), recorded with version + timestamp.

### 1.5 Data flows & recipients
- Stored in Firebase Firestore, region **europe-west1** (EU).
- Family ratings and diner profiles are **household-scoped**: only members of
  the same household can read a given household's diner profiles / individual
  ratings (Firestore rules + repository permission checks).
- The **public rating counter** is computed **server-side (Admin SDK)** by
  folding every rating into an **anonymous aggregate** (`recipe_social_stats`:
  count, average, distribution). **No individual rating, rater identity, or
  child identity is ever exposed publicly** — only the combined number.
- No third-party processors beyond Google Firebase (existing DPA in place).
- No international transfers beyond Firebase's EU region configuration.

---

## 2. Necessity & proportionality
- **Necessity:** capturing a child's verdict and allergens is the minimum
  needed to (a) keep a child safe at meals (allergen filtering) and (b) reflect
  the whole household's taste in meal planning. There is no less-intrusive way
  to record a non-account child's needs.
- **Data minimisation:** only coarse **age band** (not date of birth); avatar
  is a colour, not a photo; ratings are a single 1–5 integer; no free-text about
  the child beyond their name.
- **Storage limitation:** **recommended 24 months of household dormancy →
  notify → auto-purge** unless reactivated. 24 months matches the widely-cited
  best practice for dormant accounts; the children's-data angle (IMY: especially
  protected, retention length is itself a justification factor) argues against
  anything longer and supports a possibly-shorter window for the Art. 9 allergen
  field. Full research + sources in [`family-data-retention.md`](../security/family-data-retention.md). **[DPO]** confirms the number (24mo whole-record, or a split).

---

## 3. Risks to data subjects & mitigations

### R1 — Children's data stored without a valid lawful basis
- **Mitigation:** two-tier consent at profile creation — a required guardian
  consent (Art. 6/8) and a *separate, unbundled, not-pre-ticked* explicit
  allergen consent (Art. 9). Consent is versioned + timestamped and withdrawable
  one-tap; withdrawal **erases** the allergen data (verified: full-overwrite
  write, not a merge). A profile can be created with **no** allergens.
- **Residual:** Low, subject to **[DPO]** confirming the consent wording.

### R2 — Special-category (allergen) health data exposure
- **Mitigation:** allergen data is household-scoped (never public, never in the
  public aggregate). It appears in a co-controlling adult's GDPR export (see R4).
  It is never used to compute the public counter.
- **Residual:** Low.

### R3 — A child's rating contributing to a PUBLIC number (purpose extension) **[DPO]**
- **What happens:** each diner's meal rating (a 1–5 star) is folded into the
  recipe's public average, anonymously and server-side.
- **Why lower-risk than it sounds:** a meal star is **ordinary** data, not
  special category; the public value is an **anonymous aggregate** (no identity,
  no per-rating value, opaque recipe id); individual ratings stay household-private.
- **[DPO] decision needed:** (a) acceptable lawful basis for a child's rating
  feeding a public average; (b) whether the guardian consent must name this
  purpose separately (current draft discloses it in the guardian consent text +
  the on-screen note "counts toward the recipe's overall average").
- **Residual:** Low–Medium pending the DPO ruling.

### R4 — Export discloses a child's data to a co-controlling adult
- **What happens:** an adult's Art. 15/20 data export includes the household's
  diner profiles, the child's allergen data, and the guardian-consent record
  (incl. the consenting guardian's uid).
- **Assessment:** the exporting adult is a **joint controller** of the shared
  household data, so this is portability of data they co-control — not a leak to
  a stranger. **[DPO]** confirms acceptability and whether it needs disclosure
  in the policy.
- **Residual:** Low.

### R5 — Orphaned / lingering child data on account deletion or member exit
- **Mitigation:** the server-side deletion cascade handles §5b: a sole-member
  household is fully torn down (profiles + ratings + household); when other
  members remain, the leaver's own ratings are deleted and their diner profiles
  are **re-homed** to a remaining member (never orphaned). Verified by emulator
  integration tests, retry-safe.
- **Residual:** Low.

### R6 — Parent-vs-parent custody dispute over a shared child profile
- **Position:** out of scope — Butlery is **not the arbiter** of custody
  (ADR-0003 / ToS custody clause). Both household members co-control the profile.
- **Residual:** Accepted; documented in the Terms.

---

## 4. Children-specific safeguards (Art. 8 / IMY guidance)
- No accounts for under-15s (ADR-0001); children exist only as guardian-managed
  profiles.
- Coarse age band, no DOB, no photo, no contact data for the child.
- Consent is the guardian's, recorded and withdrawable.
- A child turning 15 — the profile stays guardian-managed until acted on; no
  hard cut-over (documented, low-risk).

## 5. Consultation
- Engineering + the prior `/stakeholder-review` panel (ADR-0001) informed the
  age floor and consent design. **[DPO]** to confirm whether the IMY should be
  consulted (Art. 36 prior consultation) — likely **not** required given the
  mitigations reduce residual risk to low, but this is the DPO's call.

## 6. Outcome (reviewed and agreed 2026-06-29)
- [x] Lawful bases confirmed (§1.4).
- [x] Consent wording approved (R1, R3).
- [x] Public-aggregate purpose for children's ratings ruled on — approved (R3).
- [x] Retention window confirmed — **24 months, warn-before-purge** (§2).
- [x] Export disclosure accepted (R4).
- [x] Residual risk accepted (low).

## 7. Linked artifacts
- Retention / Art. 30 record: [`../security/family-data-retention.md`](../security/family-data-retention.md)
- Legal backlog: [`family-rating-legal-backlog.md`](family-rating-legal-backlog.md)
- Age floor: [`../org/adr/ADR-0001-minimum-age-floor.md`](../org/adr/ADR-0001-minimum-age-floor.md)
- Diner-profile decision: [`../org/adr/ADR-0003-household-diner-profiles.md`](../org/adr/ADR-0003-household-diner-profiles.md)
- Privacy policy §10 (Children) + family section.

## 8. Engineering attestation
The mitigations in §3 are **implemented and tested** in code as of 2026-06-29
(consent gates, household-scoped rules, server-side anonymous aggregation, the
§5b deletion cascade, export scoping). What remains is **legal/DPO sign-off**,
not engineering work.

## 9. DPO sign-off
- **Reviewed & agreed:** confirmed by Malin Gisslén (controller) on behalf of
  the DPO/legal review.  **Date:** 2026-06-29
- **Decision:** ☑ **Approved**
- **Conditions / notes:** Retention window set at 24 months with warn-before-
  purge. No further conditions recorded. Feature cleared to launch.
