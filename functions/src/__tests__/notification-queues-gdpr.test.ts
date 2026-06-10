/**
 * Security-review C2: GDPR cascade for notification queues.
 *
 * Verifies `cleanupNotificationQueuesWithDb` deletes all rows where
 * `userId == deletedUid` across the three notification-related collections:
 *   - scheduled_notifications
 *   - notification_send_events
 *   - notification_opened_events
 *
 * Coverage:
 *   1. Deletes all matching rows in each collection.
 *   2. Leaves OTHER users' rows alone.
 *   3. Empty collections (no docs for the user) → no-op, returns 0.
 *   4. Total returned reflects sum across all three collections.
 *
 * Run with: npx ts-node src/__tests__/notification-queues-gdpr.test.ts
 */

// firebase-admin's module-level `admin.firestore()` in `on-user-deleted.ts`
// requires an initialized default app. We don't USE that app —
// `cleanupNotificationQueuesWithDb` accepts an injected stub — but the
// import-time side-effect must succeed. Same pattern as `presence-cascade.test.ts`.
import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-gdpr-cascade" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  cleanupNotificationQueuesWithDb,
} = require("../cleanup/on-user-deleted");

interface SeedDoc {
  collection: string;
  id: string;
  userId: string;
}

interface FakeStore {
  docs: SeedDoc[];
  /** Set of `<collection>/<id>` paths that were deleted. */
  deleted: Set<string>;
  /** BUT-886: committed audit rows staged via `batch.set`. */
  audits: { path: string; data: Record<string, unknown> }[];
}

function makeFakeDb(store: FakeStore) {
  let nextAutoId = 0;
  return {
    collection(name: string) {
      return {
        // BUT-886: stageCascadeAuditEntry calls `.collection("audit_logs")
        // .doc()` for an auto-id audit ref.
        doc(id?: string) {
          return { path: `${name}/${id ?? `auto-${nextAutoId++}`}` };
        },
        where(field: string, _op: string, value: unknown) {
          const matches = store.docs.filter(
            (d) => d.collection === name && (d as never as Record<string, unknown>)[field] === value
          );
          return {
            async get() {
              return {
                empty: matches.length === 0,
                docs: matches.map((m) => ({
                  id: m.id,
                  ref: {
                    delete: async () => {
                      store.deleted.add(`${m.collection}/${m.id}`);
                    },
                  },
                })),
              };
            },
          };
        },
      };
    },
    batch() {
      const ops: Array<() => Promise<void>> = [];
      return {
        delete(ref: { delete: () => Promise<void> }) {
          ops.push(() => ref.delete());
        },
        set(ref: { path: string }, data: Record<string, unknown>) {
          ops.push(async () => {
            store.audits.push({ path: ref.path, data });
          });
        },
        async commit() {
          for (const op of ops) await op();
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

async function deletesAcrossAllThreeCollections(): Promise<void> {
  const store: FakeStore = {
    docs: [
      { collection: "scheduled_notifications", id: "s1", userId: "u1" },
      { collection: "scheduled_notifications", id: "s2", userId: "u1" },
      { collection: "notification_send_events", id: "se1", userId: "u1" },
      { collection: "notification_opened_events", id: "o1", userId: "u1" },
    ],
    deleted: new Set(),
    audits: [],
  };
  const total = await cleanupNotificationQueuesWithDb(
    makeFakeDb(store) as never,
    "u1"
  );
  const ok =
    total === 4 &&
    store.deleted.has("scheduled_notifications/s1") &&
    store.deleted.has("scheduled_notifications/s2") &&
    store.deleted.has("notification_send_events/se1") &&
    store.deleted.has("notification_opened_events/o1");
  record(
    "deletes user rows across all three notification collections",
    ok,
    `total=${total} deleted=${[...store.deleted].join(", ")}`
  );

  // BUT-886: one audit_logs row committed per deleted doc, same batch.
  const auditsOk =
    store.audits.length === 4 &&
    store.audits.every(
      (a) =>
        a.path.startsWith("audit_logs/") &&
        a.data.operation === "cascade_delete" &&
        a.data.userId === "u1"
    );
  record(
    "stages one cascade_delete audit row per purged doc",
    auditsOk,
    `audits=${store.audits.length}`
  );
}

async function leavesOtherUsersAlone(): Promise<void> {
  const store: FakeStore = {
    docs: [
      { collection: "scheduled_notifications", id: "s1", userId: "u1" },
      { collection: "scheduled_notifications", id: "s2", userId: "u2" },
      { collection: "notification_send_events", id: "se1", userId: "u1" },
      { collection: "notification_send_events", id: "se2", userId: "u3" },
    ],
    deleted: new Set(),
    audits: [],
  };
  const total = await cleanupNotificationQueuesWithDb(
    makeFakeDb(store) as never,
    "u1"
  );
  const ok =
    total === 2 &&
    store.deleted.has("scheduled_notifications/s1") &&
    store.deleted.has("notification_send_events/se1") &&
    !store.deleted.has("scheduled_notifications/s2") &&
    !store.deleted.has("notification_send_events/se2");
  record(
    "leaves other users' rows alone",
    ok,
    `total=${total} deleted=${[...store.deleted].join(", ")}`
  );
}

async function emptyCollectionsNoop(): Promise<void> {
  const store: FakeStore = { docs: [], deleted: new Set(), audits: [] };
  const total = await cleanupNotificationQueuesWithDb(
    makeFakeDb(store) as never,
    "u1"
  );
  const ok = total === 0 && store.deleted.size === 0;
  record("empty collections → no-op, returns 0", ok, `total=${total}`);
}

async function totalReflectsCrossCollectionSum(): Promise<void> {
  const store: FakeStore = {
    docs: [
      { collection: "scheduled_notifications", id: "s1", userId: "u1" },
      { collection: "scheduled_notifications", id: "s2", userId: "u1" },
      { collection: "scheduled_notifications", id: "s3", userId: "u1" },
      { collection: "notification_send_events", id: "se1", userId: "u1" },
      { collection: "notification_send_events", id: "se2", userId: "u1" },
      { collection: "notification_opened_events", id: "o1", userId: "u1" },
    ],
    deleted: new Set(),
    audits: [],
  };
  const total = await cleanupNotificationQueuesWithDb(
    makeFakeDb(store) as never,
    "u1"
  );
  const ok = total === 6 && store.deleted.size === 6;
  record(
    "total returned = sum across all three collections (3+2+1=6)",
    ok,
    `total=${total} deletedCount=${store.deleted.size}`
  );
}

async function runAll(): Promise<void> {
  console.log("Security-C2: GDPR notification-queue cascade tests\n");
  console.log("===================================================\n");
  await deletesAcrossAllThreeCollections();
  await leavesOtherUsersAlone();
  await emptyCollectionsNoop();
  await totalReflectsCrossCollectionSum();

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
