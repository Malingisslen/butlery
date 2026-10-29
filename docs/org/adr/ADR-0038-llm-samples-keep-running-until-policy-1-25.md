# ADR-0038: The existing AI sample capture keeps running until policy 1.25

- **Date:** 2026-10-29
- **Status:** Escalated to Malin
- **Trigger:** `tasks/parser-shadow-plan.md`
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy / Data Protection Officer (GDPR), Financial Controller / FinOps, Security Architect, Data / Integrations Engineer, Codebase Archaeologist

## The disagreement
`llm-sample-capture.ts` (BUT-1451) writes scrubbed recipe text and AI answers to
`llm_response_samples` with a 30-day TTL, while policy 1.24 does not mention that collection.
The DPO asked whether capture should be switched off (`system/config.llmSampleCaptureEnabled =
false`) until 1.25 is published, and named the undisclosed period an Art. 13 finding. The
alternative was to keep capturing and close the gap in 1.25.

## Decision
Escalated to Malin → capture keeps running; 1.25 describes it. Policy 1.25 is ordered first in
the plan (Step 0).

## Consequence
The Art. 13 gap remains open until 1.25 ships. The DPO's objection stands on record here.
