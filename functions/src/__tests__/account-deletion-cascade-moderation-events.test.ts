/**
 * BUT-1766 / BUT-1768: deletion cascade moderation events and records scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-moderation-events.test.ts
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
  finishSuite,
} from "./_account-deletion-cascade-test-seeds";

/**
 * BUT-2032: the two moderation row shapes in `system_events`, which no erasure
 * path reached until this step.
 *
 * The fixture seeds BOTH shapes plus rows belonging to other people, because a
 * sweep with no filter passes "the user's rows are gone" exactly as easily as a
 * correct one — the point `scenario_ingredientSuggestionsErasedAndProbed` makes
 * about its own control row.
 */
function seedModerationEvents(store: FakeFirestore): void {
  // The threshold alert about the erased user. Its document id IS their uid.
  store.set(`system_events/moderation_threshold_${UID}`, {
    type: "moderation_threshold_reached",
    details: { userId: UID, totalReports: 5, action: "review_required" },
  });
  // A report the erased user FILED against someone still present.
  store.set("system_events/content_report_r1", {
    type: "content_report",
    details: { reportId: "r1", reporterId: UID, contentOwnerId: OTHER },
  });
  // A report someone else filed ABOUT the erased user.
  store.set("system_events/content_report_r2", {
    type: "content_report",
    details: { reportId: "r2", reporterId: OTHER, contentOwnerId: UID },
  });
  // Controls: a report between two other people, a threshold alert about
  // somebody else, an ownerless report, and a row from a different writer.
  store.set("system_events/content_report_r3", {
    type: "content_report",
    details: { reportId: "r3", reporterId: OTHER, contentOwnerId: THIRD },
  });
  store.set(`system_events/moderation_threshold_${OTHER}`, {
    type: "moderation_threshold_reached",
    details: { userId: OTHER, totalReports: 7 },
  });
  store.set("system_events/content_report_r4", {
    type: "content_report",
    details: { reportId: "r4", reporterId: THIRD, contentOwnerId: null },
  });
  store.set("system_events/cleanup_run_1", {
    type: "audit_log_cleanup",
    totalDeleted: 12,
  });
}

