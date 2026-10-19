/**
 * BUT-1766 / BUT-1768: deletion cascade moderation holds scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-moderation-holds.test.ts
 */

import * as admin from "firebase-admin";
import {
  USER_MODERATION,
  type DeletionResult,
} from "../account/account-deletion-cascade";
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
 * BUT-2353: the cascade's `moderation_appeals` step and its probe leg. An
 * appeal stores its appellant, so it is found whatever became of its report.
 */
async function scenario_appealsGoByAppellant(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");
  const { deleteAppealsByAppellant } = require("../moderation/appeal-erasure");

  const result = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });
  const seed = (s: FakeFirestore): void => {
    s.set("moderation_appeals/r1_owner", { reportId: "r1", role: "owner", appellantId: UID });
    s.set("moderation_appeals/r2_reporter", { reportId: "r2", role: "reporter", appellantId: UID });
    s.set("moderation_appeals/r1_reporter", { reportId: "r1", role: "reporter", appellantId: OTHER });
  };

  const dirty = new FakeFirestore();
  seed(dirty);
  const dirtyResult = result();
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "an appeal still naming the user is reported as residual",
    dirtyResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );

  const store = new FakeFirestore();
  seed(store);
  const deleted = await deleteAppealsByAppellant(asDb(store), UID);
  check(
    "the step deletes the user's appeals in both roles, with no report present",
    deleted === 2 && store.idsIn("moderation_appeals").join(",") === "r1_reporter",
    `deleted ${deleted}, left: ${JSON.stringify(store.idsIn("moderation_appeals"))}`,
  );
  const cleanResult = result();
  await probeResidualData(asDb(store), UID, cleanResult);
  check(
    "after the step the probe is clean, the other party's appeal not counted",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );
}

/* ── BUT-2046 follow-up: the legal hold ─────────────────────────────────── */

/** A store with one report against UID, at [status]. */
function holdStore(status: string): FakeFirestore {
  const s = new FakeFirestore();
  s.set("reports/rep1", {
    reporterId: OTHER,
    contentOwnerId: UID,
    status,
  });
  s.set(`user_moderation/${UID}`, { totalReports: 1 });
  s.set(`user_moderation/${UID}/report_history/rep1`, {
    reportId: "rep1",
    reporterId: OTHER,
    // Written when the REPORT was filed, so it expires long before a hold
    // placed today would.
    expireAt: admin.firestore.Timestamp.fromDate(new Date("2026-10-01")),
  });
  s.set("system_events/content_report_rep1", {
    type: "content_report",
    details: { reportId: "rep1", reporterId: OTHER, contentOwnerId: UID },
  });
  // The threshold alert. Seeded because its ABSENCE made a whole failure mode
  // invisible: the deleter kept this row under a hold while the probe still
  // counted it, which flips `gdprCompliant` false permanently — and no
  // scenario could see it, because no fixture held one.
  s.set(`system_events/moderation_threshold_${UID}`, {
    type: "moderation_threshold_reached",
    details: { userId: UID, totalReports: 5, action: "review_required" },
  });
  return s;
}

/**
 * An OPEN case holds the record: the document and its rows stand, and the step
 * reports itself DONE rather than failed — a lawful refusal is not a failure.
 */
async function scenario_openCaseHoldsTheModerationRecord(): Promise<void> {
  const { applyErasureHold } = require("../moderation/erasure-hold");
  const store = holdStore("in_review");

  const { retained } = await applyErasureHold(asDb(store), UID);

  check(
    "an open case returns one retained record",
    retained.length === 1 && retained[0].legalBasis === "GDPR Art. 17(3)(e)",
    `got ${JSON.stringify(retained)}`,
  );
  // The PRODUCER of `resourceType`, compared against the same constant both
  // `held` predicates read. Asserted here rather than trusted: a divergent
  // literal in the hold module would make `held` false everywhere at once,
  // and the destructive steps would run under a standing hold.
  check(
    "and stamps the resourceType both `held` predicates key on",
    retained[0].resourceType === USER_MODERATION,
    `got ${JSON.stringify(retained[0])}`,
  );
  check(
    "the moderation record and its rows are untouched by the hold step",
    store.has(`user_moderation/${UID}`) &&
      store.has(`user_moderation/${UID}/report_history/rep1`),
    "the hold step removed what it exists to keep",
  );
}

/**
 * `actioned` is NOT terminal. The predicate is `status != 'closed'` and nothing
 * narrower, so a case a moderator has acted on but not closed still holds —
 * the decision, spelled as a test because the word reads the other way.
 */
