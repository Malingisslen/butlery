# `analytics/ingredients/unmatched/{name}` — Art. 30 Record

GDPR Article 30 record for the unknown-ingredient tally (core-flow step 10F). Companion to
`account-subcollections-retention.md`.

| | |
|---|---|
| **Purpose** | Show an admin which ingredient names the tagger could not match, so they can be added to the ingredient database. |
| **Lawful basis** | None needed while the tally stays anonymous: no field links a name to a recipe or an account. Should that change, the basis would be legitimate interest, Art. 6(1)(f). |
| **Data** | The document id is the normalised name. Fields written by `trackUnmatchedIngredients` (`functions/src/analytics/track-unmatched-ingredients.ts`): `name`, `count`, `firstSeenDay`, `lastSeenDay`. The parent document `analytics/ingredients` holds only `skippedPiiCount`. Names that look like personal data (`looksPersonal`) are never stored. |
| **Access** | Admin read only (`match /analytics/{document=**}` in `firestore.rules`); only the server writes. `getUnmatchedIngredientStats` shows names whose `count` is at least `UNMATCHED_SHOWN_MIN_COUNT`. |
| **Deleted** | By `pruneUnmatchedIngredients`, run from the weekly `cleanupOldSystemEvents` job: a name whose `count` is below `UNMATCHED_SHOWN_MIN_COUNT` and that has not been seen for `UNMATCHED_RETENTION_DAYS`. |
| **Account deletion and Art. 15** | No cascade step and no export section: nothing in the tally is keyed to an account. A user's contribution to a `count` cannot be taken back. |
