/**
 * BUT-1766 / BUT-1768: deletion cascade own account data scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-own-account-data.test.ts
 */

import { FakeFirestore } from "./_account-deletion-cascade-fake-firestore";
import {
  OTHER,
  THIRD,
  UID,
  asDb,
  check,
  finishSuite,
} from "./_account-deletion-cascade-test-seeds";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  deleteFamilyData,
} = require("../account/account-deletion-cascade");

/**
 * BUT-2267: a household linked to the erased user's OWN group ends the way the
 * group-deleted trigger ends it — every joined member out, their shares gone —
 * and, with its owner gone too, it is torn down. Never re-pointed to a `view`
 * member. The trigger-first order is the solo path; both orders are pinned
 * end to end in group-household.integration.test.ts.
 */
async function scenario_ownedGroupHouseholdIsTornDown(): Promise<void> {
  const db = new FakeFirestore();
  const linked = {
    name: "x",
    members: [
      { userId: UID, permission: "admin" },
      { userId: OTHER, permission: "view" },
      { userId: THIRD, permission: "view" },
    ],
    memberUserIds: [UID, OTHER, THIRD],
    memberPermissions: { [UID]: "admin", [OTHER]: "view", [THIRD]: "view" },
    createdBy: UID,
    sourceGroupOwnerId: UID,
    sourceGroupId: "g1",
  };
  db.set("households/owned", linked);
  db.set("household_allergen_shares/owned_" + OTHER, { householdId: "owned" });
  db.set("household_allergen_shares/owned_" + THIRD, { householdId: "owned" });
  db.set("diner_profiles/ella", { householdId: "owned", createdBy: UID });
  // The same shape created by someone else is not a link the trigger honours,
  // so it keeps its members; only the erased uid leaves it.
  db.set("households/notOwned", { ...linked, createdBy: OTHER });
  db.set("household_allergen_shares/notOwned_" + OTHER, {
    householdId: "notOwned",
  });

  // An ordinary shared household the erased user created stays for the
  // others, as before BUT-2267.
  const { sourceGroupOwnerId: _o, sourceGroupId: _g, ...plain } = linked;
  db.set("households/plain", plain);

  await deleteFamilyData(asDb(db), UID);

  check("an unlinked shared household survives for the others",
    db.has("households/plain"));
  check("an owned group household is deleted", !db.has("households/owned"));
  check("its joined members' shares are deleted",
    !db.has("household_allergen_shares/owned_" + OTHER) &&
      !db.has("household_allergen_shares/owned_" + THIRD));
  check("its diner profile is deleted", !db.has("diner_profiles/ella"));
  const kept = db.get("households/notOwned");
  check("a household someone else created keeps its other members",
    JSON.stringify(kept?.memberUserIds) === JSON.stringify([OTHER, THIRD]) &&
      db.has("household_allergen_shares/notOwned_" + OTHER),
    JSON.stringify(kept));
  check("…and loses the erased uid from its link",
    kept !== undefined && !("sourceGroupOwnerId" in kept));
}

/**
 * BUT-1789: the per-user-per-day feature-retention rows must go, and only
 * those.
 *
 * `analytics/feature_retention/users/{uid}_{date}` held one behavioural row per
 * active day — cooked / imported / shared / meal-planned / shopped — with the
 * uid in both the id and a `userId` field, and no step, TTL or deviation entry
 * covering it. Three properties, all of which a wrong implementation gets
 * wrong in a different way:
 *
 *   - EVERY day of the deleted user goes, not just the newest (the rows
 *     accumulate for the life of the account);
 *   - another user's row on the same day survives (a prefix/`listDocuments`
 *     sweep of the whole subcollection would take it);
 *   - the `daily/{date}` aggregate survives (integer counts, no uid — the
 *     accepted residual; deleting it would destroy other people's history).
 */
