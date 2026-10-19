/**
 * BUT-1766 / BUT-1768: deletion cascade user subcollections scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-user-subcollections.test.ts
 */

import { FakeFirestore } from "./_account-deletion-cascade-fake-firestore";
import {
  OTHER,
  UID,
  asDb,
  check,
  emptyResult,
  finishSuite,
  sawResidual,
} from "./_account-deletion-cascade-test-seeds";

/**
 * BUT-1957: `users/{uid}/notifications`.
 *
 * Written by `analytics/detect-lapsed-users.ts` and
 * `notifications/send-activity-digest.ts`, and it carries the push text ACTUALLY
 * SHOWN (`message`/`bodyShown`) plus the win-back A/B assignment. Nothing
 * reached it — deleting `users/{uid}` does not delete its subcollections, so
 * every row survived erasure.
 *
 * The other user's row is the half that says this is a sweep and not a
 * collection wipe; `deleteUserSubcollections` reads through the user document,
 * so a mutant swapping the uid would still empty the target and only this
 * assertion would notice.
 */
async function scenario_userNotificationRowsAreErased(): Promise<void> {
  const {
    deleteUserSubcollections,
  } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set(`users/${UID}`, { displayName: "Raderad" });
  db.set(`users/${UID}/notifications/n1`, {
    message: "Vi saknar dig i köket!",
    variant: "winback_b",
    contextKey: "lapsed_14d",
  });
  db.set(`users/${UID}/notifications/n2`, { bodyShown: "3 nya recept" });
  db.set(`users/${OTHER}/notifications/n3`, { message: "Hej igen" });

  const ok = await deleteUserSubcollections(asDb(db), UID);
  check("deleteUserSubcollections reports success", ok === true, `returned ${ok}`);
  check(
    "every users/{uid}/notifications row is erased",
    db.pathsUnder(`users/${UID}/notifications`).length === 0,
    `left: ${JSON.stringify(db.pathsUnder(`users/${UID}/notifications`))}`,
  );
  check(
    "…and another user's notification rows are untouched",
    db.has(`users/${OTHER}/notifications/n3`),
    "the other user's row was swept too",
  );
}

/**
 * BUT-1956: `analytics/notifications/effectiveness`, written daily by
 * `analytics/correlate-notifications.ts` with a RAW `userId`. It was reached by
 * no cascade step, no `onUserDeleted` leg and no TTL.
 */
async function scenario_notificationEffectivenessRowsAreErased(): Promise<void> {
  const {
    deleteNotificationEffectiveness,
  } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set("analytics/notifications/effectiveness/e1", {
    userId: UID,
    opened: true,
  });
  db.set("analytics/notifications/effectiveness/e2", {
    userId: UID,
    opened: false,
  });
  db.set("analytics/notifications/effectiveness/e3", { userId: OTHER });

  const ok = await deleteNotificationEffectiveness(asDb(db), UID);
  check(
    "deleteNotificationEffectiveness reports success",
    ok === true,
    `returned ${ok}`,
  );
  check(
    "the erased user's effectiveness rows are gone",
    !db.has("analytics/notifications/effectiveness/e1") &&
      !db.has("analytics/notifications/effectiveness/e2"),
    "at least one row survived",
  );
  check(
    "…and another user's effectiveness row survives",
    db.has("analytics/notifications/effectiveness/e3"),
    "the sweep was not keyed on userId",
  );
}

/**
 * The `listCollections()` leg of `probeResidualData` (BUT-1957).
 *
 * The leg it replaced was a hand-written include-list naming ONE subcollection,
 * so anything absent from it was not merely unreported — it was invisible, and
 * the cascade returned an all-clear with the rows still on disk. This asserts
 * the enumeration reports what the database actually holds.
 *
 * The clean control is not decoration: the probe's outer catch fails CLOSED, so
 * a fake missing `listCollections()` would count residual on every fixture and
 * make the dirty case pass for the wrong reason.
 */
async function scenario_probeEnumeratesUserSubcollections(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const clean = new FakeFirestore();
  clean.set(`users/${OTHER}/notifications/n3`, { message: "Hej igen" });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "a user with no subcollection rows left probes CLEAN",
    !sawResidual(cleanResult),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const dirty = new FakeFirestore();
  dirty.set(`users/${UID}/notifications/n1`, { message: "Vi saknar dig" });
  const dirtyResult = emptyResult();
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "a leftover users/{uid}/notifications row is reported as residual",
    sawResidual(dirtyResult),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );

  // The enumeration's whole point is that it is NOT a list: a subcollection no
  // deleter and no test ever named must still be reported. A fixture using the
  // name the ticket fixed would pass equally well against a two-name include
  // list, which is the state this leg replaced.
  const unknown = new FakeFirestore();
  unknown.set(`users/${UID}/a_subcollection_nobody_listed/x`, { secret: 1 });
  const unknownResult = emptyResult();
  await probeResidualData(asDb(unknown), UID, unknownResult);
  check(
    "…and so is a subcollection no deleter has ever heard of",
    sawResidual(unknownResult),
    `failed: ${JSON.stringify(unknownResult.failedCollections)}`,
  );
}

