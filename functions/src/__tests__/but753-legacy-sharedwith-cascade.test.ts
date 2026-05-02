/**
 * BUT-753: admin-cascade scrub of legacy `sharedWith` flat-array entries.
 *
 * The user-driven `removeFromSharedContent` path (Flutter side, BUT-692)
 * already scrubs the modern members-subcollection sharing model. But
 * `firestore.rules:515-518` blocks user-driven `update` on `shared_content`
 * docs unless the caller is the owner OR has a `members/{uid}` doc — a
 * recipient appearing only in the legacy flat `sharedWith: [...]` array
 * cannot scrub their own legacy entry. This test exercises the cascade
 * step in `on-user-deleted.ts` that runs in admin context (rules
 * bypassed) and uses `arrayRemove` for idempotency.
 *
 * We test `cleanupLegacySharedWithArraysWithDb` (the test seam) against
 * an in-memory Firestore stub, mirroring the `presence-cascade.test.ts`
 * shape exactly.
 *
 * Run with: npx ts-node src/__tests__/but753-legacy-sharedwith-cascade.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-but753" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  cleanupLegacySharedWithArraysWithDb,
} = require("../cleanup/on-user-deleted");

/**
 * Sentinel marker that mimics admin.firestore.FieldValue.arrayRemove
 * without depending on the real SDK's internal type. The fake batch
 * recognises this marker and applies the array-remove semantics on commit.
 */
const ARRAY_REMOVE_MARKER = Symbol("arrayRemove");
interface ArrayRemoveOp {
  [ARRAY_REMOVE_MARKER]: true;
  values: unknown[];
}
function isArrayRemoveOp(v: unknown): v is ArrayRemoveOp {
  return (
    typeof v === "object" &&
    v !== null &&
    (v as ArrayRemoveOp)[ARRAY_REMOVE_MARKER] === true
  );
}

/**
 * Hijack `admin.firestore.FieldValue.arrayRemove` so the SUT's call
 * produces our recognisable marker. The real SDK is not available in
 * this minimal test setup (no app initialised against a live project).
 */
(admin.firestore.FieldValue as unknown as {
  arrayRemove: (...values: unknown[]) => ArrayRemoveOp;
}).arrayRemove = (...values: unknown[]) => ({
  [ARRAY_REMOVE_MARKER]: true,
  values,
});

interface FakeRef {
  path: string;
}

class FakeFirestore {
  private docs = new Map<string, Record<string, unknown>>();
  public commits = 0;
  public failNextCommit = false;
  public failedCommits = 0;

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
      where: (field: string, op: string, value: unknown) => ({
        get: async () => {
          const matches: { path: string; data: Record<string, unknown> }[] = [];
          for (const [path, data] of this.docs) {
            const segments = path.split("/");
            // Top-level collection match: path is `<name>/<docId>`.
            if (segments.length !== 2 || segments[0] !== name) continue;
            const fieldVal = data[field];
            if (op === "array-contains") {
              if (Array.isArray(fieldVal) && fieldVal.includes(value)) {
                matches.push({ path, data });
              }
            }
          }
          return {
            empty: matches.length === 0,
            docs: matches.map((d) => ({
              ref: { path: d.path },
              data: () => d.data,
            })),
          };
        },
      }),
    };
  }

  batch(): {
    update: (ref: FakeRef, data: Record<string, unknown>) => void;
    commit: () => Promise<void>;
  } {
    const ops: { path: string; data: Record<string, unknown> }[] = [];
    return {
      update: (ref, data) => {
        ops.push({ path: ref.path, data });
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
          const next = { ...existing };
          for (const [k, v] of Object.entries(op.data)) {
            if (isArrayRemoveOp(v)) {
              const cur = Array.isArray(next[k]) ? (next[k] as unknown[]) : [];
              next[k] = cur.filter((item) => !v.values.includes(item));
            } else {
              next[k] = v;
            }
          }
          this.docs.set(op.path, next);
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

async function scenario_scrubsTargetUserPreservesOthers(): Promise<void> {
  const db = new FakeFirestore();
  const userA = "userA";
  const userB = "userB";
  const userC = "userC";

  // Doc 1: legacy sharedWith holds [A, B, C] — B is being deleted.
  db.set("shared_content/legacy_doc_1", {
    sharedByUserId: userA,
    sharedWith: [userA, userB, userC],
  });
  // Doc 2: legacy sharedWith holds only [A, C] — B is NOT in it.
  db.set("shared_content/legacy_doc_2", {
    sharedByUserId: userA,
    sharedWith: [userA, userC],
  });

  const removed = await cleanupLegacySharedWithArraysWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    userB
  );

  check(
    "queues exactly one doc for update (the one containing userB)",
    removed === 1,
    `expected 1, got ${removed}`
  );

  const after1 = db.get("shared_content/legacy_doc_1");
  check(
    "doc1 sharedWith is [A, C] after scrubbing B",
    Array.isArray(after1?.sharedWith) &&
      JSON.stringify(after1?.sharedWith) === JSON.stringify([userA, userC]),
    `expected [A,C], got ${JSON.stringify(after1?.sharedWith)}`
  );

  const after2 = db.get("shared_content/legacy_doc_2");
  check(
    "doc2 sharedWith stays [A, C] (B was never present)",
    Array.isArray(after2?.sharedWith) &&
      JSON.stringify(after2?.sharedWith) === JSON.stringify([userA, userC]),
    `expected [A,C], got ${JSON.stringify(after2?.sharedWith)}`
  );
}

async function scenario_idempotentRerun(): Promise<void> {
  const db = new FakeFirestore();
  const userB = "userB";
  // Already-scrubbed dataset.
  db.set("shared_content/already_clean", {
    sharedByUserId: "userA",
    sharedWith: ["userA", "userC"],
  });

  const removed1 = await cleanupLegacySharedWithArraysWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    userB
  );
  const removed2 = await cleanupLegacySharedWithArraysWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    userB
  );

  check(
    "first run on already-scrubbed data is a no-op (0 matched)",
    removed1 === 0,
    `expected 0, got ${removed1}`
  );
  check(
    "second run is also a no-op (idempotent)",
    removed2 === 0,
    `expected 0, got ${removed2}`
  );
  check(
    "no batch commits issued when nothing matches",
    db.commits === 0,
    `expected 0 commits, got ${db.commits}`
  );
}

