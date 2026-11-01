# ADR-0040: Imported recipes may be shown on the profile

- **Date:** 2026-10-31
- **Status:** Escalated to Malin
- **Trigger:** kärnflöde steg 10E plan (`tasks/karnflode-steg10e-plan.md`), recipes shown on a user's public profile
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Security, DPO, Legal Counsel, Database Architect, Trust & Safety, Codebase Archaeologist

## The disagreement
Legal Counsel recommended that only recipes the user wrote by hand could be shown publicly (option A), because a web, cookbook-photo or video import is usually someone else's work. The other option let any recipe be shown, imports included.

## Decision
Escalated to Malin on a decision card, 2026-10-31. Her choice: "Allt kan bli publikt". Any recipe the owner chooses can be shown, imports included.

## Stakes (per role)
- **Legal Counsel:** copyright exposure from publishing third-party recipe text and photos to all signed-in users.

## Consequence
The profile copy carries `sourceUrl` and `sourceAuthor` when the recipe has them. A photo-import's pictures are never copied, because they may be the scanned cookbook page. The terms (1.4) make the user confirm they may share what they show, and a moderator removes a reported recipe by deleting it, which removes the copy. The setting "Nya recept är publika" still applies only to recipes written by hand.