/**
 * The two exclusions are load-bearing in the OTHER direction (BUT-1957).
 *
 * `notificationCounters` and `recentContentHashes` belong to `onUserDeleted`
 * (`cleanupContentGuardSubcollections`), which runs AFTER
 * `admin.auth().deleteUser(uid)` — so this probe, which runs before it, always
 * sees them still populated. Without the exclusion every single deletion of claim-lint:ok moved unchanged, BUT-2113
 * every user would report residual and `gdprCompliant` would be false forever,
 * with nothing able to clear it.
 *
 * That failure mode is invisible to every other test in this file: they seed no
 * guard rows, so the exclusion is never exercised and deleting it stays green.
 */
async function scenario_probeExcludesTriggerOwnedSubcollections(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set(`users/${UID}/notificationCounters/2026-09-02`, { count: 4 });
  db.set(`users/${UID}/recentContentHashes/abc123`, { hash: "abc123" });
  const result = emptyResult();
  await probeResidualData(asDb(db), UID, result);
  check(
    "the two trigger-owned subcollections are NOT residual — they outlive this probe by design",
    !sawResidual(result),
    `failed: ${JSON.stringify(result.failedCollections)}`,
  );

  // The pair is exercised one at a time as well: an exclusion set that lost a
  // single entry would still be caught by the case above, but the message would
  // not say which, and a mutant dropping only one would be attributed to both.
  for (const name of ["notificationCounters", "recentContentHashes"]) {
    const single = new FakeFirestore();
    single.set(`users/${UID}/${name}/row`, { v: 1 });
    const singleResult = emptyResult();
    await probeResidualData(asDb(single), UID, singleResult);
    check(
      `…including ${name} on its own`,
      !sawResidual(singleResult),
      `failed: ${JSON.stringify(singleResult.failedCollections)}`,
    );
  }
}

/**
 * `users/{uid}/settings` must be erased as a COLLECTION, not as one document id.
 *
 * `deleteUserPreferences` used to delete `settings/preferences` by id while
 * `probeResidualData` counts the collection. `firestore.rules` leaves the id
 * unconstrained on an owner-only create, so a second document under `settings`
 * was both an un-erased Art. 17 residual and a `gdprCompliant: false` no code
 * path could clear.
 *
 * The pre-existing coverage-map case seeds `settings/preferences` and therefore
 * passes either way — it is the seeded id that made it green, not the deleter's
 * scope. This case is the one that can tell them apart.
 */
