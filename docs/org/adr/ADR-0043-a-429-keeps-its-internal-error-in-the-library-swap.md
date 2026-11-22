# ADR-0043: A 429 from Gemini keeps its "internal" error in the library swap

- **Date:** 2026-11-22
- **Status:** Decided (CTO priority order)
- **Trigger:** `tasks/genai-migration-plan.md` (swap `@google-cloud/vertexai` for `@google/genai`)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy / Data Protection Officer (GDPR), Security Architect, Financial Controller / FinOps, Software Architect, Vendor / Procurement Manager, Codebase Archaeologist

## The disagreement
`structureRecipe` and `ocrRecipeImage` turn an error into `resource-exhausted` only when its
message contains "rate limit"; a Gemini 429 does not, so it reaches the app as `internal`.
Security asked the swap to test the error's status instead (429 → `resource-exhausted`). The
Codebase Archaeologist warned that this changes what the app does after a 429, which ADR-001
(the app is the only retry layer) governs.

## Decision
CTO priority order, correctness of the stated scope over a hardening: the swap changes the
library and nothing the app sees, so the message check stays as it is. Mapping a 429 to
`resource-exhausted` is a separate change that must first check the app's retry behaviour
for that code.

## Stakes (per role)
- **Security Architect:** an error check that reads library message text is brittle.
- **Codebase Archaeologist:** a different callable error code changes client retries (ADR-001).

## Consequence
The 404 fallback reads the status (it already depended on the error shape); the "rate limit"
check is untouched. Advisory only.
