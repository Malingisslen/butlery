# ADR-0001: Butlery's single minimum age is 15

- **Date:** 2026-06-27
- **Status:** Escalated to Malin → Decided (15)
- **Trigger:** Plan "Resolve Butlery's age-gate discrepancy" (ToS/Privacy say 13, UI enforces 15, Firestore rules enforce a bypassable 13, no server-side floor / audit / COPPA runbook). First run of `/stakeholder-review`.
- **Blast-radius tier:** full-panel (high-stakes: `firestore.rules`)
- **Stakeholders seated:** Security Architect, Privacy/DPO (GDPR), Legal Counsel, Product Manager, Software Architect, Trust & Safety, FinOps, DBA, Accessibility, UX Writer, Localization, Customer Support.

## The disagreement

The panel split on **which single minimum age** to adopt — and, more importantly, on its **legal basis**:

- **Legal Counsel → 13.** 13 is the GDPR Art. 8 Swedish statutory floor for ordinary processing and matches the current ToS/Privacy text; called the UI's 15 "arbitrary, no legal basis."
- **Trust & Safety + DBA → 15.** Sweden's *Dataskyddslag* 2 kap. 4 § sets **15** for *information-society services with a social component*. Butlery has UGC (comments, sharing, groups, ratings), so 15 is legally grounded — Legal's "arbitrary" read missed the social-feature bracket.
- **Product Manager + Security → 15** on product/enforcement grounds (matches current UI; safer App-Store age-rating posture for a UGC app; one-file doc edit vs. re-deriving the whole gate).
- **Privacy, Architect, UX Writer, Localization, Accessibility, FinOps, Customer Support → either, but consistent.**

Because the conflict turns on an **interpretive reading of Swedish law** (ordinary-processing 13 vs. social-ISS 15), it was not decided by the CTO priority rubric — per the constitution, interpretive legal/privacy conflicts escalate to Malin.

## Decision

**Escalated to Malin via the review's `AskUserQuestion`. She chose 15.**

Rationale carried into the decision: Butlery's social/UGC component places it in the Dataskyddslag 15 bracket (Trust & Safety + DBA), 15 already matches the UI, and it avoids building a parental-consent flow for 13–14-year-olds. The cost is editing ToS + Privacy Policy from 13 → 15.

## Stakes (per role)

- **Legal Counsel:** wanted 13 as the statutory floor; the live three-layer inconsistency (docs 13 / UI 15 / rules 13) is an active IMY-enforcement target until collapsed to one number.
- **Trust & Safety / DBA:** 15 is the correct *social-service* threshold under Swedish law and protects minors on UGC surfaces.
- **Product Manager:** 15 is better App-Store positioning and lower churn than 13.
- **Privacy/DPO:** indifferent to the number, but a 15 floor *stricter than the 13 statutory base* must be explained in the Privacy Policy.
- **Localization:** the UI currently cites GDPR Art. 8 to justify 15 — Art. 8 does not mandate 15; that citation must be corrected to the Dataskyddslag social-ISS basis.

## Consequence

Proceed with **15** as the single floor. Conditions (see the review synthesis): align ToS + Privacy Policy + all ARB strings (incl. `authAgeConfirmation`, which currently says 13) + the Firestore rule (currently 13) to 15 **atomically**; correct the Art. 8 citation to the Dataskyddslag social-ISS basis; Privacy Policy must note why 15 (stricter than statutory 13). Advisory only — implementation happens when Malin schedules it. Enforcement mechanism is ADR-0002.
