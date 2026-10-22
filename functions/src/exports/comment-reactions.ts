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
 * BUT-2398: the same for the reactions a user has put on chat messages
 * (`messages/{id}.reactions.<key>`), returned as `{messageId, key}`, never
 * message content.
 *
 * Above the cap it DECLINES with `comment-reactions-too-large` or
 * `message-reactions-too-large` and never truncates: a truncated Art. 15
 * answer reads as complete.
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
  MAX_MESSAGE_REACTION_SWEEP_ROWS,
} from "../account/account-deletion-cascade";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";

const db = admin.firestore();

export const RATE_LIMIT_KEY = "exportCommentReactions";
export const TOO_LARGE_ERROR_CODE = "comment-reactions-too-large";
export const MESSAGES_TOO_LARGE_ERROR_CODE = "message-reactions-too-large";

/** Per key, the erasure sweep's own cap. */
export const MAX_REACTIONS_PER_KEY = MAX_COMMENT_REACTION_SWEEP_ROWS;
export const MAX_MESSAGE_REACTIONS_PER_KEY = MAX_MESSAGE_REACTION_SWEEP_ROWS;

export interface CommentReactionExport {
  commentId: string;
  key: string;
}

export interface MessageReactionExport {
  messageId: string;
  key: string;
}

export interface ExportCommentReactionsResponse {
  reactions: CommentReactionExport[];
  messageReactions: MessageReactionExport[];
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
    cors: WEB_CALLABLE_ORIGINS,
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
  const [commentRows, messageRows] = await Promise.all([
    reactionRows(database, Collections.recipeComments, uid, MAX_REACTIONS_PER_KEY),
    reactionRows(database, Collections.messages, uid, MAX_MESSAGE_REACTIONS_PER_KEY),
  ]);
  if ("overCapKey" in commentRows) {
    decline(uid, commentRows.overCapKey, TOO_LARGE_ERROR_CODE);
  }
  if ("overCapKey" in messageRows) {
    decline(uid, messageRows.overCapKey, MESSAGES_TOO_LARGE_ERROR_CODE);
  }

  const reactions = commentRows.rows.map(({ id, key }) => ({ commentId: id, key }));
  const messageReactions = messageRows.rows.map(({ id, key }) => ({ messageId: id, key }));

  logger.info("exportCommentReactions.complete", {
    event: "export_comment_reactions.complete",
    uid_prefix: uid.slice(0, 6),
    reactions: reactions.length,
    messageReactions: messageReactions.length,
  });
  return {
    reactions,
    messageReactions,
    gdprArticle: "Article 15 - Right of Access",
  };
}

/**
 * The requester's reactions in one collection, sorted by document id then key,
 * or the first key holding more than `cap` rows.
 */
async function reactionRows(
  database: admin.firestore.Firestore,
  collection: string,
  uid: string,
  cap: number,
): Promise<{ rows: { id: string; key: string }[] } | { overCapKey: string }> {
  const snaps = await Promise.all(
    COMMENT_REACTION_KEYS.map((key) =>
      database
        .collection(collection)
        .where(`reactions.${key}`, "array-contains", uid)
        // No fields: only the document id is read, never the content.
        .select()
        .limit(cap + 1)
        .get(),
    ),
  );
  const over = snaps.findIndex((snap) => snap.size > cap);
  if (over >= 0) return { overCapKey: COMMENT_REACTION_KEYS[over] };

  const rows: { id: string; key: string }[] = [];
  snaps.forEach((snap, i) => {
    const key = COMMENT_REACTION_KEYS[i];
    for (const doc of snap.docs) rows.push({ id: doc.id, key });
  });
  rows.sort((a, b) => a.id.localeCompare(b.id) || a.key.localeCompare(b.key));
  return { rows };
}

function decline(uid: string, key: string, errorCode: string): never {
  logger.warn("exportCommentReactions.declined", {
    event: "export_comment_reactions.declined",
    uid_prefix: uid.slice(0, 6),
    key,
    error_code: errorCode,
  });
  throw new HttpsError(
    "failed-precondition",
    "Reactions are too many to export in one response.",
    { error_code: errorCode },
  );
}
