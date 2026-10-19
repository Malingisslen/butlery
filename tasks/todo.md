# BUT-2352: server check on dish creators in shared menus (2026-10-19)

Decision: Malin chose "Serverkontroll" on the card 2026-10-19 (a cloud function removes creator
names the writer was not allowed to set, after every change; the name may show for a few seconds).
Router tier for `functions/src/` and the deviation files: run `python tools/stakeholder_router.py
--json functions/src/moderation` before the commit.

## Goal beyond the ticket

Cause: rules let the sharer and any member write any `createdBy` into `menuSnapshot` dishes, and
no server check exists. Siblings: a stale whole-menu save can write back a name that
`withdrawReporterCredit` removed (BUT-2339 accepted it); this closes that too. Not covered:
`realtime_resources` and other menu collections (follow-up ticket).

## Steps

1. `functions/src/moderation/menu-dish-creator.ts` (pure): `introducedCredits(before, after,
   writerUid)` returns (dish id, createdBy, title) triples in `after` that are not in `before`
   (by presence, across categories) and not the writer's own uid; `stripCredits(snapshot, offending)`
   deletes only `createdBy` on dishes still carrying the offending triple, returns null when
   nothing changed; `MAX_CREDIT_CHECKS = 40`, triples above it are removed unchecked.
2. `report-decision.ts`: export `isPersonAuth(authType)` and use it at its own call site.
3. `functions/src/moderation/on-menu-dish-creator.ts`: `handleMenuDishCreator(event, deps)` skips
   deletes, non-menu content, non-person auth (the trigger's own write, the cascade, the withdrawal,
   every Admin SDK write) and writes without new credits. A new triple is kept only if
   `users/{createdBy}/recipes/{dish.id}` exists with the same `core.createdBy` and `core.title`,
   the writer is its owner or in `socialData.memberPermissions`, and the named person has no
   misattribution report on that menu and dish. Otherwise a transaction re-reads the menu and
   removes that `createdBy`. `onMenuDishCreatorWrite = onDocumentWrittenWithAuthContext(
   "shared_content/{contentId}", retry: true)`, exported from `functions/src/index.ts`.
4. No rules change.
5. Accepted deviations: a dated BUT-2352 entry in `.claude/rules/accepted-deviations.md` and
   `docs/architecture/ACCEPTED_DEVIATIONS.md` superseding the BUT-2339 "`createdBy` stays
   forgeable" clause; a dated note on ADR-0029.

## Verification

- Unit: `functions/src/__tests__/menu-dish-creator.test.ts` (unchanged menu, moved dish, duplicate
  id, own uid, forged uid, retitle, no id, create, garbage shapes, strip idempotent and
  concurrent-change safe, cap).
- Emulator: `functions/src/__tests__/menu-dish-creator.integration.test.ts` calling the handler
  (forged removed with other fields identical, shared recipe kept, unreadable recipe removed,
  stale re-save after withdrawal removed, writer's own kept, service account ignored, second run
  writes nothing, concurrent change left alone, non-menu ignored); registered in
  `functions/package.json` and `.github/workflows/firestore-rules.yml`.
- `npm run build`, `test:deploy-manifest`, the moderation suites touched.
- Mutation-check each keep condition.
- Deploy after merge: `deploy-firebase.yml` with `target=functions`,
  `functions_only=onMenuDishCreatorWrite`; check the log line on a test write.

## Summary for Malin

En molnfunktion kontrollerar varje ändring av en delad meny: står någon annans namn på en rätt
utan att det stämmer, tas namnet bort. Namnet får stå kvar om du själv gjort rätten, om det redan
stod där, eller om personens eget recept bekräftar det. Har någon sagt "Det här är inte min rätt"
kommer namnet inte tillbaka. Namnet kan synas några sekunder innan det tas bort.