async function scenario_featureRetentionRowsAreErased(): Promise<void> {
  const db = new FakeFirestore();
  const row = (uid: string, date: string) =>
    db.set(`analytics/feature_retention/users/${uid}_${date}`, {
      userId: uid,
      date,
      cooked: true,
      imported: false,
      shared: false,
      mealPlanned: false,
      shopped: true,
    });
  row(UID, "2026-04-27");
  row(UID, "2026-04-28");
  row(UID, "2026-04-29");
  row(OTHER, "2026-04-29");
  db.set("analytics/feature_retention/daily/2026-04-29", {
    date: "2026-04-29",
    dau: { cooked: 2, imported: 0, shared: 0, mealPlanned: 0, shopped: 2 },
  });

  const { deleteFeatureRetentionFlags } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  await deleteFeatureRetentionFlags(asDb(db), UID);

  const left = db.pathsUnder("analytics/feature_retention/users");
  check(
    "every feature-retention day of the deleted user is erased",
    left.every((p) => !p.includes(`/${UID}_`)),
    `left: ${JSON.stringify(left)}`,
  );
  check(
    "another user's row for the same day is untouched",
    db.has(`analytics/feature_retention/users/${OTHER}_2026-04-29`),
    `left: ${JSON.stringify(left)}`,
  );
  check(
    "the anonymous daily aggregate is kept (accepted residual)",
    db.has("analytics/feature_retention/daily/2026-04-29"),
    `daily left: ${JSON.stringify(
      db.pathsUnder("analytics/feature_retention/daily"),
    )}`,
  );
}

/**
 * BUT-1997: the per-user attribution row goes with the account; the uid-free
 * `analytics/acquisition/daily/{date}` tally it was counted into stays (the
 * BUT-1789 split).
 */
async function scenario_acquisitionTallySurvivesErasure(): Promise<void> {
  const {
    deleteUserSubcollections,
  } = require("../account/account-deletion-cascade");

  const db = new FakeFirestore();
  db.set(`users/${UID}`, { displayName: "Raderad" });
  db.set(`users/${UID}/acquisition/current`, {
    source: "instagram",
    medium: "social",
    campaign: "spring",
    countedAt: "2026-10-20T08:00:00Z",
  });
  db.set(`users/${OTHER}/acquisition/current`, { source: "google" });
  db.set("analytics/acquisition/daily/2026-10-20", {
    date: "2026-10-20",
    total: 1,
    bySource: { instagram: 1 },
  });

  const ok = await deleteUserSubcollections(asDb(db), UID);
  check("deleteUserSubcollections reports success", ok === true, `returned ${ok}`);
  check(
    "the deleted user's acquisition row is erased",
    db.pathsUnder(`users/${UID}/acquisition`).length === 0,
    `left: ${JSON.stringify(db.pathsUnder(`users/${UID}/acquisition`))}`,
  );
  check(
    "the anonymous acquisition tally is kept (accepted residual)",
    db.has("analytics/acquisition/daily/2026-10-20"),
    `daily left: ${JSON.stringify(db.pathsUnder("analytics/acquisition/daily"))}`,
  );
  check(
    "another user's acquisition row is untouched",
    db.has(`users/${OTHER}/acquisition/current`),
    "the other user's row was swept too",
  );
}

/**
 * BUT-1800. `analytics/retention/events` and `analytics/lapsed_users/events`
 * were left out of BUT-1789's scope.
 * Both carry `userId`; the second has AUTO ids, so it can only be reached by a
 * field query — a doc-id form would find nothing and look exactly like
 * "nothing to delete".
 */
async function scenario_retentionAnalyticsRowsAreErased(): Promise<void> {
  const db = new FakeFirestore();
  const retention = (uid: string, day: number) =>
    db.set(`analytics/retention/events/${uid}_d${day}`, {
      userId: uid,
      day,
      wasActive: true,
      lifecycleStage: "active",
    });
  retention(UID, 1);
  retention(UID, 7);
  retention(OTHER, 7);
  // Auto ids, exactly as `detect-lapsed-users.ts` writes them: the id says
  // nothing about the subject, so only `userId` can find these.
  db.set("analytics/lapsed_users/events/aUtOiD1", {
    userId: UID,
    daysInactive: 30,
    notificationSent: true,
  });
  db.set("analytics/lapsed_users/events/aUtOiD2", {
    userId: OTHER,
    daysInactive: 30,
    notificationSent: true,
  });

  const { deleteRetentionAnalytics } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  await deleteRetentionAnalytics(asDb(db), UID);

  const retentionLeft = db.pathsUnder("analytics/retention/events");
  check(
    "every retention event of the deleted user is erased",
    retentionLeft.every((p: string) => !p.includes(`/${UID}_`)),
    `left: ${JSON.stringify(retentionLeft)}`,
  );
  check(
    "another user's retention event for the same day is untouched",
    db.has(`analytics/retention/events/${OTHER}_d7`),
    `left: ${JSON.stringify(retentionLeft)}`,
  );

  const lapsedLeft = db.pathsUnder("analytics/lapsed_users/events");
  check(
    "the deleted user's auto-id lapsed row is erased despite its opaque id",
    !db.has("analytics/lapsed_users/events/aUtOiD1"),
    `left: ${JSON.stringify(lapsedLeft)}`,
  );
  check(
    "another user's lapsed row is untouched",
    db.has("analytics/lapsed_users/events/aUtOiD2"),
    `left: ${JSON.stringify(lapsedLeft)}`,
  );
}

