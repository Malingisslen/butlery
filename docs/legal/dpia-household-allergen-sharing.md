# DPIA addendum — Household allergen sharing (BUT-1693)

**Data Protection Impact Assessment (GDPR Article 35) — addendum to
[`family-rating-dpia.md`](family-rating-dpia.md)**

> ✅ **APPROVED** by Malin Gisslén (controller) on **2026-08-12**, including the
> consent copy in Annex A and the policy clause in Annex B. Drafted by
> engineering as a starting point for the controller's review, not as legal
> advice. The build is cleared to start; the feature stays behind an off flag
> until the policy clause is live (§9).

- **Feature:** an adult household member opts in to share their own declared
  allergens and dietary choices with their household, so weekly-menu generation
  filters on the real list instead of a guessed common-allergen floor.
- **Controller:** Butlery (Malin Gisslén, sole founder).
- **Date drafted:** 2026-08-12
- **Status:** ✅ **APPROVED — 2026-08-12. Build cleared.**
- **Why an addendum and not a new DPIA:** the parent DPIA already assesses
  household-scoped Art. 9 allergen data (for guardian-managed diner profiles)
  inside the same household boundary, with the same storage, the same rules
  mechanism and the same recipients. What is new is the **data subject** (an
  adult, or a 15–17-year-old account holder, sharing their *own* health data
  rather than a guardian sharing a child's) and the **consent actor** (the data
  subject themselves). Everything else is inherited.
- **Why a DPIA is required at all (Art. 35(3)):** special-category health data
  (allergens) processed systematically. Unchanged from the parent.

---

## 1. Description of the processing

### 1.1 What happens today, and why it is not good enough

An account holder's allergen list lives in a private per-user settings document
that only its owner may read (`firestore.rules`, `allow read: if isOwner(userId)`).
Butlery therefore **cannot** read another adult household member's allergies at
all — the field is always empty to everyone else, no matter what that person
declared.

Because a household's weekly menu must still be safe, the app substitutes a
**common-allergen floor** for every member it cannot read: gluten, mjölk, nötter,
jordnötter (BUT-1663, shipped 2026-07-26). That floor is honest but blunt:

- a member allergic to **egg or shellfish is not protected**, and
- a household where nobody has those four gets a **needlessly narrowed menu**.

This feature replaces the guess with the member's real list — for members who
choose to share it. Members who do not share keep exactly today's floor.

### 1.2 Data subjects

- **Account holders only.** Under-15s cannot hold accounts
  ([ADR-0001](../org/adr/ADR-0001-minimum-age-floor.md)), so the sharer is always
  15 or older. A 15–17-year-old sharer is above the Swedish age of digital
  consent (13, Dataskyddslagen 2 kap. 4 §) and consents for themselves; no
  guardian consent is involved on this path.
- **Recipients:** the other members of that household — see §1.6.

### 1.3 Personal data processed

| Data | Category | Source |
|---|---|---|
| The member's tracked **allergens** | **Special category — health (Art. 9)** | The member, from their own settings |
| The member's tracked **dietary choices** (vegetarisk / vegansk) | Ordinary (Art. 6) — may sit adjacent to a belief, see R6 | The member |
| `includeUnknownInMenu` (how cautious to be about unverified recipes) | Ordinary | The member |
| Consent record — granted flag, version, timestamp | Ordinary | System |
| The member's user id and their household's id | Ordinary | System |

**Deliberately not stored:** the member's name, avatar, or anything identifying
beyond the uid the household can already resolve. The household UI shows a
**combined list only** — never "Anna: mjölk". Data minimisation is the reason.

### 1.4 Purposes

1. Filter the household's weekly menu on the household's **real** allergens
   rather than a guessed floor — the safety purpose.
2. Stop shrinking a household's menu for allergies nobody in it has — the
   accuracy purpose.

No secondary purpose. The shared list is **never** used for analytics, never
leaves the household, and never contributes to any public or aggregate figure.

### 1.5 Lawful bases

- **Allergens (health):** Art. 9(2)(a) — **explicit consent**, given by the data
  subject about their own data, separate and unbundled from any other consent,
  not pre-ticked, versioned, timestamped, withdrawable in one tap.
