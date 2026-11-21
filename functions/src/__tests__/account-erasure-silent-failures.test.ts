/**
 * BUT-2512: a failed delete during account erasure must never be silent.
 *
 * Run with: npx ts-node src/__tests__/account-erasure-silent-failures.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import { Firestore } from "firebase-admin/firestore";
import { FakeFirestore } from "./_account-deletion-cascade-fake-firestore";
import {
  OTHER,
  UID,
  asDb,
  check,
  finishSuite,
} from "./_account-deletion-cascade-test-seeds";
import { ChunkCommitError, commitInChunks } from "../shared/batch-update";
import { runLegs } from "../account/cascade/core";
import { onlyAuthWasAlreadyGone } from "../account/account-deletion-schedule";
import {
  ERASURE_GAVE_UP_LOG,
  ERASURE_ON_DEMAND_INCOMPLETE_LOG,
  reportOnDemandOutcome,
} from "../account/erasure-alert-log";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const cascade = require("../account/account-deletion-cascade");

/**
 * A database whose N-th batch commit rejects with an error whose MESSAGE holds
 * a document path, as a real Firestore error does.
 */
function chunkDb(failOnCommit: number): {
  db: Firestore;
  committed: number[];
} {
  const committed: number[] = [];
  let commits = 0;
  const db = {
    batch: () => {
      let ops = 0;
      return {
        delete: () => {
          ops++;
        },
        commit: async () => {
          commits++;
          if (commits === failOnCommit) {
            throw Object.assign(
              new Error(`NOT_FOUND: users/${UID}/menus/x`),
              { code: 14 },
            );
          }
          committed.push(ops);
        },
      };
    },
  } as unknown as Firestore;
  return { db, committed };
}

/** The first of three chunks fails: the other two still commit, then it throws. */
async function scenario_attemptAllCommitsEveryChunkThenThrows(): Promise<void> {
  const { db, committed } = chunkDb(1);
  const items = Array.from({ length: 1100 }, (_, i) => i);
  let caught: unknown = null;
  try {
    await commitInChunks(db, items, (batch) => batch.delete({} as never), {
      label: "probe",
      strict: "attempt-all",
    });
  } catch (err) {
    caught = err;
  }
  check(
    "the chunks after the failed one are still committed",
    committed.length === 2 && committed[0] === 500 && committed[1] === 100,
    `committed: ${JSON.stringify(committed)}`,
  );
  check(
    "…and then it throws a ChunkCommitError",
    caught instanceof ChunkCommitError &&
      caught.failedChunks === 1 &&
      caught.totalChunks === 3,
    String(caught),
  );
  const message = caught instanceof Error ? caught.message : "";
  check(
    "the error names codes only, never the uid or a document path",
    message.includes("14") && !message.includes(UID) && !message.includes("/"),
    message,
  );
}

/** The default mode is unchanged: a failed chunk is still swallowed. */
async function scenario_defaultModeIsUnchanged(): Promise<void> {
  const { db, committed } = chunkDb(1);
  const queued = await commitInChunks(
    db,
    Array.from({ length: 600 }, (_, i) => i),
    (batch) => batch.delete({} as never),
    { label: "probe" },
  );
  check(
    "without the new mode a failed chunk does not throw (other callers untouched)",
    queued === 600 && committed.length === 1,
    `queued ${queued}, committed ${JSON.stringify(committed)}`,
  );
}

async function scenario_runLegsRunsEveryLegAndFailsAtTheEnd(): Promise<void> {
  const ran: string[] = [];
  const ok = await runLegs("probe", UID, [
    async () => {
      ran.push("a");
      throw new Error(`users/${UID}/x`);
    },
    async () => {
      ran.push("b");
      return false;
    },
    async () => {
      ran.push("c");
    },
  ]);
  check(
    "every leg runs after one throws and one returns false",
    JSON.stringify(ran) === '["a","b","c"]',
    JSON.stringify(ran),
  );
  check("…and the step reports failure", ok === false, `returned ${ok}`);
  check(
    "all legs succeeding reports success",
    (await runLegs("probe", UID, [async () => true, async () => undefined])) === true,
  );
}

/**
 * One subcollection's delete fails: every other subcollection and the
 * `system_rate_limits` sweep still go, and the step reports failure.
 */
