# ADR-0045: Meal-box data ships before the flows, policy text with the flows

- **Date:** 2026-11-24
- **Status:** Decided (CTO priority order)
- **Trigger:** BUT-2486 part 5 plan (`tasks/but-2486-del5-plan.md`), fridge and freezer boxes
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy / Data Protection Officer (GDPR), Security Architect, Database Administrator / Data-layer Engineer, Product Manager, Codebase Archaeologist

## The disagreement
Product Manager: the data slice (collection, rules, cascade, export, policy row) should not
reach production before Malin has approved the mockup for the new flows, since it gives no user
value alone and may need redoing. Security and Privacy: the rules and the erasure step must be
live before any app build that writes the collection, and the policy row must be published
before such a build reaches users.

## Decision
The data slice (model, repository, rules, cascade, export) ships first in its own PR and is
deployed functions-then-rules; it writes nothing on its own. The privacy-policy row moves to the
flows PR and is published before an app that writes boxes is released. Rule applied:
data-integrity and security (rules and erasure in place before writers) over velocity; the
Product Manager's redo risk is met by keeping the policy text, the only user-facing part, with
the flows.

## Also converged (conditions, not conflicts)
The Data-layer Engineer's objection to a transaction for the box count (fails offline, leaks on a
late refusal) changed the design: takes are a keyed map on the box, written in the same batch as
the week.
