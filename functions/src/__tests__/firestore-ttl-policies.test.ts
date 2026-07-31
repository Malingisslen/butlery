/**
 * BUT-1699 — the TTL policies declared in `firestore.indexes.json`.
 *
 * Two collections stamped an `expireAt` field for months while no policy ever
 * deleted anything: `notification_send_events` (30d) and
 * `scheduled_notifications` (7d). Both writers even carried a comment saying
 * the policy needed a manual one-off `gcloud` command that was never run. This
 * suite pins them as DECLARED, alongside the 13 that were already there.
 *
 * WHAT THIS SUITE CAN AND CANNOT PROVE. It proves the policy is DECLARED in the
 * file that gets deployed. It cannot prove the policy is ACTIVE in a project —
 * Firestore offers no round-trip, so nothing in this repo can. Activation is
 * `firebase deploy --only firestore:indexes` followed by a
 * `gcloud firestore fields ttls list` check by a human. Do not let a green run
 * here be read as "retention is on"; that was exactly the mistake the three
 * stale runbook claims made.
 *
 * THE COUNT ASSERTION IS THE POINT, not decoration.
 * `firebase deploy --only firestore:indexes --force` DELETES any TTL policy
 * absent from this file. A future edit that drops entries would otherwise be
 * invisible until retention silently stopped on collections nobody was looking
 * at. Asserting the exact total turns that into a red test. If you are adding a
 * policy, bump the number deliberately; if a diff lowers it, that is the bug.
 *
 * Run: `npm run test:firestore-ttl-policies` (from functions/).
 */

import * as fs from "fs";
import * as path from "path";

// functions/src/__tests__ → up 3 → repo root. Same resolution as
// compute-feature-retention.test.ts, which is the precedent this mirrors.
const INDEXES_PATH = path.resolve(
  __dirname,
  "..",
  "..",
  "..",
  "firestore.indexes.json",
);

interface FieldOverride {
  collectionGroup: string;
  fieldPath: string;
  ttl?: boolean;
  indexes?: unknown[];
}

const results: { name: string; passed: boolean; reason?: string }[] = [];

function record(name: string, passed: boolean, reason?: string): void {
  results.push({ name, passed, reason });
}

function loadOverrides(): FieldOverride[] {
  const parsed = JSON.parse(fs.readFileSync(INDEXES_PATH, "utf8"));
  if (!Array.isArray(parsed.fieldOverrides)) {
    throw new Error("firestore.indexes.json has no `fieldOverrides` array");
  }
  return parsed.fieldOverrides as FieldOverride[];
}

/** The two this ticket adds, with the retention its writer stamps. */
const TARGETS: { group: string; days: number; writer: string }[] = [
  {
    group: "notification_send_events",
    days: 30,
    writer: "functions/src/shared/notification-send-events.ts",
  },
  {
    group: "scheduled_notifications",
    days: 7,
    writer: "functions/src/shared/scheduled-notifications.ts",
  },
];

/**
 * Every TTL policy declared today: 13 pre-existing + the 2 BUT-1699 adds.
 *
 * The SET, not just the count. A count catches a `--force` prune (net loss),
 * which is the main threat — but it stays green when one entry is deleted and
 * another added in the same edit. Since the groups are named anyway, asserting
 * the set costs nothing and catches the swap too.
 *
 * Verified against production 2026-07-31 (`gcloud firestore fields ttls list`):
 * the 13 below were live and ACTIVE before the BUT-1699 deploy, and the 2 new
 * ones went from absent to present after it — which is also the empirical proof
 * that declaring in this file is what creates a policy.
 */
const EXPECTED_TTL_GROUPS = [
  "audit_logs",
  "deletion_audit_logs",
  "dismissals",
  "engagements",
  "globalRecipeCache",
  "ingredients",
  "llm_response_samples",
  "notification_delivery",
  "notification_engagement",
  "notification_history",
  "notification_send_events",
  "parse_events",
  "rate_limits",
  "scheduled_notifications",
  "views",
].sort();

function ttlPoliciesDeclared(): void {
  const overrides = loadOverrides();

  for (const target of TARGETS) {
    const match = overrides.find(
      (o) => o.collectionGroup === target.group && o.ttl === true,
    );

    record(
      `${target.group} declares a TTL policy on expireAt (${target.days}d, written by ${target.writer})`,
      match !== undefined && match.fieldPath === "expireAt",
      match === undefined
        ? "no fieldOverride with ttl:true — nothing deletes this collection, and its rows have accumulated since the feature shipped"
        : `fieldPath=${match.fieldPath} (a TTL policy names ONE field; the writers stamp 'expireAt')`,
    );
  }

  // A TTL policy is only meaningful if the writer actually STAMPS the field it
  // names — a rename on either side silently inerts the policy with no error
  // anywhere, which is the whole failure mode this ticket exists to end.
  //
  // This must match the WRITE, not the prose. A `src.includes("expireAt")`
  // check was tried first and is VACUOUS: both writers name the field five
  // times in their own docstrings, so renaming the actually-written key to
  // `expiresAt` left the suite 5/5 green (proven by mutation, 2026-07-31).
  // Anchor on the assignment shape instead.
  const stampsExpireAt = /expireAt:\s*admin\.firestore\.Timestamp\./;
  for (const target of TARGETS) {
    const writerPath = path.resolve(__dirname, "..", "..", "..", target.writer);
    const src = fs.existsSync(writerPath)
      ? fs.readFileSync(writerPath, "utf8")
      : "";
    record(
      `${target.writer} actually STAMPS expireAt (not merely mentions it)`,
      stampsExpireAt.test(src),
      src === ""
        ? `writer not found at ${target.writer} — the path moved, so this policy may now target a field nothing stamps`
        : "no `expireAt: admin.firestore.Timestamp.…` assignment found — if the key was renamed, the declared policy is now inert",
    );
  }

  const declared = overrides
    .filter((o) => o.ttl === true)
    .map((o) => o.collectionGroup)
    .sort();

  const missing = EXPECTED_TTL_GROUPS.filter((g) => !declared.includes(g));
  const unexpected = declared.filter((g) => !EXPECTED_TTL_GROUPS.includes(g));

  record(
    `exactly these ${EXPECTED_TTL_GROUPS.length} collection groups declare a TTL policy (the --force-deploy tripwire)`,
    missing.length === 0 && unexpected.length === 0,
    [
      missing.length > 0
        ? `MISSING: ${missing.join(", ")} — a deploy would switch retention OFF for these, silently. That is the bug, not this test.`
        : "",
      unexpected.length > 0
        ? `NOT IN THE LIST: ${unexpected.join(", ")} — if you deliberately added a policy, add it to EXPECTED_TTL_GROUPS in the same edit.`
        : "",
    ]
      .filter(Boolean)
      .join(" | "),
  );
}

function main(): void {
  ttlPoliciesDeclared();

  let failed = 0;
  for (const r of results) {
    if (r.passed) {
      console.log(`  PASS  ${r.name}`);
    } else {
      failed += 1;
      console.log(`  FAIL  ${r.name}`);
      if (r.reason) console.log(`        ${r.reason}`);
    }
  }
  console.log(
    `\nBUT-1699 TTL policy declarations: ${results.length - failed}/${results.length} passing.`,
  );
  if (failed > 0) process.exit(1);
}

main();
