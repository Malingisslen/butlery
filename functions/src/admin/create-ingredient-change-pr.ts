/**
 * Admin-vy step C: turns the queued ingredient proposals into one rolling
 * pull request against the ingredient CSV.
 *
 * Admin only. One run at a time (`ingredient_change_locks/singleton`). Each
 * run rebuilds `bot/ingredient-changes` from the current `main`, so a
 * withdrawn proposal drops out of the PR and a proposal whose PR was closed
 * unmerged goes back to `pending` first. Proposals the push carried become
 * `inReview` with the PR number; the rest become `conflict` or `rejected`.
 * Status writes re-read each proposal and leave one alone whose status moved
 * meanwhile (a withdrawal), so the PR can briefly hold a withdrawn proposal
 * until the next run.
 *
 * Nothing here writes an admin's uid outside Firestore: the commit and the
 * PR text carry ingredient data only, and logs and the run record carry a
 * hashed uid.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { requireAdmin } from "../shared/require-admin";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";
import { Collections } from "../shared/collections";
import { hashUid } from "../shared/hash-uid";
import {
  BASE_BRANCH,
  BranchCommit,
  connectRepo,
  FetchLike,
  GitHubError,
  INGREDIENT_BOT_BRANCH,
  RepoClient,
} from "./github-app";
import { ChangePlan, planIngredientChanges, QueuedProposal, SelfCheckError } from "./ingredient-change-plan";
import { CsvWriteError } from "./ingredient-csv-writer";
import { buildPrBody, BodyConflict, BodyProposal, PR_TITLE } from "./ingredient-pr-body";

export const RATE_LIMIT_KEY = "createIngredientChangePr";
export const GLOBAL_RATE_LIMIT_KEY = "createIngredientChangePrGlobal";
// The subject the global bucket is kept under; no uid is this string.
export const GLOBAL_RATE_LIMIT_SUBJECT = "all-admins";

export const CSV_PATH = "docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv";
// Same cap as IngredientChangeRequestRepository.maxPending in the app.
export const MAX_QUEUE = 500;
export const LOCK_DOC = "singleton";
export const LOCK_MS = 10 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
export const REVIEW_RETENTION_MS = 90 * DAY_MS;
export const REJECTED_RETENTION_MS = 365 * DAY_MS;
export const RUN_RETENTION_MS = 365 * DAY_MS;
const STATUS_CHUNK = 100;

/** Fields only this function writes on a proposal (never the client). */
export const SERVER_WRITTEN_PROPOSAL_KEYS = ["prNumber", "csvValue", "reason"] as const;

const githubAppPrivateKey = defineSecret("GITHUB_APP_PRIVATE_KEY");

export interface IngredientChangePrResult {
  prNumber: number | null;
  prUrl: string | null;
  applied: number;
  conflicts: number;
  rejected: number;
  reopened: number;
  skipped: number;
}

export interface CreateIngredientChangePrDeps {
  db: admin.firestore.Firestore;
  rateLimit: (subject: string, operation: string) => Promise<void>;
  connect: () => Promise<RepoClient>;
  now: () => Date;
  runId: () => string;
}

const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);

