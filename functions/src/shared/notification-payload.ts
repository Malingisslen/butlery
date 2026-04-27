/**
 * Notification payload schema (BUT-641).
 *
 * FCM data payloads are string-only maps. This helper enforces the
 * cross-platform contract every push must carry so the client can
 * deep-link the user to the right destination on tap:
 *
 *   - `route`            One of the six allowlisted top-level routes.
 *   - `targetId`         Entity ID for the destination (recipe id,
 *                        request id, session id, etc.). Empty string
 *                        for routes that don't need it (e.g. `/winback`,
 *                        inbox-style `/friend_request`).
 *   - `notificationType` Free-form analytics tag (e.g. `winback_d7`,
 *                        `friend_request_received`, `comment_posted`).
 *
 * Matching client-side allowlist lives in `lib/services/notifications/`
 * (BUT-641 client-side task). Any addition to this list MUST be made on
 * both sides in lockstep, otherwise unknown routes will be dropped to
 * `/` and CTR attribution will silently misbucket.
 *
 * Why a helper instead of leaving the literal in each call site:
 *   - One place to enforce the FCM string-only invariant. A stray
 *     `null`, `undefined`, or `Number` slipping into a data payload
 *     causes `messaging/invalid-argument` at delivery time, which is
 *     billed but undelivered.
 *   - One place to validate `route` against the allowlist. A typo in
 *     a sender (`/recipes` vs `/recipe`) would otherwise silently route
 *     users to the home screen.
 *   - Schema fields win on key collision with `additionalData`, so a
 *     legacy sender that already happened to set `route: "/somewhere"`
 *     in `additionalData` can't override a properly built payload.
 */

/**
 * Allowlisted top-level routes. Keep in sync with the client-side
 * `NotificationRoute` enum (BUT-641 client task).
 */
export const NOTIFICATION_ROUTES = [
  "/recipe",
  "/friend_request",
  "/comment_thread",
  "/cooking_session",
  "/menu_voting",
  "/winback",
] as const;

export type NotificationRoute = (typeof NOTIFICATION_ROUTES)[number];

export interface BuildNotificationPayloadOpts {
  route: NotificationRoute | string;
  /** Entity id for the destination. Empty string when route doesn't need one. */
  targetId: string;
  /** Free-form analytics tag — `friend_request_received`, `winback_d7`, ... */
  notificationType: string;
  /**
   * Optional pass-through fields the client may already consume (e.g.
   * legacy `imageUrl`, recipe-shared `senderName`). Keys colliding with
   * the schema are overridden by the schema fields — schema wins.
   */
  additionalData?: Record<string, string | undefined | null>;
}

/**
 * Builds the data payload for `messaging.send*` calls. Validates the
 * route against the allowlist and coerces `additionalData` so the
 * resulting object is `Record<string, string>` (FCM's contract).
 *
 * Throws `Error` if `route` is missing or unknown — this is a programmer
 * error, not a runtime one, and should fail tests/builds, not silently
 * drop the push.
 */
export function buildNotificationPayload(
  opts: BuildNotificationPayloadOpts
): Record<string, string> {
  const { route, targetId, notificationType, additionalData } = opts;

  if (typeof route !== "string" || route.length === 0) {
    throw new Error(
      "buildNotificationPayload: `route` is required and must be a non-empty string"
    );
  }
  if (!isKnownRoute(route)) {
    throw new Error(
      `buildNotificationPayload: unknown route "${route}". ` +
        `Allowed: ${NOTIFICATION_ROUTES.join(", ")}`
    );
  }
  if (typeof targetId !== "string") {
    throw new Error(
      "buildNotificationPayload: `targetId` is required and must be a string " +
        "(use empty string for routes that don't need an id)"
    );
  }
  if (typeof notificationType !== "string" || notificationType.length === 0) {
    throw new Error(
      "buildNotificationPayload: `notificationType` is required and must be a non-empty string"
    );
  }

  const out: Record<string, string> = {};

  // Pass-through first, schema fields win on collision.
  if (additionalData) {
    for (const [key, value] of Object.entries(additionalData)) {
      if (value === undefined || value === null) continue;
      // Coerce defensively — callers may have a legacy `Number` in
      // their `additionalData` shape. FCM rejects non-strings outright.
      out[key] = typeof value === "string" ? value : String(value);
    }
  }

  out.route = route;
  out.targetId = targetId;
  out.notificationType = notificationType;

  return out;
}

function isKnownRoute(route: string): route is NotificationRoute {
  return (NOTIFICATION_ROUTES as readonly string[]).includes(route);
}
