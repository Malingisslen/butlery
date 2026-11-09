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
import { connectRepo, FetchLike, GitHubError, INGREDIENT_BOT_BRANCH, RepoClient } from "./github-app";
import {
  publishBotPull,
  pullStates,
  readBotBranch,
  REJECTED_RETENTION_MS,
  REVIEW_RETENTION_MS,
  writeIfStatus,
} from "./bot-pull-request";
import { ChangePlan, planIngredientChanges, QueuedProposal, SelfCheckError } from "./ingredient-change-plan";
import { CsvWriteError } from "./ingredient-csv-writer";
import { buildPrBody, BodyConflict, BodyProposal, PR_TITLE } from "./ingredient-pr-body";
import { OccasionFileError } from "./occasion-vocabulary";
import { MAX_OCCASION_QUEUE, OccasionChangePrResult, runOccasionChangePr } from "./occasion-change-pr";

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
export { REVIEW_RETENTION_MS, REJECTED_RETENTION_MS };
export const RUN_RETENTION_MS = 365 * DAY_MS;

/** Fields only this function writes on a proposal (never the client). */
export const SERVER_WRITTEN_PROPOSAL_KEYS = ["prNumber", "prHeadSha", "csvValue", "reason"] as const;

const githubAppPrivateKey = defineSecret("GITHUB_APP_PRIVATE_KEY");

export interface IngredientChangePrResult {
  prNumber: number | null;
  prUrl: string | null;
  applied: number;
  conflicts: number;
  rejected: number;
  reopened: number;
  skipped: number;
  // Step D's word-list PR, built in the same run on its own branch. Null
  // when that part failed; `occasionError` then holds its error code.
  occasion: OccasionChangePrResult | null;
  occasionError: string | null;
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
  let occasion: OccasionChangePrResult | null = null;
  let occasionError: string | null = null;
  try {
    const github = await deps.connect();
    // The two PRs are independent: a failure in one never stops the other.
    let ingredientFailure: unknown = null;
    let ingredient: Omit<IngredientChangePrResult, "occasion" | "occasionError"> | null = null;
    try {
      ingredient = await runIngredientChangePr(deps.db, github, deps.now());
    } catch (err) {
      ingredientFailure = err;
    }
    try {
      occasion = await runOccasionChangePr(deps.db, github, deps.now());
    } catch (err) {
      occasionError = toHttpsError(err, uid, "occasion").message;
    }
    if (ingredient === null) throw ingredientFailure;
    const result: IngredientChangePrResult = { ...ingredient, occasion, occasionError };
    await writeRunRecord(deps.db, uid, { outcome: "ok", result }, deps.now());
    logger.info("ingredient_change_pr", { admin_hash: hashUid(uid), ...result });
    return result;
  } catch (err) {
    const failure = toHttpsError(err, uid, "ingredient");
    await writeRunRecord(deps.db, uid, { outcome: "failed", errorCode: failure.message, occasion, occasionError }, deps.now());
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
function toHttpsError(err: unknown, uid: string, part: "ingredient" | "occasion"): HttpsError {
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
  } else if (err instanceof OccasionFileError) {
    code = `occasion-${err.code}`;
  }
  logger.error("ingredient_change_pr failed", {
    admin_hash: hashUid(uid),
    part,
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

// Ingredient proposals carry no `kind`; a word-list proposal (step D) is
// left to occasion-change-pr.ts.
const isIngredientProposal = (d: admin.firestore.QueryDocumentSnapshot) => d.get("kind") == null;

async function byStatus(db: admin.firestore.Firestore, status: string) {
  // Word-list proposals share the collection, so the read leaves room for
  // them before the cap is judged on ingredient proposals alone.
  const snap = await db.collection(Collections.ingredientChangeRequests)
    .where("status", "==", status)
    .limit(MAX_QUEUE + MAX_OCCASION_QUEUE + 1)
    .get();
  if (snap.size > MAX_QUEUE + MAX_OCCASION_QUEUE) throw new HttpsError("failed-precondition", "too-many-proposals");
  return snap.docs.filter(isIngredientProposal);
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

export async function runIngredientChangePr(
  db: admin.firestore.Firestore,
  github: RepoClient,
  now: Date,
): Promise<Omit<IngredientChangePrResult, "occasion" | "occasionError">> {
  const branch = await readBotBranch(github, INGREDIENT_BOT_BRANCH);
  const { mainSha, openPull } = branch;

  // Sweep: a PR closed unmerged hands its proposals back to the queue, a
  // merged one keeps them `inReview` for the sync to mark `applied`.
  const inReview = await byStatus(db, "inReview");
  const pullState = await pullStates(github, inReview);
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
    const pull = await publishBotPull(github, {
      branch: INGREDIENT_BOT_BRANCH,
      state: branch,
      mainTreeSha: main.treeSha,
      files: [{ path: CSV_PATH, text: plan.text }],
      title: PR_TITLE,
      body: buildPrBody(bodyInput(plan, queued)),
      message: `${PR_TITLE}\n\n${plan.appliedIds.length} förslag.`,
    });
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
  | { outcome: "failed"; errorCode: string; occasion: OccasionChangePrResult | null; occasionError: string | null };

/** Best-effort: never throws, so it cannot mask the run's own result or error. */
async function writeRunRecord(
  db: admin.firestore.Firestore,
  uid: string,
  record: RunRecord,
  now: Date,
): Promise<void> {
  const r = record.outcome === "ok" ? record.result : null;
  const occasion = r ? r.occasion : record.outcome === "failed" ? record.occasion : null;
  const occasionError = r ? r.occasionError : record.outcome === "failed" ? record.occasionError : null;
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
      occasionPrNumber: occasion ? occasion.prNumber : null,
      occasionCounts: occasion
        ? {
          applied: occasion.applied, conflicts: occasion.conflicts, rejected: occasion.rejected,
          reopened: occasion.reopened, merged: occasion.merged, skipped: occasion.skipped,
        }
        : null,
      occasionErrorCode: occasionError,
      expireAt: admin.firestore.Timestamp.fromMillis(now.getTime() + RUN_RETENTION_MS),
    });
  } catch (err) {
    logger.error("ingredient_change_pr run record failed", {
      errCode: (err as { code?: unknown }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
}
