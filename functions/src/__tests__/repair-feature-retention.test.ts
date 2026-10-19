/**
 * One-shot repair of the `cooked` / `shared` feature-retention flags.
 *
 * Coverage:
 *   1. A stored false with activity that day becomes true; the aggregate of
 *      that day and of a later day whose windows cover it gain the change, and
 *      the three flags the repair does not own keep their stored counts.
 *   2. A user already seen in the window earlier moves `dau` but not the
 *      rollups.
 *   3. A second run finds nothing to change (idempotent).
 *   4. A dry run reports the same counts and writes nothing.
 *   5. Activity by a user with no row that day creates no row, and a stored
 *      true with no activity stays true.
 *   6. A probe that still throws stops the run before any write and reports
 *      the code and the decoded index spec.
 *   7. A row erased between the read and the write fails the whole batch:
 *      no row and no aggregate changes, and the error names no document.
 *   8. The rollup windows end at offsets 6 and 27, as the nightly job's do.
 *   9. `apply` is refused around the 06:00 UTC nightly run.
 *
 * Run with: npx ts-node src/__tests__/repair-feature-retention.test.ts
 */

import {
  repairFeatureRetentionFlags,
  RepairProbeError,
  decodeCreateCompositeSpec,
} from "../analytics/repair-feature-retention";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

let totalRun = 0;
let totalFailed = 0;

function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

interface Activity {
  source: "cook_snaps" | "shared_content";
  userId: string;
  ts: number;
  contentType?: string;
}

interface Filter {
  field: string;
  op: string;
  value: unknown;
}

function millisOf(v: unknown): number {
  return (v as { toMillis: () => number }).toMillis();
}

const USERS_PREFIX = "analytics/feature_retention/users/";
const DAILY_PREFIX = "analytics/feature_retention/daily/";

function makeDb(args: {
  docs: Map<string, Record<string, unknown>>;
  activity: Activity[];
  failSource?: { source: string; error: Error };
  /** Deleted after every read, before the batch commits. */
  eraseBeforeCommit?: string;
}) {
  const { docs, activity } = args;
  let commits = 0;

  function query(path: string, filters: Filter[]): Record<string, unknown> {
    return {
      where(field: string, op: string, value: unknown) {
        return query(path, [...filters, { field, op, value }]);
      },
      limit() {
        return query(path, filters);
      },
      async get() {
        if (path === "cook_snaps" || path === "shared_content") {
          if (args.failSource?.source === path) throw args.failSource.error;
          const matches = activity.filter((a) => {
            if (a.source !== path) return false;
            return filters.every((f) => {
              if (f.field === "userId" || f.field === "sharedByUserId") {
                return a.userId === f.value;
              }
              if (f.field === "contentType") return a.contentType === f.value;
              if (f.op === ">=") return a.ts >= millisOf(f.value);
              if (f.op === "<") return a.ts < millisOf(f.value);
              return false;
            });
          });
          return { size: matches.length, docs: matches };
        }
        const prefix = `${path}/`;
        const found = [...docs.entries()]
          .filter(([p]) => p.startsWith(prefix) && !p.slice(prefix.length).includes("/"))
          .filter(([, d]) =>
            filters.every((f) =>
              f.op === "=="
                ? d[f.field] === f.value
                : f.op === ">="
                ? String(d[f.field]) >= String(f.value)
                : false,
            ),
          )
          .map(([p, d]) => ({ id: p.slice(prefix.length), ref: ref(p), data: () => d }));
        return { size: found.length, docs: found };
      },
    };
  }

  function ref(path: string) {
    return {
      path,
      collection(sub: string) {
        return collection(`${path}/${sub}`);
      },
    };
  }

  function collection(path: string): Record<string, unknown> {
    return {
      ...query(path, []),
      doc(id: string) {
        return ref(`${path}/${id}`);
      },
    };
  }

  const db = {
    collection(name: string) {
      return collection(name);
    },
    batch() {
      const ops: Array<{ path: string; data: Record<string, unknown> }> = [];
      return {
        update(r: { path: string }, data: Record<string, unknown>) {
          ops.push({ path: r.path, data });
        },
        async commit() {
          if (args.eraseBeforeCommit) docs.delete(args.eraseBeforeCommit);
          // All or nothing, as Firestore: one missing document fails the batch.
          for (const op of ops) {
            if (!docs.has(op.path)) {
              // Firestore's own message names the missing document.
              const err = new Error(
                `5 NOT_FOUND: no entity to update: ${op.path}`,
              ) as Error & { code: number };
              err.code = 5;
              throw err;
            }
          }
          for (const op of ops) {
            const doc = { ...docs.get(op.path)! };
            for (const [key, value] of Object.entries(op.data)) {
              const dot = key.indexOf(".");
              if (dot < 0) {
                doc[key] = value;
              } else {
                const group = key.slice(0, dot);
                doc[group] = {
                  ...(doc[group] as Record<string, unknown>),
                  [key.slice(dot + 1)]: value,
                };
              }
            }
            docs.set(op.path, doc);
          }
          commits++;
        },
      };
    },
  };
  return { db, commits: () => commits };
}

