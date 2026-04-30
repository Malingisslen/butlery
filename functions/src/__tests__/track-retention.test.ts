/**
 * BUT-605: Day-N retention tracker tests.
 *
 * Coverage:
 *   1. Day-1 active vs inactive emits with `wasActive` flag.
 *   2. Day-14 active emits a cohort row with lifecycleStage.
 *   3. Day-90 active emits.
 *   4. Day-180 active emits.
 *   5. Day-not-on-schedule (e.g. day 42) emits nothing.
 *   6. Idempotent re-run on the same day overwrites the same doc id
 *      (writeCount=2, unique paths=1).
 *   7. Lifecycle stage classifier rules — recency-first ordering.
 *
 * Run with: npx ts-node src/__tests__/track-retention.test.ts
 */

import {
  runTrackRetention,
  classifyLifecycleStageServer,
} from "../analytics/track-retention";

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

interface FakeUser {
  id: string;
  /** Days before `now` (positive = past). null skips lastActiveAt. */
  joinedDaysAgo: number;
  lastActiveDaysAgo: number;
}

interface DocStore {
  /** Map keyed by doc path → last-written data. */
  data: Map<string, Record<string, unknown>>;
  /** Total `set()` calls across the run (idempotency check). */
  writeCount: number;
  /** Total `commit()` calls (cost / batching check). */
  commitCount: number;
}

function tsFromDaysAgo(now: Date, days: number) {
  const ms = now.getTime() - days * MS_PER_DAY;
  return {
    toMillis: () => ms,
    toDate: () => new Date(ms),
  };
}

function makeFakeDb(users: FakeUser[], now: Date, store: DocStore) {
  // Build fake user docs once.
  const userDocs = users.map((u) => ({
    id: u.id,
    data: () => ({
      joinedAt: tsFromDaysAgo(now, u.joinedDaysAgo),
      lastActiveAt: tsFromDaysAgo(now, u.lastActiveDaysAgo),
    }),
  }));

  function makeUserQuery(startAfterIdx: number) {
    return {
      where() {
        return this;
      },
      orderBy() {
        return this;
      },
      limit() {
        return this;
      },
      startAfter(_lastDoc: { id: string }) {
        const idx = userDocs.findIndex((d) => d.id === _lastDoc.id);
        return makeUserQuery(idx + 1);
      },
      async get() {
        const slice = userDocs.slice(startAfterIdx);
        return { size: slice.length, docs: slice };
      },
    };
  }

  return {
    collection(name: string) {
      if (name === "users") {
        return makeUserQuery(0);
      }
      if (name === "analytics") {
        return makeAnalyticsRoot(store);
      }
      throw new Error(`unexpected collection: ${name}`);
    },
    batch() {
      const ops: { path: string; data: Record<string, unknown> }[] = [];
      return {
        set(ref: { path: string }, data: Record<string, unknown>) {
          ops.push({ path: ref.path, data });
        },
        async commit() {
          for (const op of ops) {
            store.data.set(op.path, op.data);
            store.writeCount++;
          }
          store.commitCount++;
          ops.length = 0;
        },
      };
    },
  };
}

function makeAnalyticsRoot(_store: DocStore) {
  return {
    doc(docId: string) {
      const docPath = `analytics/${docId}`;
      return {
        collection(subName: string) {
          return {
            doc(subId: string) {
              const fullPath = `${docPath}/${subName}/${subId}`;
              return { path: fullPath };
            },
          };
        },
      };
    },
  };
}

async function day1ActiveEmits(): Promise<void> {
  const now = new Date("2026-04-27T06:00:00Z");
  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [
    { id: "uActive", joinedDaysAgo: 1, lastActiveDaysAgo: 0 },
    { id: "uInactive", joinedDaysAgo: 1, lastActiveDaysAgo: 5 },
  ];
  await runTrackRetention({
    db: makeFakeDb(users, now, store) as never,
    now,
  });
  const active = store.data.get(
    "analytics/retention/events/uActive_d1"
  ) as Record<string, unknown> | undefined;
  const inactive = store.data.get(
    "analytics/retention/events/uInactive_d1"
  ) as Record<string, unknown> | undefined;
  const ok =
    active != null &&
    active.wasActive === true &&
    active.day === 1 &&
    inactive != null &&
    inactive.wasActive === false &&
    inactive.day === 1;
  record(
    "day-1 active vs inactive emits both with correct wasActive flag",
    ok,
    `active=${JSON.stringify(active)} inactive=${JSON.stringify(inactive)}`
  );
}

async function day14ActiveEmits(): Promise<void> {
  const now = new Date("2026-04-27T06:00:00Z");
  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [
    { id: "u14", joinedDaysAgo: 14, lastActiveDaysAgo: 0 },
  ];
  await runTrackRetention({
    db: makeFakeDb(users, now, store) as never,
    now,
  });
  const evt = store.data.get("analytics/retention/events/u14_d14") as
    | Record<string, unknown>
    | undefined;
  const ok =
    evt != null &&
    evt.day === 14 &&
    evt.wasActive === true &&
    typeof evt.lifecycleStage === "string";
  record(
    "day-14 active user emits row with lifecycleStage",
    ok,
    `evt=${JSON.stringify(evt)}`
  );
}