async function scenario_oneFailedSubcollectionDoesNotStopTheRest(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`users/${UID}`, { displayName: "Raderad" });
  db.set(`users/${UID}/notifications/n1`, { message: "a" });
  db.set(`users/${UID}/ingredients/i1`, { name: "mjöl" });
  db.set(`system_rate_limits/${UID}_import`, { count: 1 });
  db.batchFailures.set(`users/${UID}/notifications/n1`, 14);

  const ok = await cascade.deleteUserSubcollections(asDb(db), UID);
  check("a failed subcollection delete fails the step", ok === false, `returned ${ok}`);
  check(
    "…while the subcollections after it are still deleted",
    !db.has(`users/${UID}/ingredients/i1`),
  );
  check(
    "…and the rate-limit sweep still runs",
    !db.has(`system_rate_limits/${UID}_import`),
  );
  check(
    "the row that failed is still there for the next run",
    db.has(`users/${UID}/notifications/n1`),
  );
}

/**
 * The owned live menu's delete fails: the step reports failure, the menu (still
 * owned by the erased uid) stays for the next run, and that run finishes it.
 */
async function scenario_failedOwnedRealtimeMenuIsFinishedByTheNextRun(): Promise<void> {
  const db = new FakeFirestore();
  db.set("realtime_menus/mine", { ownerId: UID, participantIds: [UID] });
  db.batchFailures.set("realtime_menus/mine", 14);

  const first = await cascade.deleteRealtimeMenus(asDb(db), UID);
  check("run 1: a failed owned-menu delete reports failure", first === false, `returned ${first}`);
  check("run 1: the menu is still there", db.has("realtime_menus/mine"));

  db.batchFailures.clear();
  const second = await cascade.deleteRealtimeMenus(asDb(db), UID);
  check("run 2: reports success", second === true, `returned ${second}`);
  check("run 2: the menu is gone", !db.has("realtime_menus/mine"));
}

/**
 * The owned share's parent delete fails after its children went: the step
 * reports failure, the parent (still naming the sharer) stays, the next run
 * deletes it.
 */
async function scenario_failedOwnedShareParentIsFinishedByTheNextRun(): Promise<void> {
  const db = new FakeFirestore();
  db.set("shared_content/owned", {
    contentType: "recipe",
    sharedByUserId: UID,
    sharedToUserIds: [UID, OTHER],
  });
  db.set("shared_content/owned/members/m1", { userId: OTHER });
  db.batchFailures.set("shared_content/owned", 14);

  const first = await cascade.removeFromSharedContent(asDb(db), UID).then(
    (value: boolean) => `returned ${value}`,
    (err: Error) => `threw ${err.name}`,
  );
  check(
    "run 1: a failed parent delete fails the step",
    first === "threw ChunkCommitError" || first === "returned false",
    first,
  );
  check("run 1: the share is still there", db.has("shared_content/owned"));

  db.batchFailures.clear();
  const second = await cascade.removeFromSharedContent(asDb(db), UID);
  check("run 2: reports success", second === true, `returned ${second}`);
  check("run 2: the share is gone", !db.has("shared_content/owned"));
}

/**
 * A personal shopping list's own delete fails (its items are already gone):
 * the step fails loudly, the list is still found by `listDocuments()`, and the
 * next run deletes it. Before BUT-2512 that parent delete was swallowed.
 */
async function scenario_failedShoppingListParentIsFinishedByTheNextRun(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`users/${UID}`, { displayName: "Raderad" });
  db.set(`users/${UID}/unified_shopping_lists/l1`, { name: "Veckohandling" });
  db.batchFailures.set(`users/${UID}/unified_shopping_lists/l1`, 14);

  const first = await cascade.deleteShoppingLists(asDb(db), UID).then(
    (value: boolean) => `returned ${value}`,
    (err: Error) => `threw ${err.message}`,
  );
  check(
    "run 1: a failed list delete fails the step",
    first.startsWith("threw") && first.includes("1 list delete leg(s) failed"),
    first,
  );
  check(
    "run 1: the list is still there",
    db.has(`users/${UID}/unified_shopping_lists/l1`),
  );

  db.batchFailures.clear();
  const second = await cascade.deleteShoppingLists(asDb(db), UID);
  check("run 2: reports success", second === true, `returned ${second}`);
  check(
    "run 2: the list is gone",
    !db.has(`users/${UID}/unified_shopping_lists/l1`),
  );
}

/**
 * The erased user's `members` row on someone else's share fails to delete:
 * the rest of the step still runs (the recipient list is still scrubbed), the
 * step reports failure, and the next run deletes the row.
 */
