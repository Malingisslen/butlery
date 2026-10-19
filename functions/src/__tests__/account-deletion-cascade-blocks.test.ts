/**
 * BUT-1766 / BUT-1768: deletion cascade blocks scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-blocks.test.ts
 */

import {
  DocData,
  FakeFirestore,
} from "./_account-deletion-cascade-fake-firestore";
import {
  OTHER,
  UID,
  asDb,
  check,
  finishSuite,
} from "./_account-deletion-cascade-test-seeds";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  deleteBlocks,
  deleteBlockMirrors,
  MAX_BLOCK_SWEEP_ROWS,
  MAX_MIRROR_SWEEP_ROWS,
} = require("../account/account-deletion-cascade");

/**
 * BUT-1917: both `blocks` legs of the residual probe.
 *
 * `deleteBlocks` sweeps through `batchDeleteAll` -> `commitInChunks(strict:
 * false)`, which swallows a failed chunk and lets the step return success — so
 * without these legs the sweep self-reports clean over rows whose document id
 * is the erased uid. They also fire when the sweep DECLINED above the cap and
 * deleted nothing, which is the state the decline deliberately leaves behind.
 *
 * One document per case, reachable by exactly ONE leg, so deleting either leg
 * from the probe list turns its case red rather than leaving both green on the
 * strength of the other.
 */
async function scenario_probeSeesLeftoverBlocks(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const emptyResult = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });

  const clean = new FakeFirestore();
  clean.set("blocks/third-uid_fourth-uid", {
    blockerId: "third-uid",
    blockedId: "fourth-uid",
  });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "blocks between other people do not make the probe fire",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const asBlocker = new FakeFirestore();
  asBlocker.set(`blocks/${UID}_${OTHER}`, {
    blockerId: UID,
    blockedId: OTHER,
  });
  const blockerResult = emptyResult();
  await probeResidualData(asDb(asBlocker), UID, blockerResult);
  check(
    "a surviving block the user MADE is reported as residual",
    blockerResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(blockerResult.failedCollections)}`,
  );

  const asBlocked = new FakeFirestore();
  asBlocked.set(`blocks/${OTHER}_${UID}`, {
    blockerId: OTHER,
    blockedId: UID,
  });
  const blockedResult = emptyResult();
  await probeResidualData(asDb(asBlocked), UID, blockedResult);
  check(
    "a surviving block made OF the user is reported too — the other leg",
    blockedResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(blockedResult.failedCollections)}`,
  );
}

/**
 * BUT-1917: the residual probe SEES a block mirror the sweep missed.
 *
 * `deleteBlockMirrors` is a cross-user sweep, so nothing under `users/{uid}`
 * can tell whether it finished. The leg uses the same collection-group index the sweep needs, so
 * a missing index surfaces here as a false alarm rather than a false all-clear.
 */
async function scenario_probeSeesLeftoverBlockMirrors(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const clean = new FakeFirestore();
  clean.set("users/fourth-uid/block_mirror/current", {
    blockedByUserIds: ["third-uid"],
  });
  const cleanResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  };
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "somebody else's mirror does not make the probe fire",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const dirty = new FakeFirestore();
  dirty.set(`users/${OTHER}/block_mirror/current`, {
    blockedByUserIds: [UID],
  });
  const dirtyResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  };
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "a mirror still naming the erased user is reported as residual",
    dirtyResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );
}

/**
 * BUT-1917: the erased uid comes out of OTHER people's block mirrors.
 *
 * Their own mirror goes with the `users/{uid}` subcollection sweep. This is the
 * cross-user half: a mirror belonging to somebody the erased user had blocked
 * still names them, and that document is a live safety control on an account
 * that continues to exist.
 *
 * `arrayRemove` rather than a rebuild, and the distinction has a test of its
 * own below: the mirror belongs to another user, so this cascade must take out
 * one entry rather than rewrite their document from its own view of `blocks`.
 */
