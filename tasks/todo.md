# BUT-2346: a deleted cook snap takes its feed event with it (2026-10-10)

Malin started this ticket from the project chat ("börja med alla dessa", 2026-10-10).
Scope: `functions/src/cleanup/cleanup-row-images.ts` and its test. Not touched:
`firestore.rules`, `firestore.indexes.json`, anything under `lib/`.

## Measured on `main` 53c037f

- `lib/services/cook_snap_service.dart` `addCookSnap` is the only writer of a `cooked`
  event (`grep ActivityEventType.cooked lib`). Its `extraData` holds `photoUrl`
  (= `snap.photoUrl`, the cover, `photoUrls.first`), `photoUrls` and `caption`. No `snapId`.
- `activity_events` documents carry `actorId` (rules require `actorId == request.auth.uid`
  on create; `ActivityEvent.toFirestore` writes no `userId`).
- `onCookSnapDeleted` (`cleanup-row-images.ts`, BUT-2337) fires on every hard delete of
  `cook_snaps/{snapId}`: the author's own delete, `onRecipeDeleted`'s cleanup, moderation
  and the account cascade. It deletes the Storage files, so the feed event's photo breaks
  and its caption stays visible to friends.
- No composite index exists on `activity_events`; two equality filters are served by the
  automatic single-field indexes (no `fieldOverrides` exempt `extraData`).

## Decision: link by cover URL, not by a new `snapId`

The ticket suggests adding `snapId` to the event first. The cover URL already links them:
it is a unique Storage download URL the event copied from the snap at write time. Matching
on it covers every event already written as well as new ones, with no client or schema
change. A `snapId` field would leave every existing event unlinked.

Delete the event rather than blank its photo fields: the event exists only because the
snap was posted, and blanking would leave the caption (the user's own text about a post
they removed) in friends' feeds.

## Steps

1. `handleCookSnapFeedEvents(db, snapId, data)`: owner = `ownerOf(data, "userId")`; the
   snap's URLs = `photoUrls` plus `photoUrl` (non-empty strings only, deduplicated,
   capped at `MAX_SNAP_URLS`). No owner or no URL → no read, no write. One query:
   `activity_events` where `actorId == owner` and `extraData.photoUrl in urls`,
   `limit(MAX_FEED_EVENTS_PER_SNAP = 10)`; keep only docs whose `type == "cooked"`;
   delete them in one batch; warn when the query returns the cap. Matching every snap
   URL rather than only the cover covers a cover reordered by a hand-rolled client (the
   app never updates a snap: no `update` on `cook_snaps` in `lib/`).
   The `actorId` filter is the guard: `extraData` is client-written, so only the snap
   owner's own events can be matched; `userId` is immutable on `cook_snaps`
   (`cannotModify(['recipeId', 'userId', 'createdAt'])`).
2. `onCookSnapDeleted` runs the feed cleanup first, catching and logging its own error
   (snapId and counts only, never URLs, captions or titles), then the photo cleanup as
   before. `deleteRecipePhotos` already catches each file's failure, so a Storage error
   cannot stop the feed half.
3. Tests in `cleanup-row-images.test.ts` with a fake Firestore that applies the filters
   by dot-path: the owner's matching event is deleted; another actor's event with the
   same URL is kept (attacker snap vs victim event); a non-`cooked` event of the owner's
   with the same URL is kept; a legacy `photoUrl`-only snap matches; a non-cover album
   URL matches; no owner / no URL / empty-string URL does nothing and reads nothing; a
   non-matching event of the owner's is kept; a Firestore failure still deletes the
   photos and a Storage failure still deletes the event.

## Stakeholder conditions (panel 2026-10-10: DPO, DBA, Security, PM, archaeologist)

- C1 `type == "cooked"` post-filter (DPO, Security).
- C2 match all snap URLs, not only the cover (DBA, DPO, PM).
- C3 small cap with a warning, one batch (DBA, Security).
- C4 logs carry no user content (DPO, Security).
- C5 the event also goes when the snap goes through recipe deletion, moderation or the
  account cascade. Intended: in each case the post it announced is gone (PM). The
  cascade's own `activity_events` step is untouched by this ticket.
- C6 `fieldOverrides` checked: none on `activity_events` or `cook_snaps` (DBA).
- C7 a feed card whose photo fails to load already shows a fallback
  (`CookSnapPhotoCarousel` `errorWidget`), covering the time before the trigger runs (PM).
- Known limit: a snap deleted before the app's fire-and-forget event write lands leaves
  that event; the trigger has already run. Accepted.
- Known limit: an event whose `extraData.photoUrl` a hand-rolled client rewrote to
  something not in the snap stays. No production measurement of old events was made, so
  the note for Malin does not promise every old post.
- Side effect (gate review): `scheduled/north-star-weekly.ts` counts `cooked` events as
  cooks and every event for active users and retention, so a deleted snap no longer
  counts as a cook once its event is gone. Put to Malin as a decision card.
- Follow-up filed: BUT-2350, the account cascade's `activity_events` step queries `userId`,
  a field events do not have. Out of scope here.

## Acceptance criteria

- AC1: deleting a cook snap deletes the owner's `cooked` event whose `extraData.photoUrl`
  is one of the snap's URLs.
- AC2: no event of another actor, and no non-`cooked` event, is ever deleted.
- AC3: a Storage failure does not keep the event, and a Firestore failure does not keep
  the photos.
- AC4: one read query per snap, bounded; no new index, no rules change.
- AC5: `onCookSnapDeleted` deployed after merge, once the deploy queue is idle.

## Verification

1. In `functions/`: `npm run build`, `npm run test:cleanup-row-images`
   (already registered in `package.json`).
2. Mutation-probe the `actorId` filter and the `type` filter (remove each; a named test
   must go red; print the failing line; restore in the same call).
3. Commit gate: cloud-functions-specialist, plus `/code-review` at high for a
   data-deleting function.
4. After merge: check no `deploy-firebase.yml` run is in progress, deploy
   `onCookSnapDeleted`, then read its logs after one real snap delete and confirm no
   `FAILED_PRECONDITION` (the fake cannot prove the query needs no index).

## What this means in plain language

När någon raderar sin matbild försvinner nu också inlägget om den i vännernas
aktivitetsflöde, i stället för att visa en trasig bild. Det gäller också inlägg från före ändringen, så länge bilden i inlägget är en av matbildens.

- Vad kan gå fel: i värsta fall blir ett inlägg kvar som i dag. Bara den egna personens
  inlägg av typen "lagade" med samma bildlänk kan tas bort.
- Ångra: ändringen backas genom att den gamla funktionen läggs ut igen. Inlägg som redan
  tagits bort kommer inte tillbaka, men de hörde till matbilder som redan var raderade.
- Inget att göra för dig. Jag hittade också ett större fel (BUT-2350): när ett konto
  raderas blir personens inlägg i flödet kvar. Det är ett eget ärende.
