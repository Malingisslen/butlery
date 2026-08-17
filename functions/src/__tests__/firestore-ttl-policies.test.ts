/**
 * The TTL policies declared in `firestore.indexes.json` (BUT-1699, BUT-1792).
 *
 * The recurring defect is one shape: a writer stamps an expiry field, a comment
 * promises a one-off `gcloud` command will arm the policy, nobody runs it, and
 * the collection grows forever with nothing anywhere reporting a problem. Six
 * collections have been found in that state so far — `notification_send_events`
 * and `scheduled_notifications` (BUT-1699), then `notification_opened_events`,
 * `report_processing_markers`, `system_ip_audit_caps` and the presence rows in
 * `activeUsers` (BUT-1792). This suite pins every policy as DECLARED.
 *
 * `activeUsers` is the one to read twice: its field is `expiresAt`, with an
 * `s`, because a Dart writer stamps it while every TS writer in TARGETS spells
 * it `expireAt`. A TTL policy names exactly one field, so declaring the wrong
 * spelling produces a policy that is live, valid and deletes nothing — the
 * failure this whole suite exists to make visible, arrived at through the fix
 * rather than the omission. Hence a per-target field name below, never a
 * constant.
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

/**
 * Every policy whose writer this suite checks, with the field that writer
 * actually stamps and the retention that writer stamps.
 *
 * `field` and `stamp` are per-target on purpose. A shared field name would have
 * hard-coded `expireAt` and made the `activeUsers` entry — the one that spells
 * it `expiresAt` — the single case the suite could not express. A shared regex
 * would have done the same to the Dart writers, which cannot match a
 * `admin.firestore.Timestamp` pattern at all.
 */
const TARGETS: {
  group: string;
  field: string;
  retention: string;
  writer: string;
  stamp: RegExp;
}[] = [
  {
    group: "notification_send_events",
    field: "expireAt",
    retention: "30d",
    writer: "functions/src/shared/notification-send-events.ts",
    stamp: /expireAt:\s*admin\.firestore\.Timestamp\./,
  },
  {
    group: "scheduled_notifications",
    field: "expireAt",
    retention: "7d",
    writer: "functions/src/shared/scheduled-notifications.ts",
    stamp: /expireAt:\s*admin\.firestore\.Timestamp\./,
  },
  // BUT-1792 — four more collections stamping an expiry with no policy behind it.
  {
    group: "notification_opened_events",
    field: "expireAt",
    retention: "30d",
    writer: "functions/src/notifications/record-notification-opened.ts",
    stamp: /expireAt:\s*admin\.firestore\.Timestamp\./,
  },
  {
    group: "report_processing_markers",
    field: "expireAt",
    retention: "180d",
    writer: "functions/src/feedback/on-report-created.ts",
    stamp: /expireAt:\s*admin\.firestore\.Timestamp\./,
  },
  {
    group: "system_ip_audit_caps",
    field: "expireAt",
    retention: "2h",
    writer: "functions/src/account/verify-signup-age.ts",
    stamp: /expireAt:\s*admin\.firestore\.Timestamp\./,
  },
  // Presence rows. Two Dart writers, one shared helper, and the field is
  // `expiresAt` — see the header. The anchor is the helper call rather than a
  // Timestamp constructor, for the same reason the TS anchor is not
  // `src.includes("expiresAt")`: both files name the field in prose.
  {
    group: "activeUsers",
    field: "expiresAt",
    retention: "60s",
    writer: "lib/repositories/firebase/firebase_recipe_presence_repository.dart",
    stamp: /'expiresAt':\s*PresenceTtl\.computeExpiresAt\(\)/,
  },
  // `activeUsers` is a collection GROUP with more than one parent, so it has
  // more than one writer — and anchoring only the first leaves the second free
  // to rename the field while this suite stays green and shopping-presence rows
  // silently stop being reaped. That is the exact hole the suite exists to
  // close, reached from the one direction a per-collection list does not cover.
  // Every entry above names a single STAMPING writer because its collection
  // has one. Not a single writer full stop — `scheduled_notifications` is also
  // updated by `deliver-scheduled-notifications.ts`, and three of the five are
  // deleted from by `on-user-deleted.ts`. What this suite anchors is whoever
  // sets the EXPIRY FIELD, which is the only writer a renamed field can break.
  {
    group: "activeUsers",
    field: "expiresAt",
    retention: "60s",
    writer:
      "lib/repositories/firebase/firebase_shopping_presence_repository.dart",
    stamp: /'expiresAt':\s*PresenceTtl\.computeExpiresAt\(\)/,
  },
];

/**
 * Every TTL policy declared today: 13 pre-existing + 2 (BUT-1699) + 4 (BUT-1792).
 *
 * The SET, not just the count. A count catches a `--force` prune (net loss),
 * which is the main threat — but it stays green when one entry is deleted and
 * another added in the same edit. Since the groups are named anyway, asserting
 * the set costs nothing and catches the swap too.
 *
 * Verified against production 2026-07-31 (`gcloud firestore fields ttls list`):
 * 13 of these were live and ACTIVE before the BUT-1699 deploy, and the 2 that
 * ticket added went from absent to present after it — which is also the
 * empirical proof that declaring in this file is what creates a policy. The 4
 * BUT-1792 entries have NOT been checked against a project: they are declared
 * here and become real on the next `firebase deploy --only firestore:indexes`.
 * Do not extend the 2026-07-31 verification to cover them.
 */
const EXPECTED_TTL_GROUPS = [
  "activeUsers",
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
  "notification_opened_events",
  "notification_send_events",
  "parse_events",
  "report_processing_markers",
  "rate_limits",
  "scheduled_notifications",
  "system_ip_audit_caps",
  "views",
].sort();

function ttlPoliciesDeclared(): void {
  const overrides = loadOverrides();

  for (const target of TARGETS) {
    const match = overrides.find(
      (o) => o.collectionGroup === target.group && o.ttl === true,
    );

    record(
      `${target.group} declares a TTL policy on ${target.field} (${target.retention}, written by ${target.writer})`,
      match !== undefined && match.fieldPath === target.field,
      match === undefined
        ? "no fieldOverride with ttl:true — nothing deletes this collection, and its rows have accumulated since the feature shipped"
        : `fieldPath=${match.fieldPath}, writer stamps '${target.field}' (a TTL policy names ONE field; the wrong name arms a policy that deletes nothing)`,
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
  // Anchor on the assignment shape instead — `target.stamp`, per writer, since
  // the Dart presence writer has no `admin.firestore.Timestamp` to anchor on.
  for (const target of TARGETS) {
    const writerPath = path.resolve(__dirname, "..", "..", "..", target.writer);
    const src = fs.existsSync(writerPath)
      ? fs.readFileSync(writerPath, "utf8")
      : "";
    record(
      `${target.writer} actually STAMPS ${target.field} (not merely mentions it)`,
      target.stamp.test(src),
      src === ""
        ? `writer not found at ${target.writer} — the path moved, so this policy may now target a field nothing stamps`
        : `no assignment matching ${target.stamp} found — if the key was renamed, the declared policy is now inert`,
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
    `\nTTL policy declarations: ${results.length - failed}/${results.length} passing.`,
  );
  if (failed > 0) process.exit(1);
}

main();
