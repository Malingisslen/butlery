# ADR-0002: Age enforcement uses a signup Cloud Function (authoritative) + a Firestore rule (gate), not one or the other

- **Date:** 2026-06-27
- **Status:** Decided (CTO priority order)
- **Trigger:** Same plan as ADR-0001 ("Resolve Butlery's age-gate discrepancy"), step (b) "enforce server-side."
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** as ADR-0001.

## The disagreement

How to enforce the age floor server-side:

- **FinOps → pure Firestore rule.** A rule reading a stored `birthYear` is zero marginal invocation cost; a Cloud Function bills per signup forever and can't be cached. Prefer the rule wherever it suffices.
- **Security Architect, Software Architect, Privacy/DPO, Trust & Safety, DBA → a Cloud Function is required.** Firestore rules cannot write an audit document, cannot gate Firebase Auth account creation, and must not trust a client-submitted `birthYear`. The critics also found two live holes: today you can skip the preferences write entirely (no rule forces it) and you can null-out `birthYear` on update.

## Decision

**Resolved by the CTO priority order (DESIGN.md): data-integrity & security (level 3) and correctness (level 4) outrank cost (level 5).** Use **both layers**:

- A **signup Cloud Function** (v2, europe-west1) is the *authoritative writer* of `birthYear` and the *only* writer of the age-enforcement audit event. Firestore rules reject any client write to `birthYear`.
- A Firestore **`isAgeCompliant()`** rule function (composed with — not merged into — the existing `isAccountMatured()` gate) is the read-time gate on user data **and on UGC write paths** (comments, groups, chat, ratings), closing the "skip preferences write" / "null-out birthYear" bypasses.

FinOps's cost concern is honored as **attached conditions, not overridden**: enforce App Check on the signup callable, rate-limit it, and **cap age-enforcement audit writes per-IP** so a bot loop can't bill unbounded writes.

## Stakes (per role)

- **FinOps:** unbounded per-signup Function cost + uncapped audit writes under bot abuse.
- **Security / Architect / DBA:** a client-trusted or rules-only design is bypassable and produces no audit trail — fails the actual security goal.
- **Privacy / Trust & Safety:** the audit trail (consent-category, 730-day retention) and UGC-path gating are the compliance evidence and the minor-protection mechanism.

## Consequence

Implement the dual-layer design with the cost caps as hard conditions. This costs one Function invocation per signup (negligible at current scale) in exchange for an enforceable, auditable gate. Advisory only — Malin decides when to build it.