/**
 * The probe leg for the two analytics parents. Without this the leg is
 * decoration: `batchDeleteAll` commits non-strict, so a swallowed chunk failure
 * leaves rows behind while `deleteRetentionAnalytics` still returns true — the
 * probe is the only thing that can contradict it. claim-lint:ok moved unchanged, BUT-2113
 *
 * Both parents separately, because a probe that catches one and misses the
 * other still certifies a bad erasure clean.
 */
async function scenario_probeSeesLeftoverRetentionAnalytics(): Promise<void> {
  const { probeResidualData, RETENTION_ANALYTICS_PARENTS } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");

  // The deleter's own list, not a copy: a third parent added to the const must
  // widen this scenario too, or the probe silently under-covers it.
  for (const parent of RETENTION_ANALYTICS_PARENTS) {
    const clean = new FakeFirestore();
    clean.set(`analytics/${parent}/events/somebodyElse`, { userId: OTHER });
    const cleanResult = {
      deletedCollections: [],
      failedCollections: [] as string[],
      errors: [],
      retained: [],
    };
    await probeResidualData(asDb(clean), UID, cleanResult);
    check(
      `another user's ${parent} row is not this user's residual`,
      !cleanResult.failedCollections.includes("residual_data_detected"),
      `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
    );

    const dirty = new FakeFirestore();
    dirty.set(`analytics/${parent}/events/mine`, { userId: UID });
    const dirtyResult = {
      deletedCollections: [],
      failedCollections: [] as string[],
      errors: [],
      retained: [],
    };
    await probeResidualData(asDb(dirty), UID, dirtyResult);
    check(
      `a leftover ${parent} row is reported as residual data`,
      dirtyResult.failedCollections.includes("residual_data_detected"),
      `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
    );
  }
}

/**
 * The "nothing to delete" case: the step must still report success. An empty
 * query is knowledge, not a failure.
 */
async function scenario_retentionAnalyticsWithNoRowsSucceeds(): Promise<void> {
  const db = new FakeFirestore();
  db.set("analytics/retention/events/someoneElse_d1", { userId: OTHER, day: 1 });

  const { deleteRetentionAnalytics } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  const ok = await deleteRetentionAnalytics(asDb(db), UID);

  check("a user with no analytics rows still reports success", ok === true, `got ${ok}`);
  check(
    "and nobody else's rows were swept",
    db.has("analytics/retention/events/someoneElse_d1"),
    "other user's row vanished",
  );
}

/**
 * BUT-2028: `ingredient_suggestions` is erased, and the probe SEES a leftover.
 *
 * Both halves in one scenario because they only mean anything together — the
 * deleter's own success value is `true` below the cap (it comes from
 * `batchDeleteAll` -> `commitInChunks(strict: false)`, which swallows a failed
 * chunk), so nothing but the probe can tell a completed sweep from a silently
 * dropped one.
 *
 * The other-user row is what makes the delete assertion non-vacuous: an
 * unfiltered sweep passes "the user's row is gone" just as easily.
 */
