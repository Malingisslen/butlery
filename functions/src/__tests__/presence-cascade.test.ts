/**
 * BUT-477: GDPR cascade — account deletion purges per-user presence rows
 * across both Firestore presence surfaces (`recipePresence` + `shoppingPresence`)
 * via a `collectionGroup('activeUsers')` sweep keyed on `userId`.
 *
 * We test `cleanupPresenceRowsWithDb` (the test seam) against an in-memory
 * Firestore stub that mimics just enough of the API surface used by the
 * implementation: `collectionGroup`, `where('==', value)`, `get`, `batch`,
 * `delete`, `commit`. This is the same pattern as `detect-lapsed-users.test.ts`
 * and `send-activity-digest.test.ts` — direct exercise of the function with
 * injected stubs, no emulator.
 *
 * Run with: npx ts-node src/__tests__/presence-cascade.test.ts
 */

// firebase-admin's module-level `admin.firestore()` call in
// `on-user-deleted.ts` requires an initialized default app. We don't actually
// USE that app — `cleanupPresenceRowsWithDb` is the test seam and accepts an
// injected stub — but the import-time side-effect must succeed.
import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-cascade" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { cleanupPresenceRowsWithDb } = require("../cleanup/on-user-deleted");

interface FakeDoc {
  path: string;
  data: Record<string, unknown>;
}

/**
 * Doc-ref stub with the `.parent.parent` chain the SUT walks to derive the
 * presence parent collection + parent doc id for the BUT-886 audit row.
 * Path shape: `{collection}/{parentId}/activeUsers/{rowId}`.
 */
interface FakeRef {
  path: string;
  id: string;
  parent: { id: string; parent: FakeParentRef | null };
}

interface FakeParentRef {
  id: string;
  parent: { id: string };
}

function makeRef(path: string): FakeRef {
  const segments = path.split("/");
  const id = segments[segments.length - 1];
  const collId = segments[segments.length - 2];
  let parentDoc: FakeParentRef | null = null;
  if (segments.length >= 4) {
    parentDoc = {
      id: segments[segments.length - 3],
      parent: { id: segments[segments.length - 4] },
    };
  }
  return { path, id, parent: { id: collId, parent: parentDoc } };
}

/**
 * Minimal Firestore-like stub. Stores docs by full path string. Supports
 * `collectionGroup(name).where('userId', '==', uid).get()`, batched deletes,
 * and — since BUT-886 wired cascade audit rows — `collection('audit_logs')
 * .doc()` auto-id refs plus `batch.set` for the staged audit entries.
 * Audit writes land in `auditRows` (not the presence doc map) so presence
 * size/has assertions stay about presence rows.
 */
class FakeFirestore {
  private docs = new Map<string, Record<string, unknown>>();
  private nextAutoId = 0;
  public commits = 0;
  public deletedPaths: string[] = [];
  public auditRows: { path: string; data: Record<string, unknown> }[] = [];

  set(path: string, data: Record<string, unknown>): void {
    this.docs.set(path, data);
  }

  size(): number {
    return this.docs.size;
  }

  has(path: string): boolean {
    return this.docs.has(path);
  }

  collection(name: string): { doc: (id?: string) => FakeRef } {
    return {
      doc: (id?: string) =>
        makeRef(`${name}/${id ?? `auto-${this.nextAutoId++}`}`),
    };
  }

  collectionGroup(name: string): {
    where: (
      field: string,
      op: string,
      value: unknown
    ) => {
      get: () => Promise<{
        empty: boolean;
        docs: { ref: FakeRef }[];
      }>;
    };
  } {
    return {
      where: (field: string, op: string, value: unknown) => ({
        get: async () => {
          const matches: FakeDoc[] = [];
          for (const [path, data] of this.docs) {
            // only consider docs in a `<name>` subcollection (e.g. activeUsers)
            const segments = path.split("/");
            // collection group matches if any path segment equals `name`
            // AND the doc-id segment immediately follows it.
            // i.e. parent.../<name>/<docId>
            if (segments.length < 2) continue;
            const lastCollection = segments[segments.length - 2];
            if (lastCollection !== name) continue;

            if (op === "==" && data[field] === value) {
              matches.push({ path, data });
            }
          }
          return {
            empty: matches.length === 0,
            docs: matches.map((d) => ({ ref: makeRef(d.path) })),
          };
        },
      }),
    };
  }

  batch(): {
    delete: (ref: { path: string }) => void;
    set: (ref: { path: string }, data: Record<string, unknown>) => void;
    commit: () => Promise<void>;
  } {
    const deleteOps: string[] = [];
    const setOps: { path: string; data: Record<string, unknown> }[] = [];
    return {
      delete: (ref) => {
        deleteOps.push(ref.path);
      },
      set: (ref, data) => {
        setOps.push({ path: ref.path, data });
      },
      commit: async () => {
        for (const path of deleteOps) {
          this.docs.delete(path);
          this.deletedPaths.push(path);
        }
        for (const op of setOps) {
          this.auditRows.push(op);
        }
        this.commits++;
      },
    };
  }
}

interface ScenarioResult {
  name: string;
  passed: boolean;
  reason?: string;
}

const results: ScenarioResult[] = [];

function check(name: string, condition: boolean, reason?: string): void {
  results.push({ name, passed: condition, reason });
}

