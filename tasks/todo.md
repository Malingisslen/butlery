# BUT-2287 + BUT-2288: shopping list and pantry edits made without a connection (2026-10-10)

Malin said "kör" on 2026-10-10 (thread "Runda 8 i backloggen"). BUT-2289 (weekly menu) is out.

## What is actually broken (measured by tracing the code, 2026-10-10)

Shopping lists and the pantry already write through Firestore's offline cache (BUT-2162 F3-1,
BUT-2140 B1). Firestore keeps an offline write on the device and sends it on reconnect, so no
edit is lost. What breaks is the wait: Firestore's write future settles only when the SERVER
acknowledges, and every personal-list and pantry write is awaited with no timeout.

- Pantry: add / edit sheet keeps spinning and stays open until the connection returns; +/-,
  remove, undo and "Återställ" show nothing until then (no optimistic update).
- Personal shopping list: remove and edit do not show; adding from a recipe never finishes;
  tick/add show at once but the call never returns.
- Shared lists already use `unawaited(... .catchError(...))` (`_mutateFromCache`, BUT-1683) and
  the menu merge does the same (`_mergeFromMemory`). Those are unchanged.

## Decision (default taken, asked on a card)

Keep Firestore's own queue for these two collections instead of moving them into the app's
Drift queue. Reasons: Firestore already persists and replays these writes; the Drift queue
would need a server-side `opId` guard (F3-2: "build the guard with the first collection where
a repeat does harm"), which is a `firestore.rules` change, blocked until #671 merges; and
BUT-2140 B1 (2026-10-08) already decided shopping stays on Firestore's cache.

## Steps

1. New helper `lib/repositories/firebase/queued_write.dart`:
   `Future<void> awaitOrLeaveQueued(Future<void> write, {required String what})`. Waits for the
   server up to a short patience (2 s). A failure inside that window is rethrown as today. If
   the server has not answered by then, it returns and leaves the write in Firestore's queue; a
   later rejection is logged.
2. Pantry (`firebase_pantry_repository.dart`): `add`, `updateFields`, `adjustQuantity`, `remove`
   go through the helper. `deleteAll` (account deletion) stays fully awaited.
3. Personal shopping list (`shopping_item_operations_module.dart`,
   `shopping_restore_operations_module.dart`): the personal-path `set`, `update` and
   `batch.commit()` calls go through the helper; `_touchPersonalListDay` too (its errors are
   already swallowed). Shared-list paths, templates, list create/delete untouched.
4. `undoPersonalMerge` (`shopping_personal_merge_module.dart`) through the helper too.

## Verification

- Unit test for the helper: answered write returns; early failure rethrows; a write that never
  answers returns after the patience; a late failure is logged, not thrown.
- An emulator test that can raise the alarm (emulator lane, real Firestore): with
  `disableNetwork()`, a pantry add + quantity change and a personal-list add + tick + remove
  each return within a few seconds and are visible from the cache; after `enableNetwork()` and
  `waitForPendingWrites()`, a server read shows every change. Import it in
  `integration_test/emulator_lane_test.dart`. Mutation check: revert the helper to a plain
  `await` and the suite must time out.
- `flutter analyze`, changed-file tests, review gates.

## Out of scope

Weekly menu (BUT-2289), shared lists, templates, `firestore.rules`.

## Summary for Malin

Utan nät sparas ändringar i inköpslistan och skafferiet redan på telefonen och skickas när
nätet kommer tillbaka, men appen väntade på servern och fastnade i en snurra. Nu väntar den
högst två sekunder och visar sedan ändringen direkt. Inga data flyttas och inga regler ändras.