export async function handleCreateIngredientChangePr(
  request: CallableRequest<unknown>,
  deps: CreateIngredientChangePrDeps,
): Promise<IngredientChangePrResult> {
  requireAdmin(request);
  const uid = request.auth!.uid;
  const adminDoc = await deps.db.collection("admins").doc(uid).get();
  if (!adminDoc.exists) throw new HttpsError("permission-denied", "Admin access required");
  await deps.rateLimit(uid, RATE_LIMIT_KEY);
  await deps.rateLimit(GLOBAL_RATE_LIMIT_SUBJECT, GLOBAL_RATE_LIMIT_KEY);

  const runId = deps.runId();
  await acquireLock(deps.db, runId, deps.now());
  try {
    const github = await deps.connect();
    const result = await runIngredientChangePr(deps.db, github, deps.now());
    await writeRunRecord(deps.db, uid, { outcome: "ok", result }, deps.now());
    logger.info("ingredient_change_pr", { admin_hash: hashUid(uid), ...result });
    return result;
  } catch (err) {
    const failure = toHttpsError(err, uid);
    await writeRunRecord(deps.db, uid, { outcome: "failed", errorCode: failure.message }, deps.now());
    throw failure;
  } finally {
    await releaseLock(deps.db, runId).catch((err) =>
      logger.error("ingredient_change_pr lock release failed", {
        errCode: (err as { code?: unknown }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      }),
    );
  }
}

/** Every error leaves as a code; a message from GitHub or Firestore never does. */
function toHttpsError(err: unknown, uid: string): HttpsError {
  if (err instanceof HttpsError) return err;
  let code = "internal-error";
  let kind: "unavailable" | "internal" | "failed-precondition" = "internal";
  if (err instanceof GitHubError) {
    code = `github-${err.code}`;
    kind = err.code === "not-configured" ? "failed-precondition" : "unavailable";
  } else if (err instanceof SelfCheckError) {
    code = `self-check-${err.code}`;
  } else if (err instanceof CsvWriteError) {
    code = `csv-${err.code}`;
  }
  logger.error("ingredient_change_pr failed", {
    admin_hash: hashUid(uid),
    code,
    status: err instanceof GitHubError ? err.status : null,
    errName: err instanceof Error ? err.name : typeof err,
  });
  return new HttpsError(kind, code);
}

export const createIngredientChangePr = onCall(
  {
    timeoutSeconds: 300,
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
    secrets: [githubAppPrivateKey],
  },
  async (request) => {
    const db = admin.firestore();
    return handleCreateIngredientChangePr(request, {
      db,
      rateLimit: (subject, operation) => enforceRateLimit(subject, operation),
      connect: () => connectRepo({ fetch: fetch as unknown as FetchLike, privateKey: githubAppPrivateKey.value() }),
      now: () => new Date(),
      runId: () => db.collection(Collections.ingredientChangeLocks).doc().id,
    });
  },
);

function lockRef(db: admin.firestore.Firestore) {
  return db.collection(Collections.ingredientChangeLocks).doc(LOCK_DOC);
}

/**
 * A lock past `expiresAt` belongs to a run that died; it is taken over. It
 * names the run, never the admin, so nothing in it outlives an erasure.
 */
export async function acquireLock(db: admin.firestore.Firestore, runId: string, now: Date): Promise<void> {
  const ref = lockRef(db);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const expiresAt = snap.get("expiresAt") as admin.firestore.Timestamp | undefined;
    if (snap.exists && expiresAt && expiresAt.toMillis() > now.getTime() && snap.get("owner") !== runId) {
      throw new HttpsError("failed-precondition", "locked");
    }
    tx.set(ref, { owner: runId, expiresAt: ts(now.getTime() + LOCK_MS) });
  });
}

export async function releaseLock(db: admin.firestore.Firestore, runId: string): Promise<void> {
  const ref = lockRef(db);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists && snap.get("owner") === runId) tx.delete(ref);
  });
}

async function byStatus(db: admin.firestore.Firestore, status: string) {
  const snap = await db.collection(Collections.ingredientChangeRequests)
    .where("status", "==", status)
    .limit(MAX_QUEUE + 1)
    .get();
  return snap.docs;
}

/** Writes [data] on each doc whose status is still [expected]; returns how many were left alone. */
async function writeIfStatus(
  db: admin.firestore.Firestore,
  writes: Array<{ id: string; expected: string; data: Record<string, unknown> }>,
): Promise<number> {
  let skipped = 0;
  const col = db.collection(Collections.ingredientChangeRequests);
  for (let i = 0; i < writes.length; i += STATUS_CHUNK) {
    const chunk = writes.slice(i, i + STATUS_CHUNK);
    skipped += await db.runTransaction(async (tx) => {
      const snaps = await Promise.all(chunk.map((w) => tx.get(col.doc(w.id))));
      let left = 0;
      chunk.forEach((w, j) => {
        if (snaps[j].exists && snaps[j].get("status") === w.expected) tx.update(col.doc(w.id), w.data);
        else left++;
      });
      return left;
    });
  }
  return skipped;
}

function toQueued(doc: admin.firestore.QueryDocumentSnapshot): QueuedProposal {
  const createdAt = doc.get("createdAt") as admin.firestore.Timestamp | undefined;
  return {
    id: doc.id,
    ingredientId: String(doc.get("ingredientId") ?? ""),
    changes: doc.get("changes"),
    status: doc.get("status") === "inReview" ? "inReview" : "pending",
    createdAtMs: typeof createdAt?.toMillis === "function" ? createdAt.toMillis() : 0,
  };
}

// A commit the App makes through the API is authored by the App and
// committed by GitHub's `web-flow`, which signs it; only that signature tells
// it apart from a commit someone else pushed with the App named as author.
export const GITHUB_WEB_FLOW_LOGIN = "web-flow";

