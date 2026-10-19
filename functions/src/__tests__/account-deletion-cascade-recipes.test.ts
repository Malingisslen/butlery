/**
 * BUT-1766 / BUT-1768: deletion cascade recipes scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-recipes.test.ts
 */

import {
  DocData,
  FakeFirestore,
} from "./_account-deletion-cascade-fake-firestore";
import {
  OTHER,
  THIRD,
  UID,
  asDb,
  check,
  emptyResult,
  finishSuite,
  sawResidual,
} from "./_account-deletion-cascade-test-seeds";

/**
 * BUT-1801: the recipes leg of the residual probe.
 *
 * Until this fix, `probeResidualData` counted `recipes` as a TOP-LEVEL collection
 * filtered by a `userId` field, alongside `user_notifications` and friends. No
 * production writer puts a recipe there — every `FirestoreCollections.recipes`
 * site in `lib/` that builds a path is user-scoped (the one that does not,
 * `recipe_stats_repository`, is a `collectionGroup` read and builds none), and
 * no rule lets a client write the top-level collection — so the count returned
 * zero on every real deletion. The probe certified every erasure clean without ever looking at a
 * recipe, and would have gone on saying so if `deleteRecipes` broke.
 *
 * Note "no production writer", not "no such collection": the Admin SDK needs no
 * rule, and `request-account-deletion.integration.test.ts` plants a document
 * there deliberately to prove the cascade's top-level leg still sweeps it. An
 * earlier draft of this docstring said the collection could not exist, which is
 * the claim that briefly justified deleting that leg.
 *
 * That is the failure mode this scenario exists to make impossible to reintroduce:
 * the dirty half seeds a recipe at the ONLY path recipes live at, claim-lint:ok moved unchanged, BUT-2113
 * `users/{uid}/recipes`, and requires the probe to see it. Point the probe back at
 * the top-level collection and the dirty half goes green — which is the bug.
 *
 * The clean half runs first: a
 * stub method the probe needs but does not have would land in a per-leg catch,
 * count as residual, and make the dirty half pass for the wrong reason.
 */
async function scenario_probeSeesLeftoverRecipes(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const clean = new FakeFirestore();
  // Somebody else's recipe. If the probe were user-blind — a collection-group
  // sweep with no uid scoping, say — this is what would make it cry wolf.
  clean.set(`users/${OTHER}/recipes/r-other`, { core: { title: "Pannkakor" } });
  const cleanResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  };
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "another user's recipes do not read as residual for this user",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const dirty = new FakeFirestore();
  dirty.set(`users/${OTHER}/recipes/r-other`, { core: { title: "Pannkakor" } });
  dirty.set(`users/${UID}/recipes/r-mine`, { core: { title: "Köttbullar" } });
  const dirtyResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  };
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "one leftover recipe under users/{uid}/recipes is reported as residual data",
    dirtyResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );
}

/**
 * BUT-2272: a shared recipe of someone else's loses the erased uid from both
 * `memberPermissions` and `grants`, and every other member keeps both. The
 * erased user's own recipe is not written to. A viewer is stored as 0, which
 * `!= null` must still find.
 */
