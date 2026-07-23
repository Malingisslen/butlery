/**
 * BUT-1659 — export-llm-samples unit tests (BUT-1472 follow-up).
 *
 * Verifies `runExportLlmSamplesWithDb` (the testable extraction from the
 * `export-llm-samples.ts` admin script) correctly:
 *
 *   1. Projects each `llm_response_samples` doc down to the already-scrubbed
 *      field whitelist — a raw uid or an unscrubbed payload present on the
 *      source doc never reaches the export (the privacy boundary the script's
 *      header promises).
 *   2. Emits rows in a deterministic order: oldest `createdAt` first, ties
 *      broken by doc id, null `createdAt` sorted last. Deterministic output is
 *      what makes the exported JSON diff-stable for offline mining.
 *   3. Honors the `--mode` narrowing (equality filter on `mode`).
 *
 * Run: npx ts-node src/__tests__/export-llm-samples.test.ts
 *
 * Pattern follows `export-audit-logs.test.ts` — a fake admin Firestore shape
 * driven by an in-memory store; the admin SDK bypasses rules by design so a
 * rules-test harness adds no value here.
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-export-llm-samples" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  runExportLlmSamplesWithDb,
  projectSample,
} = require("../admin/export-llm-samples");

// A seeded doc carries BOTH the whitelisted fields AND deliberately-unwanted
// raw fields (rawUserId, unscrubbedInput, apiKey) so the projection test can
// prove those never survive into the export.
interface SeedDoc {
  id: string;
  mode?: string;
  createdAtMs?: number | null;
  extra?: Record<string, unknown>;
}

interface FakeStore {
  docs: SeedDoc[];
}

function docData(d: SeedDoc): Record<string, unknown> {
  return {
    mode: d.mode ?? "extract",
    inputKind: "url",
    scrubbedInput: "scrubbed in",
    scrubbedInputLength: 12,
    scrubbedOutput: "scrubbed out",
    outputLength: 34,
    promptVersion: "v3",
    promptSource: "firestore",
    experimentBucket: 1,
    promptVariant: "A",
    domain: "example.com",
    authUidHash: "hash-abc",
    modelId: "gemini-x",
    promptTokenCount: 100,
    candidatesTokenCount: 200,
    createdAt:
      d.createdAtMs === undefined || d.createdAtMs === null
        ? undefined
        : admin.firestore.Timestamp.fromMillis(d.createdAtMs),
    ...(d.extra ?? {}),
  };
}

function makeFakeDb(store: FakeStore): admin.firestore.Firestore {
  function buildQuery(filter: { mode?: string }) {
    return {
      where(field: string, op: string, value: unknown) {
        if (field === "mode" && op === "==") {
          return buildQuery({ ...filter, mode: value as string });
        }
        return buildQuery(filter);
      },
      async get() {
        const rows =
          filter.mode !== undefined
            ? store.docs.filter((d) => (d.mode ?? "extract") === filter.mode)
            : store.docs;
        return {
          size: rows.length,
          docs: rows.map((d) => ({
            id: d.id,
            data: () => docData(d),
          })),
        };
      },
    };
  }

  return {
    collection(_name: string) {
      return buildQuery({});
    },
  } as unknown as admin.firestore.Firestore;
}

interface TestCase {
  name: string;
  fn: () => Promise<void>;
}
const tests: TestCase[] = [];
function test(name: string, fn: () => Promise<void>): void {
  tests.push({ name, fn });
}

const EXPORTED_KEYS = [
  "id",
  "mode",
  "inputKind",
  "scrubbedInput",
  "scrubbedInputLength",
  "scrubbedOutput",
  "outputLength",
  "promptVersion",
  "promptSource",
  "experimentBucket",
  "promptVariant",
  "domain",
  "authUidHash",
  "modelId",
  "promptTokenCount",
  "candidatesTokenCount",
  "createdAt",
].sort();

// Test 1: the export carries ONLY the scrubbed-field whitelist. Seeding raw
// PII-shaped fields (rawUserId, unscrubbedInput, apiKey) and asserting the
// exported row's key set is exactly EXPORTED_KEYS pins the privacy boundary —
// a future field added to the source doc cannot silently leak into the export.
test("BUT-1659: export contains only the scrubbed-field whitelist", async () => {
  const store: FakeStore = {
    docs: [
      {
        id: "s1",
        createdAtMs: 1000,
        extra: {
          rawUserId: "uid-raw-should-not-leak",
          unscrubbedInput: "https://user@secret.example/recipe",
          apiKey: "sk-secret",
        },
      },
    ],
  };
  const rows = await runExportLlmSamplesWithDb(makeFakeDb(store), {});
  if (rows.length !== 1) throw new Error(`expected 1 row, got ${rows.length}`);
  const keys = Object.keys(rows[0]).sort();
  if (keys.join(",") !== EXPORTED_KEYS.join(",")) {
    throw new Error(
      `exported key set drifted.\n  got:      ${keys.join(",")}\n  expected: ${EXPORTED_KEYS.join(",")}`
    );
  }
  for (const leaked of ["rawUserId", "unscrubbedInput", "apiKey"]) {
    if (leaked in rows[0]) throw new Error(`raw field ${leaked} leaked into export`);
  }
});

// Test 2: deterministic sort — oldest createdAt first, ties broken by id,
// null createdAt last. Without a stable order the exported JSON churns on every
// run and the offline mining diffs become noise.
test("BUT-1659: rows sorted oldest-first, ties by id, null last", async () => {
  const store: FakeStore = {
    docs: [
      { id: "b", createdAtMs: 2000 },
      { id: "no-date", createdAtMs: null },
      { id: "a", createdAtMs: 2000 }, // same ts as "b" → id breaks the tie
      { id: "old", createdAtMs: 1000 },
    ],
  };
  const rows = await runExportLlmSamplesWithDb(makeFakeDb(store), {});
  const order = rows.map((r: { id: string }) => r.id).join(",");
  if (order !== "old,a,b,no-date") {
    throw new Error(`sort order wrong: ${order}`);
  }
});

// Test 3: --mode narrows to a single call type via an equality filter.
test("BUT-1659: mode filter narrows the export", async () => {
  const store: FakeStore = {
    docs: [
      { id: "e1", mode: "extract", createdAtMs: 100 },
      { id: "o1", mode: "ocr", createdAtMs: 200 },
      { id: "e2", mode: "extract", createdAtMs: 300 },
    ],
  };
  const rows = await runExportLlmSamplesWithDb(makeFakeDb(store), {
    mode: "extract",
  });
  const ids = rows.map((r: { id: string }) => r.id).sort();
  if (ids.join(",") !== "e1,e2") {
    throw new Error(`mode filter wrong: ${ids.join(",")}`);
  }
});

// Test 4: createdAt is emitted as an ISO string (Timestamp → ISO), and a
// missing createdAt coalesces to null rather than undefined (JSON-friendly).
test("BUT-1659: createdAt projected to ISO string, missing → null", async () => {
  const store: FakeStore = {
    docs: [
      { id: "withDate", createdAtMs: 0 },
      { id: "noDate", createdAtMs: null },
    ],
  };
  const rows = await runExportLlmSamplesWithDb(makeFakeDb(store), {});
  const withDate = rows.find((r: { id: string }) => r.id === "withDate");
  const noDate = rows.find((r: { id: string }) => r.id === "noDate");
  if (withDate.createdAt !== "1970-01-01T00:00:00.000Z") {
    throw new Error(`createdAt not ISO: ${withDate.createdAt}`);
  }
  if (noDate.createdAt !== null) {
    throw new Error(`missing createdAt should be null, got ${noDate.createdAt}`);
  }
});

// Test 5: empty collection yields a well-formed empty array (not undefined).
test("BUT-1659: empty collection yields []", async () => {
  const rows = await runExportLlmSamplesWithDb(makeFakeDb({ docs: [] }), {});
  if (!Array.isArray(rows) || rows.length !== 0) {
    throw new Error("expected empty array");
  }
});

// Test 6: projectSample coalesces absent optional fields to null (not
// undefined) so the written JSON has stable, explicit keys.
test("BUT-1659: projectSample coalesces absent fields to null", async () => {
  const row = projectSample("bare", { mode: "extract" });
  if (row.scrubbedInput !== null) throw new Error("scrubbedInput should be null");
  if (row.modelId !== null) throw new Error("modelId should be null");
  if (row.inputKind !== "") throw new Error("inputKind should default to empty string");
  if (row.createdAt !== null) throw new Error("createdAt should be null");
});

async function run(): Promise<void> {
  console.log("BUT-1659: export-llm-samples unit tests\n");
  console.log("========================================\n");
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(err);
    }
  }
  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