async function scenario_settingsIsErasedAsACollectionNotOneDocument(): Promise<void> {
  const {
    deleteUserPreferences,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set(`users/${UID}/settings/preferences`, { theme: "dark" });
  db.set(`users/${UID}/settings/somethingElse`, { v: 1 });
  db.set(`users/${OTHER}/settings/preferences`, { theme: "light" });

  await deleteUserPreferences(asDb(db), UID);

  check(
    "deleteUserPreferences erases a settings document that is NOT `preferences`",
    db.get(`users/${UID}/settings/somethingElse`) === undefined,
    "a second settings document survived the cascade",
  );
  check(
    "…and `preferences` itself, as before",
    db.get(`users/${UID}/settings/preferences`) === undefined,
    "the original settings document survived",
  );
  check(
    "…and another user's settings are untouched",
    db.get(`users/${OTHER}/settings/preferences`) !== undefined,
    "the other user's settings were erased too",
  );

  const result = emptyResult();
  await probeResidualData(asDb(db), UID, result);
  check(
    "…so the enumerating probe reports no residual settings",
    !sawResidual(result),
    `failed: ${JSON.stringify(result.failedCollections)}`,
  );
}

/**
 * The `users/{uid}` subcollections BUT-1957 added to `subs` that have no tier
 * step of their own.
 *
 * Some are written today and were simply never erased; others are names only
 * `admin/reset-user-data.ts` still mentions, where a row can predate their
 * removal. That distinction does not matter here, and that is the point: the
 * probe asks the database what is left instead of consulting a list, so a row
 * under ANY of these names would be reported as residual on every deletion of
 * that account with nothing able to erase it — a `gdprCompliant` that is false
 * forever and unclearable.
 *
 * The invariant this pins is DELETER ⊇ PROBE. Without it the two disagree, and
 * the direction they disagree in is the one that cannot be recovered from.
 *
 * Seeded through the whole cascade rather than the probe alone, because the
 * claim is about the two halves agreeing, not about either one on its own.
 */
async function scenario_steplessSubcollectionsAreErasedNotJustReported(): Promise<void> {
  const {
    deleteUserSubcollections,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  // `notifications` is absent: it has its own scenario above.
  const NO_OWN_STEP = [
    // written today
    "onboarding",
    "ingredients",
    "rate_limits",
    "counters",
    // P5-U26b: overwritten week menus and own recipes kept 30 days behind
    // "Återställ". The TTL policy removes them after 30 days; an account
    // deletion must erase them at once.
    "overwritten_versions",
    // BUT-907: own deleted recipes kept 30 days in the trash. The TTL policy
    // removes them after 30 days; an account deletion must erase them at once.
    "trash",
    // no live writer found; rows can predate their removal
    "category_memberships",
    "connection_tests",
    "unified_recipes",
    "conversations",
    "fcm_tokens",
    // BUT-1850 removed the writer, the model, the rules block and the export
    // section. The `subs` entry stays: rows written before that removal are
    // reached by nothing else, and the probe enumerates.
    "conversation_memberships",
    // BUT-2040. Measured in production, not inferred: the reset script's dry
    // run counted 5 rows under this pre-rename spelling on 2026-09-07, while
    // the deleter's list named only `rate_limits`. The probe enumerates, so
    // such an account's deletion reports itself incomplete with nothing able
    // to clear it.
    "rateLimits",
  ];

  for (const name of NO_OWN_STEP) {
    const db = new FakeFirestore();
    db.set(`users/${UID}/${name}/legacy-row`, { v: 1 });
    db.set(`users/${OTHER}/${name}/legacy-row`, { v: 1 });

    await deleteUserSubcollections(asDb(db), UID);

    const result = emptyResult();
    await probeResidualData(asDb(db), UID, result);
    check(
      `a ${name} row is erased, so the enumerating probe reports nothing`,
      !sawResidual(result),
      `failed: ${JSON.stringify(result.failedCollections)}`,
    );
    check(
      `…and another user's ${name} row survives`,
      db.get(`users/${OTHER}/${name}/legacy-row`) !== undefined,
      "the other user's legacy row was erased too",
    );
  }
}

/**
 * The `analytics/notifications/effectiveness` leg of the probe (BUT-1956).
 *
 * A deleter without a probe leg is how this class of gap survives: `batchDeleteAll`
 * commits `strict: false`, so a failed chunk is swallowed and
 * `deleteNotificationEffectiveness` returns true over rows it did not remove.
 * This leg is the only contradiction to that `return true`. claim-lint:ok moved unchanged, BUT-2113
 */
async function scenario_probeSeesLeftoverNotificationEffectiveness(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const clean = new FakeFirestore();
  clean.set("analytics/notifications/effectiveness/e3", { userId: OTHER });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "another user's effectiveness row is not this user's residual",
    !sawResidual(cleanResult),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const dirty = new FakeFirestore();
  dirty.set("analytics/notifications/effectiveness/e1", { userId: UID });
  const dirtyResult = emptyResult();
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "a leftover notification-effectiveness row is reported as residual",
    sawResidual(dirtyResult),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );
}

/**
 * The RESURRECTION window (BUT-1956).
 *
 * `correlateNotificationEffectiveness` runs daily inside `dailyAnalytics` and
 * writes `effectiveness/{id}` rows from pages it is already holding in memory.
 * A cascade landing mid-run can therefore have a row written back AFTER the
 * deleter swept, and the deleter — which has already returned true — cannot
 * know. The probe runs later in the same cascade, so it can.
 *
 * This is the case that proves the probe is not merely a mirror of the deleter:
 * the deleter succeeded, the store was empty when it finished, and the run must
 * still come back `gdprCompliant: false`.
 */
async function scenario_effectivenessRowWrittenBackAfterTheSweep(): Promise<void> {
  const {
    deleteNotificationEffectiveness,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set("analytics/notifications/effectiveness/e1", { userId: UID });

  const ok = await deleteNotificationEffectiveness(asDb(db), UID);
  check(
    "the deleter reports success and leaves the collection clean",
    ok === true && !db.has("analytics/notifications/effectiveness/e1"),
    `returned ${ok}, remaining: ${JSON.stringify(db.pathsUnder("analytics/notifications/effectiveness"))}`,
  );

  // The daily correlation job flushing a page it read before the cascade began.
  db.set("analytics/notifications/effectiveness/e-resurrected", {
    userId: UID,
    opened: true,
  });

  const result = emptyResult();
  await probeResidualData(asDb(db), UID, result);
  check(
    "a row written back AFTER the sweep still fails the run — the probe is not a mirror of the deleter",
    sawResidual(result),
    `failed: ${JSON.stringify(result.failedCollections)}`,
  );
}

async function main(): Promise<void> {
  await scenario_userNotificationRowsAreErased();
  await scenario_notificationEffectivenessRowsAreErased();
  await scenario_probeEnumeratesUserSubcollections();
  await scenario_probeExcludesTriggerOwnedSubcollections();
  await scenario_steplessSubcollectionsAreErasedNotJustReported();
  await scenario_settingsIsErasedAsACollectionNotOneDocument();
  await scenario_probeSeesLeftoverNotificationEffectiveness();
  await scenario_effectivenessRowWrittenBackAfterTheSweep();

  finishSuite("BUT-1766/BUT-1768 deletion cascade user subcollections");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
