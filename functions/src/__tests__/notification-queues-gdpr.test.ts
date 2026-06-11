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
 * BUT-838: also covers `cleanupRecipeCookEventsWithDb` — the GDPR cascade
 * for the recipe_cook_events/{userId} tree (event subcollection discovered
 * via listCollections + per-user root doc), with one audit row per delete.
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
  cleanupRecipeCookEventsWithDb,
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

// BUT-838: fake for the recipe_cook_events/{userId} doc tree. Models the
// admin-SDK surface the cascade uses: `.collection().doc()` for the root
// ref (listCollections / get / delete) and for audit_logs auto-id refs
// (path + standalone `set` used by writeCascadeAuditEntry), plus the same
// batch shape as makeFakeDb.
interface CookEventsState {
  /** Event docs keyed by subcollection name. */
  events: { sub: string; id: string }[];
  rootExists: boolean;
  /** Full paths of deleted docs (events + root). */
  deleted: Set<string>;
  audits: { path: string; data: Record<string, unknown> }[];
}

function makeCookEventsFakeDb(state: CookEventsState) {
  let nextAutoId = 0;
  return {
    collection(name: string) {
      return {
        doc(id?: string) {
          if (name === "audit_logs") {
            const path = `audit_logs/${id ?? `auto-${nextAutoId++}`}`;
            return {
              path,
              // writeCascadeAuditEntry (root-doc audit) sets directly on the ref.
              set: async (data: Record<string, unknown>) => {
                state.audits.push({ path, data });
              },
            };
          }
          const rootPath = `${name}/${id}`;
          return {
            path: rootPath,
            async listCollections() {
              const subNames = [...new Set(state.events.map((e) => e.sub))];
              return subNames.map((sub) => ({
                id: sub,
                async get() {
                  const docs = state.events.filter((e) => e.sub === sub);
                  return {
                    empty: docs.length === 0,
                    docs: docs.map((e) => ({
                      id: e.id,
                      ref: {
                        path: `${rootPath}/${sub}/${e.id}`,
                        delete: async () => {
                          state.deleted.add(`${rootPath}/${sub}/${e.id}`);
                        },
                      },
                    })),
                  };
                },
              }));
            },
            async get() {
              return { exists: state.rootExists };
            },
            async delete() {
              state.deleted.add(rootPath);
              state.rootExists = false;
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
            state.audits.push({ path: ref.path, data });
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

// BUT-838: the cook-event log is timestamped behavioral PII; account
// deletion must remove the event docs AND the per-user root doc, staging
// one cascade_delete audit row per delete.
async function purgesRecipeCookEventsTree(): Promise<void> {
  const state: CookEventsState = {
    events: [
      { sub: "events", id: "e1" },
      { sub: "events", id: "e2" },
      { sub: "events", id: "e3" },
    ],
    rootExists: true,
    deleted: new Set(),
    audits: [],
  };
  const total = await cleanupRecipeCookEventsWithDb(
    makeCookEventsFakeDb(state) as never,
    "u1"
  );

  const eventAudits = state.audits.filter(
    (a) => a.data.resourceType === "recipe_cook_events/events"
  );
  const rootAudits = state.audits.filter(
    (a) => a.data.resourceType === "recipe_cook_events"
  );
  const ok =
    total === 4 && // 3 event docs + root doc
    state.deleted.has("recipe_cook_events/u1/events/e1") &&
    state.deleted.has("recipe_cook_events/u1/events/e2") &&
    state.deleted.has("recipe_cook_events/u1/events/e3") &&
    state.deleted.has("recipe_cook_events/u1") &&
    eventAudits.length === 3 &&
    rootAudits.length === 1 &&
    state.audits.every(
      (a) =>
        a.path.startsWith("audit_logs/") &&
        a.data.operation === "cascade_delete" &&
        a.data.userId === "u1"
    );
  record(
    "BUT-838: purges recipe_cook_events tree (events + root) and stages audit rows",
    ok,
    `total=${total} deleted=${[...state.deleted].join(", ")} audits=${state.audits.length}`
  );
}

async function recipeCookEventsNoopWhenAbsent(): Promise<void> {
  const state: CookEventsState = {
    events: [],
    rootExists: false,
    deleted: new Set(),
    audits: [],
  };
  const total = await cleanupRecipeCookEventsWithDb(
    makeCookEventsFakeDb(state) as never,
    "u1"
  );
  const ok = total === 0 && state.deleted.size === 0 && state.audits.length === 0;
  record(
    "BUT-838: no cook events + no root doc → no-op, returns 0, no audit rows",
    ok,
    `total=${total} audits=${state.audits.length}`
  );
}

async function runAll(): Promise<void> {
  console.log("Security-C2: GDPR notification-queue cascade tests\n");
  console.log("===================================================\n");
  await deletesAcrossAllThreeCollections();
  await leavesOtherUsersAlone();
  await emptyCollectionsNoop();
  await totalReflectsCrossCollectionSum();
  await purgesRecipeCookEventsTree();
  await recipeCookEventsNoopWhenAbsent();

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
