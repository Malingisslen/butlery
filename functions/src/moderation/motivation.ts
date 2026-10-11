/**
 * BUT-2353: the ready-made motivation a moderator picks when closing a report.
 *
 * Only the KEY is stored and returned; the app owns the text. The key set is
 * mirrored in Dart, so a key added here must be added there in the same change.
 */

import type { Decision } from "./report-decision";

export const MOTIVATIONS_BY_DECISION: Readonly<Record<Decision, readonly string[]>> = {
  content_removed: [
    "removed_copyright",
    "removed_spam",
    "removed_abuse",
    "removed_harassment",
    "removed_other",
  ],
  profile_hidden: ["hidden_rules", "hidden_spam"],
  no_action: ["kept_no_breach", "kept_already_gone", "kept_unclear"],
};

export const DEFAULT_MOTIVATION: Readonly<Record<Decision, string>> = {
  content_removed: "removed_other",
  profile_hidden: "hidden_rules",
  no_action: "kept_no_breach",
};

/**
 * A misattribution report removes the reporter's own name from a dish, so the
 * only thing there is to say about it is that the name is gone, whatever the
 * moderator picked.
 */
export const MISATTRIBUTION_MOTIVATION = "misattribution_name_removed";

/**
 * The key to store for [decision]. A missing key, or one that belongs to
 * another decision, falls back to the decision's default rather than being
 * refused: the close has already happened by the time the server sees it.
 */
export function resolveMotivation(decision: Decision, reason: unknown, raw: unknown): string {
  if (reason === "misattribution") return MISATTRIBUTION_MOTIVATION;
  if (typeof raw === "string" && MOTIVATIONS_BY_DECISION[decision].includes(raw)) return raw;
  return DEFAULT_MOTIVATION[decision];
}
