/**
 * BUT-2414 — emulator-backed test for the collection-group legs of
 * `exportErasureResidue`: `members` and `engagements` under `shared_content`
 * (with the document-id range), roster `participants`, `report_history`,
 * `activeUsers`, and the legacy `comments` and `ratings`.
 *
 * The emulator runs these queries for real, including the `shared_content`
 * document-id range a fake only imitates. It does NOT enforce indexes, so
 * index coverage is pinned by `erasure-residue.test.ts` against
 * `firestore.indexes.json`, not here.
 *
 * Per-run isolation: unique PROJECT_ID per suite + a per-run uid.
 *
 * Prerequisite: Firestore emulator running locally
 * (`bash .claude/hooks/ensure-firestore-emulator.sh`).
 *
 * Run: npx ts-node src/__tests__/erasure-residue.integration.test.ts
 */

import { requireEmulatorsOrSkip } from "./integration-gate";

const PROJECT_ID = "butlery-erasure-residue-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

// eslint-disable-next-line @typescript-eslint/no-require-imports
import * as admin from "firebase-admin";

const RUN = Date.now().toString(36);
const UID = `requester-${RUN}`;
const OTHER = `other-${RUN}`;

let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

type Rows = Array<Record<string, unknown>>;

async function run_(): Promise<void> {
  console.log("exportErasureResidue integration tests (BUT-2414)\n");
  console.log("=============================\n");

  await requireEmulatorsOrSkip(
    [{ name: "Firestore", hostPort: EMULATOR_HOST }],
    "bash .claude/hooks/ensure-firestore-emulator.sh",
  );

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();

  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const residue = require("../exports/erasure-residue") as typeof import("../exports/erasure-residue");

  const share = `share-${RUN}`;
  const seeds: Array<[string, Record<string, unknown>]> = [
    [`shared_content/${share}`, { sharedByUserId: OTHER, sharedToUserIds: [UID] }],
    [`shared_content/${share}/members/${UID}`, { userId: UID, displayName: "Me", addedBy: OTHER }],
    [`shared_content/${share}/members/${OTHER}`, { userId: OTHER }],
    [`users/${OTHER}/friend_categories/c-${RUN}/members/${UID}`, { userId: UID }],
    [`shared_content/${share}/x/y/members/${UID}`, { userId: UID }],
    [`shared_content/${share}/engagements/${UID}`, { userId: UID, action: "viewed" }],
    [`recipes/r-${RUN}/engagements/${UID}`, { userId: UID }],
    [`conversations/c-${RUN}/participants/${UID}`, {
      conversationId: `c-${RUN}`, participantId: UID, displayName: "Me",
    }],
    [`conversations/c-${RUN}/participants/${OTHER}`, { participantId: OTHER }],
    [`user_moderation/${OTHER}/report_history/rep-${RUN}`, {
      reportId: `rep-${RUN}`, reporterId: UID, reason: "spam",
    }],
    [`recipePresence/rec-${RUN}/activeUsers/${UID}`, { userId: UID, displayName: "Me" }],
    [`users/${OTHER}/recipes/r-${RUN}/comments/cm-${RUN}`, { commentedBy: UID, text: "Gott" }],
    [`users/${OTHER}/recipes/r-${RUN}/ratings/rt-${RUN}`, { ratedBy: UID, rating: 4 }],
  ];
  for (const [p, data] of seeds) await db.doc(p).set(data);

  const names = [
    "share_memberships",
    "share_engagements",
    "conversation_roster_rows",
    "report_history_as_reporter",
    "active_users",
    "legacy_comments",
    "legacy_ratings",
  ];
  const sections = residue.SECTIONS.filter((s) => names.includes(s.name));
  const out = await residue.runExportErasureResidueWithDb(db, UID, sections);
  const rows = (name: string): Rows => {
    const r = out.sections[name] as { rows?: Rows };
    return r.rows ?? [];
  };
  const dump = (name: string): string => JSON.stringify(out.sections[name]);

  check("every collection-group section answered", names.every((n) => "rows" in out.sections[n]),
    JSON.stringify(out.sections));
  check(
    "members: only the row under a top-level shared_content parent",
    rows("share_memberships").length === 1 && rows("share_memberships")[0].shareId === share,
    dump("share_memberships"),
  );
  check(
    "members: another person's addedBy is not exported",
    !dump("share_memberships").includes(OTHER),
    dump("share_memberships"),
  );
  check(
    "engagements: only the row under shared_content",
    rows("share_engagements").length === 1 && rows("share_engagements")[0].shareId === share,
    dump("share_engagements"),
  );
  check(
    "participants: the requester's roster row only",
    rows("conversation_roster_rows").length === 1 &&
      rows("conversation_roster_rows")[0].participantId === UID,
    dump("conversation_roster_rows"),
  );
  check(
    "report_history: the reporter's row, without the reported person's uid",
    rows("report_history_as_reporter").length === 1 &&
      !dump("report_history_as_reporter").includes(OTHER),
    dump("report_history_as_reporter"),
  );
  check(
    "activeUsers: the presence row with its parent",
    rows("active_users").length === 1 && rows("active_users")[0].parentId === `rec-${RUN}`,
    dump("active_users"),
  );
  check(
    "legacy comments and ratings: found by commentedBy and ratedBy",
    rows("legacy_comments").length === 1 && rows("legacy_ratings").length === 1,
    `${dump("legacy_comments")} ${dump("legacy_ratings")}`,
  );

  console.log(`\n${run - failed}/${run} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
