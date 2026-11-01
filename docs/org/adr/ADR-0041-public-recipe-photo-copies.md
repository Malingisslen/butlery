# ADR-0041: The profile shows its own copies of recipe photos

- **Date:** 2026-10-31
- **Status:** Escalated to Malin
- **Trigger:** kärnflöde steg 10E plan (`tasks/karnflode-steg10e-plan.md`)
- **Blast-radius tier:** full-panel
- **Stakeholders seated:** Security, DPO, Legal Counsel, Database Architect, Trust & Safety, Codebase Archaeologist

## The disagreement
A recipe photo is a Storage download URL whose token never expires. Pointing the profile copy at it costs nothing extra, but anyone who saw the URL keeps the photo after the owner chooses "Sluta visa på profilen". A separate copy makes unpublishing stop the photo, at the price of a Storage copy per shown photo. The panel put the choice to Malin.

## Decision
Escalated to Malin on a decision card, 2026-10-31. Her choice: "Ja, egen publik bildkopia".

## Stakes (per role)
- **DPO:** what the privacy policy may say happens when a recipe stops being shown.
- **Database Architect:** Storage copies and deletes, bounded by 100 shown recipes per user and 10 photos per recipe.

## Consequence
`syncPublicRecipe` copies each of the owner's own photos to `users/{uid}/public_recipes/{recipeId}/` with a token of its own and deletes the copies the profile no longer shows. Account erasure covers the prefix through the existing `users/{uid}/` Storage delete.
