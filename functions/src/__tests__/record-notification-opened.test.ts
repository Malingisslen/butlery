/**
 * Security-review C1: `recordNotificationOpened` callable + dedup contract.
 *
 * Coverage (8 cases):
 *   1. Happy path — first call writes a doc with the right schema.
 *   2. Dedup — second call with same (userId, notificationId) is a no-op
 *      (recorded=false, no second write).
 *   3. Different users with the same notificationId DO get separate docs
 *      (deterministic id includes uid).
 *   4. Different notificationIds for the same user DO get separate docs.
 *   5. Validation: missing notificationId throws.
 *   6. Validation: missing notificationType throws.
 *   7. Validation: notificationId with `/` is sanitized into the doc id
 *      (Firestore reserves `/`).
 *   8. expireAt is stamped at openedAt + 30 days.
 *
 * **Why this test matters specifically (regression guard)**: the security
 * review caught a "producerless aggregator" — `suppressLowPerformers`
 * reads `notification_opened_events` but no code wrote it. This test pins
 * that the writer exists and emits the schema the aggregator expects, so
 * the same wire-up gap can't regress silently.
 *
 * Run with: npx ts-node src/__tests__/record-notification-opened.test.ts
 */

import { runRecordNotificationOpened } from "../notifications/record-notification-opened";

interface FakeDoc {
  exists: boolean;
  data?: Record<string, unknown>;
}

interface FakeRefCalls {
  gets: number;
  sets: Array<Record<string, unknown>>;
}

interface FakeStore {
  /** path → doc */
  docs: Map<string, FakeDoc>;
  /** path → call counts */
  refs: Map<string, FakeRefCalls>;
}

