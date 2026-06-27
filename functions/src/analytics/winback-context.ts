/**
 * BUT-934: Contextual win-back copy.
 *
 * Personalizes the win-back push with what the user actually has, instead
 * of the generic threshold copy in `BASELINE_COPY` / the A/B variants.
 * Deterministic — a rule-based priority ladder, NO LLM call.
 *
 * Cost model (this is the BUT-934 cost tradeoff, decided 2026-06-27):
 *   - The lapsed-user detection query already loads each user's full doc,
 *     so the profile / recipes / friends signals cost ZERO extra reads.
 *   - The friend-share signal (highest impact — "Anna delade ett recept
 *     med dig") costs ONE indexed query per lapsed user per run. Included
 *     deliberately; it reuses the existing `sharedToUserIds CONTAINS +
 *     sharedAt DESC` composite index, so no index maintenance is added.
 *
 * Resolution returns `null` when no signal applies → the caller falls back
 * to the existing Remote Config variant copy (`winback-variant.ts`). The
 * layer is purely additive: on any failure it degrades to generic copy,
 * never blocking the send.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";

/** A resolved, personalized push line plus the signal that produced it. */
export interface ContextualCopy {
  title: string;
  body: string;
  /** Analytics key for the winning signal (e.g. "ctx_friend_share"). */
  contextKey: string;
}

/**
 * Mirror of the deleted-sharer tombstone written by `on-user-deleted.ts`
 * (`SHARED_BY_DISPLAY_NAME_TOMBSTONE`). Duplicated rather than imported to
 * avoid coupling this module to the cleanup function; the value rarely
 * changes and a stale name in a push is the only failure mode if it drifts.
 */
const SHARED_BY_DISPLAY_NAME_TOMBSTONE = "[Raderad användare]";

/**
 * A friend share older than this is not a compelling reason to return —
 * fall through to a fresher signal or the generic copy instead.
 */
export const SHARE_RECENCY_MS = 30 * 24 * 60 * 60 * 1000;

/** Title is kept constant for brand consistency with the existing copy. */
const TITLE = "Butlery";

interface RecentShare {
  sharerName: string;
  sharedAtMs: number;
}

export interface ResolveContextDeps {
  db?: admin.firestore.Firestore;
  /** Current time in ms; injected for deterministic recency tests. */
  now?: number;
  /** Test seam: override the friend-share lookup entirely. */
  loadRecentShare?: (userId: string) => Promise<RecentShare | null>;
}

/**
 * First whitespace-delimited token of a display name ("Anna Andersson"
 * → "Anna"). Falls back to the whole trimmed name if there's no space.
 */
function firstName(displayName: string): string {
  const trimmed = displayName.trim();
  const space = trimmed.search(/\s/);
  return space === -1 ? trimmed : trimmed.slice(0, space);
}

function toMillis(value: unknown): number | null {
  if (value instanceof admin.firestore.Timestamp) return value.toMillis();
  if (value instanceof Date) return value.getTime();
  if (typeof value === "number") return value;
  return null;
}

/**
 * Default friend-share loader: the single most-recent recipe shared TO
 * this user that (a) wasn't shared BY them (the share creator seeds their
 * own uid into `sharedToUserIds`), (b) has a usable sharer name, and (c)
 * is within the recency window.
 *
 * Reads up to 3 docs so own-shares / tombstoned sharers can be skipped
 * without a second query. Because the query is ordered `sharedAt` desc,
 * once we reach a valid-named share that is stale, every later doc is
 * older too, so we stop.
 */
export async function loadRecentShareDefault(
  db: admin.firestore.Firestore,
  userId: string,
  nowMs: number,
): Promise<RecentShare | null> {
  const snap = await db
    .collection("shared_recipes")
    .where("sharedToUserIds", "array-contains", userId)
    .orderBy("sharedAt", "desc")
    .limit(3)
    .get();

  for (const doc of snap.docs) {
    const data = doc.data();
    if (data.sharedByUserId === userId) continue; // creator seeded self
    const name = data.sharedByDisplayName;
    if (typeof name !== "string" || name.trim().length === 0) continue;
    if (name === SHARED_BY_DISPLAY_NAME_TOMBSTONE) continue;

    const sharedAtMs = toMillis(data.sharedAt);
    if (sharedAtMs == null) continue;
    if (nowMs - sharedAtMs > SHARE_RECENCY_MS) return null; // newest valid is stale

    return { sharerName: name, sharedAtMs };
  }
  return null;
}

/**
 * Resolve personalized copy for a lapsed user, or `null` to fall back to
 * the generic variant copy.
 *
 * Priority ladder (highest engagement intent first):
 *   1. ctx_friend_share  — a recent recipe a friend shared with them.
 *   2. ctx_setup_prefs   — onboarding/dietary prefs never set up.
 *   3. ctx_saved_recipes — they have recipes waiting.
 *   4. ctx_has_friends   — they have friends to re-engage with.
 *
 * `userData` is the already-loaded user doc — signals 2–4 read no extra
 * data. Signal 1 is the only one that issues a query.
 */
export async function resolveContextualWinbackCopy(
  userId: string,
  userData: admin.firestore.DocumentData,
  deps: ResolveContextDeps = {},
): Promise<ContextualCopy | null> {
  const nowMs = deps.now ?? Date.now();

  // 1. Friend share (the only costed signal). Resolve Firestore lazily so
  // an injected `loadRecentShare` seam never touches the Admin SDK.
  try {
    const loader = deps.loadRecentShare
      ? deps.loadRecentShare
      : (uid: string) =>
          loadRecentShareDefault(deps.db ?? admin.firestore(), uid, nowMs);
    const share = await loader(userId);
    if (share) {
      return {
        title: TITLE,
        body: `${firstName(share.sharerName)} delade ett recept med dig`,
        contextKey: "ctx_friend_share",
      };
    }
  } catch (err) {
    // Never let a personalization lookup block the send.
    logger.warn("[winback-context] friend-share lookup failed", { err });
  }

  // 2. Dietary prefs / onboarding never completed.
  const onboardingDone = userData.hasCompletedOnboarding === true;
  const hasPrefs =
    userData.allergenPreferences != null &&
    typeof userData.allergenPreferences === "object";
  if (!onboardingDone || !hasPrefs) {
    return {
      title: TITLE,
      body: "Ställ in dina kostpreferenser så hittar vi recept som passar dig",
      contextKey: "ctx_setup_prefs",
    };
  }

  // 3. They have recipes waiting.
  if (typeof userData.publicRecipeCount === "number" &&
      userData.publicRecipeCount > 0) {
    return {
      title: TITLE,
      body: "Dina recept väntar — kom tillbaka och laga något gott",
      contextKey: "ctx_saved_recipes",
    };
  }

  // 4. They have friends to re-engage with.
  if (typeof userData.friendsCount === "number" && userData.friendsCount > 0) {
    return {
      title: TITLE,
      body: "Dina vänner är på Butlery — se vad de lagar",
      contextKey: "ctx_has_friends",
    };
  }

  return null;
}