async function day90ActiveEmits(): Promise<void> {
  const now = new Date("2026-04-27T06:00:00Z");
  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [
    { id: "u90", joinedDaysAgo: 90, lastActiveDaysAgo: 0 },
    // Inactive 90-day cohort member: joined 90 days ago, last active 60 days ago → churned.
    { id: "u90c", joinedDaysAgo: 90, lastActiveDaysAgo: 60 },
  ];
  await runTrackRetention({
    db: makeFakeDb(users, now, store) as never,
    now,
  });
  const active = store.data.get("analytics/retention/events/u90_d90") as
    | Record<string, unknown>
    | undefined;
  const churned = store.data.get("analytics/retention/events/u90c_d90") as
    | Record<string, unknown>
    | undefined;
  const ok =
    active != null &&
    active.wasActive === true &&
    churned != null &&
    churned.wasActive === false &&
    churned.lifecycleStage === "churned";
  record(
    "day-90 active+churned cohort members each emit",
    ok,
    `active=${JSON.stringify(active)} churned=${JSON.stringify(churned)}`
  );
}

async function day180ActiveEmits(): Promise<void> {
  const now = new Date("2026-04-27T06:00:00Z");
  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [
    { id: "u180", joinedDaysAgo: 180, lastActiveDaysAgo: 0 },
  ];
  await runTrackRetention({
    db: makeFakeDb(users, now, store) as never,
    now,
  });
  const evt = store.data.get("analytics/retention/events/u180_d180") as
    | Record<string, unknown>
    | undefined;
  const ok = evt != null && evt.day === 180 && evt.wasActive === true;
  record(
    "day-180 active user emits row",
    ok,
    `evt=${JSON.stringify(evt)}`
  );
}

async function nonScheduledDaySkipped(): Promise<void> {
  const now = new Date("2026-04-27T06:00:00Z");
  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [
    { id: "uOffSchedule", joinedDaysAgo: 42, lastActiveDaysAgo: 0 },
    { id: "uOffSchedule2", joinedDaysAgo: 100, lastActiveDaysAgo: 0 },
  ];
  await runTrackRetention({
    db: makeFakeDb(users, now, store) as never,
    now,
  });
  const ok = store.data.size === 0 && store.writeCount === 0;
  record(
    "user not on day {1,7,14,30,90,180} emits nothing",
    ok,
    `size=${store.data.size} writes=${store.writeCount}`
  );
}

async function idempotentRerun(): Promise<void> {
  const now = new Date("2026-04-27T06:00:00Z");
  const store: DocStore = { data: new Map(), writeCount: 0, commitCount: 0 };
  const users: FakeUser[] = [
    { id: "u30", joinedDaysAgo: 30, lastActiveDaysAgo: 0 },
  ];
  await runTrackRetention({
    db: makeFakeDb(users, now, store) as never,
    now,
  });
  await runTrackRetention({
    db: makeFakeDb(users, now, store) as never,
    now,
  });
  // Same UTC day → deterministic doc id `u30_d30` overwritten on second run.
  const ok = store.data.size === 1 && store.writeCount === 2;
  record(
    "idempotent same-day re-run: writeCount=2 paths=1",
    ok,
    `size=${store.data.size} writes=${store.writeCount}`
  );
}

function lifecycleClassifier(): void {
  const nowMs = new Date("2026-04-27T06:00:00Z").getTime();

  const churned = classifyLifecycleStageServer({
    joinedAtMs: nowMs - 100 * MS_PER_DAY,
    lastActiveAtMs: nowMs - 35 * MS_PER_DAY,
    nowMs,
  });
  record(
    "classifier: lastActive >30d ago → churned",
    churned === "churned",
    `got ${churned}`
  );

  const dormant = classifyLifecycleStageServer({
    joinedAtMs: nowMs - 100 * MS_PER_DAY,
    lastActiveAtMs: nowMs - 20 * MS_PER_DAY,
    nowMs,
  });
  record(
    "classifier: lastActive 14-30d ago → dormant",
    dormant === "dormant",
    `got ${dormant}`
  );

  const habitual = classifyLifecycleStageServer({
    joinedAtMs: nowMs - 60 * MS_PER_DAY,
    lastActiveAtMs: nowMs - 1 * MS_PER_DAY,
    nowMs,
  });
  record(
    "classifier: signup>7d + lastActive<=7d → habitual",
    habitual === "habitual",
    `got ${habitual}`
  );

  const activated = classifyLifecycleStageServer({
    joinedAtMs: nowMs - 3 * MS_PER_DAY,
    lastActiveAtMs: nowMs - 1 * MS_PER_DAY,
    nowMs,
  });
  record(
    "classifier: signup<=7d + active → activated",
    activated === "activated",
    `got ${activated}`
  );

  const newUser = classifyLifecycleStageServer({
    joinedAtMs: null,
    lastActiveAtMs: null,
    nowMs,
  });
  record(
    "classifier: missing joinedAt → new",
    newUser === "new",
    `got ${newUser}`
  );
}

async function runAll(): Promise<void> {
  console.log("BUT-605: Day-N retention tracker tests\n");
  console.log("==============================================\n");
  await day1ActiveEmits();
  await day14ActiveEmits();
  await day90ActiveEmits();
  await day180ActiveEmits();
  await nonScheduledDaySkipped();
  await idempotentRerun();
  lifecycleClassifier();

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : "")
  );
  if (totalFailed > 0) process.exit(1);
}

runAll().catch((err) => {
  console.error(err);
  process.exit(1);
});
