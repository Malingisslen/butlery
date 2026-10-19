/**
 * BUT-1766 / BUT-1768: deletion cascade reporter reports scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-moderation-reporters.test.ts
 */

import * as admin from "firebase-admin";
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
} from "./_account-deletion-cascade-test-seeds";

/**
 * BUT-2046: the erased user as the REPORTER — rows under OTHER people's
 * records, which is the half no query could reach while the data lived in an
 * array of maps.
 */
async function scenario_reporterRowsUnderOtherPeopleAreErased(): Promise<void> {
  const {
    deleteReportHistoryByReporter,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set(`user_moderation/${OTHER}/report_history/r1`, {
    reportId: "r1",
    reporterId: UID,
  });
  store.set(`user_moderation/${THIRD}/report_history/r2`, {
    reportId: "r2",
    reporterId: UID,
  });
  store.set(`user_moderation/${THIRD}/report_history/r3`, {
    reportId: "r3",
    reporterId: OTHER,
  });

  const complete = await deleteReportHistoryByReporter(asDb(store), UID);

  check(
    "the reporter leg reports itself complete",
    complete === true,
    `returned ${complete}`,
  );
  check(
    "the erased user's rows are gone from every other person's record",
    !store.has(`user_moderation/${OTHER}/report_history/r1`) &&
      !store.has(`user_moderation/${THIRD}/report_history/r2`),
    "a row naming the erased reporter survived",
  );
  check(
    "a row naming somebody else as reporter survives",
    store.has(`user_moderation/${THIRD}/report_history/r3`),
    "the sweep is not filtered on reporterId",
  );
  check(
    "the parent records are left standing",
    store.has(`user_moderation/${THIRD}/report_history/r3`) &&
      store.deletedPaths.every((p) => p.includes("/report_history/")),
    `deleted: ${JSON.stringify(store.deletedPaths)}`,
  );
}

// ─── 2026-09-18: the REPORTER's erasure keeps an open case ─────────────────

function auditRowsFor(store: FakeFirestore, resourceType: string): DocData[] {
  return store
    .idsIn("audit_logs")
    .map((id) => store.get(`audit_logs/${id}`))
    .filter((row): row is DocData => row !== undefined)
    .filter((row) => row.resourceType === resourceType);
}

/**
 * A report the erased user FILED follows its case: closed is deleted, anything
 * else — including a missing or unknown status — is kept with the reporter's
 * uid removed and their free text left in place.
 */
async function scenario_reporterReportsSplitOnCaseStatus(): Promise<void> {
  const { deleteUserReports } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  const base = { reporterId: UID, contentOwnerId: OTHER, reason: "harassment" };
  store.set("reports/open1", { ...base, status: "new", description: "hen skrev" });
  store.set("reports/acted", { ...base, status: "actioned" });
  store.set("reports/closed1", { ...base, status: "closed" });
  store.set("reports/nostatus", { ...base });
  store.set("reports/odd", { ...base, status: "archived" });
  store.set("reports/others", { ...base, reporterId: OTHER, status: "closed" });

  const now = new Date("2026-09-18T12:00:00Z");
  const outcome = await deleteUserReports(asDb(store), UID, now);

  check(
    "a closed case's report is deleted",
    !store.has("reports/closed1"),
    `left: ${JSON.stringify(store.idsIn("reports"))}`,
  );
  check(
    "open, actioned, status-less and unknown-status reports are all kept",
    store.has("reports/open1") &&
      store.has("reports/acted") &&
      store.has("reports/nostatus") &&
      store.has("reports/odd"),
    `left: ${JSON.stringify(store.idsIn("reports"))}`,
  );
  const open = (store.get("reports/open1") ?? {}) as DocData;
  check(
    "a kept report no longer names the reporter",
    open.reporterId === null &&
      store.get("reports/acted")?.reporterId === null &&
      store.get("reports/nostatus")?.reporterId === null &&
      store.get("reports/odd")?.reporterId === null,
    `open1: ${JSON.stringify(open)}`,
  );
  check(
    "a kept report keeps the reporter's free text (Malin, 2026-09-18)",
    open.description === "hen skrev",
    `description: ${JSON.stringify(open.description)}`,
  );
  const until = open.reporterRetainUntil as admin.firestore.Timestamp | undefined;
  check(
    "a kept report carries its 180-day cap, counted from the erasure",
    until instanceof admin.firestore.Timestamp &&
      until.toMillis() === now.getTime() + 180 * 24 * 60 * 60 * 1000,
    `reporterRetainUntil: ${JSON.stringify(until)}`,
  );
  check(
    "the outcome counts the kept reports",
    outcome.ok === true && outcome.keptOpen === 4,
    `outcome: ${JSON.stringify(outcome)}`,
  );
  check(
    "another reporter's report is untouched",
    store.get("reports/others")?.reporterId === OTHER,
    "the split is not filtered on reporterId",
  );

  const audits = auditRowsFor(store, "reports");
  check(
    "each report stages its own audit row, delete and anonymize told apart",
    audits.length === 5 &&
      audits.filter((a) => a.operation === "cascade_delete").length === 1 &&
      audits.filter((a) => a.operation === "cascade_anonymize").length === 4 &&
      audits.every((a) => a.userId === UID),
    `audits: ${JSON.stringify(audits.map((a) => [a.operation, a.resourceId]))}`,
  );
}

/** The ops-log row follows its `reports` document, on the reporter leg only. */
async function scenario_reporterEventRowsFollowTheirReport(): Promise<void> {
  const {
    deleteModerationSystemEvents,
  } = require("../account/account-deletion-cascade");

  for (const held of [false, true]) {
    const store = new FakeFirestore();
    store.set("reports/o", { reporterId: null, contentOwnerId: OTHER, status: "in_review" });
    store.set("reports/c", { reporterId: UID, contentOwnerId: OTHER, status: "closed" });
    store.set("system_events/content_report_o", {
      type: "content_report",
      details: { reportId: "o", reporterId: UID, contentOwnerId: OTHER },
    });
    store.set("system_events/content_report_c", {
      type: "content_report",
      details: { reportId: "c", reporterId: UID, contentOwnerId: OTHER },
    });
    store.set("system_events/content_report_m", {
      type: "content_report",
      details: { reportId: "m", reporterId: UID, contentOwnerId: OTHER },
    });

    const complete = await deleteModerationSystemEvents(asDb(store), UID, held);
    const tag = held ? " (reported side held)" : "";

    const kept = store.get("system_events/content_report_o") as
      | { details: Record<string, unknown> }
      | undefined;
    check(
      `an open case's reporter row is kept without the reporter${tag}`,
      kept !== undefined &&
        kept.details.reporterId === null &&
        kept.details.contentOwnerId === OTHER,
      `row: ${JSON.stringify(kept)}`,
    );
    check(
      `a closed or missing report's reporter row is deleted${tag}`,
      !store.has("system_events/content_report_c") &&
        !store.has("system_events/content_report_m"),
      `left: ${JSON.stringify(store.idsIn("system_events"))}`,
    );
    check(`the step reports itself complete${tag}`, complete === true, `returned ${complete}`);
    const anon = auditRowsFor(store, "system_events").filter(
      (a) => a.operation === "cascade_anonymize",
    );
    check(
      `the kept row stages a cascade_anonymize audit row${tag}`,
      anon.length === 1 && anon[0].resourceId === "content_report_o",
      `anonymize audits: ${JSON.stringify(anon.map((a) => a.resourceId))}`,
    );
  }
}

/**
 * An unreadable report status keeps the row, without the reporter, and the
 * step says it is incomplete.
 */
async function scenario_reporterLegsKeepRowsWhenStatusUnreadable(): Promise<void> {
  const {
    deleteModerationSystemEvents,
    deleteReportHistoryByReporter,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set("reports/c", { reporterId: UID, contentOwnerId: OTHER, status: "closed" });
  store.readFailures.add("reports/c");
  store.set("system_events/content_report_c", {
    type: "content_report",
    details: { reportId: "c", reporterId: UID, contentOwnerId: OTHER },
  });
  store.set(`user_moderation/${OTHER}/report_history/c`, { reportId: "c", reporterId: UID });

  const eventsComplete = await deleteModerationSystemEvents(asDb(store), UID);
  const historyComplete = await deleteReportHistoryByReporter(asDb(store), UID);

  check(
    "an unreadable status keeps the ops-log row, without the reporter",
    (store.get("system_events/content_report_c")?.details as
      | Record<string, unknown>
      | undefined)?.reporterId === null,
    `row: ${JSON.stringify(store.get("system_events/content_report_c"))}`,
  );
  check(
    "an unreadable status keeps the report_history row, without the reporter",
    store.get(`user_moderation/${OTHER}/report_history/c`)?.reporterId === null,
    `row: ${JSON.stringify(store.get(`user_moderation/${OTHER}/report_history/c`))}`,
  );
  check(
    "both legs report themselves incomplete",
    eventsComplete === false && historyComplete === false,
    `events ${eventsComplete}, history ${historyComplete}`,
  );
}

/** `report_history` rows follow their report the same way. */
async function scenario_reporterHistoryRowsFollowTheirReport(): Promise<void> {
  const {
    deleteReportHistoryByReporter,
  } = require("../account/account-deletion-cascade");

  const store = new FakeFirestore();
  store.set("reports/o", { reporterId: null, contentOwnerId: OTHER, status: "new" });
  store.set("reports/c", { reporterId: UID, contentOwnerId: OTHER, status: "closed" });
  store.set(`user_moderation/${OTHER}/report_history/o`, {
    reportId: "o",
    reporterId: UID,
    reason: "spam",
  });
  store.set(`user_moderation/${OTHER}/report_history/c`, { reportId: "c", reporterId: UID });

  const complete = await deleteReportHistoryByReporter(asDb(store), UID);

  const kept = store.get(`user_moderation/${OTHER}/report_history/o`);
  check(
    "an open case's history row is kept without the reporter",
    kept !== undefined && kept.reporterId === null && kept.reason === "spam",
    `row: ${JSON.stringify(kept)}`,
  );
  check(
    "a closed case's history row is deleted",
    !store.has(`user_moderation/${OTHER}/report_history/c`),
    `left: ${JSON.stringify(store.pathsUnder(`user_moderation/${OTHER}/report_history`))}`,
  );
  check("the leg reports itself complete", complete === true, `returned ${complete}`);
  const anon = auditRowsFor(store, "report_history").filter(
    (a) => a.operation === "cascade_anonymize",
  );
  check(
    "the kept row stages a cascade_anonymize audit row",
    anon.length === 1 && anon[0].resourceId === "o",
    `anonymize audits: ${JSON.stringify(anon.map((a) => a.resourceId))}`,
  );
}

/** The probe counts a report still naming the reporter, and not a nulled one. */
async function scenario_probeSeesAReportStillNamingTheReporter(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const dirty = new FakeFirestore();
  dirty.set("reports/x", { reporterId: UID, status: "new" });
  const dirtyResult = emptyResult();
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "a report still naming the erased reporter is residual data",
    dirtyResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );

  const clean = new FakeFirestore();
  clean.set("reports/x", { reporterId: null, status: "new", description: "kvar" });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "a kept report with the reporter removed is NOT residual data",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );
}