export function isAppCommit(c: BranchCommit, botLogin: string): boolean {
  if (c.authorLogin !== botLogin) return false;
  return (c.committerLogin === botLogin || c.committerLogin === GITHUB_WEB_FLOW_LOGIN) && c.verified;
}

function refused(code: string): HttpsError {
  return new HttpsError("aborted", code);
}

export async function runIngredientChangePr(
  db: admin.firestore.Firestore,
  github: RepoClient,
  now: Date,
): Promise<IngredientChangePrResult> {
  const mainSha = await github.getRefSha(BASE_BRANCH);
  if (!mainSha) throw new GitHubError("no-main", null, "main has no ref");
  const botSha = await github.getRefSha(INGREDIENT_BOT_BRANCH);
  if (botSha) {
    const foreign = (await github.branchCommits(INGREDIENT_BOT_BRANCH)).some((c) => !isAppCommit(c, github.botLogin));
    if (foreign) throw refused("foreign-commits");
  }
  const openPull = await github.findOpenPull(INGREDIENT_BOT_BRANCH);

  // Sweep: a PR closed unmerged hands its proposals back to the queue, a
  // merged one keeps them `inReview` for the sync to mark `applied`.
  const inReview = await byStatus(db, "inReview");
  const pullState = new Map<number, "open" | "merged" | "closed">();
  for (const n of new Set(inReview.map((d) => d.get("prNumber")).filter((n): n is number => typeof n === "number"))) {
    const pull = await github.getPull(n);
    pullState.set(n, pull.state === "open" ? "open" : pull.merged ? "merged" : "closed");
  }
  const reopen = inReview.filter((d) => pullState.get(d.get("prNumber")) === "closed");
  const reopenSkipped = await writeIfStatus(db, reopen.map((d) => ({
    id: d.id,
    expected: "inReview",
    data: {
      status: "pending",
      prNumber: admin.firestore.FieldValue.delete(),
      expireAt: admin.firestore.FieldValue.delete(),
    },
  })));

  const queue = [
    ...(await byStatus(db, "pending")),
    ...(await byStatus(db, "inReview")).filter((d) => pullState.get(d.get("prNumber")) !== "merged"),
  ];
  if (queue.length > MAX_QUEUE) throw new HttpsError("failed-precondition", "too-many-proposals");
  const queued = queue.map(toQueued);

  const main = await github.getCommitTree(mainSha);
  const csv = await github.getFile(CSV_PATH, mainSha);
  const plan = planIngredientChanges(csv.text, queued, now);
  // Proposals that cancel out (x to y, then y to x) leave main's file as it
  // is. A PR would be empty, and left pending they would cancel out again on
  // every run, so they are closed as `no-change`.
  if (plan.appliedIds.length > 0 && plan.text === csv.text) {
    for (const id of plan.appliedIds) plan.outcomes.set(id, { kind: "rejected", reason: "no-change" });
    plan.appliedIds = [];
  }

  let prNumber: number | null = null;
  let prUrl: string | null = null;
  if (plan.appliedIds.length === 0) {
    if (openPull) await github.closePull(openPull.number);
  } else {
    const body = buildPrBody(bodyInput(plan, queued));
    const upToDate = botSha !== null && await branchHolds(github, botSha, mainSha, plan.text);
    if (!upToDate) {
      const commit = await github.commitFile({
        parent: mainSha, baseTree: main.treeSha, path: CSV_PATH, text: plan.text,
        message: `${PR_TITLE}\n\n${plan.appliedIds.length} förslag.`,
      });
      // GitHub's ref update has no compare-and-swap, so check right before it.
      if (await github.getRefSha(BASE_BRANCH) !== mainSha) throw refused("main-moved");
      if (await github.getRefSha(INGREDIENT_BOT_BRANCH) !== botSha) throw refused("branch-moved");
      if (openPull && (await github.getPull(openPull.number)).merged) throw refused("pr-merged");
      if (botSha) await github.forceUpdateBotBranch(INGREDIENT_BOT_BRANCH, commit.commitSha);
      else await github.createBotBranch(INGREDIENT_BOT_BRANCH, commit.commitSha);
    }
    const pull = openPull
      ? await github.updatePull(openPull.number, { title: PR_TITLE, body })
      : await github.createPull({ branch: INGREDIENT_BOT_BRANCH, title: PR_TITLE, body });
    if (openPull && pull.merged) throw refused("pr-merged-during-rebuild");
    prNumber = pull.number;
    prUrl = pull.url;
  }

  const expected = new Map(queued.map((q) => [q.id, q.status]));
  const writes = plan.order.map((id) => ({
    id,
    expected: expected.get(id) as string,
    data: outcomeWrite(plan, id, prNumber, now),
  }));
  const skipped = await writeIfStatus(db, writes);

  let conflicts = 0;
  let rejected = 0;
  for (const o of plan.outcomes.values()) {
    if (o.kind === "conflict") conflicts++;
    if (o.kind === "rejected") rejected++;
  }
  return {
    prNumber, prUrl, applied: plan.appliedIds.length, conflicts, rejected,
    reopened: reopen.length - reopenSkipped, skipped,
  };
}

