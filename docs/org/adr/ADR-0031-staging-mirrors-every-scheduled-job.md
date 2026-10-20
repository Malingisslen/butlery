# ADR-0031: Staging runs every scheduled job production runs

- **Date:** 2026-10-20
- **Status:** Decided (CTO priority order)
- **Trigger:** BUT-451 staging plan (`tasks/firebase-staging-plan.md`, draft PR #964)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** DevOps/SRE, Security Architect, Privacy/DPO, FinOps, QA, Codebase Archaeologist

## The disagreement
FinOps wanted the scheduled jobs paused in staging, since each Cloud Scheduler job is billed
and the free allowance is per billing account and already used by production. Privacy/DPO
and QA wanted parity: the erasure cascade and the retention sweeps are scheduled jobs, and a
staging that skips them cannot show that a change to them works, and would keep test data
longer than production does.

## Decision
Every scheduled job is deployed to staging. Priority order: legal/privacy over cost.

## Stakes (per role)
- **FinOps:** a monthly Scheduler cost for a project with no users.
- **Privacy/DPO:** staging holds Malin's real account (ADR-0032); its data must be pruned
  and erased on the same schedule as production.
- **QA:** a change to a scheduled job can only be tried where the job runs.

## Consequence
The Scheduler cost is part of staging's budget (50 kr a month, `docs/ops/staging.md`). If
staging exceeds it two months in a row, it is scaled down or deleted, not made to diverge.
