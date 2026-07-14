/**
 * BUT-1598 — index-config assertion for `cleanupExpiredSocialRequests`.
 *
 * The cleanup query in `cleanup/cleanup-expired-social-requests.ts` is:
 *   collection('social_requests')
 *     .where('status', '==', 'pending')   // equality
 *     .where('sentAt', '<', cutoff)       // range
 *
 * An equality filter combined with a range filter on a DIFFERENT field REQUIRES
 * a composite index (`status ASC, sentAt ASC`) — pure-equality filters merge via
 * automatic single-field indexes, but the moment a range joins, Firestore needs
 * the composite or the scheduled cleanup throws PERMISSION_DENIED/FAILED_PRECONDITION
 * at runtime (a failure an in-memory fake can never catch — same reasoning as the
 * `sum()`/`average()` composite-index lesson). This test pins the declared config
 * so a future edit that drops the index fails loudly in CI instead of silently at
 * the next weekly run.
 *
 * Run: npx ts-node src/__tests__/cleanup-expired-social-requests.test.ts
 *
 * Pure config assertion — no Firestore, no admin app needed.
 */

// eslint-disable-next-line @typescript-eslint/no-require-imports
const fs = require("fs");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const path = require("path");

interface IndexField {
  fieldPath: string;
  order?: string;
  arrayConfig?: string;
}

interface CompositeIndex {
  collectionGroup: string;
  queryScope: string;
  fields: IndexField[];
}

// functions/src/__tests__ → up 3 → repo root.
const INDEXES_PATH = path.resolve(
  __dirname,
  "..",
  "..",
  "..",
  "firestore.indexes.json"
);

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

function loadIndexes(): CompositeIndex[] {
  const raw = fs.readFileSync(INDEXES_PATH, "utf8");
  const parsed = JSON.parse(raw);
  if (!Array.isArray(parsed.indexes)) {
    throw new Error("firestore.indexes.json has no `indexes` array");
  }
  return parsed.indexes as CompositeIndex[];
}

function socialRequestsStatusSentAtCompositeDeclared(): void {
  const indexes = loadIndexes();

  const match = indexes.find(
    (idx) =>
      idx.collectionGroup === "social_requests" &&
      idx.fields.length === 2 &&
      idx.fields[0].fieldPath === "status" &&
      idx.fields[0].order === "ASCENDING" &&
      idx.fields[1].fieldPath === "sentAt" &&
      idx.fields[1].order === "ASCENDING"
  );

  record(
    "firestore.indexes.json declares the social_requests (status ASC, sentAt ASC) composite",
    match !== undefined,
    match === undefined
      ? "no composite with fields [status ASC, sentAt ASC] found on social_requests"
      : `queryScope=${match.queryScope}`
  );

  // The cleanup query is a plain collection query (not a collectionGroup
  // query), so the composite must be COLLECTION-scoped to serve it.
  record(
    "the (status, sentAt) composite is COLLECTION-scoped (serves the collection query)",
    match !== undefined && match.queryScope === "COLLECTION",
    match ? `queryScope=${match.queryScope}` : "index missing"
  );
}

function runAll(): void {
  console.log("BUT-1598: social_requests cleanup index-config assertion\n");
  console.log("==========================================\n");
  socialRequestsStatusSentAtCompositeDeclared();

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : "")
  );
  if (totalFailed > 0) process.exit(1);
}

runAll();