- **Dietary choices, `includeUnknownInMenu`, consent record:** Art. 6(1)(a) —
  consent, captured in the same act. (They are bundled with the allergens by the
  controller's explicit decision — see §3 R6.)
- **No legitimate-interest fallback.** If consent is absent or withdrawn, the
  processing does not happen: the app falls back to the floor it uses today.

### 1.6 Data flows & recipients

- Stored in Firebase Firestore, region **europe-west1** (EU). No new processor,
  no new transfer.
- One document per member per household, in a dedicated collection. Read access
  is decided **at read time** by Firestore rules from the household's live
  membership list — the same mechanism that already governs diner profiles.
- **Recipients are the household's current members, including anyone who joins
  the household later.** This is the controller's explicit decision (§9, decision
  2) and the consent text states it in plain Swedish before the toggle is flipped.
- Not readable by friends, not readable by the wider app, and structurally
  excluded from the world-readable public profile document.
- No Cloud Function, no LLM, no third party sees the list.

---

## 2. Necessity & proportionality

- **Necessity:** to filter a household's menu on a member's allergies, the app
  has to be able to read them. There is no less-intrusive route: the alternative
  in production today is to guess four allergens for that person, which both
  over-collects (protecting against allergies they may not have) and
  under-protects (missing the ones they do have).
- **Minimisation:** only the fields the filter consumes. No name, no avatar, no
  free text, no history. The household sees a combined list, never per-person
  attribution.
- **Proportionality:** the disclosure is to a household the member already lives
  and eats with, is opt-in per person, and is reversible in one tap with
  immediate effect.
- **Storage limitation:** the document exists only while the consent stands. It
  is deleted on withdrawal, on leaving or being removed from the household, and
  on account deletion. Nothing survives the consent except the accountability
  record (§3 R5).

---

## 3. Risks to data subjects & mitigations

### R1 — Consent that is not "explicit" enough for Art. 9
- **Mitigation:** the toggle is standalone (not bundled into any other setting),
  off by default, never pre-ticked, and turning it on opens an explain-then-
  confirm dialog naming what is shared, who sees it, and how to take it back.
  Version + timestamp are stored with the share. The bar is the one this app
  already set for guardian allergen consent
  ([ADR-0003](../org/adr/ADR-0003-household-diner-profiles.md)).
- **Residual:** Low, subject to the consent wording in **Annex A** being approved.

### R2 — Someone outside the household reads the list
- **Mitigation:** access is re-derived from live household membership on every
  read, so removing a person cuts their access immediately with no cleanup step
  and no window. A member cannot add themselves to a household they are not in
  (the existing membership rule only lets an existing member move their own id).
  Writing a share is only permitted to the list's owner, and only pointed at a
  household that owner actually belongs to — so a share cannot be aimed at a
  stranger's household.
- **Residual:** Low. Proven by allow/deny rules tests before release.

### R3 — A member who joins later sees a list shared before they arrived
- **What happens:** by design, yes. Access follows the household, not a snapshot
  of who was in it on the day the member opted in.
- **Why:** the alternative — freezing the recipient set — means a newly arrived
  family member is silently unprotected, which is the exact failure this feature
  exists to remove, and the sharer would have to notice and re-share.
