/**
 * Notification importance classification (BUT-647).
 *
 * Used by the server-side quiet-hours gate to decide whether a push that
 * lands during a user's quiet window should be DROPPED (low-importance)
 * or DELAYED until window end (high-importance).
 *
 * Keep in lockstep with the client-side notification-type allowlist.
 * Unknown types default to `low` — that errs on the side of NOT bothering
 * the user during quiet hours, which is the cheaper failure mode (the
 * client-side notification doc is still written, so the user sees it
 * in-app).
 */

export type NotificationImportance = "low" | "high";

const HIGH_IMPORTANCE_TYPES: ReadonlySet<string> = new Set([
  // Direct social interaction — user is expecting these.
  "comment_posted",
  "comment_reply",
  "friend_request_received",
  "friend_request_accepted",
  "recipe_shared",
  "menu_share_received",
  "cooking_session_started",
  "cooking_session_invite",
]);

const LOW_IMPORTANCE_TYPES: ReadonlySet<string> = new Set([
  "win_back_mild",
  "win_back_moderate",
  "win_back_strong",
  "activity_digest",
  "marketing",
  "tip",
  "feature_announcement",
]);

export function classifyImportance(
  notificationType: string | undefined
): NotificationImportance {
  if (!notificationType) return "low";
  if (HIGH_IMPORTANCE_TYPES.has(notificationType)) return "high";
  if (LOW_IMPORTANCE_TYPES.has(notificationType)) return "low";
  // Unknown → default low (safer: don't disturb during quiet hours).
  return "low";
}

/** Test-only export so spec assertions can pin the exact lists. */
export const __INTERNAL_HIGH_TYPES = HIGH_IMPORTANCE_TYPES;
export const __INTERNAL_LOW_TYPES = LOW_IMPORTANCE_TYPES;