/**
 * Both parties erasing at once: the two anonymizers write DISJOINT fields on
 * one `reports` document, so neither undoes the other.
 */
async function scenario_bothPartiesErasingLeaveBothFieldsNulled(): Promise<void> {
  const { deleteUserReports } = require("../account/account-deletion-cascade");
  const {
    anonymizeReportsByContentOwnerWithDb,
  } = require("../moderation/anonymize-reports");

  const store = new FakeFirestore();
  store.set("reports/both", { reporterId: UID, contentOwnerId: OTHER, status: "new" });

  await Promise.all([
    deleteUserReports(asDb(store), UID),
    anonymizeReportsByContentOwnerWithDb(asDb(store), OTHER),
  ]);

  const row = store.get("reports/both");
  check(
    "a report both parties erased names neither",
    row !== undefined && row.reporterId === null && row.contentOwnerId === null,
    `row: ${JSON.stringify(row)}`,
  );
}

/**
 * The daily pass ends a kept report when its case closes or its cap passes,
 * and leaves an open one inside its cap alone.
 */
async function scenario_retainedReportsSweep(): Promise<void> {
  const {
    sweepRetainedReporterReports,
    MAX_RETAINED_REPORT_SWEEP_ROWS,
  } = require("../moderation/reporter-retention");

  const now = new Date("2026-09-18T12:00:00Z");
  const future = admin.firestore.Timestamp.fromMillis(now.getTime() + 86_400_000);
  const past = admin.firestore.Timestamp.fromMillis(now.getTime() - 1);

  const store = new FakeFirestore();
  const seed = (id: string, owner: string, data: DocData) => {
    store.set(`reports/${id}`, { reporterId: null, contentOwnerId: owner, ...data });
    store.set(`system_events/content_report_${id}`, {
      details: { reportId: id, reporterId: null, contentOwnerId: owner },
    });
    store.set(`user_moderation/${owner}/report_history/${id}`, {
      reportId: id,
      reporterId: null,
    });
  };
  seed("closedA", OTHER, { status: "closed", reporterRetainUntil: future });
  seed("openB", OTHER, { status: "in_review", reporterRetainUntil: future });
  seed("expiredC", OTHER, { status: "new", reporterRetainUntil: past });
  seed("heldD", THIRD, { status: "new", reporterRetainUntil: past });
  store.set(`erasure_holds/${THIRD}`, { holdUntil: future });
  seed("plainE", OTHER, { status: "closed" });
  // A client's own report carrying the sweep's fields: its reporterId is the
  // client's uid, which only the erasure cascade can null.
  store.set("reports/plantedF", {
    reporterId: "live-user",
    contentOwnerId: OTHER,
    status: "new",
    reporterRetainUntil: past,
  });

  const result = await sweepRetainedReporterReports(asDb(store), now);

  check(
    "a kept report whose case closed is deleted with both derived rows",
    !store.has("reports/closedA") &&
      !store.has("system_events/content_report_closedA") &&
      !store.has(`user_moderation/${OTHER}/report_history/closedA`),
    `reports left: ${JSON.stringify(store.idsIn("reports"))}`,
  );
  check(
    "a kept report past its cap is deleted even while its case is open",
    !store.has("reports/expiredC") &&
      !store.has("system_events/content_report_expiredC"),
    `reports left: ${JSON.stringify(store.idsIn("reports"))}`,
  );
  check(
    "an open kept report inside its cap is left alone",
    store.has("reports/openB") &&
      store.has("system_events/content_report_openB") &&
      store.has(`user_moderation/${OTHER}/report_history/openB`),
    `reports left: ${JSON.stringify(store.idsIn("reports"))}`,
  );
  check(
    "the reporter's cap wins over the reported person's hold (Malin, 2026-09-18)",
    !store.has("reports/heldD") &&
      !store.has("system_events/content_report_heldD") &&
      !store.has(`user_moderation/${THIRD}/report_history/heldD`),
    `history: ${JSON.stringify(store.pathsUnder(`user_moderation/${THIRD}/report_history`))}`,
  );
  check(
    "a report no erasure kept is not the sweep's business",
    store.has("reports/plainE"),
    "a row with no cap was finished",
  );
  check(
    "a report a live client stamped with the sweep's fields is untouched",
    store.has("reports/plantedF"),
    "the sweep selects on a field a client can write",
  );
  check(
    "the result counts what it did",
    result.deleted === 3 && result.failed === 0 && !result.declined && !result.deferred,
    `result: ${JSON.stringify(result)}`,
  );

  // One row that cannot be finished must not stop the rest.
  const flaky = new FakeFirestore();
  flaky.set("reports/bad", { reporterId: null, status: "closed", reporterRetainUntil: future });
  flaky.set("reports/good", { reporterId: null, status: "closed", reporterRetainUntil: future });
  flaky.batchFailures.set("reports/bad", 14);
  const flakyResult = await sweepRetainedReporterReports(asDb(flaky), now);
  check(
    "one failing row does not stall the sweep",
    !flaky.has("reports/good") && flaky.has("reports/bad") && flakyResult.failed === 1,
    `result: ${JSON.stringify(flakyResult)}, left: ${JSON.stringify(flaky.idsIn("reports"))}`,
  );

  // Above the cap the sweep declines rather than truncating.
  const big = new FakeFirestore();
  for (let i = 0; i <= MAX_RETAINED_REPORT_SWEEP_ROWS; i++) {
    big.set(`reports/r${i}`, { reporterId: null, status: "closed", reporterRetainUntil: future });
  }
  const bigResult = await sweepRetainedReporterReports(asDb(big), now);
  check(
    "above the cap the sweep declines and deletes nothing",
    bigResult.declined === true &&
      big.idsIn("reports").length === MAX_RETAINED_REPORT_SWEEP_ROWS + 1,
    `result: ${JSON.stringify(bigResult)}`,
  );

  // Out of budget: nothing examined, the rest deferred.
  const slow = new FakeFirestore();
  slow.set("reports/s", { reporterId: null, status: "closed", reporterRetainUntil: future });
  const slowResult = await sweepRetainedReporterReports(asDb(slow), now, 0);
  check(
    "a run out of budget defers instead of working",
    slowResult.deferred === true && slow.has("reports/s"),
    `result: ${JSON.stringify(slowResult)}`,
  );
}

async function main(): Promise<void> {
  await scenario_reporterRowsUnderOtherPeopleAreErased();
  await scenario_reporterReportsSplitOnCaseStatus();
  await scenario_reporterEventRowsFollowTheirReport();
  await scenario_reporterLegsKeepRowsWhenStatusUnreadable();
  await scenario_reporterHistoryRowsFollowTheirReport();
  await scenario_probeSeesAReportStillNamingTheReporter();
  await scenario_bothPartiesErasingLeaveBothFieldsNulled();
  await scenario_retainedReportsSweep();

  finishSuite("BUT-1766/BUT-1768 deletion cascade reporter reports");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
