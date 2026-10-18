# BUT-2400: app push notifications rejected by `sendNotification` (2026-10-18)

Router tier: single (Database Administrator / Data-layer Engineer, Vendor / Procurement
Manager; matched on `functions/src/shared/notification-payload.ts`). No rules, auth or GDPR
change. `firestore.rules` is not touched.

## Cause

`sendNotification` runs every payload through `buildNotificationPayload` (BUT-641), which
throws without `route` and `notificationType`. The app's two template builders
(`NotificationContentManager.createTemplate`, `NotificationTemplate.fromStrategy`) never stamp
either, so every app-sent push is refused with `invalid-argument`. Silent pushes hit the same
check. Twin found while reading: `_handleMessageOpened` never forwards `notificationId` to the
router, so `recordNotificationOpened` never runs for a tapped push.

## Change

1. `NotificationStrategy` gets required `route`, `notificationType` and optional
   `targetIdKey` (the `additionalData` key whose value is the destination id). One method
   builds `{route, targetId, notificationType}`; both template builders and the fallback
   template spread it last, so schema wins on collision (as on the server).
2. The two inline strategies (chat message, recipe share request) become named constants so
   the drift test can see them.
3. New routes, added on both sides in the same change: `/conversation` (chat, id =
   conversationId), `/friends` (accepted request), `/group` (ping, id = groupId), `/home`
   (digest and strategies with no destination). The router opens chat, friends list and group
   detail for them.
4. Cook-snap push adds `recipeId` so it opens the recipe.
5. A batched push keeps the first item's destination only when every item shares it,
   otherwise `/home`.
6. Silent push (`member_removed`) carries the schema fields.
7. `_handleMessageOpened` forwards `notificationId`.

## Proof

- Dart test: parses `NOTIFICATION_ROUTES` out of `functions/src/shared/notification-payload.ts`,
  asserts it equals `NotificationRoutes.all`, and that every strategy in
  `NotificationStrategy.all` + `RecipeActivityStrategies.all` has a route in it and a
  non-empty `notificationType`.
- Dart test: each strategy's template data passes the server's checks (route known,
  targetId string, type non-empty) and the router opens the expected screen for each route.
- Functions tests updated for the new allowlist.
- Emulator: call `sendNotification` with a payload built by the app's template code for every
  strategy and see it accepted (no `invalid-argument`).

## Deploy

Functions first (`sendNotification`, `sendNotificationBatch`), then the app picks the routes up
in the next build. An old server would refuse the new routes, so the order matters.

## Summary for Malin

Alla pushnotiser som appen själv skickar (vänförfrågan, chatt, knuff, delat recept, matbild,
kommentarer) stoppades av servern eftersom appen inte talade om vilken sida notisen skulle
öppna. Lagningen ger varje notistyp en sida att öppna, lägger till de sidor som saknades
(chatten, vänlistan, gruppen) och ett test som larmar om appen och servern någonsin glider
isär igen.
