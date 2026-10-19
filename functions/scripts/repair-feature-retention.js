/**
 * Runs the one-shot `cooked`/`shared` feature-retention repair
 * (src/analytics/repair-feature-retention.ts) against production. Prints
 * counts per day, never a uid. Dry run unless `--apply`.
 *
 * Needs `npm run build` first (it loads the compiled module from lib/).
 *
 * Usage (from functions/):
 *   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> \
 *     node scripts/repair-feature-retention.js --from 2026-10-04 --to 2026-10-18 [--apply]
 */

const admin = require("firebase-admin");

function arg(name) {
  const i = process.argv.indexOf(name);
  return i >= 0 ? process.argv[i + 1] : undefined;
}

async function main() {
  const {
    repairFeatureRetentionFlags,
    RepairProbeError,
  } = require("../lib/analytics/repair-feature-retention");
  admin.initializeApp();
  const from = arg("--from");
  const to = arg("--to");
  if (!from || !to) throw new Error("--from and --to are required");
  try {
    const report = await repairFeatureRetentionFlags({
      from,
      to,
      apply: process.argv.includes("--apply"),
    });
    console.log(JSON.stringify(report, null, 2));
  } catch (err) {
    if (err instanceof RepairProbeError) {
      console.log(
        JSON.stringify(
          {
            probeFailed: err.flag,
            date: err.date,
            code: err.code,
            indexSpec: err.indexSpec,
          },
          null,
          2,
        ),
      );
      process.exit(2);
    }
    throw err;
  }
}

main().catch((err) => {
  // The name and message of a non-probe error (bad input, batch too large).
  console.error(err instanceof Error ? `${err.name}: ${err.message}` : "failed");
  process.exit(1);
});
