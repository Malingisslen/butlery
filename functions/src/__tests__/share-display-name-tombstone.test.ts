/**
 * BUT-466: admin-cascade tombstone of `sharedByDisplayName` on
 * `shared_content` docs the deleted user had originated.
 *
 * Recipient-side rendering reads `sharedByDisplayName` for attribution;
 * the value is PII (linked display name) and must be replaced with a
 * locale-aware tombstone. The Flutter-side path cannot do this —
 * `firestore.rules:515-518` blocks user-driven `update` on
 * `shared_content` unless the caller is the owner or in `members/`.
 *
 * We test `tombstoneSharedByDisplayNameWithDb` (the test seam) against
 * an in-memory Firestore stub, mirroring the
 * `but753-legacy-sharedwith-cascade.test.ts` shape exactly.
 *
 * Run with: npx ts-node src/__tests__/share-display-name-tombstone.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-but466" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  tombstoneSharedByDisplayNameWithDb,
} = require("../cleanup/on-user-deleted");

const TOMBSTONE = "[Raderad användare]";

interface FakeRef {
  path: string;
}

class FakeFirestore {
  private docs = new Map<string, Record<string, unknown>>();
  private nextAutoId = 0;
  public commits = 0;
  public failNextCommit = false;
  public failedCommits = 0;
  /** BUT-886: committed audit rows staged via `batch.set`. */
  public auditRows: { path: string; data: Record<string, unknown> }[] = [];

  set(path: string, data: Record<string, unknown>): void {
    this.docs.set(path, data);
  }

  get(path: string): Record<string, unknown> | undefined {
    return this.docs.get(path);
  }

  size(): number {
    return this.docs.size;
  }

  collection(name: string): {
    doc: (id?: string) => FakeRef;
    where: (
      field: string,
      op: string,
      value: unknown
    ) => {
      get: () => Promise<{
        empty: boolean;
        docs: { ref: FakeRef; data: () => Record<string, unknown> }[];
      }>;
    };
  } {
    return {
      // BUT-886: stageCascadeAuditEntry calls `.collection("audit_logs")
      // .doc()` for an auto-id audit ref.
      doc: (id?: string) => ({
        path: `${name}/${id ?? `auto-${this.nextAutoId++}`}`,
      }),
      where: (field: string, op: string, value: unknown) => ({
        get: async () => {
          const matches: { path: string; data: Record<string, unknown> }[] = [];
          for (const [path, data] of this.docs) {
            const segments = path.split("/");
            // Top-level collection match: path is `<name>/<docId>`.
            if (segments.length !== 2 || segments[0] !== name) continue;
            const fieldVal = data[field];
            if (op === "==") {
              if (fieldVal === value) {
                matches.push({ path, data });
              }
            }
          }
          return {
            empty: matches.length === 0,
            docs: matches.map((d) => ({
              ref: { path: d.path },
              id: d.path.split("/")[1],
              data: () => d.data,
            })),
          };
        },
      }),
    };
  }

  batch(): {
    update: (ref: FakeRef, data: Record<string, unknown>) => void;
    set: (ref: FakeRef, data: Record<string, unknown>) => void;
    commit: () => Promise<void>;
  } {
    const ops: { path: string; data: Record<string, unknown> }[] = [];
    const setOps: { path: string; data: Record<string, unknown> }[] = [];
    return {
      update: (ref, data) => {
        ops.push({ path: ref.path, data });
      },
      set: (ref, data) => {
        setOps.push({ path: ref.path, data });
      },
      commit: async () => {
        if (this.failNextCommit) {
          this.failNextCommit = false;
          this.failedCommits++;
          throw new Error("simulated chunk-commit failure");
        }
        for (const op of ops) {
          const existing = this.docs.get(op.path);
          if (!existing) continue;
          this.docs.set(op.path, { ...existing, ...op.data });
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

async function scenario_tombstonesTargetSharerOnly(): Promise<void> {
  const db = new FakeFirestore();
  const targetUid = "deleted-user";
  const otherUid = "other-user";

  db.set("shared_content/recipe_a", {
    sharedByUserId: targetUid,
    sharedByDisplayName: "Erik",
    sharedByAvatarUrl: "https://example.com/avatar/erik.png",
  });
  db.set("shared_content/recipe_b", {
    sharedByUserId: targetUid,
    sharedByDisplayName: "Erik",
    sharedByAvatarUrl: "https://example.com/avatar/erik.png",
  });
  db.set("shared_content/recipe_c", {
    sharedByUserId: targetUid,
    sharedByDisplayName: "Erik",
    sharedByAvatarUrl: null, // already-null avatar still triggers display-name update
  });
  db.set("shared_content/recipe_other", {
    sharedByUserId: otherUid,
    sharedByDisplayName: "Anna",
    sharedByAvatarUrl: "https://example.com/avatar/anna.png",
  });

  const queued = await tombstoneSharedByDisplayNameWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    targetUid
  );

  check(
    "queues exactly 3 docs (the ones sharedByUserId == targetUid)",
    queued === 3,
    `expected 3, got ${queued}`
  );

  for (const id of ["recipe_a", "recipe_b", "recipe_c"]) {
    const after = db.get(`shared_content/${id}`);
    check(
      `${id} sharedByDisplayName tombstoned`,
      after?.sharedByDisplayName === TOMBSTONE,
      `expected tombstone, got ${String(after?.sharedByDisplayName)}`
    );
    check(
      `${id} sharedByAvatarUrl nulled (BUT-466 PII)`,
      after?.sharedByAvatarUrl === null,
      `expected null, got ${String(after?.sharedByAvatarUrl)}`
    );
  }

  const otherAfter = db.get("shared_content/recipe_other");
  check(
    "other sharer's display name is untouched",
    otherAfter?.sharedByDisplayName === "Anna",
    `expected 'Anna', got ${String(otherAfter?.sharedByDisplayName)}`
  );
  check(
    "other sharer's avatar URL is untouched",
    otherAfter?.sharedByAvatarUrl === "https://example.com/avatar/anna.png",
    `expected anna.png, got ${String(otherAfter?.sharedByAvatarUrl)}`
  );

  // BUT-886: one cascade_anonymize audit row per tombstoned doc.
  check(
    "one cascade_anonymize audit row per tombstoned doc (3)",
    db.auditRows.length === 3 &&
      db.auditRows.every(
        (r) =>
          r.path.startsWith("audit_logs/") &&
          r.data.operation === "cascade_anonymize" &&
          r.data.userId === targetUid
      ),
    `audits=${db.auditRows.length}`
  );
}

async function scenario_idempotentRerun(): Promise<void> {
  const db = new FakeFirestore();
  const targetUid = "deleted-user";

  // Already-tombstoned dataset (both fields cleared).
  db.set("shared_content/already_tombstoned", {
    sharedByUserId: targetUid,
    sharedByDisplayName: TOMBSTONE,
    sharedByAvatarUrl: null,
  });

  const first = await tombstoneSharedByDisplayNameWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    targetUid
  );
  const second = await tombstoneSharedByDisplayNameWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    targetUid
  );

  check(
    "first run skips already-tombstoned docs (0 queued)",
    first === 0,
    `expected 0, got ${first}`
  );
  check(
    "second run is also a no-op (idempotent)",
    second === 0,
    `expected 0, got ${second}`
  );
  check(
    "no batch commits issued when nothing matched after skip",
    db.commits === 0,
    `expected 0 commits, got ${db.commits}`
  );
}

async function scenario_partialTombstone_displayNameDoneAvatarMissing(): Promise<void> {
  // BUT-466 review case: a doc with display name already tombstoned but
  // avatar URL still present must be re-queued so the avatar is cleared.
  const db = new FakeFirestore();
  const targetUid = "deleted-user";

  db.set("shared_content/half_done", {
    sharedByUserId: targetUid,
    sharedByDisplayName: TOMBSTONE,
    sharedByAvatarUrl: "https://example.com/avatar/erik.png", // residual PII
  });

  const queued = await tombstoneSharedByDisplayNameWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    targetUid
  );

  check(
    "partially-tombstoned doc IS re-queued to clear residual avatar",
    queued === 1,
    `expected 1, got ${queued}`
  );

  const after = db.get("shared_content/half_done");
  check(
    "avatar URL nulled on second pass",
    after?.sharedByAvatarUrl === null,
    `expected null, got ${String(after?.sharedByAvatarUrl)}`
  );
  check(
    "display name unchanged (already tombstoned)",
    after?.sharedByDisplayName === TOMBSTONE,
    `expected tombstone, got ${String(after?.sharedByDisplayName)}`
  );
}

