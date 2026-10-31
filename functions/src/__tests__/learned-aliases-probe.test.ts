/**
 * The residual probe's leg for alias candidates: after account deletion, a
 * candidate still naming the erased uid is reported, and nothing else is.
 * Kept apart from learned-aliases-cleanup.test.ts because the cascade fake
 * replaces the FieldValue helpers the other fake applies.
 *
 * Run: npx ts-node src/__tests__/learned-aliases-probe.test.ts
 */

import { FakeFirestore } from "./_account-deletion-cascade-fake-firestore";
import { OTHER, UID, asDb, check, finishSuite } from "./_account-deletion-cascade-test-seeds";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { probeResidualData } = require("../account/account-deletion-cascade");

const COL = "analytics/ingredients/learned_aliases";

function emptyResult() {
  return {
    deletedCollections: [] as string[],
    failedCollections: [] as string[],
    errors: [] as unknown[],
    retained: [] as unknown[],
  };
}

async function main(): Promise<void> {
  const clean = new FakeFirestore();
  clean.set(`${COL}/theirs`, { status: "pending", userIds: [OTHER] });
  clean.set(`${COL}/kept`, { status: "approved", userIds: [] });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "another person's candidate and a decided one with no voters leave the probe clean",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const left = new FakeFirestore();
  left.set(`${COL}/left`, { status: "pending", userIds: [UID] });
  const leftResult = emptyResult();
  await probeResidualData(asDb(left), UID, leftResult);
  check(
    "a candidate still naming the erased uid is reported as residual",
    leftResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(leftResult.failedCollections)}`,
  );

  finishSuite("learned_aliases residual probe");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
