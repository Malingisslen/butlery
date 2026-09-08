/**
 * BUT-2043 — the reset script's "what does the database hold that no list
 * decides?" report.
 *
 * The report exists because no source-scanning guard can find an orphaned
 * rename: a dead spelling has no writer to scan for. Only a live read of the
 * database can, which is how BUT-2040 was found — by a person reading a dry
 * run's output. These cases pin that the comparison itself is right, so the
 * next one is found by the tool.
 */
import {
  findUnknownCollections,
  formatUnknownCollections,
} from "../admin/unknown-collections";
import { COLLECTIONS_TO_KEEP } from "../admin/reset-collection-lists";
import { USER_SUBCOLLECTIONS } from "../account/account-deletion-cascade";

let passed = 0;
let failed = 0;
function check(name: string, cond: boolean, detail: string): void {
  if (cond) {
    passed++;
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}\n        ${detail}`);
  }
}

function main(): void {
  console.log("BUT-2043 unknown-collection report\n");

  // --- Top-level ---------------------------------------------------------
  const invented = "collection_nobody_declared";
  const top = findUnknownCollections({
    topLevelInDb: ["users", COLLECTIONS_TO_KEEP[0], invented],
    subCountsByTarget: [],
  });
  check(
    "a top-level collection in no list is reported",
    top.topLevel.includes(invented),
    `reported: ${JSON.stringify(top.topLevel)}`,
  );
  check(
    "…and a deleted or kept one is not",
    !top.topLevel.includes("users") &&
      !top.topLevel.includes(COLLECTIONS_TO_KEEP[0]),
    `reported: ${JSON.stringify(top.topLevel)}`,
  );

  // --- Subcollections ----------------------------------------------------
  //
  // THE REGRESSION CASE, in the shape BUT-2040 had: a name no register
  // accounts for. `rateLimits` itself is in `USER_SUBCOLLECTIONS` now, so
  // seeding it would be silent and prove nothing — hence a synthetic name.
  const orphan = findUnknownCollections({
    topLevelInDb: [],
    subCountsByTarget: [{ collection: "users", subs: { legacy_orphan: 5 } }],
  });
  check(
    "a subcollection no list accounts for is reported",
    orphan.unknownSubcollections.some((s) => s.name === "legacy_orphan"),
    `reported: ${JSON.stringify(orphan.unknownSubcollections)}`,
  );
  check(
    "…and it names the top-level target it appeared under",
    orphan.unknownSubcollections[0]?.underTargets.includes("users"),
    `reported: ${JSON.stringify(orphan.unknownSubcollections)}`,
  );

  // --- The noise case, which is why this reads the CASCADE's list too ------
  //
  // Measured 2026-09-08: a check built on the reset script's `users`
  // inventory alone would report eight subcollections the cascade deletes
  // correctly. This case is what keeps the report quiet about them.
  const quiet = findUnknownCollections({
    topLevelInDb: [],
    subCountsByTarget: [
      {
        collection: "users",
        subs: Object.fromEntries(USER_SUBCOLLECTIONS.map((n) => [n, 1])),
      },
    ],
  });
  check(
    "every subcollection the cascade sweeps is silent",
    quiet.unknownSubcollections.length === 0,
    `would fire on: ${JSON.stringify(
      quiet.unknownSubcollections.map((s) => s.name),
    )}`,
  );

  // --- The scope sentence ships with the report ---------------------------
  const lines = formatUnknownCollections(orphan);
  check(
    "the report states what it does not range over",
    lines.some((l) => l.includes("Scope:")),
    `lines: ${JSON.stringify(lines)}`,
  );
  check(
    "a clean report says none rather than staying silent",
    formatUnknownCollections({
      topLevel: [],
      unknownSubcollections: [],
    }).filter((l) => l.includes("none")).length === 2,
    "an empty report that prints nothing reads as a report that did not run",
  );

  console.log(`\nBUT-2043 unknown-collection report: ${passed}/${passed + failed} passing`);
  if (failed > 0) process.exitCode = 1;
}

main();