async function scenario_recipeMemberKeyIsRemoved(): Promise<void> {
  const {
    scrubRecipeMemberPermissions,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set(`users/${OTHER}/recipes/shared`, {
    core: { title: "Lasagne" },
    socialData: {
      ownerId: OTHER,
      memberPermissions: { [OTHER]: 2, [UID]: 0, [THIRD]: 1 },
      grants: { [UID]: ["direct"], [THIRD]: ["group:g1"] },
    },
  });
  db.set(`users/${THIRD}/recipes/noGrants`, {
    core: { title: "Soppa" },
    socialData: { ownerId: THIRD, memberPermissions: { [THIRD]: 2, [UID]: 1 } },
  });
  db.set(`users/${OTHER}/recipes/notShared`, {
    core: { title: "Gryta" },
    socialData: { ownerId: OTHER, memberPermissions: { [OTHER]: 2, [THIRD]: 0 } },
  });
  db.set(`users/${UID}/recipes/own`, {
    core: { title: "Min" },
    socialData: {
      ownerId: UID,
      memberPermissions: { [UID]: 2, [OTHER]: 0 },
      grants: { [OTHER]: ["direct"] },
    },
  });

  const ok = await scrubRecipeMemberPermissions(asDb(db), UID);

  const shared = db.get(`users/${OTHER}/recipes/shared`)?.socialData as
    | { memberPermissions?: DocData; grants?: DocData }
    | undefined;
  check("the recipe member scrub reports success", ok === true);
  check(
    "exactly the two other people's recipes naming the uid were written",
    JSON.stringify([...db.updatedPaths].sort()) ===
      JSON.stringify([
        `users/${OTHER}/recipes/shared`,
        `users/${THIRD}/recipes/noGrants`,
      ]),
    JSON.stringify(db.updatedPaths),
  );
  check(
    "the erased uid leaves memberPermissions and the other members stay",
    shared?.memberPermissions !== undefined &&
      !(UID in shared.memberPermissions) &&
      shared.memberPermissions[OTHER] === 2 &&
      shared.memberPermissions[THIRD] === 1,
    JSON.stringify(shared),
  );
  check(
    "the erased uid leaves grants and the other member's grant stays",
    shared?.grants !== undefined &&
      !(UID in shared.grants) &&
      JSON.stringify(shared.grants[THIRD]) === JSON.stringify(["group:g1"]),
    JSON.stringify(shared),
  );
  check(
    "the recipe itself survives",
    (db.get(`users/${OTHER}/recipes/shared`)?.core as DocData | undefined)
      ?.title === "Lasagne",
  );
  const noGrants = db.get(`users/${THIRD}/recipes/noGrants`)?.socialData as
    | DocData
    | undefined;
  check(
    "a recipe without grants loses the key and gains no grants map",
    noGrants !== undefined &&
      !(UID in (noGrants.memberPermissions as DocData)) &&
      !("grants" in noGrants),
    JSON.stringify(noGrants),
  );
  const own = db.get(`users/${UID}/recipes/own`)?.socialData as
    | { memberPermissions: DocData }
    | undefined;
  check(
    "the erased user's own recipe is left for deleteRecipes",
    own !== undefined && own.memberPermissions[UID] === 2,
    JSON.stringify(own),
  );
}

/**
 * BUT-2272: run in cascade order, `deleteRecipes` takes the user's own
 * recipes and the scrub stages no write on any of them.
 */
async function scenario_ownRecipesAreDeletedNotScrubbed(): Promise<void> {
  const {
    deleteRecipes,
    scrubRecipeMemberPermissions,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set(`users/${UID}/recipes/own`, {
    socialData: { memberPermissions: { [UID]: 2 } },
  });
  db.set(`users/${OTHER}/recipes/theirs`, {
    socialData: { memberPermissions: { [OTHER]: 2, [UID]: 0 } },
  });

  await deleteRecipes(asDb(db), UID);
  const ok = await scrubRecipeMemberPermissions(asDb(db), UID);

  check("the own recipe is deleted", !db.has(`users/${UID}/recipes/own`));
  check(
    "the scrub wrote only the other owner's recipe",
    JSON.stringify(db.updatedPaths) ===
      JSON.stringify([`users/${OTHER}/recipes/theirs`]),
    JSON.stringify(db.updatedPaths),
  );
  check("the scrub after deleteRecipes reports success", ok === true);
}

/** BUT-2272: over the cap the scrub declines and writes nothing. */
async function scenario_implausibleRecipeMemberCountDeclines(): Promise<void> {
  const {
    scrubRecipeMemberPermissions,
    MAX_RECIPE_MEMBER_SWEEP_ROWS,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  // `<=` seeds exactly one row past the cap the `.limit(MAX + 1)` read can see.
  for (let i = 0; i <= MAX_RECIPE_MEMBER_SWEEP_ROWS; i++) {
    db.set(`users/peer-${i}/recipes/r`, {
      socialData: { memberPermissions: { [`peer-${i}`]: 2, [UID]: 0 } },
    });
  }

  const ok = await scrubRecipeMemberPermissions(asDb(db), UID);

  check("the recipe member step reports itself INCOMPLETE", ok === false);
  check(
    "no recipe was written rather than a truncated sweep",
    db.updatedPaths.length === 0,
    `updated: ${db.updatedPaths.length}`,
  );
}

/** BUT-2272: exactly at the cap the scrub still runs. */
async function scenario_recipeMemberScrubRunsAtTheCap(): Promise<void> {
  const {
    scrubRecipeMemberPermissions,
    MAX_RECIPE_MEMBER_SWEEP_ROWS,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  const paths: string[] = [];
  for (let i = 0; i < MAX_RECIPE_MEMBER_SWEEP_ROWS; i++) {
    const p = `users/peer-${i}/recipes/r`;
    paths.push(p);
    db.set(p, {
      socialData: { memberPermissions: { [`peer-${i}`]: 2, [UID]: 0 } },
    });
  }

  const ok = await scrubRecipeMemberPermissions(asDb(db), UID);

  const stillKeyed = paths.filter((p) => {
    const perms = (db.get(p)?.socialData as { memberPermissions?: DocData })
      ?.memberPermissions;
    return perms === undefined || UID in perms;
  });
  check("a recipe member sweep of exactly the cap reports success", ok === true);
  check(
    "no recipe at the cap still carries the key",
    paths.length === MAX_RECIPE_MEMBER_SWEEP_ROWS && stillKeyed.length === 0,
    `still keyed: ${stillKeyed.length} of ${paths.length}`,
  );
}

/** BUT-2272: a failed chunk fails the step rather than being swallowed. */
async function scenario_failedRecipeMemberChunkFailsTheStep(): Promise<void> {
  const {
    scrubRecipeMemberPermissions,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set(`users/${OTHER}/recipes/x`, {
    socialData: { memberPermissions: { [OTHER]: 2, [UID]: 0 } },
  });
  db.batchFailures.set(`users/${OTHER}/recipes/x`, 13);

  const ok = await scrubRecipeMemberPermissions(asDb(db), UID);

  check("a rejected recipe member chunk makes the step report failure", ok === false);
  check(
    "the key is still there for the probe to find",
    (
      db.get(`users/${OTHER}/recipes/x`)?.socialData as {
        memberPermissions: DocData;
      }
    ).memberPermissions[UID] === 0,
  );
}

/**
 * BUT-2272: the probe sees a member key left on someone else's recipe, and
 * stays quiet on a recipe shared only with other people.
 */
async function scenario_probeSeesLeftoverRecipeMemberKey(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const dirty = new FakeFirestore();
  dirty.set(`users/${OTHER}/recipes/x`, {
    socialData: { memberPermissions: { [OTHER]: 2, [UID]: 0 } },
  });
  const dirtyResult = emptyResult();
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "a surviving recipe member key is reported as residual",
    sawResidual(dirtyResult),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );

  const clean = new FakeFirestore();
  clean.set(`users/${OTHER}/recipes/x`, {
    socialData: { memberPermissions: { [OTHER]: 2, [THIRD]: 0 } },
  });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "a recipe shared only with other people does not make the probe fire",
    !sawResidual(cleanResult),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );
}

async function main(): Promise<void> {
  await scenario_probeSeesLeftoverRecipes();
  await scenario_recipeMemberKeyIsRemoved();
  await scenario_ownRecipesAreDeletedNotScrubbed();
  await scenario_implausibleRecipeMemberCountDeclines();
  await scenario_recipeMemberScrubRunsAtTheCap();
  await scenario_failedRecipeMemberChunkFailsTheStep();
  await scenario_probeSeesLeftoverRecipeMemberKey();

  finishSuite("BUT-1766/BUT-1768 deletion cascade recipes");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
