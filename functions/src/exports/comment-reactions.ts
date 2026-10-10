/**
 * BUT-2318: GDPR Article 15 export of the emoji reactions a user has put on
 * comments.
 *
 * A reaction is the reactor's uid inside `recipe_comments/{id}.reactions.<key>`.
 * Finding one's own needs an `array-contains` query per key, which the
 * comment read rule cannot prove and so refuses to the client. Malin's call
 * (2026-10-10): read them here with the Admin SDK and return only
 * `{commentId, key}`, never comment content, and leave the rule as it is.
 *
 * Above the cap it DECLINES with `comment-reactions-too-large` and never
 * truncates: a truncated Art. 15 answer reads as complete.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { enforceRateLimit } from "../middleware/rate_limiter";
import {
  COMMENT_REACTION_KEYS,
  MAX_COMMENT_REACTION_SWEEP_ROWS,
} from "../account/account-deletion-cascade";

const db = admin.firestore();

export const RATE_LIMIT_KEY = "exportCommentReactions";
export const TOO_LARGE_ERROR_CODE = "comment-reactions-too-large";

/** Per key, the erasure sweep's own cap. */
export const MAX_REACTIONS_PER_KEY = MAX_COMMENT_REACTION_SWEEP_ROWS;

export interface CommentReactionExport {
  commentId: string;
  key: string;
}

export interface ExportCommentReactionsResponse {
  reactions: CommentReactionExport[];
  gdprArticle: "Article 15 - Right of Access";
}

/** The two collaborators the request handler needs, injectable for tests. */
export interface CommentReactionsDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  run: (uid: string) => Promise<ExportCommentReactionsResponse>;
}

/**
 * The uid is taken from `request.auth` only; `request.data` is never read, so
 * a payload naming another user changes nothing.
 */
export async function handleExportCommentReactions(
  request: { auth?: { uid: string } | null },
  deps: CommentReactionsDeps,
): Promise<ExportCommentReactionsResponse> {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  const uid = request.auth.uid;
  await deps.rateLimit(uid, RATE_LIMIT_KEY);
  return deps.run(uid);
}

export const exportCommentReactions = onCall(
  {
    timeoutSeconds: 60,
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  (request) =>
    handleExportCommentReactions(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      run: (uid) => runExportCommentReactionsWithDb(db, uid),
    }),
);

/** Test seam — accepts an injected Firestore. */
export async function runExportCommentReactionsWithDb(
  database: admin.firestore.Firestore,
  uid: string,
): Promise<ExportCommentReactionsResponse> {
  const snaps = await Promise.all(
    COMMENT_REACTION_KEYS.map((key) =>
      database
        .collection(Collections.recipeComments)
        .where(`reactions.${key}`, "array-contains", uid)
        // No fields: only the document id is read, never the comment.
        .select()
        .limit(MAX_REACTIONS_PER_KEY + 1)
        .get(),
    ),
  );

  const reactions: CommentReactionExport[] = [];
  snaps.forEach((snap, i) => {
    const key = COMMENT_REACTION_KEYS[i];
    if (snap.size > MAX_REACTIONS_PER_KEY) decline(uid, key);
    for (const doc of snap.docs) reactions.push({ commentId: doc.id, key });
  });
  reactions.sort(
    (a, b) => a.commentId.localeCompare(b.commentId) || a.key.localeCompare(b.key),
  );

  logger.info("exportCommentReactions.complete", {
    event: "export_comment_reactions.complete",
    uid_prefix: uid.slice(0, 6),
    reactions: reactions.length,
  });
  return { reactions, gdprArticle: "Article 15 - Right of Access" };
}

function decline(uid: string, key: string): never {
  logger.warn("exportCommentReactions.declined", {
    event: "export_comment_reactions.declined",
    uid_prefix: uid.slice(0, 6),
    key,
  });
  throw new HttpsError(
    "failed-precondition",
    "Comment reactions are too many to export in one response.",
    { error_code: TOO_LARGE_ERROR_CODE },
  );
}
