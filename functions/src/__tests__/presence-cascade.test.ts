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
 * Minimal Firestore-like stub. Stores docs by full path string. Supports
 * `collectionGroup(name).where('userId', '==', uid).get()` and batched
 * deletes — the only API surface `cleanupPresenceRowsWithDb` touches.
 */
class FakeFirestore {
  private docs = new Map<string, Record<string, unknown>>();
  public commits = 0;
  public deletedPaths: string[] = [];

  set(path: string, data: Record<string, unknown>): void {
    this.docs.set(path, data);
  }

  size(): number {
    return this.docs.size;
  }

  has(path: string): boolean {
    return this.docs.has(path);
  }

  collectionGroup(name: string): {
    where: (
      field: string,
      op: string,
      value: unknown
    ) => {
      get: () => Promise<{
        empty: boolean;
        docs: { ref: { path: string } }[];
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
            docs: matches.map((d) => ({ ref: { path: d.path } })),
          };
        },
      }),
    };
  }

  batch(): {
    delete: (ref: { path: string }) => void;
    commit: () => Promise<void>;
  } {
    const ops: string[] = [];
    return {
      delete: (ref) => {
        ops.push(ref.path);
      },
      commit: async () => {
        for (const path of ops) {
          this.docs.delete(path);
          this.deletedPaths.push(path);
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
  // Verify the 500-op batch chunking by seeding 501 target rows.
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
    "uses 2 batch commits when total > 500 (Firestore batch limit)",
    db.commits === 2,
    `expected 2 commits (500 + 1), got ${db.commits}`
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