async function scenario_actionedStillCountsAsOpen(): Promise<void> {
  const { hasOpenModerationCase } = require("../moderation/erasure-hold");

  const actioned = await hasOpenModerationCase(asDb(holdStore("actioned")), UID);
  const closed = await hasOpenModerationCase(asDb(holdStore("closed")), UID);
  check(
    "an ACTIONED case is still open — it reads as finished and is not",
    actioned === true,
    `got ${actioned}`,
  );
  check(
    "a CLOSED case is the only terminal one",
    closed === false,
    `got ${closed}`,
  );

  const other = new FakeFirestore();
  other.set("reports/rep9", {
    reporterId: UID,
    contentOwnerId: OTHER,
    status: "new",
  });
  check(
    "an open case against SOMEBODY ELSE does not hold this user's erasure",
    (await hasOpenModerationCase(asDb(other), UID)) === false,
    "the predicate matched another person's case",
  );
}

/** Only closed cases → no hold, and the cascade behaves exactly as before. */
async function scenario_closedCaseDeletesAsBefore(): Promise<void> {
  const { applyErasureHold } = require("../moderation/erasure-hold");
  const store = holdStore("closed");

  const { retained, ok } = await applyErasureHold(asDb(store), UID);

  check(
    "a closed case reports itself clean",
    ok === true,
    `ok was ${ok}`,
  );
  check(
    "a closed case retains nothing",
    retained.length === 0,
    `got ${JSON.stringify(retained)}`,
  );
  check(
    "and writes no hold document",
    !store.has(`erasure_holds/${UID}`),
    "a hold was recorded for a closed case",
  );
}

/**
 * The TTL rewrite. `report_history.expireAt` runs on the REPORT's clock and the
 * hold on the ERASURE's, so without this the row ages out mid-hold and the
 * sweep guards nothing.
 */
async function scenario_holdPushesReportHistoryTtlForward(): Promise<void> {
  const { applyErasureHold } = require("../moderation/erasure-hold");
  const store = holdStore("new");
  store.set(`user_moderation/${OTHER}/report_history/rep2`, {
    reportId: "rep2",
    reporterId: THIRD,
    expireAt: admin.firestore.Timestamp.fromDate(new Date("2026-10-01")),
  });

  const now = new Date("2026-09-09T00:00:00Z");
  const { retained } = await applyErasureHold(asDb(store), UID, now);
  const holdUntil = retained[0].holdUntil as admin.firestore.Timestamp;

  const held = store.get(`user_moderation/${UID}/report_history/rep1`) as {
    expireAt: admin.firestore.Timestamp;
  };
  check(
    "a held row's expireAt is pushed out to holdUntil",
    held.expireAt.toMillis() === holdUntil.toMillis(),
    `expireAt ${held.expireAt.toMillis()} vs holdUntil ${holdUntil.toMillis()}`,
  );
  check(
    "and holdUntil is 180 days from the ERASURE, not from the report",
    holdUntil.toMillis() === now.getTime() + 180 * 24 * 60 * 60 * 1000,
    `got ${holdUntil.toMillis()}`,
  );

  const untouched = store.get(
    `user_moderation/${OTHER}/report_history/rep2`,
  ) as { expireAt: admin.firestore.Timestamp };
  check(
    "somebody else's row keeps its own clock",
    untouched.expireAt.toMillis() === new Date("2026-10-01").getTime(),
    `got ${untouched.expireAt.toMillis()}`,
  );
}

/**
 * The hold lives in its own collection. `user_moderation/{uid}`'s read rule is
 * a `hasOnly(['totalReports','lastReportedAt'])` allowlist, so a field written
 * there would make the document unreadable to its own subject — this reddens
 * the day somebody moves it back.
 */
async function scenario_holdDocumentLivesOutsideUserModeration(): Promise<void> {
  const { applyErasureHold } = require("../moderation/erasure-hold");
  const store = holdStore("new");

  await applyErasureHold(asDb(store), UID);

  check(
    "the hold is recorded in its own collection",
    store.has(`erasure_holds/${UID}`),
    "no hold document was written",
  );
  const moderation = store.get(`user_moderation/${UID}`) as Record<
    string,
    unknown
  >;
  check(
    "and user_moderation's key set is UNCHANGED — the allowlist still holds",
    JSON.stringify(Object.keys(moderation).sort()) ===
      JSON.stringify(["totalReports"]),
    `keys: ${JSON.stringify(Object.keys(moderation))}`,
  );
}

/**
 * Condition B. Under a hold the probe must skip exactly the legs the deleter
 * keeps — no more: silencing the REPORTER leg would hide a real failure of
 * `deleteReportHistoryByReporter`, which the hold is deliberately not about.
 */