async function scenario_moderationEventsAreErasedAndAnonymized(): Promise<void> {
  const {
    deleteModerationSystemEvents,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  seedModerationEvents(store);

  const complete = await deleteModerationSystemEvents(asDb(store), UID);

  check(
    "the step reports itself complete when no leg declined",
    complete === true,
    `returned ${complete}`,
  );
  check(
    "the threshold alert keyed on the erased uid is deleted",
    !store.has(`system_events/moderation_threshold_${UID}`),
    `left behind: ${JSON.stringify(store.idsIn("system_events"))}`,
  );
  check(
    "a report the erased user FILED, with no `reports` document left, is deleted",
    !store.has("system_events/content_report_r1"),
    "a missing report reads as not open, so its derived row goes",
  );
  check(
    "a report ABOUT the erased user is KEPT, not deleted",
    store.has("system_events/content_report_r2"),
    "BUT-781 mirror: the row survives, only the identifier goes",
  );
  check(
    "that kept row no longer names the erased user",
    (store.get("system_events/content_report_r2")?.details as
      | Record<string, unknown>
      | undefined)?.contentOwnerId === null,
    `details: ${JSON.stringify(store.get("system_events/content_report_r2"))}`,
  );
  check(
    "the kept row is stamped with an anonymization tombstone",
    store.get("system_events/content_report_r2")?.contentOwnerAnonymizedAt !==
      undefined,
    `row: ${JSON.stringify(store.get("system_events/content_report_r2"))}`,
  );
  check(
    "the kept row keeps the OTHER party's identifier",
    (store.get("system_events/content_report_r2")?.details as
      | Record<string, unknown>
      | undefined)?.reporterId === OTHER,
    "the anonymization widened past the field it was aimed at",
  );

  // The four controls. Each one dies alone: an unfiltered delete kills the
  // first three, and an anonymize that matches on absence kills the fourth.
  check(
    "a report between two other people is untouched",
    store.has("system_events/content_report_r3") &&
      (store.get("system_events/content_report_r3")?.details as
        | Record<string, unknown>
        | undefined)?.contentOwnerId === THIRD,
    `row: ${JSON.stringify(store.get("system_events/content_report_r3"))}`,
  );
  check(
    "another user's threshold alert is untouched",
    store.has(`system_events/moderation_threshold_${OTHER}`),
    "the threshold leg is not filtered on the erased uid",
  );
  check(
    "a report with NO content owner is left alone",
    store.has("system_events/content_report_r4") &&
      store.get("system_events/content_report_r4")
        ?.contentOwnerAnonymizedAt === undefined,
    "a null contentOwnerId was read as a match",
  );
  check(
    "an unrelated ops row from another writer is untouched",
    store.has("system_events/cleanup_run_1"),
    "the sweep reaches rows it has no filter for",
  );
}

/**
 * ADR-0014: each mutation stages its own `audit_logs` row. This is the first
 * audit staging in the cascade.
 */
async function scenario_moderationSweepStagesItsAuditRows(): Promise<void> {
  const {
    deleteModerationSystemEvents,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  seedModerationEvents(store);

  await deleteModerationSystemEvents(asDb(store), UID);

  const audits = store
    .idsIn("audit_logs")
    .map((id) => store.get(`audit_logs/${id}`))
    .filter((row): row is DocData => row !== undefined)
    .filter((row) => row.resourceType === "system_events");

  check(
    "one audit row per mutated moderation event",
    audits.length === 3,
    `staged ${audits.length}: ${JSON.stringify(audits.map((a) => a.resourceId))}`,
  );
  check(
    "the two deletes and the one anonymization are told apart",
    audits.filter((a) => a.operation === "cascade_delete").length === 2 &&
      audits.filter((a) => a.operation === "cascade_anonymize").length === 1,
    `operations: ${JSON.stringify(audits.map((a) => a.operation))}`,
  );
  check(
    "every audit row names the erased user as its subject",
    audits.length > 0 && audits.every((a) => a.userId === UID),
    `subjects: ${JSON.stringify(audits.map((a) => a.userId))}`,
  );
}

/**
 * BUT-2032: an implausible row count DECLINES rather than truncating, and says
 * so through `failedCollections` — the contract `MAX_BLOCK_SWEEP_ROWS` and
 * `MAX_POLL_VOTE_SWEEP_ROWS` already state. A truncating sweep would report a
 * clean erasure over rows it never looked at.
 */
async function scenario_implausibleModerationEventCountDeclines(): Promise<void> {
  const {
    deleteModerationSystemEvents,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  // 2000 is MAX_SYSTEM_EVENT_SWEEP_ROWS and the read is `.limit(MAX + 1)`, so
  // 2001 rows is the smallest count that trips it.
  for (let i = 0; i < 2001; i++) {
    store.set(`system_events/content_report_flood_${i}`, {
      type: "content_report",
      details: { reportId: `flood-${i}`, reporterId: OTHER, contentOwnerId: UID },
    });
  }

  const complete = await deleteModerationSystemEvents(asDb(store), UID);

  check(
    "an implausible moderation-event count declines the sweep",
    complete === false,
    `returned ${complete}`,
  );
  check(
    "the declined sweep anonymized nothing rather than truncating",
    store.get("system_events/content_report_flood_0")
      ?.contentOwnerAnonymizedAt === undefined,
    "rows were mutated above the cap — the sweep truncated instead of declining",
  );
}

/**
 * BUT-2032: the residual probe SEES moderation rows the sweep missed.
 *
 * The legs live in the owner-keyed loop and NOT in the `probes` list at the top
 * of `probeResidualData`, which filters a top-level `userId` field. This
 * scenario is what makes that difference observable: every row it seeds carries
 * the uid under `details`, so a leg written the other way reports clean here.
 */
async function scenario_probeSeesLeftoverModerationEvents(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const emptyResult = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });

  // Clean: only other people's rows remain.
  const clean = new FakeFirestore();
  clean.set("system_events/content_report_r3", {
    type: "content_report",
    details: { reportId: "r3", reporterId: OTHER, contentOwnerId: THIRD },
  });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "with only other people's moderation rows left, the probe stays clean",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  // One dirty store per leg. Bundled into one scenario they would pass on the
  // strength of whichever leg still worked.
  const legs: ReadonlyArray<readonly [string, DocData]> = [
    [
      "a surviving threshold alert",
      { type: "moderation_threshold_reached", details: { userId: UID } },
    ],
    [
      "a surviving report the user filed",
      { type: "content_report", details: { reporterId: UID, contentOwnerId: OTHER } },
    ],
    [
      "a report about the user that was never anonymized",
      { type: "content_report", details: { reporterId: OTHER, contentOwnerId: UID } },
    ],
  ];
  for (const [label, row] of legs) {
    const dirty = new FakeFirestore();
    dirty.set("system_events/leftover", row);
    const dirtyResult = emptyResult();
    await probeResidualData(asDb(dirty), UID, dirtyResult);
    check(
      `${label} is reported as residual`,
      dirtyResult.failedCollections.includes("residual_data_detected"),
      `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
    );
  }
}

/**
 * BUT-2046: the erased user as the REPORTED person — their strike record and
 * every report row beneath it.
 *
 * The other-user rows are what make the assertions non-vacuous: an unfiltered
 * sweep passes "their rows are gone" exactly as easily as a correct one.
 */
async function scenario_moderationRecordAndItsRowsAreErased(): Promise<void> {
  const {
    deleteModerationRecord,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set(`user_moderation/${UID}`, { totalReports: 2 });
  store.set(`user_moderation/${UID}/report_history/r1`, {
    reportId: "r1",
    reporterId: OTHER,
  });
  store.set(`user_moderation/${UID}/report_history/r2`, {
    reportId: "r2",
    reporterId: THIRD,
  });
  // Another person's record, with a row naming the erased user as REPORTER.
  // This leg must not touch it — the other leg owns that row.
  store.set(`user_moderation/${OTHER}`, { totalReports: 1 });
  store.set(`user_moderation/${OTHER}/report_history/r3`, {
    reportId: "r3",
    reporterId: UID,
  });

  const complete = await deleteModerationRecord(asDb(store), UID);

  check(
    "the owner leg reports itself complete",
    complete === true,
    `returned ${complete}`,
  );
  check(
    "the erased user's own moderation record is deleted",
    !store.has(`user_moderation/${UID}`),
    "the parent document survived",
  );
  check(
    "every report row beneath it is deleted",
    store.pathsUnder(`user_moderation/${UID}/report_history`).length === 0,
    `left: ${JSON.stringify(store.pathsUnder(`user_moderation/${UID}/report_history`))}`,
  );
  check(
    "the rows go BEFORE the parent, so nothing is orphaned mid-run",
    store.deletedPaths.indexOf(`user_moderation/${UID}`) ===
      store.deletedPaths.length - 1,
    `delete order: ${JSON.stringify(store.deletedPaths)}`,
  );
  check(
    "another person's moderation record is untouched",
    store.has(`user_moderation/${OTHER}`) &&
      store.has(`user_moderation/${OTHER}/report_history/r3`),
    "the owner leg reached beyond the erased user's own document",
  );
}

/**
 * BUT-2046: both legs stage their own audit rows (ADR-0014).
 */
async function scenario_moderationRecordSweepStagesAuditRows(): Promise<void> {
  const {
    deleteModerationRecord,
    deleteReportHistoryByReporter,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set(`user_moderation/${UID}`, { totalReports: 1 });
  store.set(`user_moderation/${UID}/report_history/r1`, {
    reportId: "r1",
    reporterId: OTHER,
  });
  store.set(`user_moderation/${OTHER}/report_history/r2`, {
    reportId: "r2",
    reporterId: UID,
  });

  await deleteModerationRecord(asDb(store), UID);
  await deleteReportHistoryByReporter(asDb(store), UID);

  const audits = store
    .idsIn("audit_logs")
    .map((id) => store.get(`audit_logs/${id}`))
    .filter((row): row is DocData => row !== undefined);

  check(
    "one audit row per deleted moderation document",
    audits.length === 3,
    `staged ${audits.length}: ${JSON.stringify(audits.map((a) => a.resourceId))}`,
  );
  check(
    "the parent delete is audited under its own resource type",
    audits.some((a) => a.resourceType === "user_moderation") &&
      audits.filter((a) => a.resourceType === "report_history").length === 2,
    `types: ${JSON.stringify(audits.map((a) => a.resourceType))}`,
  );
}

/**
 * BUT-2046: an implausible row count DECLINES both legs rather than truncating,
 * and the owner leg leaves the PARENT standing when it declines — deleting it
 * would hide the rows from a reader without erasing them.
 */
async function scenario_implausibleReportHistoryCountDeclines(): Promise<void> {
  const {
    deleteModerationRecord,
    deleteReportHistoryByReporter,
  } = require("../account/account-deletion-cascade");

  // 2000 is MAX_REPORT_HISTORY_SWEEP_ROWS and the read is `.limit(MAX + 1)`, so
  // 2001 rows is the smallest count that trips it.
  const owner = new FakeFirestore();
  owner.set(`user_moderation/${UID}`, { totalReports: 2001 });
  for (let i = 0; i < 2001; i++) {
    owner.set(`user_moderation/${UID}/report_history/r${i}`, {
      reportId: `r${i}`,
      reporterId: OTHER,
    });
  }
  const ownerComplete = await deleteModerationRecord(asDb(owner), UID);
  check(
    "an implausible own-record row count declines the sweep",
    ownerComplete === false,
    `returned ${ownerComplete}`,
  );
  check(
    "the declined owner sweep leaves the parent standing",
    owner.has(`user_moderation/${UID}`),
    "the parent was deleted while its rows remained — they are now hidden, not erased",
  );

  const reporter = new FakeFirestore();
  for (let i = 0; i < 2001; i++) {
    reporter.set(`user_moderation/${OTHER}/report_history/r${i}`, {
      reportId: `r${i}`,
      reporterId: UID,
    });
  }
  const reporterComplete = await deleteReportHistoryByReporter(
    asDb(reporter),
    UID,
  );
  check(
    "an implausible reporter row count declines the sweep",
    reporterComplete === false,
    `returned ${reporterComplete}`,
  );
  check(
    "the declined reporter sweep deleted nothing rather than truncating",
    reporter.has(`user_moderation/${OTHER}/report_history/r0`),
    "rows were removed above the cap",
  );
}

/**
 * BUT-2046: the probe SEES what either leg missed. Two legs, one dirty store
 * each — bundled, they would pass on the strength of whichever still worked.
 */
async function scenario_probeSeesLeftoverModerationRows(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const emptyResult = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });

  const clean = new FakeFirestore();
  clean.set(`user_moderation/${OTHER}/report_history/r3`, {
    reportId: "r3",
    reporterId: THIRD,
  });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "with only other people's report rows left, the probe stays clean",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const asReporter = new FakeFirestore();
  asReporter.set(`user_moderation/${OTHER}/report_history/r1`, {
    reportId: "r1",
    reporterId: UID,
  });
  const reporterResult = emptyResult();
  await probeResidualData(asDb(asReporter), UID, reporterResult);
  check(
    "a surviving row naming the erased user as reporter is reported as residual",
    reporterResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(reporterResult.failedCollections)}`,
  );

  const asOwner = new FakeFirestore();
  asOwner.set(`user_moderation/${UID}/report_history/r2`, {
    reportId: "r2",
    reporterId: OTHER,
  });
  const ownerResult = emptyResult();
  await probeResidualData(asDb(asOwner), UID, ownerResult);
  check(
    "a surviving row under the erased user's own record is reported as residual",
    ownerResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(ownerResult.failedCollections)}`,
  );

  // The PARENT alone, with no rows beneath it. Its document id is the erased
  // uid and it holds the strike counter, so an empty-but-standing record is a
  // residual in its own right — and it is the one state the row legs above are
  // structurally blind to.
  const parentOnly = new FakeFirestore();
  parentOnly.set(`user_moderation/${UID}`, { totalReports: 4 });
  const parentResult = emptyResult();
  await probeResidualData(asDb(parentOnly), UID, parentResult);
  check(
    "a surviving moderation record with no rows is reported as residual",
    parentResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(parentResult.failedCollections)}`,
  );

  // …and another person's record does not trip it.
  const someoneElses = new FakeFirestore();
  someoneElses.set(`user_moderation/${OTHER}`, { totalReports: 4 });
  const elseResult = emptyResult();
  await probeResidualData(asDb(someoneElses), UID, elseResult);
  check(
    "another person's moderation record leaves the probe clean",
    !elseResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(elseResult.failedCollections)}`,
  );
}

/**
 * BUT-2046: the migration that moves the legacy array into the subcollection.
 *
 * It is a hand-run script with a dry-run default, and it is also the ONLY path claim-lint:ok moved unchanged, BUT-2113
 * that erases a reporter's uid from an un-migrated document — and it DELETES a
 * field. Its two load-bearing behaviours are pinned here: skip a target that
 * already exists, and clear the field only when nothing was left behind.
 *
 * The stub's transaction is a passthrough with no isolation, so nothing here
 * proves the chunking resists a real concurrent writer. What it proves is what
 * the code decides.
 */
async function scenario_reportHistoryMigrationMovesAndClears(): Promise<void> {
  const {
    migrateDocument,
  } = require("../admin/migrate-report-history");

  const store = new FakeFirestore();
  store.set(`user_moderation/${UID}`, {
    totalReports: 3,
    reportHistory: [
      { reportId: "r1", reporterId: OTHER, reason: "spam" },
      { reportId: "r2", reporterId: THIRD, reason: "abuse" },
      // Already migrated: a previous run, or the live writer got there first.
      { reportId: "r3", reporterId: OTHER, reason: "spam" },
    ],
  });
  store.set(`user_moderation/${UID}/report_history/r3`, {
    reportId: "r3",
    reporterId: OTHER,
    reason: "written by the live writer",
  });

  const outcome = await migrateDocument(asDb(store), UID, false);

  check(
    "every array entry becomes a row",
    store.pathsUnder(`user_moderation/${UID}/report_history`).length === 3,
    `rows: ${JSON.stringify(store.pathsUnder(`user_moderation/${UID}/report_history`))}`,
  );
  check(
    "the moved rows carry the reporter's uid",
    (store.get(`user_moderation/${UID}/report_history/r1`)
      ?.reporterId as string) === OTHER,
    `row: ${JSON.stringify(store.get(`user_moderation/${UID}/report_history/r1`))}`,
  );
  check(
    "a row that already exists is SKIPPED, not overwritten",
    store.get(`user_moderation/${UID}/report_history/r3`)?.reason ===
      "written by the live writer" && outcome.skippedExisting === 1,
    `row: ${JSON.stringify(store.get(`user_moderation/${UID}/report_history/r3`))}`,
  );
  check(
    "the legacy field is cleared once everything is accounted for",
    store.get(`user_moderation/${UID}`)?.reportHistory === undefined &&
      outcome.emptied === 1,
    `parent: ${JSON.stringify(store.get(`user_moderation/${UID}`))}`,
  );
  check(
    "the strike counter is left alone",
    store.get(`user_moderation/${UID}`)?.totalReports === 3,
    "the migration touched a field that is not its business",
  );
  check(
    "the outcome counts what it moved",
    outcome.moved === 2 && outcome.scanned === 3,
    `outcome: ${JSON.stringify(outcome)}`,
  );
}

/**
 * BUT-2046: an entry the migration CANNOT move keeps the whole field alive.
 * Clearing it would delete the only copy of a row that names a person. claim-lint:ok moved unchanged, BUT-2113
 */
async function scenario_unmovableEntryKeepsTheLegacyField(): Promise<void> {
  const {
    migrateDocument,
  } = require("../admin/migrate-report-history");

  const store = new FakeFirestore();
  store.set(`user_moderation/${UID}`, {
    reportHistory: [
      { reportId: "r1", reporterId: OTHER },
      // No reportId: there is no id to key it on, and it cannot be dropped.
      { reporterId: THIRD, reason: "abuse" },
    ],
  });

  const outcome = await migrateDocument(asDb(store), UID, false);

  check(
    "the movable entry is still moved",
    store.has(`user_moderation/${UID}/report_history/r1`),
    "a single bad entry stopped the good ones",
  );
  check(
    "the legacy field SURVIVES when an entry could not be moved",
    Array.isArray(store.get(`user_moderation/${UID}`)?.reportHistory) &&
      outcome.emptied === 0,
    `parent: ${JSON.stringify(store.get(`user_moderation/${UID}`))}`,
  );
  check(
    "the failure is reported rather than swallowed",
    outcome.failures.length === 1,
    `failures: ${JSON.stringify(outcome.failures)}`,
  );
}

/** BUT-2046: a dry run reports what it would do and writes nothing. */
async function scenario_reportHistoryMigrationDryRunWritesNothing(): Promise<void> {
  const {
    migrateDocument,
  } = require("../admin/migrate-report-history");

  const store = new FakeFirestore();
  store.set(`user_moderation/${UID}`, {
    reportHistory: [{ reportId: "r1", reporterId: OTHER }],
  });

  const outcome = await migrateDocument(asDb(store), UID, true);

  check(
    "a dry run writes no rows",
    store.pathsUnder(`user_moderation/${UID}/report_history`).length === 0,
    "the dry run wrote to the subcollection",
  );
  check(
    "a dry run leaves the legacy field in place",
    Array.isArray(store.get(`user_moderation/${UID}`)?.reportHistory),
    "the dry run cleared the field",
  );
  check(
    "a dry run reports what it would move, and empties nothing",
    outcome.moved === 1 && outcome.emptied === 0,
    // `emptied` counts fields actually cleared. A dry run clears none, so
    // reporting 1 here would be the script asserting something it did not do.
    `outcome: ${JSON.stringify(outcome)}`,
  );
}

async function main(): Promise<void> {
  await scenario_moderationEventsAreErasedAndAnonymized();
  await scenario_moderationSweepStagesItsAuditRows();
  await scenario_implausibleModerationEventCountDeclines();
  await scenario_probeSeesLeftoverModerationEvents();
  await scenario_moderationRecordAndItsRowsAreErased();
  await scenario_moderationRecordSweepStagesAuditRows();
  await scenario_implausibleReportHistoryCountDeclines();
  await scenario_probeSeesLeftoverModerationRows();
  await scenario_reportHistoryMigrationMovesAndClears();
  await scenario_unmovableEntryKeepsTheLegacyField();
  await scenario_reportHistoryMigrationDryRunWritesNothing();

  finishSuite("BUT-1766/BUT-1768 deletion cascade moderation events and records");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
