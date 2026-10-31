# Correction log and learned aliases — Art. 30 Record

GDPR Article 30 record for `parsing_corrections`, `tag_overrides_log`,
`parse_corrections_v2` and `analytics/ingredients/learned_aliases`. Companion to
`llm-sample-retention.md`.

| | |
|---|---|
| **Purpose** | Improve how the app reads recipes: mine what users correct after a parse or an automatic allergen tag, and learn ingredient spellings from repeated corrections. |
| **Lawful basis** | Legitimate interest, Art. 6(1)(f); the user can object, Art. 21. Privacy policy 1.28, §4 row ”Rättelseloggen och förslag på stavning av ingredienser”. Malin approved the policy wording on 2026-10-31. |
| **Data: `parsing_corrections`** | Written by the app (`lib/models/parsing/parsing_correction.dart`, `toFirestore`): `id`, `recipeId`, `userId` (raw uid), `timestamp`, `source`, `domain`, `successfulTier`, `originalQuality`, the title, portions, time, ingredient and instruction corrections (string values run through `scrubPii`), `totalCorrections`, `expireAt`. |
| **Data: `tag_overrides_log`** | Written by the app (`lib/models/tagging/tag_override_log_entry.dart`): `id`, `userId` (raw uid), `recipeId`, `type`, `tag`, `direction`, `triggeringIngredients` (through `scrubPii`), `timestamp`, `expireAt`. |
| **Data: `parse_corrections_v2`** | Written by `logParseCorrection` (`functions/src/events/log-parse-correction.ts`): `correctedField`, `fromValue`, `toValue`, `sourceTier`, `promptVersion`, `domain`, `userIdHash`, `recipeIdHash` (both hashed by the client), `createdAt`, `expireAt`. |
| **Data: `learned_aliases`** | Written by `processCorrectionEvent` (`functions/src/analytics/analyze-corrections.ts`) from new `parsing_corrections` rows: `originalName` (the misspelling), `correctedName`, `ingredientId`, `status`, `userIds` (raw uids of the users who made the correction), `count`, `firstSeen`, `lastSeen`. |
| **Access** | `parsing_corrections` and `tag_overrides_log`: the owner reads, creates and deletes their own rows, admins read; updates are refused. `parse_corrections_v2`: closed to clients. `analytics/**`: admins read; writes are server-side (`firestore.rules`). |
| **Recipients** | None outside Butlery. |
| **Retention** | `parsing_corrections`, `tag_overrides_log`, `parse_corrections_v2`: 365 days from creation, through Firestore TTL on `expireAt` (`kCorrectionRetention` in `lib/models/parsing/correction_retention.dart`, `CORRECTION_RETENTION_MS` in `log-parse-correction.ts`). `learned_aliases`: no `expireAt`. |
| **Deleted** | On account deletion, the cascade steps `parsing_corrections` and `tag_overrides_log` delete the user's rows, and `learned_aliases` (`cleanUserFromLearnedAliases`, `functions/src/account/cascade/learned-aliases.ts`) removes the uid from every candidate and deletes a `pending` or `held_for_review` candidate the user was the last voter on. An `approved`, `rejected` or `revoked` candidate is kept without voters (`docs/architecture/ACCEPTED_DEVIATIONS.md`, entry of 2026-10-31). `parse_corrections_v2` carries no raw uid and is not reached by the cascade; the TTL deletes it. |
| **Art. 15** | Sections `parsing_corrections`, `tag_overrides_log` and `learned_aliases` (`functions/src/exports/erasure-residue/account-sections.ts`). The `learned_aliases` section leaves out `userIds`. `parse_corrections_v2` is not exported. |