/** True when the bot branch already is main plus exactly this CSV. */
async function branchHolds(github: RepoClient, botSha: string, mainSha: string, text: string): Promise<boolean> {
  const bot = await github.getCommitTree(botSha);
  if (bot.parents.length !== 1 || bot.parents[0] !== mainSha) return false;
  return (await github.getFile(CSV_PATH, botSha)).text === text;
}

function outcomeWrite(plan: ChangePlan, id: string, prNumber: number | null, now: Date): Record<string, unknown> {
  const del = admin.firestore.FieldValue.delete();
  const o = plan.outcomes.get(id)!;
  if (o.kind === "apply") {
    return {
      status: "inReview",
      prNumber,
      csvValue: del,
      reason: del,
      expireAt: admin.firestore.Timestamp.fromMillis(now.getTime() + REVIEW_RETENTION_MS),
    };
  }
  if (o.kind === "conflict") {
    return {
      status: "conflict",
      reason: o.reason,
      csvValue: o.csvValue ?? del,
      prNumber: del,
      expireAt: admin.firestore.Timestamp.fromMillis(now.getTime() + REVIEW_RETENTION_MS),
    };
  }
  return {
    status: "rejected",
    reason: o.reason,
    csvValue: del,
    prNumber: del,
    expireAt: admin.firestore.Timestamp.fromMillis(now.getTime() + REJECTED_RETENTION_MS),
  };
}

function bodyInput(plan: ChangePlan, queued: QueuedProposal[]) {
  const ingredientOf = new Map(queued.map((q) => [q.id, q.ingredientId]));
  const applied: BodyProposal[] = [];
  const conflicts: BodyConflict[] = [];
  const rejected: Array<{ ingredientId: string; reason: string }> = [];
  for (const id of plan.order) {
    const o = plan.outcomes.get(id)!;
    const ingredientId = ingredientOf.get(id) ?? "";
    if (o.kind === "apply") {
      applied.push({ ingredientId, swedishName: o.swedishName, changes: o.changes });
    } else if (o.kind === "conflict") {
      const columns = o.csvValue ? o.changes.filter((c) => c.column in o.csvValue!) : [];
      if (columns.length === 0) {
        conflicts.push({ ingredientId, swedishName: o.swedishName, column: null, csvValue: null, old: null, new: null });
      }
      for (const c of columns) {
        conflicts.push({
          ingredientId, swedishName: o.swedishName, column: c.column,
          csvValue: o.csvValue![c.column], old: c.old, new: c.new,
        });
      }
    } else {
      rejected.push({ ingredientId, reason: o.reason });
    }
  }
  return { applied, conflicts, rejected };
}

type RunRecord =
  | { outcome: "ok"; result: IngredientChangePrResult }
  | { outcome: "failed"; errorCode: string };

/** Best-effort: never throws, so it cannot mask the run's own result or error. */
async function writeRunRecord(
  db: admin.firestore.Firestore,
  uid: string,
  record: RunRecord,
  now: Date,
): Promise<void> {
  const r = record.outcome === "ok" ? record.result : null;
  try {
    await db.collection(Collections.ingredientChangeRuns).doc().set({
      adminUidHash: hashUid(uid),
      ranAt: admin.firestore.FieldValue.serverTimestamp(),
      outcome: record.outcome,
      errorCode: record.outcome === "failed" ? record.errorCode : null,
      prNumber: r ? r.prNumber : null,
      counts: r
        ? { applied: r.applied, conflicts: r.conflicts, rejected: r.rejected, reopened: r.reopened, skipped: r.skipped }
        : null,
      expireAt: admin.firestore.Timestamp.fromMillis(now.getTime() + RUN_RETENTION_MS),
    });
  } catch (err) {
    logger.error("ingredient_change_pr run record failed", {
      errCode: (err as { code?: unknown }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
}
