/**
 * Marks `inReview` admin proposals `applied` once the ingredient sync has put
 * their values in Firestore. Run by .github/workflows/sync-ingredients.yml
 * right after the sync:
 *
 *   npx ts-node src/admin/mark-applied-proposals.ts --project <id>
 *
 * Prints counts only, appends them to $GITHUB_STEP_SUMMARY when set, and
 * exits 0 when there is nothing to do. The decision is in mark-applied-core.ts.
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import { initializeAdminApp } from "./admin-init";
import { formatMarkAppliedSummary, markAppliedProposals } from "./mark-applied-core";

// Outside main(): a refused --project must print its own reason.
initializeAdminApp();

async function main(): Promise<void> {
  const counts = await markAppliedProposals(admin.firestore(), new Date());
  console.log(
    `inReview=${counts.inReview} applied=${counts.applied} notYet=${counts.notYet} skipped=${counts.skipped}`,
  );
  if (process.env.GITHUB_STEP_SUMMARY) {
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, formatMarkAppliedSummary(counts));
  }
}

// A Firestore error message can name a document path; the code is enough.
main().catch((err) => {
  console.error(
    `mark-applied-proposals failed: ${err instanceof Error ? err.name : typeof err}` +
      ` code=${(err as { code?: unknown }).code ?? "none"}`,
  );
  process.exit(1);
});