async function scenario_heldRecordIsNotCountedAsResidual(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");
  const store = holdStore("new");

  const heldRetained = [
    {
      resourceType: "user_moderation",
      legalBasis: "GDPR Art. 17(3)(e)",
      holdUntil: admin.firestore.Timestamp.fromDate(new Date("2027-03-08")),
      provisional: false,
    },
  ];
  const heldResult: DeletionResult = {
    deletedCollections: [],
    failedCollections: [],
    errors: [],
    retained: heldRetained,
  };
  await probeResidualData(asDb(store), UID, heldResult);
  check(
    "a held record does not flip gdprCompliant",
    !heldResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(heldResult.failedCollections)}`,
  );

  const unheld: DeletionResult = {
    deletedCollections: [],
    failedCollections: [],
    errors: [],
    retained: [],
  };
  await probeResidualData(asDb(store), UID, unheld);
  check(
    "the SAME store without a hold IS residual — the skip is doing the work",
    unheld.failedCollections.includes("residual_data_detected"),
    "the probe was blind to the rows either way, so the case above proves nothing",
  );

  // A retained record for SOME OTHER collection must not disarm these legs.
  // Without this arm, keying `held` on `retained.length > 0` instead of on
  // `resourceType` passes — which is the hazard the deviation entry names.
  const foreign: DeletionResult = {
    deletedCollections: [],
    failedCollections: [],
    errors: [],
    retained: [
      {
        resourceType: "some_other_hold",
        legalBasis: "GDPR Art. 17(3)(b)",
        holdUntil: admin.firestore.Timestamp.fromDate(new Date("2027-03-08")),
        provisional: false,
      },
    ],
  };
  await probeResidualData(asDb(store), UID, foreign);
  check(
    "a hold over a DIFFERENT collection does not silence the moderation legs",
    foreign.failedCollections.includes("residual_data_detected"),
    "`held` is keyed on list length rather than on the resource",
  );

  const reporterRow = holdStore("new");
  reporterRow.set(`user_moderation/${OTHER}/report_history/rep7`, {
    reportId: "rep7",
    reporterId: UID,
  });
  const stillHeld: DeletionResult = {
    deletedCollections: [],
    failedCollections: [],
    errors: [],
    retained: heldRetained,
  };
  await probeResidualData(asDb(reporterRow), UID, stillHeld);
  check(
    "but a surviving REPORTER row still reports residual under a hold",
    stillHeld.failedCollections.includes("residual_data_detected"),
    "the hold silenced the reporter leg, which it must never do",
  );
}

/** Condition G, the system_events half: the uid STAYS while the hold stands. */
async function scenario_holdKeepsContentOwnerIdOnSystemEvents(): Promise<void> {
  const {
    deleteModerationSystemEvents,
  } = require("../account/account-deletion-cascade");

  const held = holdStore("new");
  await deleteModerationSystemEvents(asDb(held), UID, true);
  check(
    "under a hold the threshold alert about the held person SURVIVES — that " +
      "field is the reported person's uid, not the reporter's",
    held.has(`system_events/moderation_threshold_${UID}`),
    "the hold kept the report and destroyed the alert derived from it",
  );
  const heldRow = held.get("system_events/content_report_rep1") as {
    details: { contentOwnerId: string | null };
  };
  check(
    "under a hold the reported person's uid stays on the ops-log row",
    heldRow.details.contentOwnerId === UID,
    `got ${JSON.stringify(heldRow.details)}`,
  );

  const free = holdStore("new");
  await deleteModerationSystemEvents(asDb(free), UID, false);
  check(
    "without a hold the threshold alert is deleted",
    !free.has(`system_events/moderation_threshold_${UID}`),
    "the threshold alert outlived an unheld erasure",
  );
  const freeRow = free.get("system_events/content_report_rep1") as {
    details: { contentOwnerId: string | null };
  };
  check(
    "without a hold it is nulled exactly as before",
    freeRow.details.contentOwnerId === null,
    `got ${JSON.stringify(freeRow.details)}`,
  );
}

/**
 * The sweep, and what the lift actually leaves behind — the half Malin decided
 * ("the uid is nulled when the hold lifts"), which a test that only watched the
 * hold document disappear would leave unpinned.
 */
async function scenario_sweepLiftsWhenLastCaseCloses(): Promise<void> {
  const {
    applyErasureHold,
    sweepErasureHolds,
  } = require("../moderation/erasure-hold");

  const store = holdStore("in_review");
  await applyErasureHold(asDb(store), UID, new Date("2026-09-09T00:00:00Z"));

  let res = await sweepErasureHolds(
    asDb(store),
    new Date("2026-09-10T00:00:00Z"),
  );
  check(
    "an open case survives the daily sweep",
    res.lifted === 0 && store.has(`erasure_holds/${UID}`),
    `lifted ${res.lifted}`,
  );

  store.set("reports/rep1", {
    reporterId: OTHER,
    contentOwnerId: UID,
    status: "closed",
  });
  res = await sweepErasureHolds(asDb(store), new Date("2026-09-11T00:00:00Z"));

  check(
    "the hold lifts once the last case closes",
    res.lifted === 1,
    `lifted ${res.lifted}`,
  );
  check(
    "the hold document is gone",
    !store.has(`erasure_holds/${UID}`),
    "the decision outlived the hold",
  );
  check(
    "the moderation record and its rows are erased",
    !store.has(`user_moderation/${UID}`) &&
      !store.has(`user_moderation/${UID}/report_history/rep1`),
    "the lift left the evidence standing",
  );
  const row = store.get("system_events/content_report_rep1") as {
    details: { contentOwnerId: string | null };
  };
  check(
    "and the ops-log uid is nulled — the half the deviation actually promised",
    row.details.contentOwnerId === null,
    `got ${JSON.stringify(row.details)}`,
  );
  // The REPORT row is a separate anonymizer from the one above, and asserting
  // only the ops-log row left it unexercised: a probe deleting the reports call
  // passed green. Two anonymizers, two assertions.
  const report = store.get("reports/rep1") as {
    contentOwnerId: string | null;
  };
  check(
    "and the REPORT's own uid is nulled too — the other anonymizer",
    report.contentOwnerId === null,
    `got ${JSON.stringify(report)}`,
  );
}

/** A case nobody ever closes still ends, at the outer cap. */
async function scenario_sweepLiftsAtTheOuterCap(): Promise<void> {
  const {
    applyErasureHold,
    sweepErasureHolds,
  } = require("../moderation/erasure-hold");

  const store = holdStore("new");
  await applyErasureHold(asDb(store), UID, new Date("2026-09-09T00:00:00Z"));

  const before = await sweepErasureHolds(
    asDb(store),
    new Date("2027-03-07T00:00:00Z"),
  );
  check(
    "one day short of the cap, a never-triaged case still holds",
    before.lifted === 0,
    `lifted ${before.lifted}`,
  );

  const after = await sweepErasureHolds(
    asDb(store),
    new Date("2027-03-09T00:00:00Z"),
  );
  check(
    "past the cap it lifts even though the case is still open",
    after.lifted === 1 && !store.has(`erasure_holds/${UID}`),
    `lifted ${after.lifted}`,
  );
}

/**
 * Condition G, the REPORTS half — the guard the whole build exists for, and
 * the one that had no seam and no test until the integration gate said so.
 *
 * It reads the cascade's decision out of `erasure_holds/{uid}`; it does NOT
 * re-derive the predicate, so an open case with no hold document must still
 * anonymize. That third arm is what makes the first two mean something.
 */
async function scenario_holdKeepsContentOwnerIdOnReports(): Promise<void> {
  const {
    anonymizeReportsUnlessHeldWithDb,
  } = require("../moderation/erasure-hold");

  // BUT-2353: the user's appeals in both roles, one on a report already
  // deleted, and the other party's appeal, which must stay.
  const seedAppeals = (s: FakeFirestore): void => {
    s.set("moderation_appeals/rep1_owner", { reportId: "rep1", role: "owner", appellantId: UID });
    s.set("moderation_appeals/gone_reporter", { reportId: "gone", role: "reporter", appellantId: UID });
    s.set("moderation_appeals/rep1_reporter", { reportId: "rep1", role: "reporter", appellantId: OTHER });
  };
  const appealsLeft = (s: FakeFirestore): string => s.idsIn("moderation_appeals").sort().join(",");

  const held = holdStore("in_review");
  seedAppeals(held);
  held.set(`erasure_holds/${UID}`, {
    holdUntil: admin.firestore.Timestamp.fromDate(new Date("2027-03-08")),
    legalBasis: "GDPR Art. 17(3)(e)",
  });
  await anonymizeReportsUnlessHeldWithDb(asDb(held), UID);
  check(
    "with a hold recorded, the report keeps the reported person's uid",
    (held.get("reports/rep1") as { contentOwnerId: string | null })
      .contentOwnerId === UID,
    `got ${JSON.stringify(held.get("reports/rep1"))}`,
  );
  check(
    "a hold does not keep the user's appeals, in either role (BUT-2353)",
    appealsLeft(held) === "rep1_reporter",
    `left: ${appealsLeft(held)}`,
  );

  const free = holdStore("closed");
  seedAppeals(free);
  await anonymizeReportsUnlessHeldWithDb(asDb(free), UID);
  check(
    "with no hold, it is nulled exactly as BUT-781 has always done",
    (free.get("reports/rep1") as { contentOwnerId: string | null })
      .contentOwnerId === null,
    `got ${JSON.stringify(free.get("reports/rep1"))}`,
  );
  check(
    "with no hold the user's appeals go too, and the other party's stays",
    appealsLeft(free) === "rep1_reporter",
    `left: ${appealsLeft(free)}`,
  );

  // The DECISION is the input, not the predicate. An open case whose hold
  // document is missing anonymizes — that is the fail-open the cascade closes
  // by writing a provisional hold, and this pins that the guard itself does
  // not quietly second-guess the cascade.
  const openButUnrecorded = holdStore("in_review");
  await anonymizeReportsUnlessHeldWithDb(asDb(openButUnrecorded), UID);
  check(
    "an open case with NO hold document is anonymized — the guard reads the " +
      "decision, never the predicate",
    (openButUnrecorded.get("reports/rep1") as { contentOwnerId: string | null })
      .contentOwnerId === null,
    `got ${JSON.stringify(openButUnrecorded.get("reports/rep1"))}`,
  );
}

/**
 * The FAIL-CLOSED branches. Both were unpinned: deleting either `catch` left
 * every scenario green while the control it protects stopped existing.
 *
 * The distinction they pin is the whole design — a failure must cost the
 * ERASURE's completeness report, never the ANSWER about what is held. Getting
 * that backwards destroys evidence on a transient Firestore error.
 */
async function scenario_holdFailsClosedWhenItCannotDecide(): Promise<void> {
  const { applyErasureHold } = require("../moderation/erasure-hold");

  // The predicate itself is unanswerable: the `reports` query throws.
  const store = holdStore("in_review");
  const db = asDb(store) as unknown as Record<string, unknown>;
  const realCollection = db.collection as (name: string) => unknown;
  db.collection = (name: string) => {
    if (name === "reports") {
      throw Object.assign(new Error("unavailable"), { code: 14 });
    }
    return realCollection.call(db, name);
  };

  const { retained, ok } = await applyErasureHold(db, UID);

  check(
    "an undecidable predicate HOLDS rather than resolving to 'nothing kept'",
    retained.length === 1,
    `got ${JSON.stringify(retained)}`,
  );
  check(
    "and reports the erasure incomplete — the failure costs the REPORT, " +
      "never the answer",
    ok === false,
    `ok was ${ok}`,
  );
  const hold = store.get(`erasure_holds/${UID}`) as
    | { provisional?: boolean }
    | undefined;
  check(
    "a PROVISIONAL hold document is left behind, so the sweep can recover it",
    hold?.provisional === true,
    `got ${JSON.stringify(hold)}`,
  );
  // The flag must also reach the RECORD, not only the document: the Art. 12(4)
  // notice hedges its wording on it (BUT-2047), and the document never crosses
  // the callable boundary.
  check(
    "and the retained RECORD says so too, which is what the notice reads",
    retained[0].provisional === true,
    `got ${JSON.stringify(retained[0])}`,
  );
}

/**
 * ADR-0014: a cascade that acts on a document stages an audit row for it. A
 * RETENTION is an action too — `cascade_retain` is deliberately not a flavour
 * of delete, anonymize or tombstone — and nothing asserted either row.
 */
async function scenario_holdStagesItsAuditRows(): Promise<void> {
  const { applyErasureHold, liftErasureHold } =
    require("../moderation/erasure-hold");

  const store = holdStore("in_review");
  await applyErasureHold(asDb(store), UID, new Date("2026-09-09T00:00:00Z"));

  const retainRows = store
    .idsIn("audit_logs")
    .map((id) => store.get(`audit_logs/${id}`))
    .filter((row): row is DocData => row !== undefined)
    .filter((row) => row.operation === "cascade_retain");
  check(
    "placing a hold stages exactly one cascade_retain row",
    retainRows.length === 1 &&
      retainRows[0].resourceType === "erasure_holds",
    `got ${JSON.stringify(retainRows)}`,
  );

  store.set("reports/rep1", {
    reporterId: OTHER,
    contentOwnerId: UID,
    status: "closed",
  });
  await liftErasureHold(asDb(store), UID);

  const deleteRows = store
    .idsIn("audit_logs")
    .map((id) => store.get(`audit_logs/${id}`))
    .filter((row): row is DocData => row !== undefined)
    .filter(
      (row) =>
        row.operation === "cascade_delete" &&
        row.resourceType === "erasure_holds",
    );
  check(
    "and releasing it stages the matching delete row",
    deleteRows.length === 1,
    `got ${JSON.stringify(deleteRows)}`,
  );
}

/**
 * The TTL push runs OUTSIDE the predicate's try block, and a throw there once
 * escaped the function entirely — which made `held` false while the hold
 * document stood, so the cascade destroyed the rows the hold claimed to keep.
 * A half-held case, produced by a transient error.
 */
async function scenario_ttlPushFailureKeepsTheAnswer(): Promise<void> {
  const { applyErasureHold } = require("../moderation/erasure-hold");

  const store = holdStore("in_review");
  const db = asDb(store) as unknown as Record<string, unknown>;
  const realCollection = db.collection as (name: string) => unknown;
  db.collection = (name: string) => {
    const coll = realCollection.call(db, name) as Record<string, unknown>;
    if (name !== "user_moderation") return coll;
    const realDoc = coll.doc as (id: string) => Record<string, unknown>;
    coll.doc = (id: string) => {
      const doc = realDoc.call(coll, id);
      doc.collection = () => {
        throw Object.assign(new Error("unavailable"), { code: 14 });
      };
      return doc;
    };
    return coll;
  };

  const { retained, ok } = await applyErasureHold(db, UID);

  check(
    "a failed TTL push still returns the hold — losing it would let the " +
      "cascade erase what the hold document says is kept",
    retained.length === 1,
    `got ${JSON.stringify(retained)}`,
  );
  check(
    "and the erasure reports itself incomplete",
    ok === false,
    `ok was ${ok}`,
  );
  check(
    "the hold document stands, NOT provisional — the decision was reached",
    (store.get(`erasure_holds/${UID}`) as { provisional?: boolean })
      ?.provisional === false,
    `got ${JSON.stringify(store.get(`erasure_holds/${UID}`))}`,
  );
  // The control for the arm above: a TTL failure is not an undecidable
  // predicate, so the notice must keep its confident wording.
  check(
    "and the record is NOT provisional — the predicate was answered",
    retained[0].provisional === false,
    `got ${JSON.stringify(retained[0])}`,
  );
}

/**
 * The trigger's guard must not fail closed into a state nothing can recover:
 * with no hold document the sweep never sees the uid, the account is gone, and
 * no probe reaches `reports`. So a read failure leaves a handle.
 */
async function scenario_triggerGuardLeavesAHandleWhenItCannotRead(): Promise<void> {
  const {
    anonymizeReportsUnlessHeldWithDb,
  } = require("../moderation/erasure-hold");

  const store = holdStore("closed");
  const db = asDb(store) as unknown as Record<string, unknown>;
  const realCollection = db.collection as (name: string) => unknown;
  db.collection = (name: string) => {
    const coll = realCollection.call(db, name) as Record<string, unknown>;
    if (name !== "erasure_holds") return coll;
    const realDoc = coll.doc as (id: string) => Record<string, unknown>;
    coll.doc = (id: string) => {
      const doc = realDoc.call(coll, id);
      doc.get = () => {
        throw Object.assign(new Error("unavailable"), { code: 14 });
      };
      return doc;
    };
    return coll;
  };

  await anonymizeReportsUnlessHeldWithDb(db, UID);

  check(
    "an unreadable hold defers the anonymize rather than guessing",
    (store.get("reports/rep1") as { contentOwnerId: string | null })
      .contentOwnerId === UID,
    "the guard anonymized on an unanswerable question",
  );
  check(
    "and leaves a provisional hold, so 'defers to the sweep' is true rather " +
      "than aspirational",
    (store.get(`erasure_holds/${UID}`) as { provisional?: boolean })
      ?.provisional === true,
    `got ${JSON.stringify(store.get(`erasure_holds/${UID}`))}`,
  );
}

/**
 * The lift's re-probe. `anonymizeReportsByContentOwnerWithDb` commits through
 * `commitInChunks` with the default `strict: false`, which SWALLOWS a failed
 * chunk with a warn, and returns rows MATCHED rather than commits that
 * succeeded — so its return value cannot say whether the uid actually went.
 *
 * This stages exactly that: the anonymize runs, reports success, and the row
 * keeps its uid. The lift must refuse. Without the refusal the hold document
 * is deleted and the surviving row is reachable by NOTHING — no cascade (the
 * account is gone), no probe (it has no `reports` leg and ran earlier), no
 * sweep (its only handle was the document just removed).
 */
async function scenario_liftRefusesWhenTheAnonymizeSilentlyFailed(): Promise<void> {
  const { applyErasureHold, liftErasureHold } =
    require("../moderation/erasure-hold");

  const store = holdStore("in_review");
  await applyErasureHold(asDb(store), UID, new Date("2026-09-09T00:00:00Z"));
  store.set("reports/rep1", {
    reporterId: OTHER,
    contentOwnerId: UID,
    status: "closed",
  });

  // Model the swallowed chunk: the batch accepts the update and drops it.
  const db = asDb(store) as unknown as Record<string, unknown>;
  const realBatch = db.batch as () => Record<string, unknown>;
  db.batch = () => {
    const b = realBatch.call(db);
    const realUpdate = b.update as (ref: { path?: string }, d: unknown) => void;
    b.update = (ref: { path?: string }, data: unknown) => {
      if ((ref.path ?? "").startsWith("reports/")) return;
      realUpdate.call(b, ref, data);
    };
    return b;
  };

  const lifted = await liftErasureHold(db, UID);

  check(
    "a lift whose anonymize silently failed REFUSES",
    lifted === false,
    `liftErasureHold returned ${lifted}`,
  );
  check(
    "and the hold document stands, so tomorrow's sweep tries again",
    store.has(`erasure_holds/${UID}`),
    "the hold was released over a row still naming the erased user",
  );
}

/**
 * BOTH Firestore calls in the trigger guard fail — the plausible case, since a
 * read failure and a write failure share one outage.
 *
 * There is no handle left, and that residual is accepted. What must NOT happen
 * is the throw escaping: `cleanupUserSocialData` is a flat sequence of awaits,
 * the gen1 trigger rethrows, and the event is dropped — so the steps behind
 * this one, including `cleanupRecipeCookEvents` and its per-user timestamped
 * PII, would never run and nothing would retry them.
 */
async function scenario_triggerGuardSurvivesADoubleFailure(): Promise<void> {
  const {
    anonymizeReportsUnlessHeldWithDb,
  } = require("../moderation/erasure-hold");

  const store = holdStore("closed");
  const db = asDb(store) as unknown as Record<string, unknown>;
  const realCollection = db.collection as (name: string) => unknown;
  db.collection = (name: string) => {
    const coll = realCollection.call(db, name) as Record<string, unknown>;
    if (name !== "erasure_holds") return coll;
    const realDoc = coll.doc as (id: string) => Record<string, unknown>;
    coll.doc = (id: string) => {
      const doc = realDoc.call(coll, id);
      doc.get = () => {
        throw Object.assign(new Error("unavailable"), { code: 14 });
      };
      return doc;
    };
    return coll;
  };
  // ...and the fallback write fails too.
  db.batch = () => {
    throw Object.assign(new Error("unavailable"), { code: 14 });
  };

  let threw = false;
  try {
    await anonymizeReportsUnlessHeldWithDb(db, UID);
  } catch {
    threw = true;
  }

  check(
    "a doubly-failed guard RETURNS rather than throwing — losing the handle " +
      "is bad, losing every cascade step behind it is worse",
    !threw,
    "the throw escaped into the trigger and dropped the event",
  );
  check(
    "and it still did not anonymize on an unanswerable question",
    (store.get("reports/rep1") as { contentOwnerId: string | null })
      .contentOwnerId === UID,
    "the guard anonymized after failing to read the hold",
  );
}

/**
 * The three bounded branches. Every sibling cap has an
 * `implausible…Declines` scenario; these had none, so widening either cap or
 * deleting the deadline check was green — and the deviation entry rests on all
 * three by name, the deadline being what it says makes first chain position
 * survivable.
 */
async function scenario_holdSweepRespectsItsBounds(): Promise<void> {
  const {
    sweepErasureHolds,
    MAX_ERASURE_HOLD_SWEEP_ROWS,
    applyErasureHold,
    MAX_REPORT_HISTORY_ROWS,
  } = require("../moderation/erasure-hold");

  // 1. Above the row cap the sweep DECLINES — it lifts nothing rather than
  //    truncating, so a hold is never released on a partial read.
  const many = new FakeFirestore();
  for (let i = 0; i <= MAX_ERASURE_HOLD_SWEEP_ROWS; i++) {
    many.set(`erasure_holds/u${i}`, {
      holdUntil: admin.firestore.Timestamp.fromDate(new Date("2020-01-01")),
    });
  }
  const declined = await sweepErasureHolds(asDb(many), new Date());
  check(
    "above the cap the sweep declines rather than truncating",
    declined.declined === true && declined.lifted === 0,
    JSON.stringify(declined),
  );
  check(
    "and it removed nothing",
    many.has("erasure_holds/u0"),
    "a declined sweep still lifted a hold",
  );

  // 2. The wall-clock budget. A zero deadline means every hold defers, and
  //    `examined` must count what was actually looked at rather than the page.
  const two = new FakeFirestore();
  two.set("erasure_holds/a", {
    holdUntil: admin.firestore.Timestamp.fromDate(new Date("2020-01-01")),
  });
  two.set("erasure_holds/b", {
    holdUntil: admin.firestore.Timestamp.fromDate(new Date("2020-01-01")),
  });
  const deferred = await sweepErasureHolds(asDb(two), new Date(), 0);
  check(
    "a run out of budget defers instead of working past its deadline",
    deferred.deferred === true && deferred.lifted === 0,
    JSON.stringify(deferred),
  );
  check(
    "and reports what it actually examined, not the page size",
    deferred.examined === 0,
    `examined ${deferred.examined} of ${2}`,
  );

  // 3. An implausible `report_history` count SKIPS the TTL push and reports the
  //    erasure incomplete — while still returning the hold, so nothing
  //    downstream destroys the evidence.
  const huge = holdStore("in_review");
  for (let i = 0; i <= MAX_REPORT_HISTORY_ROWS; i++) {
    huge.set(`user_moderation/${UID}/report_history/r${i}`, {
      reportId: `r${i}`,
      reporterId: OTHER,
      expireAt: admin.firestore.Timestamp.fromDate(new Date("2026-10-01")),
    });
  }
  const capped = await applyErasureHold(asDb(huge), UID);
  check(
    "an implausible report_history count still HOLDS",
    capped.retained.length === 1,
    JSON.stringify(capped.retained),
  );
  check(
    "and reports the erasure incomplete rather than a silent success",
    capped.ok === false,
    `ok was ${capped.ok}`,
  );
  check(
    "the rows keep their own clock — a partial push is worse than none",
    (
      huge.get(`user_moderation/${UID}/report_history/r0`) as {
        expireAt: admin.firestore.Timestamp;
      }
    ).expireAt.toMillis() === new Date("2026-10-01").getTime(),
    "some rows were pushed above the cap",
  );
}

/**
 * One unlucky hold must not stall every other person's erasure. Without the
 * per-uid try/catch the throw aborts the run, and the same page arrives in the
 * same order tomorrow — so the second hold would never be examined again.
 */
async function scenario_oneBadHoldDoesNotStallTheSweep(): Promise<void> {
  const { sweepErasureHolds } = require("../moderation/erasure-hold");

  const store = new FakeFirestore();
  const past = admin.firestore.Timestamp.fromDate(new Date("2020-01-01"));
  store.set("erasure_holds/aaa", { holdUntil: past });
  store.set("erasure_holds/bbb", { holdUntil: past });

  const db = asDb(store) as unknown as Record<string, unknown>;
  const realCollection = db.collection as (name: string) => unknown;
  db.collection = (name: string) => {
    const coll = realCollection.call(db, name) as Record<string, unknown>;
    if (name !== "system_events") return coll;
    const realWhere = coll.where as (...a: unknown[]) => unknown;
    coll.where = (...a: unknown[]) => {
      if (a[2] === "aaa") {
        throw Object.assign(new Error("unavailable"), { code: 14 });
      }
      return realWhere.apply(coll, a);
    };
    return coll;
  };

  const result = await sweepErasureHolds(db, new Date());

  check(
    "the failing hold is counted rather than aborting the run",
    result.failed === 1,
    JSON.stringify(result),
  );
  check(
    "and the hold AFTER it was still lifted",
    result.lifted === 1 && !store.has("erasure_holds/bbb"),
    JSON.stringify(result),
  );
  check(
    "the failed one keeps its hold, so tomorrow's run tries again",
    store.has("erasure_holds/aaa"),
    "a hold was released by a run that threw on it",
  );
}

async function main(): Promise<void> {
  await scenario_openCaseHoldsTheModerationRecord();
  await scenario_actionedStillCountsAsOpen();
  await scenario_closedCaseDeletesAsBefore();
  await scenario_holdPushesReportHistoryTtlForward();
  await scenario_holdDocumentLivesOutsideUserModeration();
  await scenario_heldRecordIsNotCountedAsResidual();
  await scenario_holdKeepsContentOwnerIdOnSystemEvents();
  await scenario_holdKeepsContentOwnerIdOnReports();
  await scenario_appealsGoByAppellant();
  await scenario_holdFailsClosedWhenItCannotDecide();
  await scenario_holdStagesItsAuditRows();
  await scenario_ttlPushFailureKeepsTheAnswer();
  await scenario_triggerGuardLeavesAHandleWhenItCannotRead();
  await scenario_triggerGuardSurvivesADoubleFailure();
  await scenario_sweepLiftsWhenLastCaseCloses();
  await scenario_sweepLiftsAtTheOuterCap();
  await scenario_liftRefusesWhenTheAnonymizeSilentlyFailed();
  await scenario_holdSweepRespectsItsBounds();
  await scenario_oneBadHoldDoesNotStallTheSweep();

  finishSuite("BUT-1766/BUT-1768 deletion cascade moderation holds");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
