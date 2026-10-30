# ADR-0035: Short links are kept 14 days

- **Date:** 2026-10-28
- **Status:** Escalated to Malin
- **Trigger:** BUT-2463, `tasks/but-2463-deep-links-gdpr-plan.md` (short links in erasure, export and retention)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy / Data Protection Officer, Security Architect, Database Administrator, Legal Counsel, Codebase Archaeologist

## The disagreement
The plan under review swept `deep_links` after 30 days. Privacy / DPO called that period
unjustified, because a link stops opening after 7 days, and asked for 7 to 14 days unless 30
was documented. Legal Counsel accepted the 30-day sweep, on condition that the policy names
the stored uid and the period. The Security Architect and the Database Administrator named no
period.

## Decision
Escalated to Malin as a card with 14, 7 and 30 days. She chose 14 days. `cleanupExpiredDeepLinks`
deletes links whose `createdAt` is older than 14 days, and privacy policy 1.23.0 states it.

## Stakes (per role)
- **Privacy / DPO:** storage limitation: keep the uid no longer than the link is useful.
- **Legal Counsel:** the period must be stated in the policy, whatever it is.

## Consequence
A link older than 14 days is gone even if someone still holds it, which costs nothing because it
stopped opening at 7. A link whose `createdAt` is not a Timestamp is reached by the account
deletion cascade only (accepted deviation, BUT-2463).
