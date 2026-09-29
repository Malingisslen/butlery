# ADR-0023: Which collection carries live collaboration, and whose names the export keeps

- **Date:** 2026-09-29
- **Status:** Escalated to Malin
- **Trigger:** tasks/design-migration-but2151-plan.md (BUT-2151)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Security Architect, Privacy / Data Protection Officer (GDPR),
  Database Administrator / Data-layer Engineer, QA / Test Engineer, Codebase Archaeologist

## Context

`realtime_resources` has no Firestore rules, no Art. 17 leg and no Art. 15 section. Commit
4a4235aa7 (BUT-151, 2026-03-24) deleted its rules as a dead collection; the engine on top of
it survived and now carries the conflict notice, "Återställ" and the live role stream. The
legacy `realtime_recipes` / `realtime_menus` collections hold a second, unconnected record of
the same collaboration.

## Positions

- Security Architect — approve with conditions: closed key allowlist, roster changes owner
  only, state what happens to the same hole on `realtime_menus`.
- Privacy / DPO — approve with conditions: one explicit projection rule for other people's
  names; the two cited precedents disagree (conversations keep names, shared lists strip
  them); cap plus truncation signal on the new export.
- Database Administrator — approve with conditions: keep `setDocument`'s merge default;
  refuse `participants`/`participantIds` out of sync.
- QA — approve with conditions: the new rules suite registered in the CI chain; deny cases
  explicit.
- Codebase Archaeologist — the collection was declared dead once; the two systems for one
  recipe id are the real risk, not a rule.

## Escalated

1. Collection: build out `realtime_resources` (recommended), finish on the legacy pair, or
   keep both with a sync.
2. Export projection for other people's names: strip and keep uids (recommended), or keep.

## Decision

Pending — recorded here once Malin answers.
