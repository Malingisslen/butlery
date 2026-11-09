/**
 * Admin-vy step D: turns the queued word-list proposals (`kind:
 * occasionList`) into one rolling pull request on `bot/occasion-changes`,
 * which writes `occasions.json` and the generated `occasion_vocabulary.g.dart`
 * in one commit. Runs inside createIngredientChangePr, after the ingredient
 * PR and under the same lock, on its own branch and PR.
 *
 * The word lists are compiled into the app, so a merged PR is the change: a
 * proposal whose PR was merged with the commit it was last written into
 * (`prHeadSha`) becomes `applied` here, at the next run. A PR closed
 * unmerged, or merged with a different commit, hands its proposals back to
 * `pending`.
 *
 * The PR never touches the tagging answer key or `kTagGeneratorVersion`; its
 * text says the version must be raised before the next app release, and the
 * release check refuses a release until it is.
 */

import { HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { OCCASION_BOT_BRANCH, RepoClient } from "./github-app";
import {
  namedPulls,
  publishBotPull,
  pullState,
  readBotBranch,
  REJECTED_RETENTION_MS,
  REVIEW_RETENTION_MS,
  writeIfStatus,
} from "./bot-pull-request";
import { APPLIED_RETENTION_MS } from "./mark-applied-core";
import { OCCASION_LIST_KIND, OccasionPlan, planOccasionChanges, QueuedOccasionProposal } from "./occasion-change-plan";
import { buildOccasionPrBody, OCCASION_PR_TITLE } from "./occasion-pr-body";
import { OCCASIONS_PATH, VOCABULARY_PATH } from "./occasion-vocabulary";

// The admin app lists every editable list on one screen; this bounds a
// queue nobody can have built by hand.
export const MAX_OCCASION_QUEUE = 200;

export interface OccasionChangePrResult {
  prNumber: number | null;
  prUrl: string | null;
  applied: number;
  conflicts: number;
  rejected: number;
  reopened: number;
  // Proposals whose PR was merged, marked `applied` in this run.
  merged: number;
  skipped: number;
}

async function occasionsByStatus(db: admin.firestore.Firestore, status: string) {
  const snap = await db.collection(Collections.ingredientChangeRequests)
    .where("status", "==", status)
    .where("kind", "==", OCCASION_LIST_KIND)
    .limit(MAX_OCCASION_QUEUE + 1)
    .get();
  return snap.docs;
}

function toQueued(doc: admin.firestore.QueryDocumentSnapshot): QueuedOccasionProposal {
  const createdAt = doc.get("createdAt") as admin.firestore.Timestamp | undefined;
  return {
    id: doc.id,
    listKey: doc.get("listKey"),
    oldWords: doc.get("oldWords"),
    newWords: doc.get("newWords"),
    status: doc.get("status") === "inReview" ? "inReview" : "pending",
    createdAtMs: typeof createdAt?.toMillis === "function" ? createdAt.toMillis() : 0,
  };
}

export async function runOccasionChangePr(
  db: admin.firestore.Firestore,
  github: RepoClient,
  now: Date,
): Promise<OccasionChangePrResult> {
  const inReview = await occasionsByStatus(db, "inReview");
  const pending = await occasionsByStatus(db, "pending");
  const result: OccasionChangePrResult = {
    prNumber: null, prUrl: null, applied: 0, conflicts: 0, rejected: 0, reopened: 0, merged: 0, skipped: 0,
  };
  // Nothing queued and no branch left to tidy: no GitHub call at all.
  if (inReview.length === 0 && pending.length === 0 && await github.getRefSha(OCCASION_BOT_BRANCH) === null) {
    return result;
  }

  const branch = await readBotBranch(github, OCCASION_BOT_BRANCH);
  const pulls = await namedPulls(github, inReview);
  const stateOf = (d: admin.firestore.QueryDocumentSnapshot) => {
    const pull = pulls.get(d.get("prNumber"));
    return pull ? pullState(pull) : undefined;
  };
  const del = admin.firestore.FieldValue.delete();
  const isMergedWithIt = (d: admin.firestore.QueryDocumentSnapshot) => {
    const head = pulls.get(d.get("prNumber"))?.headSha;
    return stateOf(d) === "merged" && typeof head === "string" && d.get("prHeadSha") === head;
  };
  const merged = inReview.filter(isMergedWithIt);
  const mergedSkipped = await writeIfStatus(db, merged.map((d) => ({
    id: d.id,
    expected: "inReview",
    data: {
      status: "applied",
      appliedAt: admin.firestore.FieldValue.serverTimestamp(),
      expireAt: admin.firestore.Timestamp.fromMillis(now.getTime() + APPLIED_RETENTION_MS),
    },
  })));
  // A proposal left out of the branch after it was written `inReview` (a
  // status write that failed) still names the PR; merged without its words,
  // it goes back to the queue.
  const closed = inReview.filter((d) => stateOf(d) === "closed" || (stateOf(d) === "merged" && !isMergedWithIt(d)));
  const reopenSkipped = await writeIfStatus(db, closed.map((d) => ({
    id: d.id,
    expected: "inReview",
    data: { status: "pending", prNumber: del, prHeadSha: del, expireAt: del },
  })));
  result.merged = merged.length - mergedSkipped;
  result.reopened = closed.length - reopenSkipped;

  const queue = [
    ...(await occasionsByStatus(db, "pending")),
    ...(await occasionsByStatus(db, "inReview")).filter((d) => stateOf(d) !== "merged"),
  ];
  if (queue.length > MAX_OCCASION_QUEUE) throw new HttpsError("failed-precondition", "too-many-proposals");
  const queued = queue.map(toQueued);

  const main = await github.getCommitTree(branch.mainSha);
  const json = await github.getFile(OCCASIONS_PATH, branch.mainSha);
  const dart = await github.getFile(VOCABULARY_PATH, branch.mainSha);
  const plan = planOccasionChanges(json.text, dart.text, queued);

  let headSha: string | null = null;
  if (plan.appliedIds.length === 0) {
    if (branch.openPull) await github.closePull(branch.openPull.number);
  } else {
    const pull = await publishBotPull(github, {
      branch: OCCASION_BOT_BRANCH,
      state: branch,
      mainTreeSha: main.treeSha,
      files: [
        { path: OCCASIONS_PATH, text: plan.jsonText },
        { path: VOCABULARY_PATH, text: plan.dartText },
      ],
      title: OCCASION_PR_TITLE,
      body: buildOccasionPrBody(plan.order.map((id) => plan.outcomes.get(id)!)),
      message: `${OCCASION_PR_TITLE}\n\n${plan.appliedIds.length} förslag.`,
    });
    result.prNumber = pull.number;
    result.prUrl = pull.url;
    headSha = pull.headSha;
  }

  const expected = new Map(queued.map((q) => [q.id, q.status]));
  result.skipped = await writeIfStatus(db, plan.order.map((id) => ({
    id,
    expected: expected.get(id) as string,
    data: outcomeWrite(plan, id, result.prNumber, headSha, now),
  })));
  for (const o of plan.outcomes.values()) {
    if (o.kind === "apply") result.applied++;
    if (o.kind === "conflict") result.conflicts++;
    if (o.kind === "rejected") result.rejected++;
  }
  return result;
}

function outcomeWrite(
  plan: OccasionPlan,
  id: string,
  prNumber: number | null,
  prHeadSha: string | null,
  now: Date,
): Record<string, unknown> {
  const del = admin.firestore.FieldValue.delete();
  const o = plan.outcomes.get(id)!;
  const review = admin.firestore.Timestamp.fromMillis(now.getTime() + REVIEW_RETENTION_MS);
  if (o.kind === "apply") {
    return { status: "inReview", prNumber, prHeadSha, csvValue: del, reason: del, expireAt: review };
  }
  if (o.kind === "conflict") {
    // Same field as an ingredient conflict: the file's value, keyed by what
    // the proposal changes.
    return { status: "conflict", reason: "file-mismatch", csvValue: { [o.listKey]: o.current }, prNumber: del, prHeadSha: del, expireAt: review };
  }
  return {
    status: "rejected",
    reason: o.reason,
    csvValue: del,
    prNumber: del,
    prHeadSha: del,
    expireAt: admin.firestore.Timestamp.fromMillis(now.getTime() + REJECTED_RETENTION_MS),
  };
}