- **Mitigation:** the consent text says it **before** the toggle is flipped ("alla
  i hushållet — även den som går med senare"). Joining a household is an act the
  household controls.
- **Residual:** Low–Medium, **accepted by the controller** (§9, decision 2).

### R4 — A stale or partially-written share filters on the wrong list
- **What happens:** the member edits their allergies and only one of the two
  documents is written — the household then filters on an out-of-date list. On
  this field that is a safety defect, not an inconsistency: a newly added
  allergen that fails to propagate leaves a real allergen unfiltered.
- **Mitigation:** the settings document and the share move in **one atomic
  write**. No eventual-consistency window, no server trigger in the write path.
- **Residual:** Low.

### R5 — Withdrawal erases the proof that consent was ever given
- **What happens:** "delete on withdrawal" would also delete the record that the
  processing had been lawful, which Art. 7(1) requires the controller to be able
  to demonstrate.
- **Mitigation:** withdrawal deletes the **shared list**; the grant and
  withdrawal events are recorded in the existing audit log with version and
  timestamp, retained separately, and appear in the member's own data export.
- **STATUS 2026-08-12 — this mitigation is NOT yet built, and the sentence above
  describes the intended end state, not today's code.** What a withdrawal
  actually leaves behind is a permission-check row (actor, resource,
  `operation: 'delete'`, timestamp, granted) with **no `consentVersion`**, and
  its operation spelling puts it in the 180-day general retention bucket rather
  than the 730-day `consent_*` one. Since the share document is the only carrier
  of `consentVersion` and `consentGrantedAt`, deleting it today removes the
  record that consent was ever given. Building the real
  `consent_granted` / `consent_revoked` pair is a **named gate on switching
  the feature on** (`enable_household_allergen_sharing` is off, nothing writes
  in production). Use those exact spellings: both are ALREADY carried by
  `CONSENT_OPERATIONS` (`functions/src/audit_logs/purge-expired.ts`), so the
  retention classification needs nothing new and no second token for "withdrawn"
  should be minted. Note what that does NOT mean: nothing in this repo writes
  either operation today — the existing consent repository writes
  `consent_updated` and `consent_deleted` — so the writer itself is part of this
  gate, not something already running. That list is
  exhaustive by enumeration — an unlisted `consent_*` operation falls to the
  180-day bucket and the trail is purged at six months, invisibly.
- **Residual:** Low **once built**; until then the withdrawal half of the Art.
  7(1) trail does not exist.

### R6 — Dietary choices are bundled with allergens, and can narrow the household's menu
- **What happens:** the controller decided (§9, decision 1) that one toggle
  shares allergens **and** dietary choices. The menu treats a tracked diet as a
  hard requirement, so if one member shares "vegansk", every non-vegan recipe
  leaves the household's menu. A dietary choice can also sit adjacent to a belief
  (Art. 9's "religious or philosophical beliefs"), though the app records it as a
  food preference and asks for nothing more.
- **Mitigation:** the consent text states the menu consequence explicitly, so the
  member chooses it knowingly; the whole thing is opt-in and one tap to undo. The
  narrowing is visible immediately in the app's own menu and is not silent.
- **Residual:** Medium, **accepted by the controller** (§9, decision 1). Revisit
  if households report menus emptying; splitting the toggle in two is a small,
  non-breaking change.

### R7 — The shared list lingers after the member is gone
- **Mitigation:** four erasure triggers, not one — withdrawal, leaving the
  household, being removed from the household, and account deletion (a named step
  in the deletion cascade **and** in the residual-data probe that detects a
  stalled deletion, plus the admin reset tool). This is deliberate: the parent
  DPIA's R5 is the same risk, and this repo has a documented history of new
  collections being missed by exactly one of these paths.
- **STATUS 2026-08-12:** none of the four is built. The mitigation above is written
  in the present tense and describes the DESIGN, not the code: the consent UI shipped
  with `enable_household_allergen_sharing` OFF and `grep household_allergen
  functions/src` is empty, so there is no cascade step, no probe leg, no reset entry
  and no export section. Nothing has leaked — with no `firestore.rules` block the
  collection is default-denied, so no document can exist — but this risk is NOT
  mitigated today and the four triggers are named gates on flipping the flag.
- **Residual:** Low **once built**; today unmitigated-but-unreachable. Subject to the
  erasure tests passing before release.

### R8 — The list leaks into a data export it does not belong in
- **Position:** a member's own export contains their **own** shared list and
  their own consent record. Whether it should also contain the **other**
  members' shared lists — which that member's app can already read — is an open
  controller decision, recorded as such rather than settled by analogy with the
  export precedents for names and shopping lists. **Engineering recommendation:
  no** — other people's allergies are not the requester's personal data, and
  Art. 15 does not reach them.
- **Residual:** open until §9, decision 5.

---

## 4. Relationship to the parent DPIA's premise

The parent DPIA and its surrounding decisions were agreed on 2026-06-28/29. In
that review, legal/DPO **recommended dropping per-child allergen storage** on
data-minimisation grounds, and the controller kept it, eyes open, partly on the
stated premise that *the household filter protects the table anyway*.

This feature changes what that filter is built from: instead of one opaque
combined set, the household now stores **one list per consenting member**. The
premise behind the earlier override is therefore in play, which is why it was put
back to the controller rather than inherited. She re-confirmed it on 2026-08-11
(§9, decision 3); [ADR-0005](../org/adr/ADR-0005-household-allergen-sharing.md)
records that, so no future reviewer re-litigates it.

What has **not** changed: the household is still the boundary, the combined list
is still what the interface shows, and no allergen data of any kind becomes
public.

---

## 5. Consultation

- A full stakeholder panel ran before the plan was written (Legal Counsel,
  Privacy/DPO, Security Architect, Product Manager, Database Administrator, plus
  a codebase-history pass). All returned *approve with conditions*; the
  conditions are the mitigations in §3 and the acceptance criteria in the
  implementation plan.
- **Art. 36 prior consultation with IMY:** likely not required — the mitigations
  reduce residual risk to low, with the two accepted Medium items above being the
  controller's own informed choices. The controller's call, recorded in §9.

---

## 6. Outcome (reviewed and agreed 2026-08-12)

- [x] Lawful bases confirmed (§1.5).
- [x] Consent wording approved (**Annex A**).
- [x] Privacy-policy clause approved (**Annex B**), to be applied to the shipping
      policy when the feature flag goes on.
- [x] R3 (later joiners see an earlier share) accepted.
- [x] R6 (dietary bundled, menu can narrow) accepted.
- [x] R8 decided — the export carries the requester's **own** share and consent
      record only; other members' shared lists stay out.
- [x] Residual risk accepted; feature cleared to build.

---

## 7. Linked artifacts

- Parent DPIA: [`family-rating-dpia.md`](family-rating-dpia.md)
- Decision record: [`../org/adr/ADR-0005-household-allergen-sharing.md`](../org/adr/ADR-0005-household-allergen-sharing.md)
- Age floor: [`../org/adr/ADR-0001-minimum-age-floor.md`](../org/adr/ADR-0001-minimum-age-floor.md)
- Consent precedent: [`../org/adr/ADR-0003-household-diner-profiles.md`](../org/adr/ADR-0003-household-diner-profiles.md)
- Today's guessing behaviour and why it is accepted:
  `../architecture/ACCEPTED_DEVIATIONS.md` (BUT-1663 entry)

## 8. Engineering attestation

**None yet — nothing is built.** This document precedes the code by the
controller's instruction. The attestation is added, with the test evidence, when
the implementation is complete and before the feature flag is switched on.

## 9. Controller decisions & sign-off

Decisions 1–4 were taken by Malin Gisslén on **2026-08-11**, before this document
was drafted, and are reproduced here because the assessment depends on them.
Decision 5 is open.

1. **What is shared:** allergens **and** dietary choices, in one toggle — not
   allergens alone. Consequence assessed at R6.
2. **Who may read it:** everyone in the household, **including anyone who joins
   later**; the consent text must say so. Consequence assessed at R3.
3. **The parent DPIA's minimisation premise:** re-confirmed on the new facts —
   per-member storage, combined-list display. §4.
4. **Sequencing:** the papers come before the code. Nothing is built until this
   document, Annex A and Annex B are approved.
5. **Export scope — decided 2026-08-12:** a member's export carries their **own**
   shared list and consent record only. Other members' shared lists stay out,
   even though the requester's client can read them live: they are health data
   about other people, and Art. 15 does not reach them. This deliberately does
   **not** follow the shared-list and conversation export precedents
   (BUT-1732/1772/1798), which govern display names and shopping rows — the
   asymmetry is the decision, per Malin's recommendation-accepted "ja".

- **Reviewed & agreed:** ☑ Malin Gisslén (controller)
- **Date:** 2026-08-12
- **Decision:** ☑ **Approved**
- **Conditions / notes:** the privacy-policy clause (Annex B) is applied to the
  shipping policy before the feature flag is switched on, not at merge time; the
  engineering attestation in §8 is filled in with the test evidence at that same
  moment. No other conditions recorded.

---

## Annex A — Consent copy (draft)

Swedish is the app's language; the English column is the `app_en.arb` mirror.
Butler voice: states the facts, no exclamation marks, no congratulation.

The quotation marks here are the SHIPPED code points (Swedish ”…”, English “…”), not
ASCII, so this annex can be compared byte-wise against the ARB — which is how a wrong
opening quote (the German low-9 „) reached the generated file once and was caught. Do not
normalise them back to `"`.

### The settings toggle

| | Svenska | English |
|---|---|---|
| Title | Dela mina allergier med hushållet | Share my allergies with the household |
| Subtitle, off | Hushållet gissar just nu åt dig | The household is guessing on your behalf |
| Subtitle, on | Hushållets meny räknar med dina allergier | The household's menu accounts for your allergies |

### The confirm dialog (shown when turning it ON)

**Title (SV):** Dela din allergilista
**Title (EN):** Share your allergy list

**Body (SV):**

> Hushållet får se vilka allergier och kostval du har angett, så att veckomenyn
> kan planeras runt dem. Idag gissar Butlery åt dig — den räknar med fyra vanliga
> allergier och missar resten.
>
> Alla som är med i hushållet ser listan, även den som går med senare.
>
> Listan visas som en gemensam lista för hela hushållet. Ingen ser vilken allergi
> som är vems.
>
> Kostval räknas som ett krav när menyn planeras: delar du ”vegansk” planeras hela
> hushållets meny vegansk.
>
> Du kan sluta dela när som helst. Då tas listan bort direkt, och menyn går
> tillbaka till att vara försiktig åt dig.

**Body (EN):**

> Your household can see the allergies and dietary choices you have entered, so
> the weekly menu can be planned around them. Today Butlery guesses on your
> behalf — it assumes four common allergies and misses the rest.
>
> Everyone in the household sees the list, including anyone who joins later.
>
> It is shown as one combined list for the whole household. Nobody sees which
> allergy belongs to whom.
>
> Dietary choices count as a requirement when the menu is planned: if you share
> “vegan”, the whole household's menu is planned vegan.
>
> You can stop sharing at any time. The list is removed immediately and the menu
> goes back to being cautious on your behalf.

**Buttons:** `Dela` / `Avbryt` (SV), `Share` / `Cancel` (EN).

### Turning it OFF

No confirm dialog — withdrawing a consent must never be harder than giving it
(Art. 7(3)). A confirmation line states what happened:

- **SV:** Din allergilista delas inte längre. Menyn är försiktig åt dig igen.
- **EN:** Your allergy list is no longer shared. The menu is cautious on your
  behalf again.

### The menu invitation (shown only to a member who has not shared)

- **SV:** Dina egna allergier delas inte — menyn gissar. **Dela**
- **EN:** Your own allergies are not shared — the menu is guessing. **Share**

---

## Annex B — Privacy-policy clause (draft)

Goes in **§5.2 "Valfria funktioner (kräver samtycke)"** of
`assets/legal/privacy_policy_sv.md` and its English twin, with the matching pair
in `docs/legal/`. Applied to the shipping policy **when the feature is switched
on**, not before — a policy that describes a feature nobody can use is its own
kind of inaccuracy. Drafted now so the text exists before the code, per decision 4.

**Svenska:**

> **Delade allergier i hushållet (om du har samtyckt):**
>
> Om du väljer att dela din allergilista med ditt hushåll får hushållets
> medlemmar — även de som går med senare — se vilka allergier och kostval du har
> angett, så att veckomenyn kan planeras runt dem. Uppgifter om allergier är
> hälsouppgifter och behandlas därför med stöd av ditt **uttryckliga samtycke
> (art. 9.2 a)**. Delningen är avstängd som standard, sker per person och kan
> återkallas när som helst; listan tas då bort omedelbart. Uppgifterna lämnar
> aldrig hushållet, delas aldrig med tredje part och ingår inte i något offentligt
> eller sammanslaget mått.

**English:**

> **Shared allergies within your household (if you have consented):**
>
> If you choose to share your allergy list with your household, its members —
> including anyone who joins later — can see the allergies and dietary choices
> you have entered, so the weekly menu can be planned around them. Allergy
> information is health data and is therefore processed on the basis of your
> **explicit consent (Art. 9(2)(a))**. Sharing is off by default, is per person,
> and can be withdrawn at any time, upon which the list is deleted immediately.
> The data never leaves your household, is never shared with third parties, and
> is not part of any public or aggregated figure.