const DAY0 = Date.UTC(2026, 9, 4);
function day(offset: number): string {
  return new Date(DAY0 + offset * MS_PER_DAY).toISOString().slice(0, 10);
}
function at(offset: number): number {
  return DAY0 + offset * MS_PER_DAY + 12 * 60 * 60 * 1000;
}
const NOW = new Date(DAY0 + 20 * MS_PER_DAY);

function row(
  docs: Map<string, Record<string, unknown>>,
  userId: string,
  offset: number,
  flags: Partial<Record<"cooked" | "imported" | "shared" | "mealPlanned" | "shopped", boolean>> = {},
): void {
  docs.set(`${USERS_PREFIX}${userId}_${day(offset)}`, {
    userId,
    date: day(offset),
    cooked: false,
    imported: false,
    shared: false,
    mealPlanned: false,
    shopped: false,
    ...flags,
  });
}

function aggregate(
  docs: Map<string, Record<string, unknown>>,
  offset: number,
  counts: Record<string, number> = {},
): void {
  const c = { cooked: 0, imported: 0, shared: 0, mealPlanned: 0, shopped: 0, ...counts };
  docs.set(`${DAILY_PREFIX}${day(offset)}`, {
    date: day(offset),
    dau: { ...c },
    wau7d: { ...c },
    wau28d: { ...c },
  });
}

function agg(docs: Map<string, Record<string, unknown>>, offset: number) {
  return docs.get(`${DAILY_PREFIX}${day(offset)}`) as {
    dau: Record<string, number>;
    wau7d: Record<string, number>;
    wau28d: Record<string, number>;
  };
}

function flagsOf(docs: Map<string, Record<string, unknown>>, userId: string, offset: number) {
  return docs.get(`${USERS_PREFIX}${userId}_${day(offset)}`);
}

async function flipsAndRollups(): Promise<void> {
  const docs = new Map<string, Record<string, unknown>>();
  row(docs, "uA", 0, { imported: true });
  row(docs, "uA", 3);
  aggregate(docs, 0, { imported: 1 });
  aggregate(docs, 3, { imported: 0 });
  const { db } = makeDb({
    docs,
    activity: [
      { source: "cook_snaps", userId: "uA", ts: at(0) },
      { source: "shared_content", userId: "uA", ts: at(0), contentType: "recipe" },
    ],
  });

  const report = await repairFeatureRetentionFlags({
    db: db as never,
    from: day(0),
    to: day(3),
    apply: true,
    now: NOW,
  });

  const r0 = flagsOf(docs, "uA", 0);
  const a0 = agg(docs, 0);
  const a3 = agg(docs, 3);
  record(
    "a stored false with activity that day becomes true",
    r0?.cooked === true && r0?.shared === true && r0?.imported === true,
    JSON.stringify(r0),
  );
  record(
    "that day's aggregate gains dau, wau7d and wau28d for both flags",
    a0.dau.cooked === 1 && a0.dau.shared === 1 &&
      a0.wau7d.cooked === 1 && a0.wau28d.shared === 1,
    JSON.stringify(a0),
  );
  record(
    "a later aggregate whose windows cover the day gains the rollups, not dau",
    a3.dau.cooked === 0 && a3.wau7d.cooked === 1 && a3.wau28d.cooked === 1,
    JSON.stringify(a3),
  );
  record(
    "flags the repair does not own keep their stored counts",
    a0.dau.imported === 1 && a0.wau28d.imported === 1 && a3.dau.imported === 0,
    JSON.stringify(a0),
  );
  record(
    "the report counts one row write and two aggregate writes",
    report.rowWrites === 1 && report.aggregateWrites === 2,
    JSON.stringify(report),
  );

  const again = await repairFeatureRetentionFlags({
    db: db as never,
    from: day(0),
    to: day(3),
    apply: true,
    now: NOW,
  });
  record(
    "a second run finds nothing to change",
    again.rowWrites === 0 && again.aggregateWrites === 0 && agg(docs, 0).dau.cooked === 1,
    JSON.stringify(again),
  );
}