async function scenario_ingredientSuggestionsErasedAndProbed(): Promise<void> {
  const {
    deleteIngredientSuggestions,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set("ingredient_suggestions/mine-1", {
    userId: UID,
    ingredientName: "svartkål",
  });
  store.set("ingredient_suggestions/mine-2", {
    userId: UID,
    ingredientName: "kikärtsmjöl",
  });
  store.set("ingredient_suggestions/someone-elses", {
    userId: OTHER,
    ingredientName: "rabarber",
  });

  await deleteIngredientSuggestions(asDb(store), UID);

  check(
    "the user's own ingredient suggestions are deleted",
    !store.has("ingredient_suggestions/mine-1") &&
      !store.has("ingredient_suggestions/mine-2"),
    `left behind: ${JSON.stringify(store.idsIn("ingredient_suggestions"))}`,
  );
  check(
    "another user's suggestion survives the sweep",
    store.has("ingredient_suggestions/someone-elses"),
    "the sweep is not filtered on userId — it deleted a row it does not own",
  );

  const emptyResult = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });

  const cleanResult = emptyResult();
  await probeResidualData(asDb(store), UID, cleanResult);
  check(
    "with only another user's suggestion left, the probe stays clean",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const leftover = new FakeFirestore();
  leftover.set("ingredient_suggestions/survivor", {
    userId: UID,
    ingredientName: "svartkål",
  });
  const leftoverResult = emptyResult();
  await probeResidualData(asDb(leftover), UID, leftoverResult);
  check(
    "a surviving ingredient suggestion is reported as residual",
    leftoverResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(leftoverResult.failedCollections)}`,
  );
}

/**
 * BUT-2038: above the cap the sweep DECLINES rather than truncating.
 *
 * The direction matters and is the whole reason for the case. A truncating
 * sweep deletes what it can and returns true, so the erasure reports success
 * while rows remain. Declining returns false, which lands in
 * `failedCollections` and makes the run report `gdprCompliant: false` about
 * itself — an erasure that says it is incomplete is recoverable; one that lies
 * is not.
 *
 * Nothing is deleted on the declining path, deliberately: a partial delete plus
 * a false return would be the worst of both.
 */

async function scenario_ingredientSuggestionsDeclineAboveCap(): Promise<void> {
  const {
    deleteIngredientSuggestions,
    MAX_SUGGESTION_SWEEP_ROWS,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  // One past the cap, READ from the module rather than retyped — the constant
  // is exported for this, so the case cannot drift away from the number it is
  // about.
  const cap = MAX_SUGGESTION_SWEEP_ROWS;
  for (let i = 0; i <= cap; i++) {
    store.set(`ingredient_suggestions/mine-${i}`, {
      userId: UID,
      ingredientName: `ingrediens-${i}`,
    });
  }

  const ok = await deleteIngredientSuggestions(asDb(store), UID);

  check(
    "an implausible suggestion count is DECLINED, not truncated",
    ok === false,
    `returned ${ok}; a truncating sweep would report success with rows left`,
  );
  check(
    "and nothing is deleted on the declining path",
    store.idsIn("ingredient_suggestions").length === cap + 1,
    `rows left: ${store.idsIn("ingredient_suggestions").length} of ${cap + 1}`,
  );
}

/**
 * P5-U27b: `recipe_suggestions` names two people, and a row goes with EITHER
 * account: the ones the user suggested (`suggesterId`) and the ones made to the
 * user's recipes (`ownerId`). A row between two OTHER people survives, which is
 * what makes the delete assertions non-vacuous. The probe sees a leftover on
 * each leg.
 */
async function scenario_recipeSuggestionsErasedWithEitherAccountAndProbed(): Promise<void> {
  const {
    deleteRecipeSuggestions,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set("recipe_suggestions/i-suggested", {
    suggesterId: UID,
    ownerId: OTHER,
    recipeId: "r1",
  });
  store.set("recipe_suggestions/made-to-me", {
    suggesterId: OTHER,
    ownerId: UID,
    recipeId: "r2",
  });
  store.set("recipe_suggestions/between-others", {
    suggesterId: OTHER,
    ownerId: "third-person",
    recipeId: "r3",
  });

  const ok = await deleteRecipeSuggestions(asDb(store), UID);

  check(
    "the recipe-suggestion sweep reports success below its cap",
    ok === true,
    `returned ${ok}`,
  );
  check(
    "a suggestion the user made is deleted",
    !store.has("recipe_suggestions/i-suggested"),
    `left behind: ${JSON.stringify(store.idsIn("recipe_suggestions"))}`,
  );
  check(
    "a suggestion made to the user's recipe is deleted",
    !store.has("recipe_suggestions/made-to-me"),
    `left behind: ${JSON.stringify(store.idsIn("recipe_suggestions"))}`,
  );
  check(
    "a suggestion between two other people survives",
    store.has("recipe_suggestions/between-others"),
    "the sweep is not filtered on the two people — it deleted a row it does not own",
  );

  const emptyResult = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });
  const clean = emptyResult();
  await probeResidualData(asDb(store), UID, clean);
  check(
    "with only other people's suggestions left, the probe stays clean",
    !clean.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(clean.failedCollections)}`,
  );

  for (const field of ["suggesterId", "ownerId"]) {
    const leftover = new FakeFirestore();
    leftover.set("recipe_suggestions/survivor", {
      suggesterId: field === "suggesterId" ? UID : OTHER,
      ownerId: field === "ownerId" ? UID : OTHER,
      recipeId: "r1",
    });
    const result = emptyResult();
    await probeResidualData(asDb(leftover), UID, result);
    check(
      `a surviving recipe suggestion is reported on its ${field} leg`,
      result.failedCollections.includes("residual_data_detected"),
      `failed: ${JSON.stringify(result.failedCollections)}`,
    );
  }
}