function makeFakeDb(store: FakeStore) {
  return {
    collection(_name: string) {
      return {
        doc(docId: string) {
          const path = `notification_opened_events/${docId}`;
          if (!store.refs.has(path)) {
            store.refs.set(path, { gets: 0, sets: [] });
          }
          const refCalls = store.refs.get(path)!;
          return {
            async get() {
              refCalls.gets++;
              const fake = store.docs.get(path);
              return {
                exists: fake?.exists ?? false,
                data: () => fake?.data ?? {},
              };
            },
            async set(data: Record<string, unknown>) {
              refCalls.sets.push(data);
              store.docs.set(path, { exists: true, data });
            },
          };
        },
      };
    },
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

async function happyPathWritesDoc(): Promise<void> {
  const store: FakeStore = { docs: new Map(), refs: new Map() };
  const now = new Date("2026-04-30T10:00:00Z");
  const out = await runRecordNotificationOpened(
    "user-1",
    {
      notificationId: "msg-abc",
      notificationType: "comment_posted",
      route: "/comment_thread",
    },
    { db: makeFakeDb(store) as never, now }
  );
  const path = "notification_opened_events/user-1_msg-abc";
  const written = store.refs.get(path)?.sets[0];
  const ok =
    out.success &&
    out.recorded &&
    !!written &&
    written.userId === "user-1" &&
    written.notificationId === "msg-abc" &&
    written.notificationType === "comment_posted" &&
    written.route === "/comment_thread";
  record(
    "happy path: writes doc with correct schema",
    ok,
    `recorded=${out.recorded} written=${JSON.stringify(written)}`
  );
}

async function dedupSecondCallNoop(): Promise<void> {
  const store: FakeStore = { docs: new Map(), refs: new Map() };
  const now = new Date("2026-04-30T10:00:00Z");
  await runRecordNotificationOpened(
    "user-1",
    { notificationId: "msg-abc", notificationType: "comment_posted" },
    { db: makeFakeDb(store) as never, now }
  );
  const out2 = await runRecordNotificationOpened(
    "user-1",
    { notificationId: "msg-abc", notificationType: "comment_posted" },
    { db: makeFakeDb(store) as never, now }
  );
  const path = "notification_opened_events/user-1_msg-abc";
  const sets = store.refs.get(path)?.sets ?? [];
  const ok = !out2.recorded && sets.length === 1;
  record(
    "dedup: second call for same (uid, notificationId) is recorded=false, no second write",
    ok,
    `recorded2=${out2.recorded} sets=${sets.length}`
  );
}

async function differentUsersSeparateDocs(): Promise<void> {
  const store: FakeStore = { docs: new Map(), refs: new Map() };
  const now = new Date("2026-04-30T10:00:00Z");
  await runRecordNotificationOpened(
    "user-1",
    { notificationId: "msg-abc", notificationType: "comment_posted" },
    { db: makeFakeDb(store) as never, now }
  );
  const out2 = await runRecordNotificationOpened(
    "user-2",
    { notificationId: "msg-abc", notificationType: "comment_posted" },
    { db: makeFakeDb(store) as never, now }
  );
  const ok = out2.recorded && store.refs.size === 2;
  record(
    "different users with same notificationId → separate docs",
    ok,
    `pathsWritten=${store.refs.size}`
  );
}

async function differentNotificationsSeparateDocs(): Promise<void> {
  const store: FakeStore = { docs: new Map(), refs: new Map() };
  const now = new Date("2026-04-30T10:00:00Z");
  await runRecordNotificationOpened(
    "user-1",
    { notificationId: "msg-abc", notificationType: "comment_posted" },
    { db: makeFakeDb(store) as never, now }
  );
  const out2 = await runRecordNotificationOpened(
    "user-1",
    { notificationId: "msg-xyz", notificationType: "comment_posted" },
    { db: makeFakeDb(store) as never, now }
  );
  const ok = out2.recorded && store.refs.size === 2;
  record(
    "same user, different notificationIds → separate docs",
    ok,
    `pathsWritten=${store.refs.size}`
  );
}

async function missingNotificationIdThrows(): Promise<void> {
  const store: FakeStore = { docs: new Map(), refs: new Map() };
  let threw = false;
  try {
    await runRecordNotificationOpened(
      "user-1",
      { notificationId: "", notificationType: "comment_posted" },
      { db: makeFakeDb(store) as never }
    );
  } catch (e) {
    threw = e instanceof Error && e.message.includes("notificationId");
  }
  record("missing notificationId → throws", threw);
}

async function missingNotificationTypeThrows(): Promise<void> {
  const store: FakeStore = { docs: new Map(), refs: new Map() };
  let threw = false;
  try {
    await runRecordNotificationOpened(
      "user-1",
      { notificationId: "msg-1", notificationType: "" },
      { db: makeFakeDb(store) as never }
    );
  } catch (e) {
    threw = e instanceof Error && e.message.includes("notificationType");
  }
  record("missing notificationType → throws", threw);
}

async function slashInIdSanitized(): Promise<void> {
  const store: FakeStore = { docs: new Map(), refs: new Map() };
  await runRecordNotificationOpened(
    "user-1",
    {
      notificationId: "topic/sub/leaf",
      notificationType: "comment_posted",
    },
    { db: makeFakeDb(store) as never }
  );
  const path = "notification_opened_events/user-1_topic_sub_leaf";
  const ok = store.refs.has(path);
  record(
    "notificationId with slashes is sanitized for doc id",
    ok,
    `pathsWritten=${[...store.refs.keys()].join(", ")}`
  );
}

async function expireAtThirtyDays(): Promise<void> {
  const store: FakeStore = { docs: new Map(), refs: new Map() };
  const now = new Date("2026-04-30T10:00:00Z");
  await runRecordNotificationOpened(
    "user-1",
    { notificationId: "msg-1", notificationType: "comment_posted" },
    { db: makeFakeDb(store) as never, now }
  );
  const path = "notification_opened_events/user-1_msg-1";
  const written = store.refs.get(path)?.sets[0] ?? {};
  // Both timestamps expose `.toMillis()` — Admin SDK Timestamp shape.
  const opened = (written.openedAt as { toMillis(): number }).toMillis();
  const expire = (written.expireAt as { toMillis(): number }).toMillis();
  const diffDays = (expire - opened) / (24 * 60 * 60 * 1000);
  const ok = Math.abs(diffDays - 30) < 0.001;
  record(
    "expireAt = openedAt + 30 days (TTL parity with notification_send_events)",
    ok,
    `diffDays=${diffDays}`
  );
}

async function runAll(): Promise<void> {
  console.log("Security-C1: recordNotificationOpened + dedup tests\n");
  console.log("====================================================\n");
  await happyPathWritesDoc();
  await dedupSecondCallNoop();
  await differentUsersSeparateDocs();
  await differentNotificationsSeparateDocs();
  await missingNotificationIdThrows();
  await missingNotificationTypeThrows();
  await slashInIdSanitized();
  await expireAtThirtyDays();

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
