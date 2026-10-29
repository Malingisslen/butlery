# ADR-0037: Parser shadow sampling runs only for users with AI consent

- **Date:** 2026-10-29
- **Status:** Escalated to Malin
- **Trigger:** `tasks/parser-shadow-plan.md` (shadow comparison of the deterministic parser against the AI)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy / Data Protection Officer (GDPR), Financial Controller / FinOps, Security Architect, Data / Integrations Engineer, Codebase Archaeologist

## The disagreement
The first plan proposed legitimate interest with a right to object as the legal basis for sending
a sample of successful imports to Gemini. The DPO objected: the policy grounds AI processing on
explicit consent, and a sample from text import, which never reaches the AI today, would send
the text of users who declined AI to Vertex, under a new purpose. The other roles took no
position on the basis.

## Decision
Escalated to Malin → only users with AI consent (`ConsentPurpose.aiProcessing`) are sampled,
checked on the client and again on the server. Guests are never sampled. Accounts carry no age
field (`isMinor` exists only on diner profiles), so minors cannot be excluded beyond the 15+
sign-up limit.

## Consequence
Fewer cases than under legitimate interest. Policy 1.25 describes the sampling as part of the AI
processing the user has consented to.