/**
 * P5-U27b: the `ownerId` leg is filled by OTHER people's writes, so the sweep
 * has no decline cap: many suggestions made to the user's recipes cannot hold
 * the user's erasure in a failed state. It pages through both legs until they
 * are empty, and a row between two other people survives.
 */
async function scenario_recipeSuggestionsManyRowsArePagedNotDeclined(): Promise<void> {
  const {
    deleteRecipeSuggestions,
    RECIPE_SUGGESTION_SWEEP_PAGE,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  const many = RECIPE_SUGGESTION_SWEEP_PAGE * 4 + 7;
  for (let i = 0; i < many; i++) {
    store.set(`recipe_suggestions/to-me-${i}`, {
      suggesterId: OTHER,
      ownerId: UID,
      recipeId: `r-${i}`,
    });
  }
  for (let i = 0; i < RECIPE_SUGGESTION_SWEEP_PAGE + 1; i++) {
    store.set(`recipe_suggestions/i-suggested-${i}`, {
      suggesterId: UID,
      ownerId: OTHER,
      recipeId: `s-${i}`,
    });
  }
  store.set("recipe_suggestions/between-others", {
    suggesterId: OTHER,
    ownerId: "third-person",
    recipeId: "r",
  });

  const ok = await deleteRecipeSuggestions(asDb(store), UID);

  check(
    "many suggestions made to the user's recipes do not block the sweep",
    ok === true,
    `returned ${ok}; another person's writes must not fail this erasure`,
  );
  check(
    "every page is deleted, on both legs",
    store.idsIn("recipe_suggestions").length === 1 &&
      store.has("recipe_suggestions/between-others"),
    `rows left: ${JSON.stringify(store.idsIn("recipe_suggestions").slice(0, 5))}`,
  );
}

/**
 * P6-U09: `mfa_backup_codes/{uid}` and the per-account counter
 * `mfa_recovery_attempts/uid_{uid}` go with the account. The HMAC-keyed
 * per-IP counter and the global counter are not linkable to the account and
 * are left to their TTL, and another account's codes survive — which is what
 * makes the delete assertions non-vacuous. The probe sees a leftover of
 * either document.
 */
async function scenario_mfaRecoveryDataErasedAndProbed(): Promise<void> {
  const {
    deleteMfaRecoveryData,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set(`mfa_backup_codes/${UID}`, {
    codes: [{ salt: "s", hash: "h", usedAt: null }],
    createdAt: 1,
  });
  store.set(`mfa_backup_codes/${OTHER}`, {
    codes: [{ salt: "s", hash: "h", usedAt: null }],
    createdAt: 1,
  });
  store.set(`mfa_recovery_attempts/uid_${UID}`, { failures: 2 });
  store.set(`mfa_recovery_attempts/uid_${OTHER}`, { failures: 1 });
  store.set("mfa_recovery_attempts/ip_0123abcd", { failures: 3 });
  store.set("mfa_recovery_attempts/global", { failures: 9 });

  const ok = await deleteMfaRecoveryData(asDb(store), UID);

  check("the MFA recovery step reports success", ok === true, `returned ${ok}`);
  check(
    "the user's backup-code hashes are deleted",
    !store.has(`mfa_backup_codes/${UID}`),
    `left behind: ${JSON.stringify(store.idsIn("mfa_backup_codes"))}`,
  );
  check(
    "the user's per-account recovery counter is deleted",
    !store.has(`mfa_recovery_attempts/uid_${UID}`),
    `left behind: ${JSON.stringify(store.idsIn("mfa_recovery_attempts"))}`,
  );
  check(
    "another account's codes and counter survive, and so do the unlinkable counters",
    store.has(`mfa_backup_codes/${OTHER}`) &&
      store.has(`mfa_recovery_attempts/uid_${OTHER}`) &&
      store.has("mfa_recovery_attempts/ip_0123abcd") &&
      store.has("mfa_recovery_attempts/global"),
    `codes: ${JSON.stringify(store.idsIn("mfa_backup_codes"))}, ` +
      `attempts: ${JSON.stringify(store.idsIn("mfa_recovery_attempts"))}`,
  );

  const emptyResult = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });
  const clean = emptyResult();
  await probeResidualData(asDb(store), UID, clean);
  check(
    "with only other accounts' MFA rows left, the probe stays clean",
    !clean.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(clean.failedCollections)}`,
  );

  for (const path of [
    `mfa_backup_codes/${UID}`,
    `mfa_recovery_attempts/uid_${UID}`,
  ]) {
    const leftover = new FakeFirestore();
    leftover.set(path, { failures: 1 });
    const result = emptyResult();
    await probeResidualData(asDb(leftover), UID, result);
    check(
      `a surviving ${path.split("/")[0]} document is reported by the probe`,
      result.failedCollections.includes("residual_data_detected"),
      `failed: ${JSON.stringify(result.failedCollections)}`,
    );
  }
}

/**
 * BUT-920: `guest_quotas/{uid}` goes with the account; another guest's
 * document survives, which is what makes the delete assertion non-vacuous.
 * The probe stays clean with only the other document left and reports a
 * leftover of the erased user's.
 */
async function scenario_guestQuotaErasedAndProbed(): Promise<void> {
  const {
    deleteGuestQuota,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set(`guest_quotas/${UID}`, { importIds: ["a", "b"], calls: 3 });
  store.set(`guest_quotas/${OTHER}`, { importIds: ["c"], calls: 1 });

  const ok = await deleteGuestQuota(asDb(store), UID);

  check("the guest quota step reports success", ok === true, `returned ${ok}`);
  check(
    "the user's guest quota document is deleted",
    !store.has(`guest_quotas/${UID}`),
    `left behind: ${JSON.stringify(store.idsIn("guest_quotas"))}`,
  );
  check(
    "another guest's quota document survives",
    store.has(`guest_quotas/${OTHER}`),
    `left: ${JSON.stringify(store.idsIn("guest_quotas"))}`,
  );
  check(
    "re-running the step on a missing document still succeeds",
    (await deleteGuestQuota(asDb(store), UID)) === true,
    "second run did not return true",
  );

  const emptyResult = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });
  const clean = emptyResult();
  await probeResidualData(asDb(store), UID, clean);
  check(
    "with only another guest's quota left, the probe stays clean",
    !clean.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(clean.failedCollections)}`,
  );

  const leftover = new FakeFirestore();
  leftover.set(`guest_quotas/${UID}`, { importIds: ["a"], calls: 1 });
  const dirty = emptyResult();
  await probeResidualData(asDb(leftover), UID, dirty);
  check(
    "a surviving guest_quotas document is reported by the probe",
    dirty.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(dirty.failedCollections)}`,
  );
}

/**
 * BUT-1693: `household_allergen_shares` is erased by the flat `userId` field,
 * across every household id, and the probe SEES a leftover.
 *
 * The two households for the same user are the point: a sweep that looked up
 * the user's current household would delete one and leave the other. The
 * other member's share makes the delete assertion non-vacuous.
 */
async function scenario_householdAllergenSharesErasedAndProbed(): Promise<void> {
  const {
    deleteHouseholdAllergenShares,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set(`household_allergen_shares/h1_${UID}`, {
    householdId: "h1",
    userId: UID,
    trackedAllergens: ["gluten"],
  });
  store.set(`household_allergen_shares/h2_${UID}`, {
    householdId: "h2",
    userId: UID,
    trackedAllergens: ["mjölk"],
  });
  store.set(`household_allergen_shares/h1_${OTHER}`, {
    householdId: "h1",
    userId: OTHER,
    trackedAllergens: ["ägg"],
  });

  await deleteHouseholdAllergenShares(asDb(store), UID);

  check(
    "the user's shares in every household are deleted",
    !store.has(`household_allergen_shares/h1_${UID}`) &&
      !store.has(`household_allergen_shares/h2_${UID}`),
    `left behind: ${JSON.stringify(store.idsIn("household_allergen_shares"))}`,
  );
  check(
    "another member's share survives the sweep",
    store.has(`household_allergen_shares/h1_${OTHER}`),
    "the sweep is not filtered on userId — it deleted a row it does not own",
  );

  const emptyResult = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });

  const cleanResult = emptyResult();
  await probeResidualData(asDb(store), UID, cleanResult);
  check(
    "with only another member's share left, the probe stays clean",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const leftover = new FakeFirestore();
  leftover.set(`household_allergen_shares/h9_${UID}`, {
    householdId: "h9",
    userId: UID,
  });
  const leftoverResult = emptyResult();
  await probeResidualData(asDb(leftover), UID, leftoverResult);
  check(
    "a surviving household allergen share is reported as residual",
    leftoverResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(leftoverResult.failedCollections)}`,
  );
}

