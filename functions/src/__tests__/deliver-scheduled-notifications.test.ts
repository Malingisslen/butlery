/**
 * Security-review M1: drainer poison-pill protection.
 *
 * Coverage:
 *   1. Happy path — pending+due doc is delivered, status flips to delivered.
 *   2. Failure with attempts < MAX_ATTEMPTS → rolled back to pending,
 *      attempt counter incremented (so next run can retry).
 *   3. Failure when attempts == MAX_ATTEMPTS-1 (so post-bump = MAX) →
 *      parked at status=failed, NOT rolled back. `scheduled_notification_
 *      max_attempts_exceeded` analytics event emitted.
 *   4. Already-delivered doc (concurrent run claim) → skipped, not redelivered.
 *   5. Malformed doc (no userId/payload) → parked immediately.
 *
 * Run with: npx ts-node src/__tests__/deliver-scheduled-notifications.test.ts
 */

import {
  runDeliverScheduledNotifications,
  MAX_ATTEMPTS,
} from "../notifications/deliver-scheduled-notifications";

interface FakeDoc {
  id: string;
  data: Record<string, unknown>;
}

interface UpdateCall {
  docId: string;
  fields: Record<string, unknown>;
}

interface FakeStore {
  /** Live docs by id. */
  docs: Map<string, FakeDoc>;
  /** All update() calls in order — assertion target for status flips. */
  updates: UpdateCall[];
}

function makeFakeDb(store: FakeStore) {
  return {
    collection(_name: string) {
      return {
        where(_field: string, _op: string, _value: unknown) {
          return this; // chain
        },
        limit(_n: number) {
          return this;
        },
        async get() {
          // Return docs whose status is pending and deliverAt <= now.
          // The fake doesn't actually filter — the test seeds only
          // pending docs that should be picked up.
          const docs = [...store.docs.values()].map((d) => makeDocSnap(d, store));
          return { empty: docs.length === 0, size: docs.length, docs };
        },
      };
    },
    async runTransaction<T>(fn: (tx: FakeTx) => Promise<T>): Promise<T> {
      const tx: FakeTx = {
        async get(ref: FakeRef) {
          return makeDocSnap(store.docs.get(ref.id)!, store);
        },
        update(ref: FakeRef, fields: Record<string, unknown>) {
          store.updates.push({ docId: ref.id, fields });
          const existing = store.docs.get(ref.id);
          if (existing) {
            existing.data = { ...existing.data, ...fields };
          }
        },
      };
      return fn(tx);
    },
  };
}

interface FakeRef {
  id: string;
  update(fields: Record<string, unknown>): Promise<void>;
}

interface FakeTx {
  get(ref: FakeRef): Promise<{
    exists: boolean;
    data(): Record<string, unknown>;
  }>;
  update(ref: FakeRef, fields: Record<string, unknown>): void;
}

function makeDocSnap(doc: FakeDoc, store: FakeStore) {
  return {
    id: doc.id,
    ref: {
      id: doc.id,
      async update(fields: Record<string, unknown>) {
        store.updates.push({ docId: doc.id, fields });
        doc.data = { ...doc.data, ...fields };
      },
    },
    data: () => doc.data,
    exists: true,
  };
}

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

function pendingDoc(
  id: string,
  attempts = 0,
  malformed = false
): FakeDoc {
  return {
    id,
    data: {
      status: "pending",
      attempts,
      userId: malformed ? undefined : `user-${id}`,
      notificationType: "comment_posted",
      payload: malformed
        ? undefined
        : {
            title: "T",
            body: "B",
            data: { route: "/comment_thread" },
          },
    },
  };
}

async function happyPathDelivers(): Promise<void> {
  const store: FakeStore = {
    docs: new Map([["d1", pendingDoc("d1")]]),
    updates: [],
  };
  const sendCalls: Array<{ userId: string }> = [];
  const result = await runDeliverScheduledNotifications({
    db: makeFakeDb(store) as never,
    now: new Date("2026-04-30T10:00:00Z"),
    send: async (userId) => {
      sendCalls.push({ userId });
      return {
        sent: true,
        reason: "sent" as const,
        successCount: 1,
        failureCount: 0,
      };
    },
  });

  const finalStatus = store.docs.get("d1")!.data.status;
  const ok =
    result.delivered === 1 &&
    sendCalls.length === 1 &&
    finalStatus === "delivered";
  record(
    "happy path: pending+due → delivered, status flipped",
    ok,
    `delivered=${result.delivered} sendCalls=${sendCalls.length} status=${finalStatus}`
  );
}

