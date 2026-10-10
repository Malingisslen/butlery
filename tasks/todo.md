# BUT-2318 + BUT-2093: own reactions in the export, no names in a shared list copy (2026-10-10)

Malin's decisions, recorded on both Linear tickets 2026-10-10: BUT-2318 path 1 (a
callable reads with the Admin SDK and returns only `{commentId, key}` for the caller),
BUT-2093 option 1 (the `shared_content.listData` copy is written without display names).
Not touched: `firestore.rules`, `functions/src/account/account-deletion-cascade.ts`
(read and imported from only), `firestore.indexes.json`.

## Measured on `main` 7a0c99c

- Reactions are `recipe_comments/{id}.reactions.<key>` = list of uids, written only by
  `comment_reactions_system.dart` (`arrayUnion`/`arrayRemove`). The six keys are
  `COMMENT_REACTION_KEYS` in the cascade file, pinned by a functions test against
  `reactionKeys()` in the rules and `kReactionEmojis` in Dart.
- The cascade already runs `where("reactions.<key>", "array-contains", uid)` per key
  (`scrubCommentReactions`, residual probe), so the query shape is served in production
  by the automatic single-field indexes; no `fieldOverrides` exempt `recipe_comments`.
- `activity_export_manager.dart` `exportCommentLikes` says in its note that reactions are
  not included.
- `shopping_social_share_module.dart` writes `listData: listDoc.data()` verbatim.
  Nothing reads `listData` back except the export's redaction
  (`dropOtherMembersNamesInListData`); recipients read `itemCount`, `title`, `sharedBy*`.
  No rule constrains the `listData` shape.

## Steps

### BUT-2318

1. `functions/src/exports/comment-reactions.ts`: `exportCommentReactions` onCall,
   `enforceAppCheck: true`, same CORS as `exportSharedResidue`, uid from `request.auth`
   only (`request.data` never read), rate limit key `exportCommentReactions` (5/h, 10/day,
   same as `exportSharedResidue`). One query per key: `select()` (no fields, so no
   comment content is loaded), `limit(MAX_COMMENT_REACTION_SWEEP_ROWS + 1)`; above the
   cap it DECLINES with `comment-reactions-too-large` and never truncates. Response
   `{ reactions: [{commentId, key}] sorted, gdprArticle }`. Exported from index.ts.
2. Unit test `functions/src/__tests__/comment-reactions.test.ts`: unauthenticated →
   refused; `request.data` naming another uid changes nothing; rows only for the caller;
   returns ids and keys only; decline at cap+1; every key queried.
3. Dart `CommentReactionsExportManager` (shape of `SharedResidueExportManager`): section
   `comment_reactions` = `{reactions: [{comment_id, reaction}], total, note}`; an error
   returns a stable `error_code`, never aborts the bundle. Wired in `DataExportService`
   and `core_module.dart`. The `comment_likes` note drops its "not included" sentence.
4. Tests for the manager and the bundle key; existing `DataExportService` test call sites
   get the new required manager.

### BUT-2093

5. `shopping_social_share_module.dart`: write `listData` with every display name in
   `SharedShoppingListExport.nameKeysByOwnerIdKey` removed at every depth (items,
   `previous`). Uids stay (the cascade and residue export need them). That map also
   holds `ownerDisplayName`, the sender's own name: it goes too, since `sharedByDisplayName`
   on the same document carries it and is the field erasure tombstones (`on-user-deleted.ts`).
6. Test: a shared list's stored `listData` has no `*DisplayName` key on the list or any
   item; uids and item content survive; `itemCount` unchanged.

## Panel conditions (stakeholder review 2026-10-10)

Tier full-panel (router). Seated: Privacy/GDPR, Security Architect, Software Architect,
Codebase Archaeologist. Dropped: Legal Counsel (the Art. 15 text is the privacy seat's),
FinOps and Vendor (one rate-limiter entry, six projection queries), Product Manager (no
UI). All approve-with-conditions, no conflict, so no ADR. Conditions carried:

- Keys from `COMMENT_REACTION_KEYS` (import), never a copy; a test that every key is queried.
- Register `exportCommentReactions` in `RATE_LIMIT_CONFIGS`, the two pins in
  `rate-limiter-daily-cap.test.ts`, `USER_FACING` in `app-check-enforcement.test.ts`, index.ts.
- Decline/errors: fixed code, no counts or ids in the message; the Dart manager maps every
  failure (callable not deployed included) to a stable `error_code` in the section.
- The name map moves to a neutral file beside the shopping models, with a pure
  `withoutShoppingDisplayNames` stripper; the export keeps referencing the same map and
  `dropOtherMembersNamesInListData` stays for shares written before this change.
- `ACCEPTED_LARGE_FILES` row for `data_export_service.dart` gets its new count; dated
  supersession lines in both accepted-deviation files; workflow map if its marker appears.
- Nothing rewrites `listData` names on rename (`on-profile-updated.ts` does not touch it).

## Not in scope

- Shares written before this change keep their names until re-shared. The export already
  redacts other members' names from them (BUT-1798). A backfill is a production data
  write and is offered to Malin, not run.

## Verification

`npm test` for the new functions test plus `npm run build`/lint in `functions/`;
`flutter analyze`; the changed Dart tests. Review gates per `reviewGates`.
Deploy `exportCommentReactions` alone (functions_only) after merge, before the app uses it.

## Summary for Malin

När någon begär ut sina uppgifter kommer nu även emojierna de satt på andras kommentarer
med (bara vilken kommentar och vilken emoji, aldrig kommentarens text). När du delar en
inköpslista sparas kopian utan namnen på dem som lagt in, köpt eller ändrat varorna.
Gamla delningar behåller namnen tills de delas om; en engångsstädning av dem kan göras om
du vill.