/**
 * BUT-2350: activity events are erased by `actorId`, the field
 * `ActivityEvent.toFirestore` writes, and the probe sees a leftover.
 */
async function scenario_activityEventsErasedByActorAndProbed(): Promise<void> {
  const {
    deleteActivityEvents,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set(`activity_events/mine1`, {
    actorId: UID,
    type: "cooked",
    recipeId: "r1",
  });
  store.set(`activity_events/mine2`, {
    actorId: UID,
    type: "recipe_shared",
    recipeId: "r2",
  });
  store.set(`activity_events/theirs`, {
    actorId: OTHER,
    type: "cooked",
    recipeId: "r3",
  });

  await deleteActivityEvents(asDb(store), UID);

  check(
    "the user's activity events are deleted",
    !store.has(`activity_events/mine1`) && !store.has(`activity_events/mine2`),
    `left behind: ${JSON.stringify(store.idsIn("activity_events"))}`,
  );
  check(
    "a friend's activity event survives the sweep",
    store.has(`activity_events/theirs`),
    "the sweep is not filtered on actorId",
  );

  const emptyResult = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });

  const cleanResult = emptyResult();
  await probeResidualData(asDb(store), UID, cleanResult);
  check(
    "with only a friend's event left, the probe stays clean",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const leftover = new FakeFirestore();
  leftover.set(`activity_events/left`, { actorId: UID, type: "cooked" });
  const leftoverResult = emptyResult();
  await probeResidualData(asDb(leftover), UID, leftoverResult);
  check(
    "a surviving activity event is reported as residual",
    leftoverResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(leftoverResult.failedCollections)}`,
  );
}

/**
 * BUT-2354: the user's shopping-list templates, public ones included, are
 * erased by `ownerId`, and the probe sees a leftover.
 */
async function scenario_shoppingListTemplatesErasedByOwnerAndProbed(): Promise<void> {
  const {
    deleteShoppingListTemplates,
    probeResidualData,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set(`shopping_list_templates/public1`, {
    ownerId: UID,
    ownerDisplayName: "Erased User",
    name: "Veckohandling",
    isPublic: true,
  });
  store.set(`shopping_list_templates/private1`, {
    ownerId: UID,
    name: "Fest",
    isPublic: false,
  });
  store.set(`shopping_list_templates/theirs`, {
    ownerId: OTHER,
    ownerDisplayName: "Someone Else",
    name: "Deras mall",
    isPublic: true,
  });

  await deleteShoppingListTemplates(asDb(store), UID);

  check(
    "the user's public and private templates are deleted",
    !store.has(`shopping_list_templates/public1`) &&
      !store.has(`shopping_list_templates/private1`),
    `left behind: ${JSON.stringify(store.idsIn("shopping_list_templates"))}`,
  );
  check(
    "another user's public template survives the sweep",
    store.has(`shopping_list_templates/theirs`),
    "the sweep is not filtered on ownerId",
  );

  const emptyResult = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });

  const cleanResult = emptyResult();
  await probeResidualData(asDb(store), UID, cleanResult);
  check(
    "with only another user's template left, the probe stays clean",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const leftover = new FakeFirestore();
  leftover.set(`shopping_list_templates/left`, {
    ownerId: UID,
    isPublic: true,
  });
  const leftoverResult = emptyResult();
  await probeResidualData(asDb(leftover), UID, leftoverResult);
  check(
    "a surviving template is reported as residual",
    leftoverResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(leftoverResult.failedCollections)}`,
  );
}