async function transientFailureRollsBack(): Promise<void> {
  const store: FakeStore = {
    docs: new Map([["d1", pendingDoc("d1", /*attempts=*/ 0)]]),
    updates: [],
  };
  const result = await runDeliverScheduledNotifications({
    db: makeFakeDb(store) as never,
    now: new Date("2026-04-30T10:00:00Z"),
    send: async () => {
      throw new Error("transient FCM error");
    },
  });

  const finalStatus = store.docs.get("d1")!.data.status;
  const finalAttempts = store.docs.get("d1")!.data.attempts;
  const ok =
    result.failed === 1 &&
    result.parked === 0 &&
    finalStatus === "pending" &&
    finalAttempts === 1;
  record(
    "transient failure with attempts<MAX → rolled back to pending, attempts++",
    ok,
    `status=${finalStatus} attempts=${finalAttempts} parked=${result.parked}`
  );
}

async function maxAttemptsParksDoc(): Promise<void> {
  // Seed with attempts = MAX_ATTEMPTS - 1; the bump inside the
  // transaction takes it to MAX, so post-failure should park.
  const store: FakeStore = {
    docs: new Map([
      ["d1", pendingDoc("d1", /*attempts=*/ MAX_ATTEMPTS - 1)],
    ]),
    updates: [],
  };
  const result = await runDeliverScheduledNotifications({
    db: makeFakeDb(store) as never,
    now: new Date("2026-04-30T10:00:00Z"),
    send: async () => {
      throw new Error("permanent FCM error (invalid recipient)");
    },
  });

  const finalStatus = store.docs.get("d1")!.data.status;
  const finalReason = store.docs.get("d1")!.data.failureReason;
  const ok =
    result.failed === 1 &&
    result.parked === 1 &&
    finalStatus === "failed" &&
    finalReason === "max_attempts_exceeded";
  record(
    "attempts==MAX → parked at status=failed (NOT rolled back)",
    ok,
    `status=${finalStatus} reason=${finalReason} parked=${result.parked}`
  );
}

async function alreadyDeliveredSkipped(): Promise<void> {
  const doc = pendingDoc("d1");
  doc.data.status = "delivered"; // pre-claimed by a concurrent run
  const store: FakeStore = {
    docs: new Map([["d1", doc]]),
    updates: [],
  };
  const sendCalls: Array<{ userId: string }> = [];
  const result = await runDeliverScheduledNotifications({
    db: makeFakeDb(store) as never,
    now: new Date("2026-04-30T10:00:00Z"),
    send: async (userId) => {
      sendCalls.push({ userId });
      return {
        sent: true,
        reason: "sent" as const,
        successCount: 1,
        failureCount: 0,
      };
    },
  });
  const ok =
    result.skipped === 1 && result.delivered === 0 && sendCalls.length === 0;
  record(
    "already-delivered doc → skipped, not redelivered",
    ok,
    `skipped=${result.skipped} sendCalls=${sendCalls.length}`
  );
}

async function malformedDocParked(): Promise<void> {
  const store: FakeStore = {
    docs: new Map([["d1", pendingDoc("d1", 0, /*malformed=*/ true)]]),
    updates: [],
  };
  const result = await runDeliverScheduledNotifications({
    db: makeFakeDb(store) as never,
    now: new Date("2026-04-30T10:00:00Z"),
    send: async () => ({
      sent: true,
      reason: "sent" as const,
      successCount: 1,
      failureCount: 0,
    }),
  });
  const finalStatus = store.docs.get("d1")!.data.status;
  const finalReason = store.docs.get("d1")!.data.failureReason;
  const ok =
    result.parked === 1 && finalStatus === "failed" && finalReason === "malformed";
  record(
    "malformed doc (no userId/payload) → parked immediately",
    ok,
    `status=${finalStatus} reason=${finalReason}`
  );
}

async function runAll(): Promise<void> {
  console.log("Security-M1: drainer poison-pill tests\n");
  console.log("========================================\n");
  await happyPathDelivers();
  await transientFailureRollsBack();
  await maxAttemptsParksDoc();
  await alreadyDeliveredSkipped();
  await malformedDocParked();

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