async function scenario_noMatch(): Promise<void> {
  const db = new FakeFirestore();
  // Only docs from other sharers exist.
  db.set("shared_content/recipe_other", {
    sharedByUserId: "someone-else",
    sharedByDisplayName: "Anna",
  });

  const queued = await tombstoneSharedByDisplayNameWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    "deleted-user"
  );

  check(
    "no-match returns 0 with no commits",
    queued === 0 && db.commits === 0,
    `expected 0 queued / 0 commits, got ${queued} / ${db.commits}`
  );
}

async function scenario_largeResultsetIsBatched(): Promise<void> {
  const db = new FakeFirestore();
  const targetUid = "heavy-user";

  for (let i = 0; i < 501; i++) {
    db.set(`shared_content/doc${i}`, {
      sharedByUserId: targetUid,
      sharedByDisplayName: `User${i}`,
    });
  }

  const queued = await tombstoneSharedByDisplayNameWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    targetUid
  );

  check(
    "queues all 501 docs across multiple batches",
    queued === 501,
    `expected 501, got ${queued}`
  );

  check(
    // BUT-886: opsPerItem=2 (update + audit) halves the chunk cap to 250
    // docs/batch → 501 docs = 3 commits.
    "uses 3 batch commits at 250 docs/batch (update + audit = 2 ops/doc)",
    db.commits === 3,
    `expected 3 commits (250 + 250 + 1), got ${db.commits}`
  );

  let allTombstoned = true;
  for (let i = 0; i < 501; i++) {
    const d = db.get(`shared_content/doc${i}`);
    if (d?.sharedByDisplayName !== TOMBSTONE) {
      allTombstoned = false;
      break;
    }
  }
  check(
    "all 501 docs tombstoned",
    allTombstoned,
    "at least one doc was not correctly tombstoned"
  );
}

