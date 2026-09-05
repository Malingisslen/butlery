/**
 * The reset kill switch (BUT-2028).
 *
 * `admin/reset-user-data.ts` deletes every Auth user in Phase 1 and then wipes
 * Firestore in Phase 2. Deleting an Auth user fires `onUserDeleted`, which
 * writes into collections Phase 2 is concurrently deleting — a race the script
 * cannot win, because a gen1 Auth trigger has no bounded delivery time.
 *
 * So the script switches the trigger OFF for the duration. What it would do
 * during a reset is unnecessary as well as harmful: the references it repairs
 * belong to accounts Phase 1 has already deleted, and the collections it
 * writes its own-data deletes into are in Phase 2's delete list.
 *
 * Operating instructions, including how to clear a stuck flag by hand:
 * `docs/ops/reset-user-data-runbook.md`.
 *
 * **This is the dangerous part of BUT-2028.** A flag that sticks ON silently
 * stops report anonymisation and between-user cleanup on every REAL account
 * deletion. Several things guard that: the script clears it in a `finally` and
 * on SIGINT/SIGTERM, the document carries an expiry the reader honours and the
 * run re-stamps while it works, and the verification phase fails the run if the
 * document is still standing at the end.
 */

import * as admin from "firebase-admin";

/**
 * Where the flag lives.
 *
 * `system` — beside `system/config`, this repo's existing kill-switch home
 * (BUT-439) — and NOT `site_configs`, which every signed-in user can read and
 * which `log-parse-event.ts` writes at runtime with hostnames as document ids.
 *
 * The document id is deliberately `__`-prefixed. Every other document in
 * `system` is a domain key (`config`, `llmLimits`, `prompts`), so a name that
 * cannot be mistaken for one is what stops a future writer merging the flag
 * into a config document — or a config write clearing the flag.
 */
export const RESET_KILL_SWITCH_COLLECTION = "system";
export const RESET_KILL_SWITCH_DOC_ID = "__reset_in_progress";
export const RESET_KILL_SWITCH_PATH = `${RESET_KILL_SWITCH_COLLECTION}/${RESET_KILL_SWITCH_DOC_ID}`;

/**
 * How long a set flag stays believable.
 *
 * This bounds the RUN, not only an abandoned one — so the script re-stamps it
 * as it works (`setResetKillSwitch` with the same run id). Without that a
 * long Phase 2 outlives its own suppression: the flag reads expired,
 * `onUserDeleted` resumes mid-wipe, and the race this exists to stop is back
 * with nothing on screen to say so.
 */
export const RESET_KILL_SWITCH_TTL_MINUTES = 90;

export interface ResetKillSwitchState {
  /**
   * Whether a document is there at all. The verification phase asks THIS —
   * `active || expired || runId` misses a document with a future expiry,
   * `active: false` and no run id, which is exactly the "tidy record" shape
   * deleting-rather-than-flagging exists to forbid.
   */
  exists: boolean;
  /** True only for a flag that is set AND has not expired. */
  active: boolean;
  /** Present whenever a document exists, expired or not. */
  runId?: string;
  startedAt?: number;
  expiresAt?: number;
  /** True when a document exists but its expiry has passed. */
  expired: boolean;
}

/**
 * Reads the flag. **Never cache this.**
 *
 * Other flag readers in this repo cache at module scope for minutes at a
 * time. That is right for a config value read on every request and wrong
 * here: a warm instance would keep writing long after the switch was thrown,
 * which is exactly the window the switch exists to close. This costs one
 * document read per real account deletion, forever, and
 * caching it away is not an acceptable trade.
 *
 * Expiry is enforced HERE rather than by a Firestore TTL policy. A TTL policy
 * is configured per collection, so arming one on `system` would point it at
 * `system/config` — the LLM kill switch — and delete it on schedule. The
 * document is removed by the script's `finally`; this expiry is the net for
 * when that never runs.
 */
export async function readResetKillSwitch(
  db: admin.firestore.Firestore,
): Promise<ResetKillSwitchState> {
  const snap = await db.doc(RESET_KILL_SWITCH_PATH).get();
  if (!snap.exists) return { exists: false, active: false, expired: false };

  const data = snap.data() ?? {};
  const startedAt = toMillis(data.startedAt);
  const expiresAt = toMillis(data.expiresAt);
  const runId = typeof data.runId === "string" ? data.runId : undefined;

  // A document with no usable expiry is treated as EXPIRED, not as active.
  // Failing closed here would mean a malformed write — by a future edit, or by
  // a half-finished set — disabling the cleanup trigger permanently, with
  // nothing to notice: the run that wrote it has ended, so nothing is going to
  // clear it.
  if (expiresAt === undefined) {
    return { exists: true, active: false, expired: true, runId, startedAt };
  }

  const expired = expiresAt <= Date.now();
  return {
    exists: true,
    active: data.active === true && !expired,
    expired,
    runId,
    startedAt,
    expiresAt,
  };
}

function toMillis(value: unknown): number | undefined {
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (typeof value === "number") return value;
  return undefined;
}

/**
 * Sets the flag, or re-stamps an existing one with a fresh expiry. The run id
 * stays the same across re-stamps, and is what `clearResetKillSwitch` compares
 * against.
 */
export async function setResetKillSwitch(
  db: admin.firestore.Firestore,
  runId: string,
  ttlMinutes: number = RESET_KILL_SWITCH_TTL_MINUTES,
): Promise<void> {
  const now = Date.now();
  // A whole-document `set`, never a merge: a merge would inherit `active`,
  // `runId` and `expiresAt` from an abandoned earlier run, so a partially
  // written flag could survive into a run that believes it wrote its own.
  await db.doc(RESET_KILL_SWITCH_PATH).set({
    active: true,
    runId,
    startedAt: admin.firestore.Timestamp.fromMillis(now),
    expiresAt: admin.firestore.Timestamp.fromMillis(now + ttlMinutes * 60_000),
  });
}

/**
 * Removes the flag, and says whether it did.
 *
 * With a `runId` it declines, returning false, when the stored id belongs to
 * another run. A stored id that is not a string falls through and deletes:
 * such a document cannot be attributed to anyone, so leaving it would suppress
 * the cleanup trigger with no run left to finish and clear it. The
 * no-argument form has no production caller.
 *
 * Deletes rather than setting `active: false`, so a leftover document is
 * always a fault rather than sometimes a tidy record — the verification phase
 * asks whether the document is gone, which is a question with one right
 * answer.
 */
export async function clearResetKillSwitch(
  db: admin.firestore.Firestore,
  runId?: string,
): Promise<boolean> {
  const ref = db.doc(RESET_KILL_SWITCH_PATH);
  if (runId === undefined) {
    await ref.delete();
    return true;
  }
  // Transactional compare, so a run cannot clear a flag another run set. Two
  // overlapping runs are implausible behind the confirmation gate, but the
  // failure mode if they happen is the one this whole module guards: the
  // second run finishes, deletes the flag, and leaves the first wiping with
  // the trigger live again.
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (!snap.exists) return true;
    const storedRunId = snap.data()?.runId;
    if (typeof storedRunId === "string" && storedRunId !== runId) return false;
    tx.delete(ref);
    return true;
  });
}
