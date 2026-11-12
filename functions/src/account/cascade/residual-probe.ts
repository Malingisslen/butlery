import * as admin from "firebase-admin";
import { DeletionResult } from "./core";
import { USER_MODERATION } from "./moderation";
import {
  probeUserIdCollections,
  probeOwnerFieldCollections,
  probeOwnRecipes,
} from "./residual-probe-top-level";
import {
  probePollVotes,
  probeLiveMenuBallots,
} from "./residual-probe-votes";
import { probeModerationRecords } from "./residual-probe-moderation";
import { probeUidKeyedAccountDocs } from "./residual-probe-account-docs";
import {
  probeRatingOwnerStamps,
  probeCommentStamps,
  probeRecipeMemberKeys,
  probeReactionStamps,
  probeCommentLikes,
} from "./residual-probe-recipe-social";
import { probeBlockMirrors } from "./residual-probe-blocks";
import {
  probeNotificationDelivery,
  probeOwnerKeyedDocs,
  probeIngredientChangeRuns,
} from "./residual-probe-owner-keyed";
import { probeUserSubcollections } from "./residual-probe-user-subcollections";
import {
  probeNotificationEffectiveness,
  probeFeatureRetention,
  probeRetentionAnalytics,
} from "./residual-probe-analytics";
import {
  probePersonalShoppingLists,
  probeSharedShoppingLists,
  probeSharedListAttribution,
} from "./residual-probe-shopping-lists";

/**
 * GDPR canary — query the highest-risk collections AFTER the cascade.
 * Any non-zero count means a delete path silently dropped data. The probe
 * is the safety net, never the cascade itself: errors are logged but never
 * abort the wider deletion.
 *
 * Mirrors `_probeResidualData` in the prior client implementation.
 */
export async function probeResidualData(
  db: admin.firestore.Firestore,
  uid: string,
  result: DeletionResult,
): Promise<void> {
  /**
   * BUT-2046 follow-up. A lawful hold makes the probe's own house rule — the
   * deleter is a true superset of the probe — false for the legs the hold
   * keeps, and that exception is written here rather than left to be inferred:
   * without it every held erasure reports `gdprCompliant: false` about itself,
   * permanently, with no code path able to clear it.
   *
   * The set must stay in step with `deleteModerationSystemEvents`'s own `legs`
   * array. They are two spellings of one decision about which rows survive a
   * hold, and the day they disagree the erasure lies about itself.
   *
   * Scoped to the RESOURCE, not to `retained` being non-empty: `RetainedRecord`
   * is a general shape, so the day a second Art. 17(3) hold ships over some
   * other collection, a length test would silently disarm the legs below for a
   * hold that has nothing to do with moderation.
   *
   * The skipped legs are named by their LOG LABELS below, not by collection,
   * because `report_history` has two legs and only one of them is held. The other —
   * "residual report rows as reporter" — must keep firing: it is the reporter
   * side, which the hold is deliberately one-directional about, and silencing
   * it would hide a real failure of `deleteReportHistoryByReporter`.
   */
  const held = result.retained.some(
    (r) => r.resourceType === USER_MODERATION,
  );

  let residual = 0;
  residual += await probeUserIdCollections(db, uid);
  residual += await probeOwnerFieldCollections(db, uid);
  residual += await probeOwnRecipes(db, uid);
  residual += await probePollVotes(db, uid);
  residual += await probeLiveMenuBallots(db, uid);
  residual += await probeModerationRecords(db, uid, held);
  residual += await probeUidKeyedAccountDocs(db, uid);
  residual += await probeRatingOwnerStamps(db, uid);
  residual += await probeCommentStamps(db, uid);
  residual += await probeRecipeMemberKeys(db, uid);
  residual += await probeReactionStamps(db, uid);
  residual += await probeCommentLikes(db, uid);
  residual += await probeBlockMirrors(db, uid);
  residual += await probeNotificationDelivery(db, uid);
  residual += await probeOwnerKeyedDocs(db, uid, held);
  residual += await probeIngredientChangeRuns(db, uid);
  residual += await probeUserSubcollections(db, uid);
  residual += await probeNotificationEffectiveness(db, uid);
  residual += await probePersonalShoppingLists(db, uid);
  residual += await probeSharedShoppingLists(db, uid);
  residual += await probeSharedListAttribution(db, uid);
  residual += await probeFeatureRetention(db, uid);
  residual += await probeRetentionAnalytics(db, uid);

  if (
    residual > 0 &&
    !result.failedCollections.includes("residual_data_detected")
  ) {
    result.failedCollections.push("residual_data_detected");
  }
}
