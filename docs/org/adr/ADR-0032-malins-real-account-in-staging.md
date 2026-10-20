# ADR-0032: Malin uses her real Google account in staging

- **Date:** 2026-10-20
- **Status:** Escalated to Malin
- **Trigger:** BUT-451 staging plan (`tasks/firebase-staging-plan.md`, draft PR #964)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** DevOps/SRE, Security Architect, Privacy/DPO, FinOps, QA, Codebase Archaeologist

## The disagreement
Privacy/DPO preferred synthetic accounts only, so staging would hold no real person's data.
Signing in with Google in the staging app needs a real Google account, and testing as
herself is what Malin wants staging for. Whether that is acceptable is an interpretive
privacy call, so it went to Malin.

## Decision
Escalated to Malin → she chose her real Google account (2026-10-20).

## Stakes (per role)
- **Privacy/DPO:** a real person's data in a second project widens where personal data is
  processed and must be recorded.
- **QA:** Google sign-in and the real sign-in flow can only be tried with a real account.

## Consequence
Staging is recorded as a place where personal data is processed (`docs/ops/staging.md`,
"Personal data in staging"). The same TTLs and erasure cascade run there (ADR-0031).
Analytics and Crashlytics are off in the staging app. Every other account is synthetic, and
no data is copied between the projects.