async function alreadySeenInWindow(): Promise<void> {
  const docs = new Map<string, Record<string, unknown>>();
  row(docs, "uB", -2, { cooked: true });
  row(docs, "uB", 0);
  aggregate(docs, 0, { cooked: 1 });
  const { db } = makeDb({
    docs,
    activity: [{ source: "cook_snaps", userId: "uB", ts: at(0) }],
  });

  await repairFeatureRetentionFlags({
    db: db as never,
    from: day(0),
    to: day(0),
    apply: true,
    now: NOW,
  });

  const a0 = agg(docs, 0);
  record(
    "a user already seen earlier in the window moves dau, not the rollups",
    a0.dau.cooked === 2 && a0.wau7d.cooked === 1 && a0.wau28d.cooked === 1,
    JSON.stringify(a0),
  );
}

async function dryRunWritesNothing(): Promise<void> {
  const docs = new Map<string, Record<string, unknown>>();
  row(docs, "uC", 0);
  aggregate(docs, 0);
  const { db, commits } = makeDb({
    docs,
    activity: [{ source: "cook_snaps", userId: "uC", ts: at(0) }],
  });

  const report = await repairFeatureRetentionFlags({
    db: db as never,
    from: day(0),
    to: day(0),
    apply: false,
    now: NOW,
  });

  record(
    "a dry run reports the flips and writes nothing",
    report.days[0].flips.cooked === 1 &&
      report.aggregates[0].dau.cooked === 1 &&
      commits() === 0 &&
      flagsOf(docs, "uC", 0)?.cooked === false &&
      agg(docs, 0).dau.cooked === 0,
    JSON.stringify(report),
  );
}

async function noRowNoWriteAndNeverFalse(): Promise<void> {
  const docs = new Map<string, Record<string, unknown>>();
  row(docs, "uD", 0, { shared: true });
  aggregate(docs, 0, { shared: 1 });
  const { db } = makeDb({
    docs,
    activity: [
      { source: "cook_snaps", userId: "uNoRow", ts: at(0) },
      { source: "shared_content", userId: "uD", ts: at(0), contentType: "menu" },
    ],
  });

  const report = await repairFeatureRetentionFlags({
    db: db as never,
    from: day(0),
    to: day(0),
    apply: true,
    now: NOW,
  });

  record(
    "activity by a user without a row that day creates no row",
    !docs.has(`${USERS_PREFIX}uNoRow_${day(0)}`) && report.rowWrites === 0,
    JSON.stringify(report),
  );
  record(
    "a stored true with no activity stays true",
    flagsOf(docs, "uD", 0)?.shared === true && agg(docs, 0).dau.shared === 1,
    JSON.stringify(flagsOf(docs, "uD", 0)),
  );
}

function compositeError(): Error {
  const spec = Buffer.from(
    "\n@projects/butlery-app-1/databases/(default)/collectionGroups/cook_snaps/indexes/_" +
      "\u0010\u0001\u001a\n\n\u0006userId\u0010\u0001\u001a\r\n\tcreatedAt\u0010\u0001",
    "latin1",
  ).toString("base64url");
  const err = new Error(
    "9 FAILED_PRECONDITION: The query requires an index. You can create it here: " +
      "https://console.firebase.google.com/v1/r/project/butlery-app-1/firestore/indexes?create_composite=" +
      spec,
  ) as Error & { code: number };
  err.code = 9;
  return err;
}

async function probeErrorStopsTheRun(): Promise<void> {
  const docs = new Map<string, Record<string, unknown>>();
  row(docs, "uE", 0);
  row(docs, "uF", 1);
  aggregate(docs, 0);
  const { db, commits } = makeDb({
    docs,
    activity: [{ source: "shared_content", userId: "uF", ts: at(1), contentType: "recipe" }],
    failSource: { source: "cook_snaps", error: compositeError() },
  });

  let caught: unknown;
  try {
    await repairFeatureRetentionFlags({
      db: db as never,
      from: day(0),
      to: day(1),
      apply: true,
      now: NOW,
    });
  } catch (err) {
    caught = err;
  }

  const e = caught as RepairProbeError;
  record(
    "a probe that still throws stops the run with its code and index spec",
    caught instanceof RepairProbeError &&
      e.flag === "cooked" &&
      e.code === 9 &&
      e.indexSpec.includes("collectionGroups/cook_snaps/indexes/_") &&
      e.indexSpec.includes("userId") &&
      e.indexSpec.includes("createdAt"),
    JSON.stringify({ flag: e?.flag, code: e?.code, spec: e?.indexSpec }),
  );
  record(
    "nothing is written when a probe throws",
    commits() === 0 && flagsOf(docs, "uF", 1)?.shared === false,
    `commits=${commits()}`,
  );
  record(
    "the decoded spec carries no project path",
    !decodeCreateCompositeSpec(compositeError().message).some((s) =>
      s.includes("butlery-app-1"),
    ),
    JSON.stringify(decodeCreateCompositeSpec(compositeError().message)),
  );
}

