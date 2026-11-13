# ADR-0042: Old private "Om mig" texts are not published automatically

- **Date:** 2026-11-13
- **Status:** Escalated to Malin → decided 2026-11-13
- **Trigger:** `tasks/but-2509-plan.md` (BUT-2509)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Privacy / Data Protection Officer (GDPR), Trust & Safety / Content Moderation, Security Architect, Database Administrator / Data-layer Engineer, Codebase Archaeologist

## The disagreement
The plan moved every existing `bio` from `users/{uid}/settings/preferences` to
`public_profiles` on the owner's next profile read. Every seated role objected to that step as
written. Privacy: the text was stored privately, so publishing it without the owner acting is
a new purpose. Security: the read is cache-first, so a stale cache can overwrite a newer
public text, and the move ran before any policy sentence. Trust & Safety: the old text never
passed the profanity gate on the way to a public surface, and a minor's text would be
published. Data-layer: absence on `public_profiles` cannot tell "never set" from "cleared",
so a cleared text could come back.

## Decision
Escalated to Malin on a card in the BUT-2509 thread. Recommended: do not publish; the private
copy is deleted on the owner's next profile save (it is already invisible to the owner, so
nothing they see changes), and whoever wants the text retypes it. Alternative: publish for
adults automatically. Malin also has a card on whether under-18 accounts may have a text at
all (recommended: no).

Malin, 2026-11-13, on both cards: old private texts are not published, the private copy is
deleted on the next save; an account under 18 has no "Om mig" text.

## Stakes (per role)
- **Privacy / DPO:** no purpose change without the person acting; policy sentence first.
- **Trust & Safety:** no unfiltered or minor text on a surface every signed-in account reads.
- **Security Architect:** no write-on-read from a cache-first read.
- **Data-layer:** no resurrection of a cleared text; one shape for "no text".

## Consequence
No migration code. `saveProfile` deletes the private `bio` key; the rules cap `bio` at 160
characters and deny a minor's text; the policy sentence ships with the app.