async function scenario_failedShareMemberRowDoesNotStopTheRest(): Promise<void> {
  const db = new FakeFirestore();
  db.set("shared_content/theirs", {
    contentType: "recipe",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, UID],
  });
  db.set(`shared_content/theirs/members/${UID}`, { userId: UID });
  db.batchFailures.set(`shared_content/theirs/members/${UID}`, 14);

  const first = await cascade.removeFromSharedContent(asDb(db), UID);
  check("run 1: a failed member-row delete reports failure", first === false, `returned ${first}`);
  check(
    "run 1: the row is still there for the next run",
    db.has(`shared_content/theirs/members/${UID}`),
  );
  check(
    "run 1: the recipient list is still scrubbed",
    !((db.get("shared_content/theirs")?.sharedToUserIds as string[] | undefined) ?? [])
      .includes(UID),
    JSON.stringify(db.get("shared_content/theirs")?.sharedToUserIds),
  );

  db.batchFailures.clear();
  const second = await cascade.removeFromSharedContent(asDb(db), UID);
  check("run 2: reports success", second === true, `returned ${second}`);
  check(
    "run 2: the row is gone",
    !db.has(`shared_content/theirs/members/${UID}`),
  );
}

/** One block direction's delete fails: the other direction still goes. */
async function scenario_failedBlockDirectionDoesNotStopTheOther(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`blocks/${UID}_${OTHER}`, { blockerId: UID, blockedId: OTHER });
  db.set(`blocks/${OTHER}_${UID}`, { blockerId: OTHER, blockedId: UID });
  db.batchFailures.set(`blocks/${UID}_${OTHER}`, 13);

  const ok = await cascade.deleteBlocks(asDb(db), UID);
  check("a failed block delete reports the step incomplete", ok === false, `returned ${ok}`);
  check("…while the other direction is still deleted", !db.has(`blocks/${OTHER}_${UID}`));
}

/** The menus subcollection's delete fails: the owned shared menus still go. */
async function scenario_failedMenuLegDoesNotStopTheRest(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`users/${UID}`, { displayName: "Raderad" });
  db.set(`users/${UID}/menus/m1`, { name: "Vecka 1" });
  db.set("menus/shared1", { sharedByUserId: UID, sharedToUserIds: [OTHER] });
  db.batchFailures.set(`users/${UID}/menus/m1`, 13);

  const ok = await cascade.deleteMenus(asDb(db), UID);
  check("a failed menu delete reports failure", ok === false, `returned ${ok}`);
  check("…while the owned shared menu is still deleted", !db.has("menus/shared1"));
}

/** The poll-vote delete fails: the poll-creator scrub still runs. */
async function scenario_failedPollVoteDeleteDoesNotStopTheCreatorScrub(): Promise<void> {
  const db = new FakeFirestore();
  db.set("messages/poll-theirs", {
    senderId: OTHER,
    metadata: { poll: { id: "p1", creatorId: OTHER, options: [] } },
  });
  db.set(`messages/poll-theirs/poll_votes/${UID}`, { voterId: UID, optionIds: [] });
  db.set("messages/poll-mine", {
    senderId: UID,
    metadata: { poll: { id: "p2", creatorId: UID, options: [] } },
  });
  db.batchFailures.set(`messages/poll-theirs/poll_votes/${UID}`, 13);

  const ok = await cascade.deletePollVotes(asDb(db), UID);
  check("a failed poll-vote delete reports the step incomplete", ok === false, `returned ${ok}`);
  const poll = (db.get("messages/poll-mine")?.metadata as { poll?: { creatorId?: unknown } })?.poll;
  check(
    "…while the creator is still scrubbed",
    poll?.creatorId === "deleted",
    `creatorId: ${JSON.stringify(poll?.creatorId)}`,
  );
}

/** One household's verdict delete fails: the next household is still erased. */
async function scenario_failedHouseholdDoesNotStopTheNext(): Promise<void> {
  const db = new FakeFirestore();
  for (const hid of ["h1", "h2"]) {
    db.set(`households/${hid}`, {
      memberUserIds: [UID, OTHER],
      members: [{ userId: UID }, { userId: OTHER }],
      memberPermissions: { [UID]: "edit", [OTHER]: "admin" },
      createdBy: OTHER,
    });
    db.set(`family_ratings/${hid}-mine`, { householdId: hid, memberId: UID });
  }
  db.batchFailures.set("family_ratings/h1-mine", 13);

  const ok = await cascade.deleteFamilyData(asDb(db), UID);
  check("a failed household reports the step incomplete", ok === false, `returned ${ok}`);
  const ids = (hid: string) => db.get(`households/${hid}`)?.memberUserIds as string[] | undefined;
  check(
    "…the failed household still names the erased user for the next run",
    ids("h1")?.includes(UID) === true,
    JSON.stringify(ids("h1")),
  );
  check(
    "…while the next household is still erased",
    ids("h2")?.includes(UID) === false && !db.has("family_ratings/h2-mine"),
    JSON.stringify(ids("h2")),
  );
}