async function scenario_failedChunkContinues(): Promise<void> {
  // Best-effort guarantee: a chunk-commit failure must not abort the
  // remaining work. Seed > 500 docs so the SUT issues two commits, then
  // arm the FIRST commit to throw.
  const db = new FakeFirestore();
  const targetUid = "uid-with-partial-failure";

  for (let i = 0; i < 501; i++) {
    db.set(`shared_content/doc${i}`, {
      sharedByUserId: targetUid,
      sharedByDisplayName: `User${i}`,
    });
  }
  db.failNextCommit = true; // first commit will throw

  const queued = await tombstoneSharedByDisplayNameWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    targetUid
  );

  check(
    "still reports all 501 docs queued even when first chunk failed",
    queued === 501,
    `expected 501, got ${queued}`
  );

  check(
    "first commit was attempted and failed",
    db.failedCommits === 1,
    `expected 1 failed commit, got ${db.failedCommits}`
  );

  check(
    // BUT-886: 3 chunks total (250 docs/batch) — first fails, two succeed.
    "remaining chunks still commit successfully (best-effort guarantee)",
    db.commits === 2,
    `expected 2 successful commits after first failed, got ${db.commits}`
  );
}

async function main(): Promise<void> {
  await scenario_tombstonesTargetSharerOnly();
  await scenario_idempotentRerun();
  await scenario_partialTombstone_displayNameDoneAvatarMissing();
  await scenario_noMatch();
  await scenario_largeResultsetIsBatched();
  await scenario_failedChunkContinues();

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
    `\nBUT-466 sharedByDisplayName tombstone: ${results.length - failed}/${results.length} passing`
  );
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