async function scenario_purgesAllUserRowsAcrossBothPresenceCollections(): Promise<void> {
  const db = new FakeFirestore();
  const targetUid = "user_to_delete";
  const otherUid = "user_to_keep";

  // Recipe presence — 2 rows owned by target, 1 owned by other.
  db.set(`recipePresence/recipe1/activeUsers/${targetUid}`, {
    userId: targetUid,
    displayName: "Target",
  });
  db.set(`recipePresence/recipe2/activeUsers/${targetUid}`, {
    userId: targetUid,
    displayName: "Target",
  });
  db.set(`recipePresence/recipe1/activeUsers/${otherUid}`, {
    userId: otherUid,
    displayName: "Other",
  });

  // Shopping presence — 1 row owned by target, 1 owned by other.
  db.set(`shoppingPresence/list1/activeUsers/${targetUid}`, {
    userId: targetUid,
    displayName: "Target",
  });
  db.set(`shoppingPresence/list1/activeUsers/${otherUid}`, {
    userId: otherUid,
    displayName: "Other",
  });

  // Unrelated `activeUsers` doc not owned by target — must be untouched.
  db.set(`shoppingPresence/list2/activeUsers/${otherUid}`, {
    userId: otherUid,
    displayName: "Other",
  });

  const initialCount = db.size();
  // Cast through unknown — this stub deliberately implements only the
  // narrow Firestore surface the implementation touches.
  const removed = await cleanupPresenceRowsWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    targetUid
  );

  check(
    "deletes exactly the target user's presence rows (3 of 6)",
    removed === 3,
    `expected 3, got ${removed}`
  );

  check(
    "target's recipe rows are purged",
    !db.has(`recipePresence/recipe1/activeUsers/${targetUid}`) &&
      !db.has(`recipePresence/recipe2/activeUsers/${targetUid}`),
    "target's recipe rows should be deleted"
  );

  check(
    "target's shopping row is purged",
    !db.has(`shoppingPresence/list1/activeUsers/${targetUid}`),
    "target's shopping row should be deleted"
  );

  check(
    "other users' rows are preserved",
    db.has(`recipePresence/recipe1/activeUsers/${otherUid}`) &&
      db.has(`shoppingPresence/list1/activeUsers/${otherUid}`) &&
      db.has(`shoppingPresence/list2/activeUsers/${otherUid}`),
    "non-target rows must not be deleted"
  );

  check(
    "exactly 3 docs remain (the non-target rows)",
    db.size() === initialCount - 3,
    `expected ${initialCount - 3} remaining, got ${db.size()}`
  );

  // BUT-886: one audit_logs row staged per deleted presence row, in the
  // same batch, with the cascade-delete shape.
  check(
    "one audit row per deleted presence row (3)",
    db.auditRows.length === 3,
    `expected 3 audit rows, got ${db.auditRows.length}`
  );
  check(
    "audit rows land in audit_logs with cascade_delete + subject uid",
    db.auditRows.every(
      (r) =>
        r.path.startsWith("audit_logs/") &&
        r.data.operation === "cascade_delete" &&
        r.data.userId === targetUid
    ),
    "audit row shape mismatch"
  );
}

async function scenario_emptyResultsetCommitIsSkipped(): Promise<void> {
  const db = new FakeFirestore();
  // No rows at all for the target user.
  db.set(`recipePresence/recipe1/activeUsers/other_uid`, {
    userId: "other_uid",
    displayName: "Other",
  });

  const removed = await cleanupPresenceRowsWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    "user_with_no_presence"
  );

  check(
    "returns 0 when no presence rows match",
    removed === 0,
    `expected 0, got ${removed}`
  );

  check(
    "skips batch commit entirely when no matches (no writes)",
    db.commits === 0,
    `expected 0 commits, got ${db.commits}`
  );

  check(
    "leaves unrelated docs untouched",
    db.has(`recipePresence/recipe1/activeUsers/other_uid`),
    "unrelated row must not be deleted"
  );
}

async function scenario_largeResultsetIsBatched(): Promise<void> {
  // Verify batch chunking by seeding 501 target rows. Since BUT-886 each
  // row stages 2 ops (delete + audit), so the per-batch row cap is 250
  // (500-op Firestore limit / 2) → 501 rows = 3 commits.
  const db = new FakeFirestore();
  const targetUid = "heavy_user";

  for (let i = 0; i < 501; i++) {
    db.set(`recipePresence/recipe${i}/activeUsers/${targetUid}`, {
      userId: targetUid,
      displayName: "Heavy",
    });
  }

  const removed = await cleanupPresenceRowsWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    targetUid
  );

  check(
    "deletes all 501 target rows across multiple batches",
    removed === 501,
    `expected 501, got ${removed}`
  );

  check(
    "uses 3 batch commits at 250 rows/batch (delete + audit = 2 ops/row)",
    db.commits === 3,
    `expected 3 commits (250 + 250 + 1), got ${db.commits}`
  );

  check(
    "no target rows remain after large purge",
    db.size() === 0,
    `expected 0 remaining, got ${db.size()}`
  );
}

async function main(): Promise<void> {
  await scenario_purgesAllUserRowsAcrossBothPresenceCollections();
  await scenario_emptyResultsetCommitIsSkipped();
  await scenario_largeResultsetIsBatched();

  let failed = 0;
  for (const r of results) {
    if (r.passed) {
      console.log(`  PASS  ${r.name}`);
    } else {
      console.log(`  FAIL  ${r.name}${r.reason ? `\n        ${r.reason}` : ""}`);
      failed++;
    }
  }

  console.log(
    `\nBUT-477 presence cascade: ${results.length - failed}/${results.length} passing`
  );
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