/** The owned weekly plans' delete fails: the group-plan scrub still runs. */
async function scenario_failedOwnedWeekPlanDoesNotStopTheGroupScrub(): Promise<void> {
  const db = new FakeFirestore();
  db.set("weekly_menu_plans/w1", { userId: UID });
  db.set("group_weekly_menu_plans/g1", {
    participantUserIds: [UID, OTHER],
    lastModifiedBy: OTHER,
    memberPermissions: { [UID]: "edit", [OTHER]: "admin" },
    contributorUserIds: [UID, OTHER],
    entries: [],
  });
  db.batchFailures.set("weekly_menu_plans/w1", 13);

  const ok = await cascade.deleteWeeklyMenuPlans(asDb(db), UID);
  check("a failed owned-plan delete reports failure", ok === false, `returned ${ok}`);
  check(
    "…while the group plan no longer names the erased user",
    !((db.get("group_weekly_menu_plans/g1")?.participantUserIds as string[] | undefined) ?? [UID])
      .includes(UID),
    JSON.stringify(db.get("group_weekly_menu_plans/g1")),
  );
}

function scenario_reRunWithAuthAlreadyGone(): void {
  check(
    "a re-run whose only failure is the already-deleted Auth account counts as done",
    onlyAuthWasAlreadyGone({ failedCollections: ["auth_deletion"] }, true),
  );
  check(
    "…but not when another step also failed",
    !onlyAuthWasAlreadyGone(
      { failedCollections: ["auth_deletion", "messages"] },
      true,
    ),
  );
  check(
    "…and not when Auth was there before this run",
    !onlyAuthWasAlreadyGone({ failedCollections: ["auth_deletion"] }, false),
  );
}

/**
 * The alert policy matches the log text exactly; a reworded message would
 * silently disable it.
 */
function scenario_alertPolicyFiltersOnTheLoggedText(): void {
  const script = fs.readFileSync(
    path.join(__dirname, "../../../infrastructure/alerting/setup-gcp-alerts.sh"),
    "utf8",
  );
  for (const line of [ERASURE_GAVE_UP_LOG, ERASURE_ON_DEMAND_INCOMPLETE_LOG]) {
    check(
      `the alert filter names "${line}"`,
      script.includes(`jsonPayload.message=\\"${line}\\"`),
    );
  }
}

/** An incomplete on-demand erasure logs the alert line; a complete one does not. */
function scenario_onDemandOutcomeLogsOnlyWhenIncomplete(): void {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const functionsLogger = require("firebase-functions/logger").logger;
  const original = functionsLogger.error;
  const seen: Array<{ message: unknown; data: unknown }> = [];
  functionsLogger.error = (message: unknown, data: unknown) => {
    seen.push({ message, data });
  };
  try {
    reportOnDemandOutcome(UID, { success: true, failedCollections: [] });
    reportOnDemandOutcome(UID, { success: false, failedCollections: ["messages"] });
  } finally {
    functionsLogger.error = original;
  }
  check(
    "only the incomplete erasure logs the alert line",
    seen.length === 1 && seen[0].message === ERASURE_ON_DEMAND_INCOMPLETE_LOG,
    JSON.stringify(seen),
  );
  check(
    "…with the uid prefix only",
    !JSON.stringify(seen[0]?.data).includes(UID),
    JSON.stringify(seen[0]?.data),
  );
}

async function main(): Promise<void> {
  await scenario_attemptAllCommitsEveryChunkThenThrows();
  await scenario_defaultModeIsUnchanged();
  await scenario_runLegsRunsEveryLegAndFailsAtTheEnd();
  await scenario_oneFailedSubcollectionDoesNotStopTheRest();
  await scenario_failedOwnedRealtimeMenuIsFinishedByTheNextRun();
  await scenario_failedOwnedShareParentIsFinishedByTheNextRun();
  await scenario_failedShoppingListParentIsFinishedByTheNextRun();
  await scenario_failedShareMemberRowDoesNotStopTheRest();
  await scenario_failedBlockDirectionDoesNotStopTheOther();
  await scenario_failedMenuLegDoesNotStopTheRest();
  await scenario_failedOwnedWeekPlanDoesNotStopTheGroupScrub();
  await scenario_failedPollVoteDeleteDoesNotStopTheCreatorScrub();
  await scenario_failedHouseholdDoesNotStopTheNext();
  scenario_reRunWithAuthAlreadyGone();
  scenario_alertPolicyFiltersOnTheLoggedText();
  scenario_onDemandOutcomeLogsOnlyWhenIncomplete();

  finishSuite("BUT-2512 account erasure silent failures");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