async function scenario_blockMirrorsLoseTheErasedUid(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`users/${OTHER}/block_mirror/current`, {
    blockedByUserIds: [UID, "third-uid"],
    sourceRev: 1000,
  });
  // A mirror the erased user is not in. If the sweep were keyed on the
  // collection rather than the uid, this one would be rewritten too and no
  // assertion about the first would notice.
  db.set("users/fourth-uid/block_mirror/current", {
    blockedByUserIds: ["third-uid"],
    sourceRev: 1000,
  });

  const complete = await deleteBlockMirrors(asDb(db), UID);

  check("the mirror sweep reports itself complete", complete === true);
  const touched = (db.get(`users/${OTHER}/block_mirror/current`) ??
    {}) as DocData;
  check(
    "the erased uid is gone from another user's mirror",
    Array.isArray(touched.blockedByUserIds) &&
      !(touched.blockedByUserIds as string[]).includes(UID),
    `left: ${JSON.stringify(touched.blockedByUserIds)}`,
  );
  check(
    "…and the OTHER blocker on that same mirror survives",
    Array.isArray(touched.blockedByUserIds) &&
      (touched.blockedByUserIds as string[]).includes("third-uid"),
    "an `arrayRemove` takes one entry; a rebuild from this cascade's view " +
      "would have rewritten somebody else's document wholesale",
  );
  const untouched = (db.get("users/fourth-uid/block_mirror/current") ??
    {}) as DocData;
  check(
    "…and the sweep RAISES the mirror's revision",
    typeof touched.sourceRev === "number" && (touched.sourceRev as number) > 1000,
    `sourceRev: ${JSON.stringify(touched.sourceRev)} — without a raised stamp a ` +
      "`syncBlockMirror` rebuild that read `blocks` before the cascade deleted " +
      "them can land afterwards and put the uid straight back, because its own " +
      "guard would see no newer revision",
  );
  check(
    "a mirror not naming the erased user is untouched",
    Array.isArray(untouched.blockedByUserIds) &&
      (untouched.blockedByUserIds as string[]).length === 1,
  );
}

/**
 * BUT-1917: an implausible mirror count DECLINES and reports the step
 * incomplete, rather than sweeping a subset.
 *
 * Each of these documents belongs to a different living user, so a truncated
 * sweep would leave the erased uid inside a live safety control on an unknown
 * subset of them — with the audit row saying the erasure was clean.
 */
async function scenario_implausibleMirrorCountDeclines(): Promise<void> {
  const db = new FakeFirestore();
  for (let i = 0; i <= MAX_MIRROR_SWEEP_ROWS; i++) {
    db.set(`users/peer-${i}/block_mirror/current`, {
      blockedByUserIds: [UID],
      sourceRev: 1000,
    });
  }

  const complete = await deleteBlockMirrors(asDb(db), UID);

  check(
    "the step reports itself INCOMPLETE rather than truncating",
    complete === false,
  );
  const first = (db.get("users/peer-0/block_mirror/current") ?? {}) as DocData;
  check(
    "and nothing was half-swept",
    Array.isArray(first.blockedByUserIds) &&
      (first.blockedByUserIds as string[]).includes(UID),
  );
}

/**
 * BUT-1917: `blocks` is erased in BOTH directions.
 *
 * The collection had no server reader at all before this, so an erased
 * account's uid survived inside every block row it was party to — including in
 * the DOCUMENT ID, `{blockerId}_{blockedId}`, which is why a field projection
 * would not have been enough and the row has to go.
 *
 * The second direction is the one worth a test of its own: those rows were
 * created by OTHER living users. That is not unprecedented here —
 * `deleteOwnRosterRows` and `tryClearRoster` do it too — but it is the half a
 * reader is most likely to assume was left alone.
 */
async function scenario_blocksAreErasedInBothDirections(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`blocks/${UID}_${OTHER}`, { blockerId: UID, blockedId: OTHER });
  db.set(`blocks/${OTHER}_${UID}`, { blockerId: OTHER, blockedId: UID });
  // A block between two people who are not being erased. If the sweep were
  // keyed on the collection rather than the uid, this row would go too — and
  // no assertion about the first two could tell.
  db.set("blocks/third-uid_fourth-uid", {
    blockerId: "third-uid",
    blockedId: "fourth-uid",
  });

  const complete = await deleteBlocks(asDb(db), UID);

  check("the blocks step reports itself complete", complete === true);
  check(
    "a block the erased user MADE is gone",
    !db.has(`blocks/${UID}_${OTHER}`),
  );
  check(
    "a block another user made OF the erased user is gone too",
    !db.has(`blocks/${OTHER}_${UID}`),
    "this row was authored by someone else and names the erased uid in its " +
      "own document id",
  );
  check(
    "a block between two other people is untouched",
    db.has("blocks/third-uid_fourth-uid"),
    `left: ${JSON.stringify(db.pathsUnder("blocks"))}`,
  );
}

