/**
 * BUT-2490: a group admin saves the group's recurring-day rules ("fasta
 * dagar"), stored as `chat_groups/{groupId}.recurringDayRules`.
 *
 * A callable rather than a client write, like every other write to a chat
 * group: `firestore.rules` refuses the field from every client, and the rows
 * are checked here (`recurring-day-rules.ts`), which rules cannot do for a
 * list. The rows name no person: no author, no uid, no timestamp.
 *
 * The caller must be in the group's STORED `adminIds` (and `memberIds`). A
 * missing group, a non-member, a member and an admin of another group all get
 * the same `permission-denied`, so the call answers nothing about a group the
 * caller is not admin of.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions/logger";
import { Firestore, getFirestore } from "firebase-admin/firestore";
import { Collections } from "../shared/collections";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { isValidDocId } from "../shared/valid-doc-id";
import { checkRecurringDayRules } from "./recurring-day-rules";

export interface SetGroupRecurringDayRulesRequest {
  groupId: string;
  rules: unknown[];
}

export type SetGroupRecurringDayRulesResponse = Record<string, never>;

export interface SetGroupRecurringDayRulesDeps {
  /** Spends the caller's `setGroupRecurringDayRules` bucket; throws when empty. */
  rateLimit: (uid: string) => Promise<void>;
}

export const RECURRING_DAY_RULES_FIELD = "recurringDayRules";

export const setGroupRecurringDayRules =
  onCall<SetGroupRecurringDayRulesRequest>(
    { enforceAppCheck: true },
    async (request): Promise<SetGroupRecurringDayRulesResponse> =>
      setGroupRecurringDayRulesWithDeps(
        getFirestore(),
        request.auth?.uid,
        request.data,
        {
          // `enforceRateLimit`, not `withRateLimit`: the latter also spends the
          // global LLM budget, and this call costs no model spend (ADR-0013).
          rateLimit: (uid) => enforceRateLimit(uid, "setGroupRecurringDayRules"),
        },
      ),
  );

function stringIds(value: unknown): string[] {
  return Array.isArray(value) ? value.filter(isValidDocId) : [];
}

/** Dependency-injected core, exposed for tests with a fake Firestore. */
export async function setGroupRecurringDayRulesWithDeps(
  db: Firestore,
  callerUid: string | undefined,
  data: unknown,
  deps: SetGroupRecurringDayRulesDeps,
): Promise<SetGroupRecurringDayRulesResponse> {
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Sign-in required.");
  }
  await deps.rateLimit(callerUid);

  const request = (data ?? {}) as Partial<Record<string, unknown>>;
  const groupId = request.groupId;
  if (!isValidDocId(groupId)) {
    throw new HttpsError("invalid-argument", "groupId is required.");
  }
  const checked = checkRecurringDayRules(request.rules);
  if (!checked.ok) {
    throw new HttpsError("invalid-argument", "Invalid rules.", {
      reason: checked.reason,
    });
  }

  const groupRef = db.collection(Collections.chatGroups).doc(groupId);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(groupRef);
    const group = snap.exists ? (snap.data() ?? {}) : {};
    if (
      !snap.exists ||
      !stringIds(group.memberIds).includes(callerUid) ||
      !stringIds(group.adminIds).includes(callerUid)
    ) {
      throw new HttpsError("permission-denied", "Not allowed.");
    }
    tx.update(groupRef, { [RECURRING_DAY_RULES_FIELD]: checked.rows });
  });

  logger.info("[setGroupRecurringDayRules] saved", {
    groupId,
    ruleCount: checked.rows.length,
  });
  return {};
}