async function scenario_largeResultsetIsBatched(): Promise<void> {
  const db = new FakeFirestore();
  const targetUid = "heavy_user";

  for (let i = 0; i < 501; i++) {
    db.set(`shared_content/doc${i}`, {
      sharedByUserId: "owner",
      sharedWith: ["owner", targetUid],
    });
  }

  const removed = await cleanupLegacySharedWithArraysWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    targetUid
  );

  check(
    "queues all 501 docs for update across multiple batches",
    removed === 501,
    `expected 501, got ${removed}`
  );

  check(
    "uses 2 batch commits when total > 500 (Firestore batch limit)",
    db.commits === 2,
    `expected 2 commits (500 + 1), got ${db.commits}`
  );

  // Verify all docs scrubbed (target gone, owner stays).
  let allScrubbed = true;
  for (let i = 0; i < 501; i++) {
    const d = db.get(`shared_content/doc${i}`);
    const arr = (d?.sharedWith as unknown[]) ?? [];
    if (arr.includes(targetUid) || !arr.includes("owner")) {
      allScrubbed = false;
      break;
    }
  }
  check(
    "all 501 docs have target removed from sharedWith, owner preserved",
    allScrubbed,
    "at least one doc was not correctly scrubbed"
  );
}

async function scenario_failedChunkContinues(): Promise<void> {
  // Best-effort guarantee: a chunk-commit failure must not abort the
  // remaining work. Seed > 500 docs so the SUT issues two commits, then
  // arm the FIRST commit to throw.
  const db = new FakeFirestore();
  const targetUid = "uid_with_partial_failure";

  for (let i = 0; i < 501; i++) {
    db.set(`shared_content/doc${i}`, {
      sharedByUserId: "owner",
      sharedWith: ["owner", targetUid],
    });
  }
  db.failNextCommit = true; // first commit will throw

  const removed = await cleanupLegacySharedWithArraysWithDb(
    db as unknown as import("firebase-admin").firestore.Firestore,
    targetUid
  );

  check(
    "still reports all 501 docs queued even when first chunk failed",
    removed === 501,
    `expected 501, got ${removed}`
  );

  check(
    "first commit was attempted and failed",
    db.failedCommits === 1,
    `expected 1 failed commit, got ${db.failedCommits}`
  );

  check(
    "second chunk still commits successfully (best-effort guarantee)",
    db.commits === 1,
    `expected 1 successful commit after first failed, got ${db.commits}`
  );
}

async function main(): Promise<void> {
  await scenario_scrubsTargetUserPreservesOthers();
  await scenario_idempotentRerun();
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
    `\nBUT-753 legacy sharedWith cascade: ${results.length - failed}/${results.length} passing`
  );
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