/**
 * BUT-1917: an implausible block count DECLINES that direction and reports the
 * step incomplete, rather than truncating.
 *
 * The `blockedId` leg is the one this really guards: any authenticated account
 * may block this user and nothing rate-limits it, so a peer chooses how many
 * rows exist. Declining is strictly less erasure for the same alarm — the audit
 * row lands `gdprCompliant: false` either way.
 *
 * The other direction must still be swept. Two independent residues; half an
 * erasure beats none as long as the step says so.
 */
async function scenario_implausibleBlockCountDeclines(): Promise<void> {
  const db = new FakeFirestore();
  // Imported, not restated as 2000: a literal here and a literal in
  // production is two copies of one number, and the read is `.limit(MAX + 1)`,
  // so `<=` seeds exactly one row past the cap.
  for (let i = 0; i <= MAX_BLOCK_SWEEP_ROWS; i++) {
    db.set(`blocks/peer-${i}_${UID}`, {
      blockerId: `peer-${i}`,
      blockedId: UID,
    });
  }
  db.set(`blocks/${UID}_${OTHER}`, { blockerId: UID, blockedId: OTHER });

  const complete = await deleteBlocks(asDb(db), UID);

  check(
    "the step reports itself INCOMPLETE rather than truncating",
    complete === false,
  );
  check(
    "the over-cap direction is left alone rather than half-erased",
    db.has(`blocks/peer-0_${UID}`),
  );

  // The over-cap direction is `blockedId`, the LAST leg the loop visits, so by
  // the time it declines the `blockerId` leg has already run. That makes this
  // fixture unable to tell `continue` from `return` — both leave identical
  // state. The mirrored case below is what pins the `continue`, and the two
  // must stay together: this one alone would read as proving independence
  // while proving loop order.
  check(
    "the other direction was swept, before the decline",
    !db.has(`blocks/${UID}_${OTHER}`),
  );
}

/**
 * BUT-1917: the mirror of the case above, and the only one that pins claim-lint:ok moved unchanged, BUT-2113
 * `continue` rather than `return`.
 *
 * Here the OVER-CAP direction is `blockerId` — the FIRST leg — so the
 * `blockedId` leg is reachable only by continuing past a declined one.
 * Swapping `continue` for `return` in `deleteBlocks` leaves the peer's block
 * standing and reddens this scenario alone.
 */
async function scenario_aDeclinedLegDoesNotStopTheOther(): Promise<void> {
  const db = new FakeFirestore();
  for (let i = 0; i <= MAX_BLOCK_SWEEP_ROWS; i++) {
    db.set(`blocks/${UID}_peer-${i}`, {
      blockerId: UID,
      blockedId: `peer-${i}`,
    });
  }
  db.set(`blocks/${OTHER}_${UID}`, { blockerId: OTHER, blockedId: UID });

  const complete = await deleteBlocks(asDb(db), UID);

  check(
    "the step still reports itself incomplete",
    complete === false,
  );
  check(
    "the declined FIRST leg is left alone",
    db.has(`blocks/${UID}_peer-0`),
  );
  check(
    "the second leg still ran — a declined leg does not abandon the rest",
    !db.has(`blocks/${OTHER}_${UID}`),
    "with `return` in place of `continue` this row survives, and the erased " +
      "uid stays on a block another user made of them",
  );
}

async function main(): Promise<void> {
  await scenario_probeSeesLeftoverBlockMirrors();
  await scenario_blockMirrorsLoseTheErasedUid();
  await scenario_implausibleMirrorCountDeclines();
  await scenario_blocksAreErasedInBothDirections();
  await scenario_probeSeesLeftoverBlocks();
  await scenario_implausibleBlockCountDeclines();
  await scenario_aDeclinedLegDoesNotStopTheOther();

  finishSuite("BUT-1766/BUT-1768 deletion cascade blocks");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
