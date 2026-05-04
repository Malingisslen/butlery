/**
 * BUT-627: Ping sweeper.
 *
 * Sweeps expired `pings/{groupId}/pings/{pingId}` documents every 10
 * minutes via collection-group query. Pings carry `expiresAt` (default TTL
 * set client-side via `kPingDefaultTtl`); this server-side sweeper exists
 * as a defence-in-depth backstop in case clients fail to clean up after
 * themselves.
 *
 * Required composite index (firestore.indexes.json):
 *   collectionGroup `pings` on (`expiresAt` ASC).
 *
 * Region pinned via `setGlobalOptions` in index.ts.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { batchDeleteDocs } from "../shared/batch-delete";

const PAGE_SIZE = 500;
const MAX_PAGES = 20;

export interface SweeperDeps {
  db?: admin.firestore.Firestore;
  now?: () => Date;
}

export async function runPingSweeper(
  deps: SweeperDeps = {}
): Promise<{ deleted: number; durationMs: number }> {
  const start = Date.now();
  const db = deps.db ?? admin.firestore();
  const now = (deps.now ?? (() => new Date()))();
  const cutoff = admin.firestore.Timestamp.fromDate(now);

  let deleted = 0;
  // 500/page × 20 pages = 10k pings/run, far above realistic single-run
  // volume. The `<` filter + the deletes make each page disappear from
  // the query, so re-running the same query walks forward naturally.
  for (let page = 0; page < MAX_PAGES; page++) {
    const snap = await db
      .collectionGroup("pings")
      .where("expiresAt", "<", cutoff)
      .limit(PAGE_SIZE)
      .get();

    if (snap.empty) break;

    deleted += await batchDeleteDocs(db, snap);

    if (snap.size < PAGE_SIZE) break;
  }

  return { deleted, durationMs: Date.now() - start };
}

export const pingSweeper = onSchedule(
  { schedule: "every 10 minutes", timeoutSeconds: 120 },
  async () => {
    const { deleted, durationMs } = await runPingSweeper();
    logger.info("ping_sweeper.complete", {
      event: "ping_sweeper.complete",
      deleted,
      durationMs,
    });
  }
);