async function erasedRowFailsTheBatch(): Promise<void> {
  const docs = new Map<string, Record<string, unknown>>();
  row(docs, "uG", 0);
  row(docs, "uH", 0);
  aggregate(docs, 0);
  const { db } = makeDb({
    docs,
    activity: [
      { source: "cook_snaps", userId: "uG", ts: at(0) },
      { source: "cook_snaps", userId: "uH", ts: at(0) },
    ],
    eraseBeforeCommit: `${USERS_PREFIX}uG_${day(0)}`,
  });

  let threw = false;
  let message = "";
  try {
    await repairFeatureRetentionFlags({
      db: db as never,
      from: day(0),
      to: day(0),
      apply: true,
      now: NOW,
    });
  } catch (err) {
    threw = true;
    message = String((err as Error).message);
  }

  record(
    "a row erased before the write fails the whole batch, recreating nothing",
    threw &&
      !docs.has(`${USERS_PREFIX}uG_${day(0)}`) &&
      flagsOf(docs, "uH", 0)?.cooked === false &&
      agg(docs, 0).dau.cooked === 0,
    `threw=${threw}`,
  );
  record(
    "the batch failure names no document, so no uid reaches the log",
    threw && !message.includes("uG") && !message.includes("uH"),
    message,
  );
}

/**
 * The rollup windows end exactly where the nightly job's do: a stored true
 * 6 days back is inside wau7d, 7 days back is not; 27 days back is inside
 * wau28d, 28 days back is not.
 */
async function windowEdges(): Promise<void> {
  const cases: Array<{ back: number; wau7d: number; wau28d: number }> = [
    { back: 6, wau7d: 0, wau28d: 0 },
    { back: 7, wau7d: 1, wau28d: 0 },
    { back: 27, wau7d: 1, wau28d: 0 },
    { back: 28, wau7d: 1, wau28d: 1 },
  ];
  for (const c of cases) {
    const docs = new Map<string, Record<string, unknown>>();
    row(docs, "uW", -c.back, { cooked: true });
    row(docs, "uW", 0);
    aggregate(docs, 0);
    const { db } = makeDb({
      docs,
      activity: [{ source: "cook_snaps", userId: "uW", ts: at(0) }],
    });
    const report = await repairFeatureRetentionFlags({
      db: db as never,
      from: day(0),
      to: day(0),
      apply: false,
      now: NOW,
    });
    const a = report.aggregates[0];
    record(
      `a stored true ${c.back} days back moves wau7d by ${c.wau7d} and wau28d by ${c.wau28d}`,
      a?.dau.cooked === 1 && a?.wau7d.cooked === c.wau7d && a?.wau28d.cooked === c.wau28d,
      JSON.stringify(a),
    );
  }
}

async function applyRefusedAroundNightlyRun(): Promise<void> {
  const docs = new Map<string, Record<string, unknown>>();
  row(docs, "uN", 0);
  aggregate(docs, 0);
  const { db, commits } = makeDb({
    docs,
    activity: [{ source: "cook_snaps", userId: "uN", ts: at(0) }],
  });
  const at0600 = new Date(NOW.getTime() + 6 * 60 * 60 * 1000);
  let refused = false;
  try {
    await repairFeatureRetentionFlags({
      db: db as never,
      from: day(0),
      to: day(0),
      apply: true,
      now: at0600,
    });
  } catch {
    refused = true;
  }
  const dry = await repairFeatureRetentionFlags({
    db: db as never,
    from: day(0),
    to: day(0),
    apply: false,
    now: at0600,
  });
  record(
    "apply is refused at 06:00 UTC, a dry run is not",
    refused && commits() === 0 && dry.days[0].flips.cooked === 1,
    `refused=${refused} commits=${commits()}`,
  );
}

async function runAll(): Promise<void> {
  console.log("Feature retention repair (cooked/shared)\n");
  await flipsAndRollups();
  await alreadySeenInWindow();
  await dryRunWritesNothing();
  await noRowNoWriteAndNeverFalse();
  await probeErrorStopsTheRun();
  await erasedRowFailsTheBatch();
  await windowEdges();
  await applyRefusedAroundNightlyRun();
  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : ""),
  );
  if (totalFailed > 0) process.exit(1);
}

runAll().catch((err) => {
  console.error(err);
  process.exit(1);
});