/**
 * BUT-2354: other accounts can rewrite a template's `ownerId`, so the sweep
 * pages rather than reading every row at once, and finishes past one page.
 */
async function scenario_shoppingListTemplatesArePaged(): Promise<void> {
  const {
    deleteShoppingListTemplates,
    TEMPLATE_SWEEP_PAGE,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  for (let i = 0; i < TEMPLATE_SWEEP_PAGE * 2 + 3; i++) {
    store.set(`shopping_list_templates/t-${i}`, { ownerId: UID });
  }

  const ok = await deleteShoppingListTemplates(asDb(store), UID);

  check(
    "every page of templates is deleted",
    ok === true && store.idsIn("shopping_list_templates").length === 0,
    `returned ${ok}; rows left: ${store.idsIn("shopping_list_templates").length}`,
  );
}

/**
 * BUT-1693: above the cap the sweep declines and deletes nothing.
 */
async function scenario_householdAllergenSharesDeclineAboveCap(): Promise<void> {
  const {
    deleteHouseholdAllergenShares,
    MAX_HOUSEHOLD_SHARE_SWEEP_ROWS,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  const cap = MAX_HOUSEHOLD_SHARE_SWEEP_ROWS;
  for (let i = 0; i <= cap; i++) {
    store.set(`household_allergen_shares/h${i}_${UID}`, {
      householdId: `h${i}`,
      userId: UID,
    });
  }

  const ok = await deleteHouseholdAllergenShares(asDb(store), UID);

  check("above the cap the share sweep returns false", ok === false, `returned ${ok}`);
  check(
    "above the cap nothing is deleted",
    store.idsIn("household_allergen_shares").length === cap + 1,
    `remaining: ${store.idsIn("household_allergen_shares").length}`,
  );

  const atCap = new FakeFirestore();
  for (let i = 0; i < cap; i++) {
    atCap.set(`household_allergen_shares/h${i}_${UID}`, {
      householdId: `h${i}`,
      userId: UID,
    });
  }
  const okAtCap = await deleteHouseholdAllergenShares(asDb(atCap), UID);
  check(
    "at the cap the share sweep deletes everything and returns true",
    okAtCap === true && atCap.idsIn("household_allergen_shares").length === 0,
    `returned ${okAtCap}, remaining ${atCap.idsIn("household_allergen_shares").length}`,
  );
}

async function main(): Promise<void> {
  await scenario_ownedGroupHouseholdIsTornDown();
  await scenario_featureRetentionRowsAreErased();
  await scenario_acquisitionTallySurvivesErasure();
  await scenario_retentionAnalyticsRowsAreErased();
  await scenario_retentionAnalyticsWithNoRowsSucceeds();
  await scenario_probeSeesLeftoverRetentionAnalytics();
  await scenario_ingredientSuggestionsErasedAndProbed();
  await scenario_ingredientSuggestionsDeclineAboveCap();
  await scenario_householdAllergenSharesErasedAndProbed();
  await scenario_recipeSuggestionsErasedWithEitherAccountAndProbed();
  await scenario_recipeSuggestionsManyRowsArePagedNotDeclined();
  await scenario_mfaRecoveryDataErasedAndProbed();
  await scenario_guestQuotaErasedAndProbed();
  await scenario_householdAllergenSharesDeclineAboveCap();
  await scenario_activityEventsErasedByActorAndProbed();
  await scenario_shoppingListTemplatesErasedByOwnerAndProbed();
  await scenario_shoppingListTemplatesArePaged();

  finishSuite("BUT-1766/BUT-1768 deletion cascade own account data");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
